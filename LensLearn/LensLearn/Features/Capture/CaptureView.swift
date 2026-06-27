import PhotosUI
import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var wordBank: WordBank
    @StateObject private var viewModel = CaptureViewModel()
    @State private var pickerItem: PhotosPickerItem?

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if AppConfig.demoMode {
                    Text("Demo mode: add a Gemini API key to enable live vision and image generation.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                imagePreview

                HStack {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Pick Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.useSample()
                    } label: {
                        Label("Use Sample", systemImage: "sparkles")
                    }

                    Button {
                        Task { await viewModel.identify() }
                    } label: {
                        Label("Identify", systemImage: "viewfinder")
                    }
                    .disabled(viewModel.isLoading)
                }

                if viewModel.isLoading {
                    ProgressView("Identifying objects...")
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(viewModel.cards) { card in
                        VocabCardView(
                            card: card,
                            isSaved: wordBank.contains(card),
                            image: viewModel.images[card.id],
                            isImageLoading: viewModel.loadingImageIDs.contains(card.id),
                            onSave: { wordBank.toggle(card) }
                        )
                    }
                }
            }
            .padding()
        }
        .task(id: pickerItem) {
            guard let pickerItem else { return }
            do {
                if let data = try await pickerItem.loadTransferable(type: Data.self) {
                    viewModel.load(data: data)
                }
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image = viewModel.selectedImage {
            Image(lensImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 340)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.04))
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                    Text("Choose a photo or use the sample scene.")
                        .font(.headline)
                }
                .foregroundStyle(.secondary)
            }
            .frame(height: 300)
        }
    }
}
