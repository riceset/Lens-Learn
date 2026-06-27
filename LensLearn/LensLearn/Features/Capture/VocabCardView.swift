import SwiftUI

struct VocabCardView: View {
    let card: VocabCard
    let isSaved: Bool
    let onSave: () -> Void

    @State private var voiceMessage: String?
    private let speechPlayer = SpeechPlayer()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.word)
                    .font(.system(size: 34, weight: .semibold))
                Spacer()
                Button {
                    if !speechPlayer.speak(card.word, locale: AppConfig.targetLanguage.ttsLocale) {
                        voiceMessage = "Voice unavailable on this device."
                    }
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderless)

                Button(action: onSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.borderless)
            }

            if let romanization = card.romanization {
                Text(romanization)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(card.english)
                .font(.title3.weight(.medium))

            Text(card.sentence)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let voiceMessage {
                Text(voiceMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
