import UIKit

#if canImport(ImagePlayground)
import ImagePlayground
#endif

/// On-device image generation via Apple's Image Playground (`ImageCreator`).
/// Used instead of a paid cloud image API — no API key or network credits required.
/// Requires iOS 18.4+ on an Apple Intelligence-capable device with the models downloaded.
enum ImagePlaygroundGenerator {
    static func generateImage(prompt: String) async throws -> UIImage {
        #if canImport(ImagePlayground)
        if #available(iOS 18.4, *) {
            let creator: ImageCreator
            do {
                creator = try await ImageCreator()
            } catch {
                throw GeminiError.imagePlaygroundUnavailable(error.localizedDescription)
            }

            // Prefer a 2D cartoon "illustration" (cute but recognizable); fall back to whatever exists.
            let preferredStyles: [ImagePlaygroundStyle] = [.illustration, .animation]
            guard let style = preferredStyles.first(where: { creator.availableStyles.contains($0) })
                    ?? creator.availableStyles.first else {
                throw GeminiError.imagePlaygroundUnavailable("No image styles available on this device.")
            }

            let stream = creator.images(for: [.text(prompt)], style: style, limit: 1)
            for try await created in stream {
                return UIImage(cgImage: created.cgImage)
            }
            throw GeminiError.missingGeneratedImage
        } else {
            throw GeminiError.imagePlaygroundUnavailable("Requires iOS 18.4 or later.")
        }
        #else
        throw GeminiError.imagePlaygroundUnavailable("ImagePlayground framework is not available in this build.")
        #endif
    }
}
