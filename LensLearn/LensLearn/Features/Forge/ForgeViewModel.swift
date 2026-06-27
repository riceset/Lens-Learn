import Combine
import Foundation

@MainActor
final class ForgeViewModel: ObservableObject {
    enum Phase {
        case idle
        case loading
        case ready(ForgeComposition)
        case error(String)
    }

    @Published var phase: Phase = .idle

    private let composer: FoundationForgeService

    init(composer: FoundationForgeService = FoundationForgeService()) {
        self.composer = composer
    }

    func forge(words: [VocabCard]) async {
        //   .idle --task--> .loading --compose(FoundationModels)--> .ready(sentence + grammar)
        //                       | err
        //                       v
        //                    .error --retry--> .loading
        phase = .loading
        do {
            let composition = try await composer.compose(words: words)
            phase = .ready(composition)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}
