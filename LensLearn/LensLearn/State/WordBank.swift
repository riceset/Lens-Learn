import Combine
import Foundation
import SwiftData

@MainActor
final class WordBank: ObservableObject {
    /// In-memory cache of persisted cards, hydrated from SwiftData and kept in
    /// saved (insertion) order. The store is the source of truth; this drives the UI.
    @Published private(set) var saved: [VocabCard] = []
    /// IDs of cards the user has picked to forge into a sentence. Selection is
    /// transient UI state, so it is intentionally not persisted.
    @Published private(set) var selectedIDs: Set<UUID> = []

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    /// Convenience for previews/tests: an isolated in-memory store.
    convenience init() {
        let container = try! ModelContainer(
            for: SavedWord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        self.init(context: container.mainContext)
    }

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

    /// Save the card (with its image) if not already saved by word, otherwise remove it.
    func toggle(_ card: VocabCard) {
        if let existing = storedWord(matching: card.word) {
            selectedIDs.remove(existing.id)
            context.delete(existing)
        } else {
            context.insert(SavedWord(from: card))
        }
        persist()
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
            context.insert(SavedWord(from: card))
        }
        persist()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets {
            let card = saved[index]
            selectedIDs.remove(card.id)
            if let existing = storedWord(matching: card.word) {
                context.delete(existing)
            }
        }
        persist()
    }

    // MARK: - Persistence helpers

    private func persist() {
        try? context.save()
        refresh()
    }

    private func refresh() {
        let descriptor = FetchDescriptor<SavedWord>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let words = (try? context.fetch(descriptor)) ?? []
        saved = words.map { $0.toCard() }
    }

    private func storedWord(matching word: String) -> SavedWord? {
        let descriptor = FetchDescriptor<SavedWord>(
            predicate: #Predicate { $0.word == word }
        )
        return try? context.fetch(descriptor).first
    }
}
