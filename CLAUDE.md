# Lens & Learn — CLAUDE.md

## Project

iOS app (SwiftUI) for a Google I/O 2026 hackathon. Users point their phone at any scene, get Mandarin vocabulary for what they see, save words, then tap "Forge" to combine them into one AI-generated sentence + illustration.

## Platform

- **iOS**, SwiftUI
- Minimum target: iOS 17+
- Language: Swift 6

## Architecture

```
Photo ──> Gemini 3.5 Flash (vision) ──> vocab cards (word, pinyin, sentence, pronunciation)
                                              │
                          tap to save ────────┘
                                              ▼
Word Bank ──> Gemini 3.5 Flash ──> { sentence + English image_prompt }
                                              │
                              image_prompt ───┘──> Nano Banana 2 ──> illustration
```

## APIs

| Feature | Model/API | Auth |
|---|---|---|
| Photo → vocab | `gemini-3.5-flash` | API key |
| Word combining + image prompt | `gemini-3.5-flash` | API key |
| Illustration generation | `gemini-3.1-flash-image` (fallback: `gemini-2.5-flash-image`) | API key |
| Pronunciation (TTS) | `texttospeech.googleapis.com`, voice `cmn-CN-Wavenet-A` | API key |

Store the API key in a local `Config.swift` or `Secrets.xcconfig` — never commit it.

## Key implementation details

- Send images to Gemini as base64-encoded strings (not file uploads).
- Force JSON output from Gemini for the vocab parse step — use `responseMimeType: "application/json"`.
- **Do NOT** ask the image model to draw the Mandarin sentence. Gemini produces a plain-English `image_prompt` describing the scene; send only that to Nano Banana.
- Word Bank is an in-memory `@State` / `@Observable` array — no database, no persistence needed.
- Target language for the demo: **Mandarin** with **pinyin** romanization.

## Scope (hackathon — ~4 hr build)

- No login, no persistence across sessions, one language only.
- One shared networking helper used by both feature areas.
- Beautiful demo path over edge-case handling.

## Fetching Apple documentation

```
npx @nshipster/sosumi fetch https://developer.apple.com/documentation/swift/array
```

Replace the URL with whichever framework page is relevant (SwiftUI, AVFoundation, PhotosUI, etc.).

## Suggested split

- **Person A** — Capture + vocab: `PhotosPicker` → base64 → Gemini vision call → vocab card UI.
- **Person B** — Forge + image: Word Bank view → combine call → Nano Banana call → result screen with loading state and image reveal.
