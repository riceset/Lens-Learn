import SwiftUI
import UIKit

extension Image {
    init(lensImage: UIImage) {
        self.init(uiImage: lensImage)
    }
}

extension UIImage {
    func jpegData(maxPixelSize: CGFloat = 1024, compressionQuality: CGFloat = 0.7) -> Data? {
        let sourceSize = size
        let scale = min(1, maxPixelSize / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
    }
}
