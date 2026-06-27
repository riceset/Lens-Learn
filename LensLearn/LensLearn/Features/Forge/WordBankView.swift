import SwiftUI

struct WordBankView: View {
    @EnvironmentObject private var wordBank: WordBank

    var body: some View {
        List {
            if wordBank.saved.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No words yet", systemImage: "bookmark")
                    } description: {
                        Text("Save words from a photo, or load sample words to try forging.")
                    } actions: {
                        Button("Load sample words") { wordBank.loadSamples() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section {
                ForEach(wordBank.saved) { card in
                    Button {
                        wordBank.toggleSelection(card)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            if let image = card.image {
                                Image(lensImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    wordBank.loadSamples()
                } label: {
                    Label("Load samples", systemImage: "sparkles")
                }
            }
        }
    }
}
