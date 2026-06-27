import Combine
import Foundation

@MainActor
final class ForgeViewModel: ObservableObject {
    enum Phase {
        case idle
        case loading
        /// Composition is ready; illustration is still rendering (or was skipped/failed).
        case sentenceReady(ForgeComposition)
        /// Composition plus a finished illustration.
        case imageReady(ForgeComposition, ForgeResult)
        case error(String)
    }

    @Published var phase: Phase = .idle

    private let composer: FoundationForgeService
    private let imageService: GeminiService

    init(composer: FoundationForgeService = FoundationForgeService(),
         imageService: GeminiService? = nil) {
        self.composer = composer
        self.imageService = imageService ?? GeminiService()
    }

    func forge(words: [VocabCard]) async {
        //   .idle --task--> .loading --compose(FoundationModels)--> .sentenceReady(+grammar)
        //                       | err                                       |
        //                       v                                           v generateImage(imagePrompt)
        //                    .error                              .imageReady  (image failure stays .sentenceReady)
        phase = .loading
        do {
            let composition = try await composer.compose(words: words)
            phase = .sentenceReady(composition)

            // Illustration is a bonus: a failure here must not discard the sentence.
            do {
                let image = try await imageService.generateImage(prompt: composition.imagePrompt)
                phase = .imageReady(composition, ForgeResult(
                    sentence: composition.sentence,
                    romanization: composition.romanization,
                    image: image,
                    synthIDWatermarked: !AppConfig.demoMode
                ))
            } catch {
                phase = .sentenceReady(composition)
            }
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}
