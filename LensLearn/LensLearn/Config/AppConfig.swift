import Foundation

struct TargetLanguage {
    let name: String
    let romanizationLabel: String?
    let ttsLocale: String
}

enum AppConfig {
    static let targetLanguage = TargetLanguage(
        name: "Mandarin Chinese",
        romanizationLabel: "pinyin",
        ttsLocale: "zh-CN"
    )

    static let primaryTextModel = "gemini-3.5-flash"
    static let fallbackTextModel = "gemini-2.5-flash"
    static let primaryImageModel = "gemini-3.1-flash-image"
    static let fallbackImageModel = "gemini-2.5-flash-image"

    static var apiKey: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
        return value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var demoMode: Bool {
        apiKey.isEmpty
    }
}
