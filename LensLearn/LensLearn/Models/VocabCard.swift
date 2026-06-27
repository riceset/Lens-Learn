import Foundation

struct VocabCard: Identifiable, Hashable {
    let id = UUID()
    let word: String
    let romanization: String?
    let english: String
    let sentence: String
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
