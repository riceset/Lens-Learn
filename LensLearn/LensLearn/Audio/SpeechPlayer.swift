import AVFoundation
import Foundation

final class SpeechPlayer {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, locale: String) -> Bool {
        let utterance = AVSpeechUtterance(string: text)
        guard let voice = AVSpeechSynthesisVoice(language: locale) else {
            return false
        }
        utterance.voice = voice
        synthesizer.speak(utterance)
        return true
    }
}
