import Foundation

/// Plain, framework-agnostic result of forging vocabulary cards into one sentence.
/// The Foundation Models layer produces this; the UI consumes it without importing
/// FoundationModels, so views/view models stay free of iOS 26 availability gates.
struct ForgeComposition {
    let sentence: String
    let romanization: String?
    let english: String
    let grammarNotes: [GrammarNote]
    /// Plain-English scene description handed to the image model (never rendered text).
    let imagePrompt: String
}

struct GrammarNote: Identifiable, Hashable {
    let id = UUID()
    /// The word, character, particle, or pattern being explained.
    let point: String
    /// Beginner-friendly explanation in English.
    let explanation: String
}
