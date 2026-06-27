import Foundation
import SwiftData
import UIKit

/// SwiftData-backed persistence for a saved vocabulary card. The app's UI and
/// networking layers work with the lightweight `VocabCard` value type (which is
/// `Sendable` and crosses the async forge boundary); this `@Model` exists purely
/// so saved words — including their generated object image — survive screen swaps
/// and app relaunches.
@Model
final class SavedWord {
    /// Mirrors the `VocabCard.id` so in-memory selection state stays stable across
    /// store reloads.
    @Attribute(.unique) var id: UUID
    var word: String
    var romanization: String?
    var english: String
    var sentence: String
    /// JPEG bytes of the generated object image. Stored as a file (not inline in
    /// the store) since these blobs are large.
    @Attribute(.externalStorage) var imageData: Data?
    /// Insertion time, used to keep the Word Bank in a stable saved order.
    var createdAt: Date

    init(
        id: UUID,
        word: String,
        romanization: String?,
        english: String,
        sentence: String,
        imageData: Data?,
        createdAt: Date
    ) {
        self.id = id
        self.word = word
        self.romanization = romanization
        self.english = english
        self.sentence = sentence
        self.imageData = imageData
        self.createdAt = createdAt
    }

    /// Build a persisted record from an in-memory card, encoding its image to JPEG.
    convenience init(from card: VocabCard, createdAt: Date = Date()) {
        self.init(
            id: card.id,
            word: card.word,
            romanization: card.romanization,
            english: card.english,
            sentence: card.sentence,
            imageData: card.image?.jpegData(),
            createdAt: createdAt
        )
    }

    /// Decode back into the value type used throughout the app, preserving `id`
    /// and rehydrating the image.
    func toCard() -> VocabCard {
        VocabCard(
            id: id,
            word: word,
            romanization: romanization,
            english: english,
            sentence: sentence,
            image: imageData.flatMap(UIImage.init(data:))
        )
    }
}
