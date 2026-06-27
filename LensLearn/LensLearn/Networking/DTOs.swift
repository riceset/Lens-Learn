import Foundation

struct GenerateContentResponse: Decodable {
    let candidates: [Candidate]

    struct Candidate: Decodable {
        let content: Content
    }

    struct Content: Decodable {
        let parts: [Part]
    }

    struct Part: Decodable {
        let text: String?
        let inlineData: InlineData?

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }
    }

    struct InlineData: Decodable {
        let mimeType: String?
        let data: String

        enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }
}

struct ForgeResponseDTO: Decodable {
    let sentence: String
    let romanization: String?
    let imagePrompt: String

    enum CodingKeys: String, CodingKey {
        case sentence
        case romanization
        case imagePrompt = "image_prompt"
    }
}

struct InteractionResponse: Decodable {
    let outputImage: OutputImage?

    enum CodingKeys: String, CodingKey {
        case outputImage = "output_image"
    }

    struct OutputImage: Decodable {
        let data: String
        let mimeType: String?

        enum CodingKeys: String, CodingKey {
            case data
            case mimeType = "mime_type"
        }
    }
}

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidImageData
    case invalidURL
    case emptyResponse
    case badStatus(Int, String)
    case malformedResponse
    case missingGeneratedImage

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Missing Gemini API key. Demo mode is available without network calls."
        case .invalidImageData:
            "Could not prepare the selected image."
        case .invalidURL:
            "Could not build the Gemini request URL."
        case .emptyResponse:
            "Gemini returned an empty response."
        case .badStatus(let status, let body):
            "Gemini request failed (\(status)): \(body)"
        case .malformedResponse:
            "Gemini returned a response the app could not read."
        case .missingGeneratedImage:
            "Gemini did not return an image."
        }
    }
}
