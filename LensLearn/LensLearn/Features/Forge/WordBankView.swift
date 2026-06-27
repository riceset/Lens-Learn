import SwiftUI

struct WordBankView: View {
    @EnvironmentObject private var wordBank: WordBank

    var body: some View {
        List {
            Section {
                ForEach(wordBank.saved) { card in
                    Button {
                        wordBank.toggleSelection(card)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.word)
                                    .font(.title3.weight(.semibold))
                                if let romanization = card.romanization {
                                    Text(romanization)
                                        .foregroundStyle(.secondary)
                                }
                                Text(card.english)
                            }
                            Spacer()
                            Image(systemName: wordBank.isSelected(card) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(wordBank.isSelected(card) ? Color.accentColor : Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    wordBank.remove(at: offsets)
                }
            } header: {
                Text("Tap to select words to forge")
            }

            Section {
                NavigationLink {
                    ForgeView(words: wordBank.selectedCards)
                } label: {
                    Label("Forge \(wordBank.selectedIDs.count) words", systemImage: "wand.and.stars")
                }
                .disabled(!wordBank.canForge)

                if !wordBank.canForge {
                    Text("Select at least two words to forge a sentence.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Word Bank")
    }
}
