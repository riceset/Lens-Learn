import CoreGraphics
import Foundation
import UIKit

struct VocabCard: Identifiable, Hashable {
    let id: UUID
    let word: String
    let romanization: String?
    let english: String
    let sentence: String
    /// Object image for the card (nil until provided). Forge-time layout positions
    /// are computed dynamically from card relationships, not stored on the card.
    var image: UIImage?

    /// `id` defaults to a fresh UUID for freshly-identified cards, but can be
    /// injected when rehydrating a persisted `SavedWord` so selection state stays
    /// stable across store reloads.
    init(
        id: UUID = UUID(),
        word: String,
        romanization: String?,
        english: String,
        sentence: String,
        image: UIImage? = nil
    ) {
        self.id = id
        self.word = word
        self.romanization = romanization
        self.english = english
        self.sentence = sentence
        self.image = image
    }

    /// A copy of this card carrying the given image (used when persisting a card
    /// whose generated image was produced after identification).
    func withImage(_ image: UIImage?) -> VocabCard {
        var copy = self
        copy.image = image
        return copy
    }

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
