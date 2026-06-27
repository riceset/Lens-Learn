# Lens & Learn — Team Brief

*Working name. Hackathon project. ~4 hr build.*

## The one-liner

Point your phone at anything → it teaches you the words for what you see in your target language → the words you collect get **combined into one sentence and turned into an AI-generated image**, so you remember them by seeing them.

## What it does (user POV)

1. **Snap or pick a photo.** The app identifies the objects and labels each one in your target language — word, romanization (e.g. pinyin), a natural example sentence, and tap-to-hear pronunciation.
2. **Save words to your Word Bank.** Tap any word you want to keep.
3. **Forge.** Tap one button and your saved words get woven into a single natural sentence — *and* an illustration of that sentence appears. You literally watch your scattered vocab become one picture.

Default target language for the demo: **Mandarin** (with pinyin).

## Why it wins

- Built on the **newest Google I/O 2026 launches**: Gemini 3.5 Flash (fast multimodal vision) + Nano Banana 2 image generation.
- Real **learning science**: pairing a word with a generated image is dual coding — verbal + visual memory together retains better than flashcards.
- **Responsible-AI angle for judges**: every generated image carries an invisible **SynthID** provenance watermark.

## How it works (the pipeline)

```
Photo ──> Gemini 3.5 Flash (vision) ──> labeled vocab (word, romaji, sentence)
                                              │
                          tap to save ────────┘
                                              ▼
Word Bank ──> Gemini 3.5 Flash ──> { sentence + English image_prompt }
                                              │
                              image_prompt ───┘──> Nano Banana ──> illustration
```

**Key trick:** we do NOT ask the image model to draw the foreign sentence (it renders text badly). Instead Gemini writes the sentence *and* a separate plain-English `image_prompt` describing the scene. We send only that prompt to the image model. Much more reliable output.

## Google tech we're using (the "must use Google Cloud" checklist)

| Feature | What for | Model / API |
|---|---|---|
| Gemini 3.5 Flash | Photo → vocab, and word-combining | Gemini API (`gemini-3.5-flash` — confirm exact ID in AI Studio) |
| Nano Banana 2 | Generate the phrase illustration | Gemini API (`gemini-3.1-flash-image`) |
| Cloud Text-to-Speech | Word pronunciation | `texttospeech.googleapis.com`, voice e.g. `cmn-CN-Wavenet-A` |

All three use simple **API-key auth** — no OAuth / service-account setup. One key, get it from Google AI Studio.

> Note: Nano Banana 2 (`gemini-3.1-flash-image`) may need billing enabled. Zero-cost fallback is `gemini-2.5-flash-image` (original Nano Banana, ~500 free images/day) — **identical request shape**, just swap the model string.

## What we're building (suggested split)

- **Person A — Capture + vocab:** PhotosPicker → base64 → Gemini vision call (forced JSON output) → render vocab cards.
- **Person B — Forge + image:** Word Bank (just an in-memory array, no database) → combine call → Nano Banana call → result screen with the sentence + image reveal + a loading state.
- **Shared:** one networking helper + the API key. Pre-pick one great demo photo.

Keep it scoped: no login, no persistence, one language, one beautiful demo path.

## Demo script (~75 sec)

1. Open app, pick a photo of a room. → vocab appears, tap a word to hear it.
2. Save 3–4 words.
3. Hit **Forge** → sentence assembles, illustration blooms.
4. Land the line: *"Your vocabulary, combined into a sentence you can see — provenance-watermarked with SynthID."*

## Links

- Project page / writeup: riceset.com (TBD)
- API keys: Google AI Studio
