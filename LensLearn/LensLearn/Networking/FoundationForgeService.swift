import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Combines selected vocabulary cards into one natural sentence with grammar notes,
/// using Apple's on-device Foundation Models (iOS 26+). Produces a plain
/// `ForgeComposition` so the rest of the app needs no FoundationModels import.
struct FoundationForgeService {
    enum ForgeUnavailable: LocalizedError {
        case osTooOld
        case modelUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .osTooOld:
                return "On-device composition requires iOS 26 or later."
            case .modelUnavailable(let reason):
                return reason
            }
        }
    }

    let targetLanguage: TargetLanguage

    init(targetLanguage: TargetLanguage = AppConfig.targetLanguage) {
        self.targetLanguage = targetLanguage
    }

    func compose(words: [VocabCard]) async throws -> ForgeComposition {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await composeOnDevice(words: words)
        } else {
            throw ForgeUnavailable.osTooOld
        }
        #else
        throw ForgeUnavailable.osTooOld
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func composeOnDevice(words: [VocabCard]) async throws -> ForgeComposition {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw ForgeUnavailable.modelUnavailable(Self.describe(reason))
        @unknown default:
            throw ForgeUnavailable.modelUnavailable("The on-device model is unavailable right now.")
        }

        let romanizationLine = targetLanguage.romanizationLabel.map {
            "Provide the \($0) romanization in the `romanization` field."
        } ?? "Leave the `romanization` field empty."

        let instructions = """
        You are a patient \(targetLanguage.name) tutor for beginners. Weave a learner's \
        saved vocabulary into one natural, grammatically correct sentence, then explain the \
        grammar simply. Keep the sentence short and beginner-appropriate.
        """

        let session = LanguageModelSession(instructions: instructions)

        let wordList = words.map { card -> String in
            if let romanization = card.romanization {
                return "- \(card.word) (\(romanization)) — \(card.english)"
            }
            return "- \(card.word) — \(card.english)"
        }.joined(separator: "\n")

        let prompt = """
        Compose ONE natural sentence in \(targetLanguage.name) that uses ALL of these words:
        \(wordList)

        \(romanizationLine)
        Add 2 to 4 short grammar notes explaining the key words, particles, or sentence patterns.

        Then arrange these objects on a canvas as they would relate in the real world. \
        For every word above, output one placement using its real-world relationships: \
        large supporting objects (a desk, the ground) sit low and wide; objects that rest \
        on or above another sit higher with a larger zIndex; size reflects real relative \
        size. Use normalized coordinates where x=0 is left, x=1 is right, y=0 is top, y=1 \
        is bottom. Output exactly one placement per word, using the words exactly as written.
        """

        let response = try await session.respond(to: prompt, generating: GeneratedComposition.self)
        let content = response.content

        let notes = content.grammarNotes.map {
            GrammarNote(point: $0.point, explanation: $0.explanation)
        }
        let romanization = content.romanization.trimmingCharacters(in: .whitespacesAndNewlines)

        let validWords = Set(words.map(\.word))
        let placements = content.placements
            .filter { validWords.contains($0.word) }
            .map { placement in
                CardPlacement(
                    word: placement.word,
                    x: placement.x.clamped(to: 0...1),
                    y: placement.y.clamped(to: 0...1),
                    scale: placement.scale.clamped(to: 0.15...1),
                    zIndex: placement.zIndex
                )
            }

        return ForgeComposition(
            sentence: content.sentence,
            romanization: romanization.isEmpty ? nil : romanization,
            english: content.english,
            grammarNotes: notes,
            placements: placements
        )
    }

    @available(iOS 26.0, *)
    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to compose sentences on-device."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        @unknown default:
            return "The on-device model is unavailable right now."
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct GeneratedComposition {
    @Guide(description: "One natural, grammatically correct sentence in the target language that uses every provided vocabulary word at least once.")
    var sentence: String

    @Guide(description: "Romanization of the sentence (e.g. Hanyu Pinyin with tone marks). Empty string if not applicable.")
    var romanization: String

    @Guide(description: "A natural English translation of the sentence.")
    var english: String

    @Guide(description: "Two to four short grammar notes about notable words, particles, or patterns used in the sentence.")
    var grammarNotes: [GeneratedGrammarNote]

    @Guide(description: "One placement per provided word, arranging the objects by their real-world spatial relationships.")
    var placements: [GeneratedPlacement]
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedGrammarNote {
    @Guide(description: "The word, character, particle, or grammar pattern from the sentence being explained.")
    var point: String

    @Guide(description: "A concise, beginner-friendly explanation in English of how this grammar point works.")
    var explanation: String
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedPlacement {
    @Guide(description: "The vocabulary word being placed; must exactly match one of the provided words.")
    var word: String

    @Guide(description: "Horizontal center from 0 (far left) to 1 (far right).")
    var x: Double

    @Guide(description: "Vertical center from 0 (top) to 1 (bottom). Supporting objects like a desk or the ground sit lower (larger y).")
    var y: Double

    @Guide(description: "Relative size from 0.15 (small) to 1.0 (large), reflecting the object's real-world size.")
    var scale: Double

    @Guide(description: "Stacking order; higher is drawn in front. An object resting on another should have a higher zIndex than what it rests on.")
    var zIndex: Int
}
#endif

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
