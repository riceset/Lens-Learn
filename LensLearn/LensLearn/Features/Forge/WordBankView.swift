import SwiftUI

struct WordBankView: View {
    @EnvironmentObject private var wordBank: WordBank

    var body: some View {
        List {
            Section {
                ForEach(wordBank.saved) { card in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.word)
                            .font(.title3.weight(.semibold))
                        if let romanization = card.romanization {
                            Text(romanization)
                                .foregroundStyle(.secondary)
                        }
                        Text(card.english)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    wordBank.remove(at: offsets)
                }
            }

            Section {
                NavigationLink {
                    ForgeView(words: wordBank.saved)
                } label: {
                    Label("Forge", systemImage: "wand.and.stars")
                }
                .disabled(!wordBank.canForge)

                if !wordBank.canForge {
                    Text("Save at least two words to forge a sentence.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Word Bank")
    }
}
