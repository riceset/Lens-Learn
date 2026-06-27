import Combine
import Foundation

@MainActor
final class WordBank: ObservableObject {
    @Published private(set) var saved: [VocabCard] = []
    /// IDs of cards the user has picked to forge into a sentence.
    @Published private(set) var selectedIDs: Set<UUID> = []

    /// Selected cards, in saved order, ready to forge.
    var selectedCards: [VocabCard] {
        saved.filter { selectedIDs.contains($0.id) }
    }

    var canForge: Bool {
        selectedIDs.count >= 2
    }

    func contains(_ card: VocabCard) -> Bool {
        saved.contains { $0.word == card.word }
    }

    func toggle(_ card: VocabCard) {
        if let index = saved.firstIndex(where: { $0.word == card.word }) {
            selectedIDs.remove(saved[index].id)
            saved.remove(at: index)
        } else {
            saved.append(card)
        }
    }

    func isSelected(_ card: VocabCard) -> Bool {
        selectedIDs.contains(card.id)
    }

    func toggleSelection(_ card: VocabCard) {
        if selectedIDs.contains(card.id) {
            selectedIDs.remove(card.id)
        } else {
            selectedIDs.insert(card.id)
        }
    }

    /// Seed the bank with sample flashcards (skips words already saved).
    func loadSamples() {
        for card in DemoData.vocabCards where !contains(card) {
            saved.append(card)
        }
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            selectedIDs.remove(saved[index].id)
            saved.remove(at: index)
        }
    }
}
