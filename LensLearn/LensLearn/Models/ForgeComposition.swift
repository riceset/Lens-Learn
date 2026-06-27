import Foundation

/// Plain, framework-agnostic result of forging vocabulary cards into one sentence.
/// The Foundation Models layer produces this; the UI consumes it without importing
/// FoundationModels, so views/view models stay free of iOS 26 availability gates.
struct ForgeComposition {
    let sentence: String
    let romanization: String?
    let english: String
    let grammarNotes: [GrammarNote]
    /// Forge-time spatial arrangement of the cards, derived from their relationships.
    let placements: [CardPlacement]
}

/// Where one card sits on the layout canvas, computed from object relationships
/// (e.g. a cup rests on top of a desk). Position is normalized 0...1, origin top-left.
struct CardPlacement: Identifiable, Hashable {
    let id = UUID()
    let word: String
    let x: Double
    let y: Double
    /// Relative size, ~0.15 (small) ... 1.0 (large).
    let scale: Double
    /// Stacking order; higher is drawn in front.
    let zIndex: Int
}

struct GrammarNote: Identifiable, Hashable {
    let id = UUID()
    /// The word, character, particle, or pattern being explained.
    let point: String
    /// Beginner-friendly explanation in English.
    let explanation: String
}
