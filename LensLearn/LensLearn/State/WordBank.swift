import Combine
import Foundation

@MainActor
final class WordBank: ObservableObject {
    @Published private(set) var saved: [VocabCard] = []

    var canForge: Bool {
        saved.count >= 2
    }

    func contains(_ card: VocabCard) -> Bool {
        saved.contains { $0.word == card.word }
    }

    func toggle(_ card: VocabCard) {
        if let index = saved.firstIndex(where: { $0.word == card.word }) {
            saved.remove(at: index)
        } else {
            saved.append(card)
        }
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            saved.remove(at: index)
        }
    }
}
