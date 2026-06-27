# Plan: Generate a cutout PNG for each identified object

## Context

Today, tapping **Identify** calls Gemini vision (`GeminiService.identifyVocab`) and renders a
vocab card per object showing the word, pinyin, English, and an example sentence
(`CaptureView` → `VocabCardView`). The user wants each identified object to also get its **own
AI-generated PNG** — a **cute-but-recognizable character** (the object given a small friendly
face, still clearly the real object) on a plain white background — shown **at the top of its
existing vocab card** (no separate scene/collage view, per the chosen design).

The image-generation machinery already exists and is proven by the Forge feature
(`GeminiService.generateImage(prompt:)` → `/v1beta/interactions` endpoint → `InteractionResponse`).
This plan reuses that path and fans it out, one call per identified object, after Identify returns.

## Design decisions (confirmed with user, via eng review)
- **Image style:** object centered and isolated on a plain white background, no text. (Gemini image
  models don't reliably emit transparent PNGs, so white background is the pragmatic "cutout".)
- **Character treatment:** **cute but still recognizable** — the object given a small friendly face
  and soft pastel styling, but it must clearly read as the real object (not an abstract mascot), so
  the image→word learning link holds. *(Resolves the cross-model tension flagged in review.)*
- **Placement:** image added to the top of each vocab card. No separate combined scene view.
- **Concurrency:** image calls **throttled to 3 in flight** (not an unbounded 6-wide burst).
- **Failure handling:** per-card failures are swallowed and stay **silent** (no aggregate error) —
  explicit user choice, matching CLAUDE.md's "beautiful demo path over edge cases."
- **Demo mode:** render a **distinct local placeholder per object** (not one shared illustration).
- **Lifecycle:** a new `identify()`/`load()` **cancels the prior in-flight image batch** and clears
  image state so stale images never linger.
- **Tests:** **manual verification only** — no XCTest target / service protocol seam this round.

## Changes

### 1. `Networking/GeminiService.swift` — add a per-object image method
Add `func generateObjectImage(for card: VocabCard) async throws -> UIImage` that builds the
prompt and delegates to the existing `generateImage(prompt:)` (reuse, don't duplicate networking).

- Prompt (plain English only, per CLAUDE.md — never ask the model to draw Mandarin text):
  e.g. `"A simple cute illustration of a \(card.english), clearly recognizable as a
  \(card.english), with a small friendly face (eyes and a little smile), soft pastel colors,
  centered and isolated on a plain white background, no text, no extra objects, no shadow."`
  The "clearly recognizable as a \(english)" clause is load-bearing — it keeps the character from
  drifting into an abstract blob.
- Demo mode: do **not** return the single shared `DemoData.demoIllustration`. Instead render a
  **distinct per-object placeholder** locally — derive a deterministic background color + a glyph
  (the object's first letter, or an emoji if available) from `card.english`, draw it with
  `UIGraphicsImageRenderer` (same API `DemoData` already uses). Add a
  `DemoData.placeholder(for: VocabCard) -> UIImage` helper. This makes the keyless demo path show
  visibly different images per card.

### 2. `Features/Capture/CaptureViewModel.swift` — fan out image generation
- Add `@Published var images: [UUID: UIImage] = [:]` (keyed by `VocabCard.id`),
  `@Published var loadingImageIDs: Set<UUID> = []` (per-card spinners), and a private
  `imageTask: Task<Void, Never>?` handle so the batch is cancellable.
- New private `generateImages(for cards:)`:
  - Set `loadingImageIDs = Set(cards.map(\.id))`.
  - Use `withTaskGroup` with a **max-in-flight window of 3** (add 3 tasks, then add one more each
    time `await group.next()` returns — the standard throttled-TaskGroup pattern, a Swift built-in,
    no extra dependency). Each task returns `(card.id, UIImage?)`; on the main actor write
    `images[id] = image` when non-nil and `loadingImageIDs.remove(id)` as each completes (cards
    fill in progressively).
  - Per-card failures: `try?` → `nil`, swallowed, card stays image-less. **No aggregate error**
    (explicit user choice).
  - Honor cancellation: check `Task.isCancelled` before enqueuing more work.
- `identify()`: cancel any prior batch and clear image state at the **top** (`imageTask?.cancel();
  images = [:]; loadingImageIDs = []`) so a re-tap on the same photo doesn't show stale images.
  Run the vision call, set `cards`, clear `isLoading`, then start the batch as a **stored,
  non-awaited** task: `imageTask = Task { await generateImages(for: cards) }`.
- `load(data:)` and `useSample()`: also `imageTask?.cancel()` and reset `images` /
  `loadingImageIDs`. (`useSample()` seeds `images` from `DemoData.placeholder(for:)` per card.)

```
identify() tap
   │  imageTask?.cancel(); images=[:]; loadingImageIDs=[]
   ▼
identifyVocab(image)  ──err──►  errorMessage (existing path)
   │ ok
   ▼  cards set, isLoading=false
imageTask = Task { generateImages(for: cards) }
                       │  TaskGroup, ≤3 in flight
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   gen(card0)     gen(card1)     gen(card2)      … card3+ enqueued as slots free
        │ ok/nil        │              │
        ▼              ▼              ▼
   images[id]=img / skip;  loadingImageIDs.remove(id)   (on @MainActor)
```

`GeminiService` is a value type with only `Sendable` stored properties (`String`, `Bool`,
`URLSession`, `TargetLanguage`), so it is implicitly `Sendable` and safe to capture into the task
group under Swift 6. If the compiler disagrees, mark `struct GeminiService: Sendable` explicitly.
The view model stays `@MainActor`; dictionary mutations happen on the main actor as tasks complete.

### 3. `Features/Capture/VocabCardView.swift` — render the image
- Add `let image: UIImage?` and `let isImageLoading: Bool` parameters.
- At the top of the card `VStack`: if `image != nil` show `Image(lensImage:)` (reuse the existing
  `Image(lensImage:)` initializer in `Models/PlatformImage.swift`), scaled to fit a fixed height
  with a rounded clip; else if `isImageLoading` show a `ProgressView` placeholder of the same
  height; else render nothing.

### 4. `Features/Capture/CaptureView.swift` — wire it up
- In the `ForEach(viewModel.cards)`, pass `image: viewModel.images[card.id]` and
  `isImageLoading: viewModel.loadingImageIDs.contains(card.id)` into `VocabCardView`.

## What already exists (reused, not rebuilt)
- `GeminiService.generateImage(prompt:)` + `postInteraction` + `InteractionResponse`
  (`Networking/`) — the full image-gen path, proven by Forge. New code delegates to it.
- `Image(lensImage:)` (`Models/PlatformImage.swift`) — verified to take `UIImage`; the card
  reuses it directly, consistent with `CaptureView.imagePreview`.
- `demoMode` short-circuit pattern (`AppConfig.swift` + every `GeminiService` method).
- `UIGraphicsImageRenderer` drawing helpers in `DemoData.swift` — the new per-object placeholder
  reuses the same rendering approach.
- `CaptureViewModel.init(service:)` already supports service injection (kept, in case a test seam
  is added later).

## NOT in scope (considered, deferred)
- `WordBank`, `ForgeView`, Forge combined illustration — unchanged (no reason to touch them).
- Persistence of generated images — out, app is intentionally in-memory / no-DB.
- Aggregate "all images failed" error surface — deferred by explicit user choice (stays silent).
- Per-card retry button — deferred; more UI/state than the hackathon needs.
- XCTest target + `GeminiServicing` protocol seam — deferred; manual verification only this round.
  (Obvious post-hackathon follow-up if automated coverage is ever wanted.)
- Combined "scene/collage" of all object images — the original phrasing; user chose per-card.

## Verification
1. Build & run in Xcode on the iOS simulator.
2. **Demo mode** (no API key): tap **Use Sample** then **Identify** — confirm each card shows a
   spinner then a **visibly different** placeholder image (not the same one repeated), and the
   words/sentences still render.
3. **Live mode** (key via Run-scheme env var `GEMINI_API_KEY`): pick a real photo, tap
   **Identify** — confirm 4–6 cards appear, each image fills in **progressively** (throttled, not
   all at once), each is a cute-but-recognizable rendering of the object, and one image failing
   does not blank the others.
4. **Re-identify:** tap Identify again on the same photo — confirm old images clear immediately
   and don't linger while the new batch loads.
5. **Cancellation:** tap Identify, then quickly pick a new photo — confirm the prior batch stops
   (no late images popping into the new card set).

## Implementation Tasks
Synthesized from this review's findings. Each derives from a finding above. Checkbox as you ship.

- [ ] **T1 (P1, human: ~1.5h / CC: ~15min)** — GeminiService/DemoData — add per-object image gen
  - Surfaced by: Architecture #1 (demo placeholders) + kawaii cross-model tension
  - Add `generateObjectImage(for:)` with the cute-but-recognizable prompt; delegate to
    `generateImage(prompt:)`. Add `DemoData.placeholder(for:)` rendering a distinct color+glyph.
  - Files: `LensLearn/LensLearn/Networking/GeminiService.swift`, `LensLearn/LensLearn/DemoData.swift`
  - Verify: demo mode shows different placeholders; live mode returns recognizable characters.
- [ ] **T2 (P1, human: ~1h / CC: ~15min)** — CaptureViewModel — throttled cancellable fan-out
  - Surfaced by: Architecture #2 (throttle ≤3), Code Quality #4 + outside-voice #1 (cancel + reset)
  - `images`/`loadingImageIDs`/`imageTask`; `generateImages(for:)` with ≤3 in flight, per-card
    swallow; cancel + clear state in `identify()`/`load()`/`useSample()`.
  - Files: `LensLearn/LensLearn/Features/Capture/CaptureViewModel.swift`
  - Verify: progressive fill, no 429 burst, re-identify clears stale, new photo cancels prior batch.
- [ ] **T3 (P2, human: ~30min / CC: ~5min)** — VocabCardView — image/loading/absent rendering
  - Surfaced by: plan section 3
  - Files: `LensLearn/LensLearn/Features/Capture/VocabCardView.swift`
  - Verify: image when present, spinner while loading, nothing when failed.
- [ ] **T4 (P2, human: ~15min / CC: ~5min)** — CaptureView — wire image + loading state into cards
  - Surfaced by: plan section 4
  - Files: `LensLearn/LensLearn/Features/Capture/CaptureView.swift`
  - Verify: each card receives its own `images[card.id]` / `loadingImageIDs.contains(card.id)`.

_No new tasks from Performance (throttle decision covers it) or Test review (manual-only by choice)._

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | issues_resolved | 5 findings, 0 critical gaps, all folded in |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **OUTSIDE VOICE:** Codex out of credits → Claude subagent ran. 3 findings overlapped (throttle, cancellation, shim), 1 new (reset state in `identify()` — folded), 1 cross-model tension (kawaii vs recognizable → resolved to "cute but recognizable").
- **VERDICT:** ENG CLEARED — ready to implement. Scope accepted as-is (right-sized, 4 files / 0 new classes).

NO UNRESOLVED DECISIONS
