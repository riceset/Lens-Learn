import SwiftUI

struct ForgeView: View {
    let words: [VocabCard]
    @StateObject private var viewModel = ForgeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch viewModel.phase {
                case .idle:
                    ProgressView()
                        .task { await viewModel.forge(words: words) }
                case .loading:
                    ProgressView("Forging...")
                        .font(.title3)
                case .sentenceReady(let composition):
                    compositionBlock(composition)
                    ProgressView("Creating illustration...")
                case .imageReady(let composition, let result):
                    compositionBlock(composition)
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
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    @ViewBuilder
    private func compositionBlock(_ composition: ForgeComposition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(composition.sentence)
                .font(.largeTitle.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let romanization = composition.romanization {
                Text(romanization)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(composition.english)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !composition.grammarNotes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Grammar")
                    .font(.headline)
                ForEach(composition.grammarNotes) { note in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(note.point)
                            .font(.subheadline.weight(.semibold))
                        Text(note.explanation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
