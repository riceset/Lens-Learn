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
                case .ready(let composition):
                    sentenceIllustration
                    if !composition.placements.isEmpty {
                        layoutCanvas(composition.placements)
                    }
                    compositionBlock(composition)
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
        case .ready: "ready"
        case .error: "error"
        }
    }

    /// Apple Image Playground illustration of the forged sentence (or a spinner
    /// while it generates). Hidden if generation failed / is unavailable.
    @ViewBuilder
    private var sentenceIllustration: some View {
        if let image = viewModel.sentenceImage {
            Image(lensImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if viewModel.isSentenceImageLoading {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Illustrating the sentence...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
        }
    }

    private func layoutCanvas(_ placements: [CardPlacement]) -> some View {
        GeometryReader { geo in
            ZStack {
                ForEach(placements) { placement in
                    if let card = words.first(where: { $0.word == placement.word }),
                       let image = card.image {
                        let side = min(geo.size.width, geo.size.height) * 0.5 * placement.scale
                        Image(lensImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: side, height: side)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 3, y: 2)
                            .position(
                                x: placement.x * geo.size.width,
                                y: placement.y * geo.size.height
                            )
                            .zIndex(Double(placement.zIndex))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
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
