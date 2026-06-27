import Combine
import Foundation
import UIKit

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var cards: [VocabCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var images: [UUID: UIImage] = [:]
    @Published var loadingImageIDs: Set<UUID> = []

    private let service: GeminiService
    private var imageTask: Task<Void, Never>?

    /// Max object-image calls in flight at once — throttled so Identify doesn't fire a 6-wide burst.
    private let maxImagesInFlight = 3

    init(service: GeminiService? = nil) {
        self.service = service ?? GeminiService()
    }

    func load(data: Data) {
        guard let image = UIImage(data: data) else {
            errorMessage = "Could not load the selected photo."
            return
        }
        imageTask?.cancel()
        selectedImage = image
        cards = []
        images = [:]
        loadingImageIDs = []
        errorMessage = nil
    }

    func useSample() {
        imageTask?.cancel()
        selectedImage = DemoData.demoIllustration
        cards = DemoData.vocabCards
        images = Dictionary(uniqueKeysWithValues: DemoData.vocabCards.map { ($0.id, DemoData.placeholder(for: $0)) })
        loadingImageIDs = []
        errorMessage = nil
    }

    func identify() async {
        imageTask?.cancel()
        images = [:]
        loadingImageIDs = []
        isLoading = true
        errorMessage = nil
        do {
            cards = try await service.identifyVocab(in: selectedImage)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false

        guard errorMessage == nil else { return }
        let cardsToRender = cards
        imageTask = Task { [weak self] in
            await self?.generateImages(for: cardsToRender)
        }
    }

    /// Fan out one image call per card, capped at `maxImagesInFlight`. Cards fill in progressively;
    /// per-card failures are swallowed silently (the card simply stays image-less).
    private func generateImages(for cards: [VocabCard]) async {
        loadingImageIDs = Set(cards.map(\.id))
        let service = self.service
        await withTaskGroup(of: (UUID, UIImage?).self) { group in
            var iterator = cards.makeIterator()
            var enqueued = 0
            while enqueued < maxImagesInFlight, let card = iterator.next() {
                group.addTask { (card.id, try? await service.generateObjectImage(for: card)) }
                enqueued += 1
            }
            while let (id, image) = await group.next() {
                if let image { images[id] = image }
                loadingImageIDs.remove(id)
                if Task.isCancelled { break }
                if let card = iterator.next() {
                    group.addTask { (card.id, try? await service.generateObjectImage(for: card)) }
                }
            }
        }
    }
}
