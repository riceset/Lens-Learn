import Foundation
import UIKit

struct GeminiService {
    private let apiKey: String
    private let demoMode: Bool
    private let session: URLSession
    private let targetLanguage: TargetLanguage

    init(
        apiKey: String = AppConfig.apiKey,
        demoMode: Bool = AppConfig.demoMode,
        targetLanguage: TargetLanguage = AppConfig.targetLanguage
    ) {
        self.apiKey = apiKey
        self.demoMode = demoMode
        self.targetLanguage = targetLanguage
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        self.session = URLSession(configuration: configuration)
    }

    func identifyVocab(in image: UIImage?) async throws -> [VocabCard] {
        if demoMode {
            try await Task.sleep(for: .milliseconds(650))
            return DemoData.vocabCards
        }
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }
        guard let jpegData = image?.jpegData() else { throw GeminiError.invalidImageData }

        let romanizationInstruction = targetLanguage.romanizationLabel.map {
            "Include \($0) in romanization."
        } ?? "Set romanization to null."

        let prompt = """
        Identify 4 to 6 salient physical objects visible in this photo. Return beginner-friendly nouns in \(targetLanguage.name).
        \(romanizationInstruction)
        For each object return JSON fields: word, romanization, english, sentence.
        The sentence must be a short natural example in \(targetLanguage.name).
        Only return concrete objects you can see, not abstract themes.
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": [
                        "mime_type": "image/jpeg",
                        "data": jpegData.base64EncodedString()
                    ]]
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": vocabSchema
            ]
        ]

        let response = try await postGenerateContent(model: AppConfig.primaryTextModel, body: body)
        let dtos: [VocabCardDTO] = try decodeJSONText(from: response)
        return dtos.map { $0.card() }
    }

    func forge(words: [VocabCard]) async throws -> (sentence: String, romanization: String?, imagePrompt: String) {
        if demoMode {
            try await Task.sleep(for: .milliseconds(700))
            return (DemoData.forgeSentence, DemoData.forgeRomanization, DemoData.imagePrompt)
        }
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        let wordsText = words.map {
            "- \($0.word) (\($0.english))"
        }.joined(separator: "\n")
        let romanizationInstruction = targetLanguage.romanizationLabel.map {
            "Return \($0) in romanization."
        } ?? "Return romanization as null."

        let prompt = """
        Weave these vocabulary words into one natural sentence in \(targetLanguage.name).
        \(romanizationInstruction)
        Return JSON with fields sentence, romanization, image_prompt.
        The image_prompt must be plain English describing the scene and must not ask for rendered text.

        Words:
        \(wordsText)
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [["text": prompt]]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": forgeSchema
            ]
        ]

        let response = try await postGenerateContent(model: AppConfig.primaryTextModel, body: body)
        let dto: ForgeResponseDTO = try decodeJSONText(from: response)
        return (dto.sentence, dto.romanization, dto.imagePrompt)
    }

    func generateImage(prompt: String) async throws -> UIImage {
        if demoMode {
            try await Task.sleep(for: .milliseconds(850))
            guard let image = DemoData.demoIllustration else { throw GeminiError.malformedResponse }
            return image
        }
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        let body: [String: Any] = [
            "model": AppConfig.primaryImageModel,
            "input": [
                ["type": "text", "text": prompt]
            ]
        ]

        let response = try await postInteraction(body: body)
        guard let base64 = response.outputImage?.data,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            throw GeminiError.missingGeneratedImage
        }
        return image
    }

    private func postGenerateContent(model: String, body: [String: Any]) async throws -> GenerateContentResponse {
        guard var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw GeminiError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw GeminiError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.badStatus(httpResponse.statusCode, body)
        }
        return try JSONDecoder().decode(GenerateContentResponse.self, from: data)
    }

    private func postInteraction(body: [String: Any]) async throws -> InteractionResponse {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.badStatus(httpResponse.statusCode, body)
        }
        return try JSONDecoder().decode(InteractionResponse.self, from: data)
    }

    private func decodeJSONText<T: Decodable>(from response: GenerateContentResponse) throws -> T {
        guard let text = response.candidates.first?.content.parts.compactMap(\.text).first else {
            throw GeminiError.emptyResponse
        }
        guard let data = text.data(using: .utf8) else {
            throw GeminiError.malformedResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private var vocabSchema: [String: Any] {
        [
            "type": "ARRAY",
            "items": [
                "type": "OBJECT",
                "properties": [
                    "word": ["type": "STRING"],
                    "romanization": ["type": "STRING", "nullable": true],
                    "english": ["type": "STRING"],
                    "sentence": ["type": "STRING"]
                ],
                "required": ["word", "english", "sentence"]
            ]
        ]
    }

    private var forgeSchema: [String: Any] {
        [
            "type": "OBJECT",
            "properties": [
                "sentence": ["type": "STRING"],
                "romanization": ["type": "STRING", "nullable": true],
                "image_prompt": ["type": "STRING"]
            ],
            "required": ["sentence", "image_prompt"]
        ]
    }
}
