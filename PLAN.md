# Lens & Learn — Implementation Plan

> iOS (SwiftUI, iOS 17+, Swift 6) hackathon build, ~4 hrs. Point phone at a scene → get
> Mandarin vocab → save words → **Forge** them into one AI sentence + illustration.

This plan turns the default Xcode template (currently a SwiftData `Item` list) into the app
described in `CLAUDE.md` and `lens-and-learn-team-brief.md`.

---

## 0. Guiding constraints (from the brief)

- **No login, no persistence, one beautiful demo path.**
- **Target language is configurable; Mandarin (+ pinyin) is the build/demo default.** The
  pipeline is language-agnostic — Gemini takes the target language as a prompt parameter, so
  the same code does **Spanish, Japanese, French, etc.** by changing one config value. We
  build and demo Mandarin first; other languages are a config flip, not a rewrite (§0.5).
- Word Bank is an in-memory `@Observable` array — **delete all SwiftData**.
- One shared networking helper used by both feature areas.
- API key auth only (Google AI Studio key). Never commit the key.
- Beautiful demo path > edge-case handling.

## 0.5. Language design — Mandarin now, extensible by design

The app is not hard-wired to Mandarin. A single `AppConfig.targetLanguage` drives the whole
pipeline:

```swift
struct TargetLanguage {
    let name: String          // "Mandarin Chinese", "Spanish"
    let romanizationLabel: String?  // "pinyin" for Mandarin; nil for Spanish/French
    let ttsLocale: String     // "zh-CN", "es-ES", "ja-JP", ...
}
```

