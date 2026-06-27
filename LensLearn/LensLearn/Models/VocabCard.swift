import CoreGraphics
import Foundation
import UIKit

struct VocabCard: Identifiable, Hashable {
    let id = UUID()
    let word: String
    let romanization: String?
    let english: String
    let sentence: String
    /// Object image for the card (nil until provided). Forge-time layout positions
    /// are computed dynamically from card relationships, not stored on the card.
    var image: UIImage?

    // Identity is the UUID; `image` (UIImage) is not Hashable, so synthesize manually.
    static func == (lhs: VocabCard, rhs: VocabCard) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct VocabCardDTO: Decodable {
    let word: String
    let romanization: String?
    let english: String
    let sentence: String

    func card() -> VocabCard {
        VocabCard(word: word, romanization: romanization, english: english, sentence: sentence)
    }
}
