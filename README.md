# Lens & Learn

> Point your phone at anything → learn the words for what you see → watch them combine into an AI-generated image.

Google I/O 2026 hackathon project. ~4 hr build.

## What it does

1. **Snap or pick a photo.** The app identifies objects and labels each one in Mandarin — character, pinyin, an example sentence, and tap-to-hear pronunciation.
2. **Save words to your Word Bank.** Tap any word you want to keep.
3. **Forge.** One button weaves your saved words into a natural Mandarin sentence and generates an illustration of that sentence. Vocabulary becomes a picture.

## Platform

iOS app built with SwiftUI (Swift 6, iOS 17+).

## Tech stack

| Layer | Technology |
|---|---|
| Vision / vocab | Gemini 3.5 Flash |
| Sentence + image prompt | Gemini 3.5 Flash |
| Illustration | Nano Banana 2 (`gemini-3.1-flash-image`) |
| Pronunciation | Cloud Text-to-Speech (`cmn-CN-Wavenet-A`) |
| Provenance | SynthID watermark (automatic) |

All APIs use a single Google AI Studio API key — no OAuth required.

## Getting started

1. Clone the repo and open the `.xcodeproj` in Xcode.
2. Create a `Secrets.xcconfig` (git-ignored) with your key:
   ```
   GEMINI_API_KEY = your_key_here
   ```
3. Build and run on a device or simulator (iOS 17+).

## Project structure

```
LensAndLearn/
├── Features/
│   ├── Capture/        # PhotosPicker → Gemini vision → vocab cards
│   └── Forge/          # Word Bank → combine → Nano Banana → result screen
├── Networking/         # Shared API client
└── Models/             # VocabWord, ForgeResult, etc.
```

## Apple documentation

Fetch any Apple docs with:

```
npx @nshipster/sosumi fetch https://developer.apple.com/documentation/swift/array
```

## Demo script

1. Open app, pick a photo of a room. Vocab appears — tap a word to hear it.
2. Save 3–4 words.
3. Hit **Forge** → sentence assembles, illustration blooms.
4. *"Your vocabulary, combined into a sentence you can see — provenance-watermarked with SynthID."*
