import Combine
import Foundation
import UIKit

@MainActor
final class ForgeViewModel: ObservableObject {
    enum Phase {
        case idle
        case loading
        case ready(ForgeComposition)
        case error(String)
    }

    @Published var phase: Phase = .idle
    /// Apple Image Playground illustration of the forged sentence (nil until ready
    /// or if generation fails / is unavailable on this device).
    @Published var sentenceImage: UIImage?
    @Published var isSentenceImageLoading = false

    private let composer: FoundationForgeService
    private let imageService: GeminiService
    private var imageTask: Task<Void, Never>?

    init(
        composer: FoundationForgeService = FoundationForgeService(),
        imageService: GeminiService = GeminiService()
    ) {
        self.composer = composer
        self.imageService = imageService
    }

    func forge(words: [VocabCard]) async {
        //   .idle --task--> .loading --compose(FoundationModels)--> .ready(sentence + grammar)
        //                       | err                                      |
        //                       v                                          v
        //                    .error --retry--> .loading        Image Playground illustration
        imageTask?.cancel()
        sentenceImage = nil
        isSentenceImageLoading = false
        phase = .loading
        do {
            let composition = try await composer.compose(words: words)
            phase = .ready(composition)
            generateSentenceImage(for: composition)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// Kick off the on-device illustration for the whole sentence. Plain-English
    /// prompt only (per project rules, never ask the image model to render Mandarin).
    /// Failures are swallowed quietly — the sentence + layout still stand on their own.
    private func generateSentenceImage(for composition: ForgeComposition) {
        let prompt = """
        A warm, friendly illustration of this scene: \(composition.english) \
        Cohesive single picture, soft colors, no text.
        """
        isSentenceImageLoading = true
        let service = imageService
        imageTask = Task { [weak self] in
            let image = try? await service.generateImage(prompt: prompt)
            guard !Task.isCancelled else { return }
            self?.sentenceImage = image
            self?.isSentenceImageLoading = false
        }
    }
}
