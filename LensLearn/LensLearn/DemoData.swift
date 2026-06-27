import CoreGraphics
import Foundation
import UIKit

enum DemoData {
    /// Pixel/point coordinate space of the demo scene (origin top-left).
    private static let sceneSize = CGSize(width: 1024, height: 768)

    /// Each sample object: vocabulary plus where to crop its image from the demo scene.
    private struct Spec {
        let word: String
        let romanization: String
        let english: String
        let sentence: String
        let rect: CGRect
    }

    private static let specs: [Spec] = [
        Spec(word: "椅子", romanization: "yǐ zi", english: "chair",
             sentence: "这把椅子很舒服。", rect: CGRect(x: 150, y: 275, width: 225, height: 275)),
        Spec(word: "杯子", romanization: "bēi zi", english: "cup",
             sentence: "桌子上有一个杯子。", rect: CGRect(x: 400, y: 290, width: 250, height: 115)),
        Spec(word: "书", romanization: "shū", english: "book",
             sentence: "我喜欢看这本书。", rect: CGRect(x: 385, y: 448, width: 195, height: 55)),
        Spec(word: "植物", romanization: "zhí wù", english: "plant",
             sentence: "植物在窗边生长。", rect: CGRect(x: 610, y: 195, width: 220, height: 275)),
        Spec(word: "灯", romanization: "dēng", english: "lamp",
             sentence: "这盏灯很亮。", rect: CGRect(x: 715, y: 80, width: 170, height: 300))
    ]

    /// Sample flashcards with per-object cropped images, used as capture demo output
    /// and to seed the Word Bank for development.
    static let vocabCards: [VocabCard] = specs.map { spec in
        VocabCard(
            word: spec.word,
            romanization: spec.romanization,
            english: spec.english,
            sentence: spec.sentence,
            image: crop(scene, to: spec.rect)
        )
    }

    static let forgeSentence = "椅子旁边的杯子、书和植物在温暖的灯光下安静地陪着我学习。"
    static let forgeRomanization = "Yǐzi pángbiān de bēizi, shū hé zhíwù zài wēnnuǎn de dēngguāng xià ānjìng de péizhe wǒ xuéxí."
    static let imagePrompt = "A cozy desk scene with a chair beside a cup, a book, a green plant, and warm lamplight, bright educational illustration style."

    static var demoIllustration: UIImage? { scene }

    // MARK: - Scene rendering

    /// The full demo scene, rendered once at scale 1 so crops map 1:1 to points.
    private static let scene: UIImage = {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: sceneSize, format: format)
        return renderer.image { context in
            drawDemoIllustration(in: context.cgContext, rect: CGRect(origin: .zero, size: sceneSize))
        }
    }()

    private static func crop(_ image: UIImage, to rect: CGRect) -> UIImage {
        guard let cgImage = image.cgImage?.cropping(to: rect) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func drawDemoIllustration(in context: CGContext, rect: CGRect) {
        context.setFillColor(CGColor(red: 0.95, green: 0.96, blue: 0.92, alpha: 1))
        context.fill(rect)

        // Desk
        context.setFillColor(CGColor(red: 0.21, green: 0.46, blue: 0.42, alpha: 1))
        context.fill(CGRect(x: 110, y: 485, width: 804, height: 56))
        context.setFillColor(CGColor(red: 0.55, green: 0.36, blue: 0.24, alpha: 1))
        context.fill(CGRect(x: 150, y: 535, width: 724, height: 48))

        // Chair
        context.setFillColor(CGColor(red: 0.18, green: 0.28, blue: 0.50, alpha: 1))
        context.fillEllipse(in: CGRect(x: 165, y: 280, width: 190, height: 170))
        context.fill(CGRect(x: 230, y: 410, width: 60, height: 140))

        // Cup
        context.setFillColor(CGColor(red: 0.89, green: 0.32, blue: 0.20, alpha: 1))
        context.fill(CGRect(x: 410, y: 350, width: 230, height: 46))
        context.setFillColor(CGColor(red: 0.96, green: 0.78, blue: 0.32, alpha: 1))
        context.fill(CGRect(x: 430, y: 302, width: 190, height: 48))

        // Book (sitting on the desk)
        context.setFillColor(CGColor(red: 0.80, green: 0.25, blue: 0.30, alpha: 1))
        context.fill(CGRect(x: 410, y: 460, width: 150, height: 30))
        context.setFillColor(CGColor(red: 0.96, green: 0.95, blue: 0.90, alpha: 1))
        context.fill(CGRect(x: 418, y: 452, width: 134, height: 10))

        // Plant
        context.setFillColor(CGColor(red: 0.94, green: 0.94, blue: 0.86, alpha: 1))
        context.fillEllipse(in: CGRect(x: 690, y: 330, width: 110, height: 140))
        context.setFillColor(CGColor(red: 0.17, green: 0.47, blue: 0.25, alpha: 1))
        context.fillEllipse(in: CGRect(x: 680, y: 220, width: 70, height: 120))
        context.fillEllipse(in: CGRect(x: 740, y: 205, width: 80, height: 132))
        context.fillEllipse(in: CGRect(x: 625, y: 235, width: 75, height: 110))

        // Lamp
        context.setFillColor(CGColor(red: 0.97, green: 0.70, blue: 0.27, alpha: 1))
        context.fillEllipse(in: CGRect(x: 725, y: 90, width: 150, height: 120))
        context.setFillColor(CGColor(red: 0.22, green: 0.25, blue: 0.25, alpha: 1))
        context.fill(CGRect(x: 790, y: 210, width: 18, height: 160))
    }
}
