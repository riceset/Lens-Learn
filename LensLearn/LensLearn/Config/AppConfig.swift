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
        // Prefer the scheme's environment variable (set in Edit Scheme ▸ Run ▸ Arguments),
        // which is only injected when launched from Xcode. Fall back to the Info.plist value
        // baked in from Secrets.xcconfig for standalone installs.
        if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let value = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
        return value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var demoMode: Bool {
        apiKey.isEmpty
    }
}