- **Vision & forge prompts** interpolate `targetLanguage.name` ("label each object in
  {language}…"), so no prompt is Mandarin-specific.
- **`romanization` field** (see §4) holds pinyin for Mandarin and is simply empty/omitted for
  languages that don't use one (Spanish, French) — the card UI hides the row when nil.
- **TTS** (§6) reads `ttsLocale`, so pronunciation follows the chosen language for free.
- **Demo default:** `TargetLanguage(name: "Mandarin Chinese", romanizationLabel: "pinyin",
  ttsLocale: "zh-CN")`. Swap to Spanish with one literal — no code path changes.

This costs ~zero extra build time (it's just a parameter instead of a constant) but lets the
pitch honestly say "works for any language — here's Mandarin."

---

## 1. Project cleanup (delete the template scaffolding)

| Action | File | Why |
|---|---|---|
| **Delete** | `LensLearn/Item.swift` | SwiftData model — not needed, brief says no persistence |
| **Rewrite** | `LensLearnApp.swift` | Remove `ModelContainer`; inject `WordBank` via `.environment` |
| **Rewrite** | `ContentView.swift` | Replace `NavigationSplitView` list with our root navigation |

`LensLearnApp.swift` becomes:

```swift
@main
struct LensLearnApp: App {
    @State private var wordBank = WordBank()      // @Observable, in-memory
    var body: some Scene {
        WindowGroup { RootView().environment(wordBank) }
    }
}
```

---

## 2. Secrets handling

- Add `Secrets.xcconfig` (gitignored) with `GEMINI_API_KEY = ...`.
- **Wire it properly** `[fold — Codex #7]`: a `.xcconfig` does nothing unless the build
  config's *Based on Configuration File* points at it AND the key is surfaced via an
  Info.plist entry (`GEMINI_API_KEY = $(GEMINI_API_KEY)`). Then read with
  `Bundle.main.object(forInfoDictionaryKey:)`, wrapped in `AppConfig.apiKey`. Skipping the
  base-config wiring is a silent failure (key reads as nil). Fastest fallback: a gitignored
  `Config.swift` with `let geminiAPIKey = "..."` and no plist plumbing at all.
- Add to `.gitignore`: `Secrets.xcconfig`, `Config.swift`.
- **Missing-key behavior** `[fold — Codex #8]`: do **not** `fatalError` (hard-crashes on
  stage). If the key is empty, force `DEMO_MODE` on (§6.5) so the app still runs canned, and
  surface a non-fatal config banner in debug.

---

## 3. File / module layout

```
LensLearn/
├── LensLearnApp.swift          (rewrite)
├── RootView.swift              (new — NavigationStack host)
├── Config/
│   └── AppConfig.swift         (new — API key + model IDs)
├── Models/
│   ├── VocabCard.swift         (new — Identifiable, Hashable)
│   └── ForgeResult.swift       (new — sentence, pinyin, image)
├── State/
│   └── WordBank.swift          (new — @Observable saved-words store)
├── DemoData.swift              (new — canned vocab/sentence for demo mode §6.5)
├── Networking/
│   ├── GeminiService.swift     (new — the ONE shared helper)
│   └── DTOs.swift              (new — Codable request/response shapes)
├── Features/
│   ├── Capture/
│   │   ├── CaptureView.swift   (new — PhotosPicker + identify)
│   │   ├── CaptureViewModel.swift
│   │   └── VocabCardView.swift (new — card UI + save + play)
│   └── Forge/
│       ├── WordBankView.swift  (new — saved list + Forge button)
│       ├── ForgeView.swift     (new — loading → reveal)
│       └── ForgeViewModel.swift
└── Audio/
    └── SpeechPlayer.swift      (new — TTS fetch + AVAudioPlayer)

LensLearnTests/                 (new test target)
├── WordBankTests.swift         (toggle / contains-by-word / canForge)
├── GeminiDecodingTests.swift   (fixture JSON → models)
└── Fixtures/
    ├── vocab_response.json      (captured vision response)
    └── forge_response.json      (captured forge response)
```

---

## 4. Data models

```swift
// App-side model. id is local identity, NOT decoded from Gemini.
// `romanization` is language-aware: pinyin for Mandarin, nil for Spanish/French.
struct VocabCard: Identifiable, Hashable {
    let id = UUID()
    let word: String              // 椅子   / "silla"
    let romanization: String?     // "yǐ zi" / nil (UI hides the row when nil)
    let english: String           // chair
    let sentence: String          // example sentence in the target language
}

// Wire model — what Gemini actually returns. Decode this, then map to VocabCard.
struct VocabCardDTO: Decodable {
    let word: String
    let romanization: String?     // ask Gemini for it only when the language has one
    let english: String
    let sentence: String
}

struct ForgeResult {
    let sentence: String          // woven sentence in the target language
    let romanization: String?     // pinyin for Mandarin; nil otherwise
    let image: UIImage?           // nil while loading
}
```

> **[P1 fix — Codable]** `VocabCard` is NOT `Codable`. A stored `let id = UUID()` makes
> Swift's synthesized `init(from:)` try to decode an `"id"` key that Gemini never sends,
> throwing `keyNotFound`. Decode `VocabCardDTO` from the API and map to `VocabCard` in the
> service. Keeps wire shape and app identity separate (explicit over clever).

`WordBank` (`@Observable`, `@MainActor`):
- `private(set) var saved: [VocabCard]`
- `func toggle(_ card:)`, `func contains(_ card:) -> Bool`, `var canForge: Bool { saved.count >= 2 }`
- **Dedupe by `word`, not `id`** — UUIDs regenerate on every vision call, so the same
  object photographed twice would otherwise create duplicate entries. `contains`/`toggle`
  key on `word`.

---

## 5. Networking — `GeminiService` (the shared helper)

Single `struct` with async throwing methods. Base host:
`https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}`

### 5a. `identifyVocab(in image: UIImage) async throws -> [VocabCard]`
- Model `gemini-3.5-flash` (ID from `AppConfig`, see preflight below).
- **Downscale first** `[P2 perf]`: resize to ~1024px longest edge, then
  `jpegData(compressionQuality: 0.7)` → base64 → `inline_data` part (`mime_type: image/jpeg`).
  A raw 12MP photo is multi-MB of base64 = slow upload + slow vision latency on stage.
- Text part: prompt to **detect the salient physical objects in the photo** (chair, lamp,
  cup, plant…) and label each object in **`targetLanguage.name`** with word / romanization
  (only if the language has one) / english / example sentence. The input is the object the
  user pointed at — not text in the image; the prompt must say "identify objects you see,"
  never "read words." No string in the prompt is Mandarin-specific (§0.5).
- **Constrain output** `[fold — Codex #11]`: ask for **4–6 concrete beginner nouns**, not
  "everything." Arbitrary room clutter yields boring/duplicate/abstract vocab; a bounded,
  concrete ask keeps cards demo-quality. Pair with a curated sample photo.
- Decode `[VocabCardDTO]` from the JSON text part, then map → `[VocabCard]`.
- `generationConfig.responseMimeType = "application/json"` **and** a `responseSchema`
  (array of objects) to force clean structured output — no markdown fences to strip.
- Decode `candidates[0].content.parts[0].text` (a JSON string) into `[VocabCard]`.

### 5b. `forge(words: [VocabCard]) async throws -> (sentence: String, romanization: String?, imagePrompt: String)`
- Model `gemini-3.5-flash`, text-only.
- Prompt: weave these words into ONE natural sentence in **`targetLanguage.name`**; return
  JSON `{ "sentence", "romanization", "image_prompt" }` (romanization null when N/A).
- **image_prompt must be plain English describing the scene** — never asks the image
  model to render Mandarin text (renders text badly).

### 5c. `generateImage(prompt: String) async throws -> UIImage`
- Model `gemini-3.1-flash-image` (**fallback `gemini-2.5-flash-image`**).
- **⚠ Verify the endpoint AND shape in preflight** `[P1 — Codex #1/#9]`: Google's image
  docs may use `/v1beta/{model}:...` with `responseModalities: ["IMAGE"]` **or** a separate
  `/v1beta/interactions` shape with `response_format`. **Do not assume it matches the
  text/vision `generateContent` DTO.** This call likely needs its **own** request/response
  path — let it diverge from the shared helper rather than forcing one DTO (the "one helper"
  abstraction is the most likely thing to break the demo). Confirm against the live docs/AI
  Studio before coding §5c.
- Send only the English `image_prompt`.
- Response carries image bytes (base64) → `Data` → `UIImage`.

### Networking notes
- One private `postGenerateContent(model:body:)` does the URLSession round-trip + status
  check — shared by the **text/vision** calls only (5a, 5b). The **image** call (5c) gets its
  own path (see warning above); don't over-share.
- **Generic decode** `[DRY]`: one `decode<T: Decodable>(_ response:) throws -> T` pulls the
  JSON string out of `candidates[0].content.parts[0].text` and decodes it — shared by the
  vision and forge calls instead of repeating the unwrap.
- **Timeout + cancellation** `[P2]`: set `URLSessionConfiguration.timeoutIntervalForRequest`
  to ~30s and run each call in a cancellable `Task` so a hung image-gen request can't freeze
  the ForgeView reveal with no escape.
- `DTOs.swift` holds the `GenerateContentRequest` / `Response` Codable types so all three
  calls share one shape.
- Errors → a single `GeminiError` enum surfaced to the UI as a retry-able banner.

### 5d. Model IDs — preflight `[P1 — top demo risk]`
- All model IDs live as constants in `AppConfig`, each with a **known-good fallback**:
  - text/vision: `gemini-3.5-flash` → fallback `gemini-2.5-flash` (**not** `gemini-2.0-flash`
    — Codex confirms 2.0 Flash is shut down; pick the latest *currently listed* flash)
  - image: `gemini-3.1-flash-image` → fallback `gemini-2.5-flash-image`
- **Before building anything (Phase 1, step 0):** confirm both IDs exist in Google AI Studio
  and run a one-time `GET /v1beta/models?key=...` (ListModels) smoke test. A wrong ID 404s
  *every* call live on stage — a 5-minute check removes the highest-probability failure.

---

## 6. Audio — `SpeechPlayer` (on-device) `[D4 — overrides CLAUDE.md]`

**Decision:** use `AVSpeechSynthesizer`, NOT Cloud Text-to-Speech. CLAUDE.md specifies
`cmn-CN-Wavenet-A`, but `texttospeech.googleapis.com` needs a GCP project + billing + API
enablement and the AI Studio key likely won't authorize it — a feasibility trap that could
eat the afternoon or 401 on stage. On-device synthesis is free, offline, zero-setup.

```swift
final class SpeechPlayer {
    private let synth = AVSpeechSynthesizer()
    func speak(_ text: String, locale: String) {   // locale from targetLanguage.ttsLocale
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: locale)  // "zh-CN", "es-ES", ...
        synth.speak(u)
    }
}
```
- Locale comes from `targetLanguage.ttsLocale`, so pronunciation follows the chosen language
  with no extra code — Mandarin uses `zh-CN`, Spanish `es-ES`.
- No network, no key, no `AVAudioSession` round-trip with a server. Slightly less natural
  than Wavenet — acceptable trade for zero demo risk.
- If the requested voice is absent on the device, `voice` is nil and it stays silent —
  surface a one-line "voice unavailable" note rather than failing silently (closes §14 gap).

---

## 6.5. Demo mode — the real safety net `[D5]`

A bundled sample *photo* still needs three live calls (vision → forge → image). A network
flake on stage still kills the money shot. So add a zero-network canned path:

- `AppConfig.demoMode: Bool` (forced on if the API key is empty, §2).
- `DemoData.swift` ships canned `[VocabCard]`, a canned `ForgeResult.sentence` + `pinyin`,
  and a **bundled illustration** in Assets.
- When `demoMode` is on, `GeminiService` returns the canned data (with a short artificial
  delay so the loading/bloom animations still play) instead of hitting the network.
- **SynthID caption is conditional** `[fold — Codex #12]`: only show
  "…provenance-watermarked with SynthID" when the image was *actually* Gemini-generated.
  Canned art is not watermarked — showing the caption then is a false claim to judges.

---

## 7. UI / screens

### RootView
`NavigationStack` → starts on **CaptureView**, toolbar button → **WordBankView**
(badge shows saved count).

### CaptureView (Person A)
- `PhotosPicker` (PhotosUI) → load `UIImage`.
- Big selected-image preview + **"Identify"** button → calls VM → loading spinner.
- Results render as a scroll/grid of `VocabCardView`.
- Pre-pick one great demo photo and bundle it in Assets for a fallback "Use sample" button.

### VocabCardView
- Shows word (large) · romanization (row hidden when nil) · english · example sentence.
- **Speaker button** → `SpeechPlayer.speak(word)`.
- **Save toggle** (bookmark) → `wordBank.toggle(card)`; filled when saved.

### WordBankView (Person B)
- List of saved `VocabCard`s, swipe-to-remove.
- **Forge** button (disabled until `canForge`) → pushes **ForgeView**.

### ForgeView (Person B) — the money shot
- Loading: shimmer / progress with "Forging…".
- Reveal sentence first (text animates in), then image **blooms** (opacity + scale
  `.transition`) when generation completes.
- Caption line for the demo: *"…provenance-watermarked with SynthID."* — **only when the
  image was Gemini-generated**, never in demo mode (§6.5).
- State machine (put this ASCII diagram as a comment in `ForgeViewModel`):

```
                 forge(words) ──ok──> sentence+pinyin+image_prompt
   .idle ──tap──> .loading ──────────────────────────────────────┐
                    │ err                                          │
                    ▼                                              ▼
                 .error <──err── generateImage(image_prompt)   .sentenceReady
                    ▲                     │ ok                     │ (sentence on screen,
                    │                     ▼                        │  image still loading)
                    └──── retry ──── .imageReady (bloom) <─────────┘
```
- Two sequential network calls (forge → image). Show the sentence the moment the forge
  call returns; don't wait for the image. `.error` is reachable from either call and is
  retry-able.

---

## 8. Build order — vertical slice first `[D6]`

Build the **whole demo path on canned data first**, so a demoable app exists by ~hour 1 and
the riskiest integration (the image call) is isolated and swapped in last. Then replace each
canned step with a live call. This protects the money shot earliest.

**Phase 0 — Scaffold + canned slice (both, ~50 min)**
1. Delete `Item.swift`; rewrite `LensLearnApp` + `RootView`; add `.gitignore`.
2. Add `AppConfig` (with `demoMode`), `WordBank`, `VocabCard`/`VocabCardDTO`, `DemoData`.
3. **End-to-end on canned data:** CaptureView shows canned cards → save → WordBankView →
   Forge → ForgeView reveals canned sentence + **bundled image**. No network yet.
   ✅ At the end of Phase 0 the full 75-sec demo already runs offline.
4. `WordBankTests` (toggle / contains-by-word / canForge).

**Phase 1 — Networking spine (shared, ~40 min)**
5. **Preflight `[P1]`:** confirm both model IDs in AI Studio + ListModels smoke test, and
   **confirm the image endpoint shape** (§5c warning) — before writing the service.
6. `GeminiService` (text/vision path) + `DTOs` + generic `decode<T>`; keep `demoMode` branch.
7. Smoke-test `forge(words:)` with a hardcoded array.
8. `GeminiDecodingTests` — fixture JSON → models (catches the Codable P1).

**Phase 2 — Swap in live, in parallel**
- **Lane A (Person A):** PhotosPicker → downscale → `identifyVocab` replaces canned cards;
  add `SpeechPlayer` (AVSpeechSynthesizer) tap-to-hear.
- **Lane B (Person B):** wire live `forge` into ForgeView (replaces canned sentence).

**Phase 3 — Live image + polish (both, ~40 min)**
9. Implement `generateImage` against the confirmed endpoint; replace the bundled image.
   Keep the bundled image as the demo-mode/fallback asset.
10. Conditional SynthID caption, error banners, badge counts.
11. Run the 75-sec script live; if any call is flaky, flip `demoMode` for a bulletproof run.

---

## 9. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Exact model IDs differ / are retired | Centralize IDs in `AppConfig`; verify in AI Studio + ListModels preflight; fallback to a *currently listed* flash (not `gemini-2.0-flash`, which is shut down) |
| Image call uses a different endpoint/shape | Verify `:generateContent` vs `/interactions` in preflight; give the image call its own path, don't force the shared DTO |
| Nano Banana 2 needs billing | Fallback `gemini-2.5-flash-image` constant ready to swap |
| Gemini wraps JSON in markdown | `responseMimeType: application/json` + `responseSchema` avoids this |
| Image model renders bad text | Never send Mandarin to it — only the English `image_prompt` |
| **Live network flakes on stage** | **`demoMode` canned path (§6.5): zero-network vocab + sentence + bundled image** |
| Cloud TTS auth trap | Use on-device `AVSpeechSynthesizer` (§6) — no Cloud project/billing |
| Swift 6 concurrency warnings | Mark `@Observable` stores `@MainActor`; keep network calls `async` off-main |

---

## 10. Definition of done

- Pick photo → vocab cards appear with working tap-to-hear.
- Save ≥2 words → Forge → one Mandarin sentence + a generated illustration reveal.
- No crashes on the demo path; API key not committed; SwiftData fully removed.
- `WordBankTests` + `GeminiDecodingTests` green.

---

## 11. Test plan

| Test file | Covers | Asserts |
|---|---|---|
| `WordBankTests` | `toggle` / `contains` / `canForge` | add+remove, toggle idempotency, **dedupe by word** (same word twice = one entry), `canForge` false at <2 and true at ≥2 |
| `GeminiDecodingTests` | wire → model mapping | `vocab_response.json` → `[VocabCard]` (count + fields), forge fixture → `(sentence, pinyin, image_prompt)`, **decode does not throw on absent `id`** (the P1) |

Out of test scope: live Gemini/TTS calls (network, not worth 4hr budget), `SpeechPlayer`
audio playback (needs device audio), SwiftUI view rendering.

---

## 12. What already exists (reuse vs rebuild)

- **Xcode SwiftData template** — `Item.swift`, `@Query`, `ModelContainer`. None reusable;
  all deleted in §1. No parallel-flow risk.
- **SDK built-ins, not rebuilt:** `PhotosPicker` (PhotosUI), `AVAudioPlayer`/`AVAudioSession`,
  `URLSession`, `Codable`, Gemini `responseSchema` structured output. **[Layer 1]**
- **Not** using `google-generative-ai-swift` SDK: it now routes through Firebase AI Logic
  (needs a Firebase project + plist), which is *more* auth ceremony than the brief's one
  AI Studio key. Raw REST is the correct lean choice here. **[EUREKA]**

## 13. NOT in scope (considered and deferred)

- **Persistence / login** — brief says in-memory only; no SwiftData, no auth.
- **Live-API & E2E tests** — network-dependent, low ROI for a 4hr demo.
- **API key hardening** — key ships in the app binary (extractable from IPA). Acceptable
  for a hackathon demo; would need a backend proxy for production.
- **In-app language switcher UI** — the pipeline is language-agnostic (§0.5) and Spanish/etc.
  work by changing `AppConfig.targetLanguage`, but we ship Mandarin as the default and don't
  build a runtime language-picker screen for the demo. (Capability stated; UI deferred.)
- **Live camera capture** — `PhotosPicker` (snap-or-pick) only; the pitch says "snap or pick
  a photo" (matches the brief), not literal live AR. Camera path deferred.
- **Cloud TTS / Wavenet voice** — replaced by on-device `AVSpeechSynthesizer` (§6); the
  higher-quality Cloud voice isn't worth the GCP setup for a 4hr build.
- **Distribution pipeline** (TestFlight/CI) — demo runs from Xcode on a tethered device.
- **Offline/empty/error-exhaustion polish** beyond one retry-able banner + sample-photo
  fallback.

## 14. Failure modes (per new codepath)

| Codepath | Realistic failure | Test? | Error handling? | User sees |
|---|---|---|---|---|
| `identifyVocab` | wrong model ID → 404 | preflight (§5d) | `GeminiError` banner | clear error + retry |
| `identifyVocab` | malformed JSON from model | `GeminiDecodingTests` | decode throws → banner | clear error |
| `generateImage` | wrong endpoint/shape → no image | preflight (§5c) | banner + demo-mode | clear error / canned image |
| `generateImage` | request hangs | — | 30s timeout + cancel | spinner → timeout banner |
| `forge` | empty/1-word bank | `WordBankTests` (`canForge`) | button disabled | button greyed, can't tap |
| `SpeechPlayer` | `zh-CN` voice missing on device | — | check `voice != nil` | "voice unavailable" note (not silent) |
| any live call | network flake on stage | — | `demoMode` canned path | full demo still runs offline |

**Critical-gap flag:** none open. The previously-silent TTS failure now surfaces a note,
and the network-flake path is covered by demo mode (§6.5).

## 15. Worktree parallelization

| Step | Modules | Depends on |
|---|---|---|
| Scaffold (Phase 0) | root, `Config/`, `State/`, `Models/` | — |
| Networking spine (Phase 1) | `Networking/` | Scaffold |
| Capture+vocab (Phase 2) | `Features/Capture/`, `Audio/` | Networking |
| Forge+image (Phase 3) | `Features/Forge/` | Networking |

- **Lane A:** Phase 2 (`Features/Capture/` + `Audio/`) — Person A
- **Lane B:** Phase 3 (`Features/Forge/`) — Person B

**Execution:** Scaffold → Networking spine (both, sequential — shared foundation). Then
launch Lane A + Lane B in parallel. No shared module directories between Capture and Forge,
so low merge-conflict risk. Both read `Networking/` + `State/` but neither edits them after
Phase 1. The Xcode `.pbxproj` is the one shared file both lanes touch when adding files —
coordinate add order or expect small project-file merge resolutions.

## 16. Implementation Tasks

Synthesized from this review's findings. Each derives from a specific finding above.

- [ ] **T1 (P1, human: ~30min / CC: ~5min)** — `AppConfig`/Phase 1 — verify model IDs + image endpoint shape + ListModels preflight + fallback constants
  - Surfaced by: Architecture A1 / D2 + Codex #1/#2/#9 — unverified IDs, stale `gemini-2.0-flash` fallback, possibly-wrong image endpoint
  - Files: `Config/AppConfig.swift`, plan Phase 1 step 0
  - Verify: `GET /v1beta/models` returns both IDs; image endpoint shape confirmed; smoke `forge()` succeeds
- [ ] **T9 (P1, human: ~30min / CC: ~10min)** — `DemoData`/`GeminiService` — canned demo mode (zero-network path)
  - Surfaced by: D5 / Codex #6 — sample photo still needs 3 live calls
  - Files: `DemoData.swift`, `Networking/GeminiService.swift`, `Config/AppConfig.swift`, Assets (bundled image)
  - Verify: with `demoMode=true`, full Capture→Forge path runs offline; SynthID caption hidden
- [ ] **T10 (P2, human: ~20min / CC: ~5min)** — `Audio` — `SpeechPlayer` via `AVSpeechSynthesizer` (drop Cloud TTS)
  - Surfaced by: D4 / Codex #3 — Cloud TTS auth trap
  - Files: `Audio/SpeechPlayer.swift`
  - Verify: tap-to-hear speaks `zh-CN`; missing-voice surfaces a note

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | not run |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | issues_found | 13 net-new (web-sourced); 3 cross-model tensions resolved |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR | 9 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | not run |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | not run |

**Decisions (D1–D7):** D1 light VMs · D2 model-ID preflight + fallback · D3 keep both test files · D4 AVSpeechSynthesizer (overrides CLAUDE.md Cloud TTS) · D5 canned demo mode · D6 vertical-slice build order · D7 tests reaffirmed.

**CODEX:** ran (gpt-5.5, web search). Highest-value net-new catches folded: Cloud TTS auth trap → on-device TTS; `gemini-2.0-flash` fallback is retired; image call likely uses a different endpoint/shape than `generateContent` (don't force the shared helper); hollow demo fallback → canned demo mode; conditional SynthID caption.

**CROSS-MODEL:** 3 tensions surfaced (TTS, demo safety net, build order) — user accepted the outside voice on all three; test-allocation tension resolved in favor of keeping tests (Codex's hours argument doesn't hold under AI-compression).

**VERDICT:** ENG CLEARED — ready to implement. CEO + Design reviews optional and not run (small hackathon build; no separate UI-spec to audit beyond this plan).

NO UNRESOLVED DECISIONS
- [ ] **T2 (P1, human: ~30min / CC: ~5min)** — `Models`/`Networking` — split `VocabCardDTO` from `VocabCard`, map in service
  - Surfaced by: Code Quality Q2 — `let id = UUID()` breaks synthesized Decodable
  - Files: `Models/VocabCard.swift`, `Networking/GeminiService.swift`
  - Verify: `GeminiDecodingTests` decodes fixture without throwing
- [ ] **T3 (P1, human: ~1.5h / CC: ~15min)** — `LensLearnTests` — add `WordBankTests` + `GeminiDecodingTests` + fixtures
  - Surfaced by: Test Review / D3
  - Files: `LensLearnTests/*`
  - Verify: both test files green
- [ ] **T4 (P2, human: ~20min / CC: ~5min)** — `Networking` — generic `decode<T>` + 30s timeout + cancellable Task
  - Surfaced by: Code Quality Q1 (DRY) + Architecture A3 (timeout)
  - Files: `Networking/GeminiService.swift`
  - Verify: hung call surfaces timeout banner, not a frozen view
- [ ] **T5 (P2, human: ~20min / CC: ~5min)** — `Features/Capture` — downscale image to ~1024px before base64
  - Surfaced by: Performance — multi-MB base64 upload latency
  - Files: `Features/Capture/CaptureViewModel.swift`
  - Verify: encoded payload size sane on a 12MP photo
- [ ] **T6 (P2, human: ~15min / CC: ~3min)** — `Networking` — set `responseModalities: ["IMAGE"]` on image call
  - Surfaced by: Architecture A2
  - Files: `Networking/GeminiService.swift`
  - Verify: `generateImage` returns a `UIImage`, not text
- [ ] **T7 (P3, human: ~10min / CC: ~3min)** — `State` — dedupe Word Bank by `word`
  - Surfaced by: Code Quality Q3
  - Files: `State/WordBank.swift`
  - Verify: `WordBankTests` same-word-twice = one entry
- [ ] **T8 (P3, human: ~10min / CC: ~2min)** — `Features/Forge` — ASCII state-machine comment in `ForgeViewModel`
  - Surfaced by: Architecture A4
  - Files: `Features/Forge/ForgeViewModel.swift`
  - Verify: diagram present and matches the four states
