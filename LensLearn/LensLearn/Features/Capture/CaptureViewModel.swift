import Combine
import Foundation
import UIKit

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var cards: [VocabCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: GeminiService

    init(service: GeminiService? = nil) {
        self.service = service ?? GeminiService()
    }

    func load(data: Data) {
        guard let image = UIImage(data: data) else {
            errorMessage = "Could not load the selected photo."
            return
        }
        selectedImage = image
        cards = []
        errorMessage = nil
    }

    func useSample() {
        selectedImage = DemoData.demoIllustration
        cards = DemoData.vocabCards
        errorMessage = nil
    }

    func identify() async {
        isLoading = true
        errorMessage = nil
        do {
            cards = try await service.identifyVocab(in: selectedImage)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
