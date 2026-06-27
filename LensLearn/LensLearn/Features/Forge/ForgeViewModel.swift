import Combine
import Foundation

@MainActor
final class ForgeViewModel: ObservableObject {
    enum Phase {
        case idle
        case loading
        case sentenceReady(sentence: String, romanization: String?)
        case imageReady(ForgeResult)
        case error(String)
    }

    @Published var phase: Phase = .idle

    private let service: GeminiService

    init(service: GeminiService? = nil) {
        self.service = service ?? GeminiService()
    }

    func forge(words: [VocabCard]) async {
        //                 forge(words) --ok--> sentence+pinyin+image_prompt
        //   .idle --tap--> .loading --------------------------------------.
        //                    | err                                         |
        //                    v                                             v
        //                 .error <--err-- generateImage(image_prompt)   .sentenceReady
        //                    ^                    | ok                     |
        //                    |                    v                        |
        //                    '---- retry ---- .imageReady (bloom) <--------'
        phase = .loading
        do {
            let forged = try await service.forge(words: words)
            phase = .sentenceReady(sentence: forged.sentence, romanization: forged.romanization)
            let image = try await service.generateImage(prompt: forged.imagePrompt)
            phase = .imageReady(ForgeResult(
                sentence: forged.sentence,
                romanization: forged.romanization,
                image: image,
                synthIDWatermarked: !AppConfig.demoMode
            ))
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}
