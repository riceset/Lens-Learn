import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import PhotosUI
#endif

struct CaptureView: View {
    @EnvironmentObject private var wordBank: WordBank
    @StateObject private var viewModel = CaptureViewModel()
    #if os(iOS)
    @State private var pickerItem: PhotosPickerItem?
    #else
    @State private var isImportingPhoto = false
    #endif

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
                    #if os(iOS)
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Pick Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    #else
                    Button {
                        isImportingPhoto = true
                    } label: {
                        Label("Pick Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)
                    #endif

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
                            onSave: { wordBank.toggle(card) }
                        )
                    }
                }
            }
            .padding()
        }
        #if os(iOS)
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
        #else
        .fileImporter(isPresented: $isImportingPhoto, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                guard url.startAccessingSecurityScopedResource() else {
                    viewModel.errorMessage = "Could not access the selected photo."
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                viewModel.load(data: try Data(contentsOf: url))
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        #endif
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image = viewModel.selectedImage {
            Image(platformImage: image)
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
