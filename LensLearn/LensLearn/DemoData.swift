import CoreGraphics
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DemoData {
    static let vocabCards: [VocabCard] = [
        VocabCard(word: "椅子", romanization: "yǐ zi", english: "chair", sentence: "这把椅子很舒服。"),
        VocabCard(word: "杯子", romanization: "bēi zi", english: "cup", sentence: "桌子上有一个杯子。"),
        VocabCard(word: "植物", romanization: "zhí wù", english: "plant", sentence: "植物在窗边生长。"),
        VocabCard(word: "书", romanization: "shū", english: "book", sentence: "我喜欢看这本书。"),
        VocabCard(word: "灯", romanization: "dēng", english: "lamp", sentence: "这盏灯很亮。")
    ]

    static let forgeSentence = "椅子旁边的杯子、书和植物在温暖的灯光下安静地陪着我学习。"
    static let forgeRomanization = "Yǐzi pángbiān de bēizi, shū hé zhíwù zài wēnnuǎn de dēngguāng xià ānjìng de péizhe wǒ xuéxí."
    static let imagePrompt = "A cozy desk scene with a chair beside a cup, a book, a green plant, and warm lamplight, bright educational illustration style."

    static var demoIllustration: PlatformImage? {
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 768))
        return renderer.image { context in
            drawDemoIllustration(in: context.cgContext, rect: CGRect(x: 0, y: 0, width: 1024, height: 768))
        }
        #elseif os(macOS)
        let image = PlatformImage(size: NSSize(width: 1024, height: 768))
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            drawDemoIllustration(in: context, rect: CGRect(x: 0, y: 0, width: 1024, height: 768))
        }
        image.unlockFocus()
        return image
        #endif
    }

    private static func drawDemoIllustration(in context: CGContext, rect: CGRect) {
        context.setFillColor(CGColor(red: 0.95, green: 0.96, blue: 0.92, alpha: 1))
        context.fill(rect)

        context.setFillColor(CGColor(red: 0.21, green: 0.46, blue: 0.42, alpha: 1))
        context.fill(CGRect(x: 110, y: 485, width: 804, height: 56))
        context.setFillColor(CGColor(red: 0.55, green: 0.36, blue: 0.24, alpha: 1))
        context.fill(CGRect(x: 150, y: 535, width: 724, height: 48))

        context.setFillColor(CGColor(red: 0.18, green: 0.28, blue: 0.50, alpha: 1))
        context.fillEllipse(in: CGRect(x: 165, y: 280, width: 190, height: 170))
        context.fill(CGRect(x: 230, y: 410, width: 60, height: 140))

        context.setFillColor(CGColor(red: 0.89, green: 0.32, blue: 0.20, alpha: 1))
        context.fill(CGRect(x: 410, y: 350, width: 230, height: 46))
        context.setFillColor(CGColor(red: 0.96, green: 0.78, blue: 0.32, alpha: 1))
        context.fill(CGRect(x: 430, y: 302, width: 190, height: 48))

        context.setFillColor(CGColor(red: 0.94, green: 0.94, blue: 0.86, alpha: 1))
        context.fillEllipse(in: CGRect(x: 690, y: 330, width: 110, height: 140))
        context.setFillColor(CGColor(red: 0.17, green: 0.47, blue: 0.25, alpha: 1))
        context.fillEllipse(in: CGRect(x: 680, y: 220, width: 70, height: 120))
        context.fillEllipse(in: CGRect(x: 740, y: 205, width: 80, height: 132))
        context.fillEllipse(in: CGRect(x: 625, y: 235, width: 75, height: 110))

        context.setFillColor(CGColor(red: 0.97, green: 0.70, blue: 0.27, alpha: 1))
        context.fillEllipse(in: CGRect(x: 725, y: 90, width: 150, height: 120))
        context.setFillColor(CGColor(red: 0.22, green: 0.25, blue: 0.25, alpha: 1))
        context.fill(CGRect(x: 790, y: 210, width: 18, height: 160))
    }
}
