import SwiftUI

struct ForgeView: View {
    let words: [VocabCard]
    @StateObject private var viewModel = ForgeViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch viewModel.phase {
            case .idle:
                ProgressView()
                    .task { await viewModel.forge(words: words) }
            case .loading:
                ProgressView("Forging...")
                    .font(.title3)
            case .sentenceReady(let sentence, let romanization):
                sentenceBlock(sentence: sentence, romanization: romanization)
                ProgressView("Creating illustration...")
            case .imageReady(let result):
                sentenceBlock(sentence: result.sentence, romanization: result.romanization)
                if let image = result.image {
                    Image(lensImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                if result.synthIDWatermarked {
                    Text("Generated illustration is provenance-watermarked with SynthID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .error(let message):
                Text(message)
                    .foregroundStyle(.red)
                Button {
                    Task { await viewModel.forge(words: words) }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }
            Spacer()
        }
        .padding()
        .animation(.easeOut(duration: 0.35), value: phaseKey)
        .navigationTitle("Forge")
    }

    private var phaseKey: String {
        switch viewModel.phase {
        case .idle: "idle"
        case .loading: "loading"
        case .sentenceReady: "sentence"
        case .imageReady: "image"
        case .error: "error"
        }
    }

    private func sentenceBlock(sentence: String, romanization: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sentence)
                .font(.largeTitle.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let romanization {
                Text(romanization)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
