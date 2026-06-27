import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

extension PlatformImage {
    func jpegData(maxPixelSize: CGFloat = 1024, compressionQuality: CGFloat = 0.7) -> Data? {
        #if os(iOS)
        let sourceSize = size
        let scale = min(1, maxPixelSize / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: compressionQuality)
        #elseif os(macOS)
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let width = CGFloat(bitmap.pixelsWide)
        let height = CGFloat(bitmap.pixelsHigh)
        let scale = min(1, maxPixelSize / max(width, height))
        let targetSize = NSSize(width: width * scale, height: height * scale)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        resized.unlockFocus()

        guard let resizedTiff = resized.tiffRepresentation,
              let resizedBitmap = NSBitmapImageRep(data: resizedTiff) else {
            return nil
        }
        return resizedBitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #endif
    }
}
