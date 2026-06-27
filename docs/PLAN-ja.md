# Lens & Learn — 実装計画書 (Implementation Plan)

> iOS (SwiftUI, iOS 17+, Swift 6) ハッカソン開発、約4時間。スマートフォンを被写体に向ける → ターゲット言語の単語を取得 → 単語を保存 → それらを1つのAI生成の文章とイラストに**結合 (Forge)** する。

この計画書は、デフォルトの Xcode テンプレート（現在は SwiftData の `Item` リスト）を `CLAUDE.md` および `lens-and-learn-team-brief.md` に記載されているアプリに変換するためのものです。

---

## 0. 基本的な制約 (要約より)

- **ログインなし、データ永続化なし、デフォルトは中国語（ピンイン付き）、美しい1つのデモパスのみ。**
- **ターゲット言語は設定可能とし、ビルド/デモのデフォルトを中国語（＋ピンイン）とします。** パイプライン自体は言語に依存しない（language-agnostic）設計にします。Gemini はプロンプトのパラメータとしてターゲット言語を受け取るため、同じコードのまま設定値を1つ変更するだけで **スペイン語、日本語、フランス語など** に対応可能です。まずは中国語をビルドしてデモを行いますが、他の言語への切り替えはコードの書き換えではなく、設定の切り替えのみで対応できるようにします（§0.5）。
- ワードバンク（Word Bank）はメモリ内の `@Observable` 配列とする — **すべての SwiftData コードを削除する**。
- 双方の機能エリア（キャプチャと結合）から使用される、1つの共有ネットワークヘルパーを作成する。
- 認証は API キーのみ（Google AI Studio のキー）。キーは絶対にコミットしないこと。
- エッジケースの処理よりも、美しいデモパスの実現を優先する。

---

## 0.5. 言語設計 — 現在は中国語、設計上は拡張可能

アプリは中国語専用にハードコードされません。単一の `AppConfig.targetLanguage` がパイプライン全体を制御します：

```swift
struct TargetLanguage {
    let name: String                // "Mandarin Chinese", "Spanish"
    let romanizationLabel: String?  // 中国語の場合は "pinyin"、スペイン語/フランス語などの場合は nil
    let ttsLocale: String           // "zh-CN", "es-ES", "ja-JP", ...
}
```

- **Vision & forge プロンプト**: `targetLanguage.name` を埋め込みます（「検出したオブジェクトを {language} でラベル付けし…」）。これにより、プロンプト自体が特定の言語（中国語など）に依存しなくなります。
- **`romanization` フィールド**（§4参照）: 中国語の場合はピンイン（pinyin）を保持し、それを使用しない言語（スペイン語、フランス語）の場合は単に空（nil）になります。カード UI は、値が nil の場合にその行を非表示にします。
- **TTS（音声合成）**（§6）: `ttsLocale` を読み取るため、追加コードなしで選択した言語に応じた発音が行われます。
- **デモデフォルト**: `TargetLanguage(name: "Mandarin Chinese", romanizationLabel: "pinyin", ttsLocale: "zh-CN")` とします。別の言語への切り替えは、この定義を変更するだけで済み、コードパスの変更は不要です。

これにより、実装にかかる時間をほぼ増やすことなく（定数の代わりにパラメータを使用するだけ）、デモ時に「あらゆる言語で動作します — ここでは中国語をお見せします」と自信を持って説明できます。

---

## 1. プロジェクトのクリーンアップ (テンプレートのコード削除)

| アクション | ファイル | 理由 |
|---|---|---|
| **削除** | `LensLearn/Item.swift` | SwiftData モデル — 不要（データ永続化なし） |
| **書き換え** | `LensLearnApp.swift` | `ModelContainer` を削除し、`.environment` を通じて `WordBank` を注入する |
| **書き換え** | `ContentView.swift` | `NavigationSplitView` のリストを、独自のルートナビゲーションに置き換える |

`LensLearnApp.swift` は以下のようになります：

```swift
@main
struct LensLearnApp: App {
    @State private var wordBank = WordBank()      // メモリ内管理の @Observable
    var body: some Scene {
        WindowGroup { RootView().environment(wordBank) }
    }
}
```

---

## 2. シークレットキーの取り扱い

- `Secrets.xcconfig`（git-ignored）を追加し、`GEMINI_API_KEY = ...` を設定します。
- **正しく接続する**: `.xcconfig` は、ビルド構成の *Based on Configuration File* がそれを指し、かつキーが Info.plist エントリー (`GEMINI_API_KEY = $(GEMINI_API_KEY)`) を介して公開されない限り、何も機能しません。その後、`Bundle.main.object(forInfoDictionaryKey:)` で読み取り、`AppConfig.apiKey` でラップします。ベース構成の配線をスキップするとサイレントエラー（キーが nil になる）になります。最も早いフォールバックは、plist を介さず単に git-ignored な `Config.swift` に `let geminiAPIKey = "..."` を記述することです。
- `.gitignore` に追加します: `Secrets.xcconfig`, `Config.swift`
- **キーが見つからない場合の挙動**: `fatalError`（ステージ上で強制クラッシュ）は**避けてください**。キーが空の場合、アプリが固定データで動作するように `DEMO_MODE` を強制的にオンにし（§6.5）、デバッグ時に致命的でない設定警告バナーを表示させます。

---

## 3. ファイル / モジュールの配置構成

```
LensLearn/
├── LensLearnApp.swift          (書き換え)
├── RootView.swift              (新規 — NavigationStack のホスト)
├── Config/
│   └── AppConfig.swift         (新規 — APIキー + モデルID)
├── Models/
│   ├── VocabCard.swift         (新規 — Identifiable, Hashable)
│   └── ForgeResult.swift       (新規 — 文章, ローマ字/ピンイン, 画像)
├── State/
│   └── WordBank.swift          (新規 — @Observable 保存単語用ストア)
├── DemoData.swift              (新規 — デモモード用の固定単語/文章 §6.5)
├── Networking/
│   ├── GeminiService.swift     (新規 — 唯一の共有ヘルパー)
│   └── DTOs.swift              (新規 — Codable リクエスト/レスポンス構造)
├── Features/
│   ├── Capture/
│   │   ├── CaptureView.swift   (新規 — PhotosPicker + 識別画面)
│   │   ├── CaptureViewModel.swift
│   │   └── VocabCardView.swift (新規 — カードUI + 保存 + 再生)
│   └── Forge/
│       ├── WordBankView.swift  (新規 — 保存リスト + 結合ボタン)
│       ├── ForgeView.swift     (新規 — ローディング → 結果表示)
│       └── ForgeViewModel.swift
└── Audio/
    └── SpeechPlayer.swift      (新規 — TTS取得 + AVAudioPlayer)

LensLearnTests/                 (新規テストターゲット)
├── WordBankTests.swift         (切り替え / 単語重複判定 / 結合可能判定)
├── GeminiDecodingTests.swift   (モックJSON → モデルデコード)
└── Fixtures/
    ├── vocab_response.json      (画像認識のモックレスポンス)
    └── forge_response.json      (結合処理のモックレスポンス)
```

---

## 4. データモデル

```swift
// アプリ側モデル。idはローカルIDであり、Geminiからデコードされるものではありません。
// `romanization` は言語に対応します：中国語の場合はピンイン、スペイン語/フランス語などの場合は nil。
struct VocabCard: Identifiable, Hashable {
    let id = UUID()
    let word: String              // 椅子   / "silla"
    let romanization: String?     // "yǐ zi" / nil (UIはnilの場合にこの行を非表示にします)
    let english: String           // chair
    let sentence: String          // ターゲット言語での例文
}

// 通信モデル — Geminiが実際に返す構造。これをデコードし、VocabCardにマッピングします。
struct VocabCardDTO: Decodable {
    let word: String
    let romanization: String?     // 対象の言語に存在する場合のみ Gemini に要求します
    let english: String
    let sentence: String
}

struct ForgeResult {
    let sentence: String          // 結合されたターゲット言語の文章
    let romanization: String?     // 中国語の場合はピンイン、それ以外は nil
    let image: UIImage?           // ローディング中はnil
}
```

> **[P1 修正 — Codable]** `VocabCard` は `Codable` にすべきではありません。`let id = UUID()` が定義されていると、Swift の自動生成される `init(from:)` は Gemini から返されない `"id"` キーをデコードしようとして `keyNotFound` をスローします。API からは `VocabCardDTO` をデコードし、サービス層で `VocabCard` にマッピングしてください。これにより、通信形式とアプリ内のアイデンティティを明確に分離できます（スマートさより明示性を優先）。

`WordBank` (`@Observable`, `@MainActor`):
- `private(set) var saved: [VocabCard]`
- `func toggle(_ card:)`, `func contains(_ card:) -> Bool`, `var canForge: Bool { saved.count >= 2 }`
- **UUIDではなく `word` で重複判定を行う**: 画像認識を行うたびに新しい UUID が生成されるため、同じ被写体を2回撮影した場合に重複エントリーが発生するのを防ぐため、`contains`/`toggle` は `word` をキーにして処理します。

---

## 5. ネットワーク — `GeminiService` (共有ヘルパー)

非同期の throwing メソッドを持つ単一の `struct`。ベースホスト：
`https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}`

### 5a. `identifyVocab(in image: UIImage) async throws -> [VocabCard]`
- モデル： `gemini-3.5-flash` （`AppConfig` から ID を取得、事前確認は下記参照）。
- **最初にリサイズする**: 最大辺を ~1024px にリサイズし、`jpegData(compressionQuality: 0.7)` → base64 → `inline_data` パート（`mime_type: image/jpeg`）の順で処理します。未加工の 12MP 写真はマルチメガバイトの base64 になり、アップロードが遅くなりステージ上のレイテンシが大きくなります。
- テキストパート: **「写真内の目立つ物理的なオブジェクト（椅子、ランプ、コップ、植物など）を検出し、それぞれの `targetLanguage.name` での単語、発音表記（存在する場合のみ）、英語、例文でラベルを付ける」**ようプロンプトを設定します。ユーザーがカメラで指した物理的な物体を識別することが目的であり、画像内の文字を読み取るわけではないため、プロンプトには「検出したオブジェクトを識別する」と記述し、「文字を読み取る」とは書かないようにします。プロンプト内の文字列は特定の言語（中国語など）に依存させません（§0.5）。
- **出力を制限する**: 「すべて」を対象にするのではなく、**「4〜6個の具体的な初級名詞」**を要求します。部屋の雑多な小物をすべて検出すると、退屈な、あるいは重複した抽象的な単語が多くなります。具体的かつ限定的な要求にすることで、デモ品質のカードを維持します。また、厳選したサンプル写真を用意しておきます。
- APIから `[VocabCardDTO]` をデコードし、`[VocabCard]` にマッピングします。
- マークダウンの装飾文字（```json など）を削除する手間を省き、クリーンな構造化出力を強制するため、`generationConfig.responseMimeType = "application/json"` および `responseSchema`（オブジェクトの配列）を指定します。
- `candidates[0].content.parts[0].text` (JSON文字列) を `[VocabCard]` にデコードします。

### 5b. `forge(words: [VocabCard]) async throws -> (sentence: String, romanization: String?, imagePrompt: String)`
- モデル： `gemini-3.5-flash` （テキスト専用）。
- プロンプト：これらの単語を **`targetLanguage.name`** での1つの自然な文章に編み込み、JSON `{ "sentence", "romanization", "image_prompt" }` を返します（ローマ字表記が不要な場合は null になります）。
- **image_promptはシーンを描写する平易な英語にする必要があります**: 画像モデルにターゲット言語のテキストを描くよう指示してはいけません（画像モデルはテキストの描画が苦手なため）。

### 5c. `generateImage(prompt: String) async throws -> UIImage`
- モデル： `gemini-3.1-flash-image` （**フォールバック：`gemini-2.5-flash-image`**）。
- **事前にエンドポイントとリクエストの形式を確認する**: Googleの画像生成用APIは、`responseModalities: ["IMAGE"]` を伴う `/v1beta/{model}:...` を使用する場合と、`response_format` を伴う別個の `/v1beta/interactions` 形式を使用する場合があります。**テキストやビジョン向けの `generateContent` DTO と同じ形式であると仮定しないでください。** このコールは独自の要求/応答パスが必要になる可能性が高いため、共通ヘルパーに無理やり統合しようとせず、個別に設計してください（「1つのヘルパー」という過度な抽象化がデモの動作を破壊する最大の原因になります）。コーディングを行う前に、最新ドキュメントや AI Studio で動作を確認してください。
- 英語の `image_prompt` のみを送信します。
- レスポンスに含まれる画像バイト（base64） → `Data` → `UIImage` を生成します。

### ネットワークに関する注意点
- 1つのプライベートメソッド `postGenerateContent(model:body:)` が URLSession の送受信とステータスチェックを処理し、**テキスト/ビジョン**のコール（5a, 5b）のみで共有します。**画像生成**コール（5c）は独自のパスを用意し、共通化しすぎないようにします。
- **ジェネリックデコード**: 1つの共通デコードメソッド `decode<T: Decodable>(_ response:) throws -> T` が `candidates[0].content.parts[0].text` から JSON 文字列を抽出しデコードする役割を担います。これをビジョンと結合（Forge）の両コールで共有することで重複コードを排除します。
- **タイムアウトとキャンセル**: `URLSessionConfiguration.timeoutIntervalForRequest` を約30秒に設定し、各コールをキャンセル可能な `Task` で実行します。これにより、画像生成リクエストがハングした場合でも、ユーザーがキャンセルできず ForgeView の画面がフリーズしたままになるのを防ぎます。
- `DTOs.swift` は `GenerateContentRequest` / `Response` の Codable 型を保持し、3つのコールすべてで同一 of 構造体を共有します。
- エラーは単一の `GeminiError` 列挙型に集約され、UI上で再試行可能な警告バナーとして表示されます。

### 5d. モデルID — 事前確認（最重要デモリスク）
- すべてのモデル ID は `AppConfig` に定数として定義し、**正常動作が確認できているフォールバックID**も用意します。
  - テキスト/ビジョン: `gemini-3.5-flash` → フォールバック: `gemini-2.5-flash` (`gemini-2.0-flash` は使用不可。2.0 Flashはすでに提供終了しているため、現在利用可能な最新のFlashを指定します)
  - 画像生成: `gemini-3.1-flash-image` → フォールバック: `gemini-2.5-flash-image`
- **開発を開始する前（フェーズ1のステップ0）に**: 両方の ID が Google AI Studio で有効であることを確認し、一度 `GET /v1beta/models?key=...` (ListModels) を呼び出して正常に取得できるかテストを行ってください。モデルIDが間違っているとすべてのリクエストが 404 エラーになり、ステージ上でのデモが失敗します。この5分間の事前チェックが、最大の失敗リスクを排除します。

---

## 6. 音声再生 — `SpeechPlayer` (デバイス内処理)

**決定事項:** Cloud Text-to-Speech ではなく、**`AVSpeechSynthesizer` を使用します**。CLAUDE.md では `cmn-CN-Wavenet-A` を使用するよう指定されていますが、`texttospeech.googleapis.com` を利用するには GCP プロジェクトの設定、課金の有効化、APIの有効化が必要となり、AI Studioのキーでは認証できない可能性が高いです。これは実装の難易度を上げ、ステージ上で 401 エラーを引き起こす罠になります。デバイスローカルでの音声合成であれば、無料で、オフラインで動作し、セットアップも不要です。

```swift
final class SpeechPlayer {
    private let synth = AVSpeechSynthesizer()
    func speak(_ text: String, locale: String) {   // localeはtargetLanguage.ttsLocaleから取得
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: locale)  // "zh-CN", "es-ES", ...
        synth.speak(u)
    }
}
```
- ロケール情報は `targetLanguage.ttsLocale` から取得されるため、追加のコードなしで選択した言語の発音に対応します（中国語は `zh-CN`、スペイン語は `es-ES`）。
- ネットワーク不要、APIキー不要、サーバーとの音声データ送受信処理も不要になります。Wavenet よりは少し機械的な発音になりますが、デモ失敗リスクをゼロに抑えるための適切なトレードオフです。
- もしデバイスに要求された音声データがない場合は `voice` が nil になり無音になります。サイレントに失敗するのではなく、画面上に「音声データが利用できません」といった1行の通知を表示するようにします（§14 のギャップに対応）。

---

## 6.5. デモモード — 確実なセーフティネット

サンプル写真を用意しても、3つのリアルタイムAPIコール（画像認識 → 結合 → 画像生成）が必要です。もし本番ステージ上でネットワークが不安定になれば、デモは失敗します。そのため、ネットワークを介さない固定データによる「デモモード」を追加します。

- `AppConfig.demoMode: Bool` (APIキーが空の場合は強制的にオンになります、§2)。
- `DemoData.swift` には固定の `[VocabCard]`、固定の結合結果 `ForgeResult.sentence` / `romanization`、および**アセットにバンドルされたイラスト画像**を用意しておきます。
- `demoMode` がオンのとき、`GeminiService` はネットワークにアクセスせず、これらの固定データを返します（ローディングアニメーションや画像表示時のフェードイン効果が確認できるように、短いダミーの遅延を挟みます）。
- **SynthIDキャプションの表示制御**: 生成された画像が「実際に Gemini によって生成されたもの」である場合のみ、「…provenance-watermarked with SynthID」と表示します。アセットに同梱されたデモ用イラストはモックデータでありウォーターマークされていません。その場合にキャプションを表示するのは誤表記となるため注意してください。

---

## 7. UI / 各画面 of 設計

### RootView
`NavigationStack` → 初期画面は **CaptureView** で、ツールバーボタンから **WordBankView** に遷移します（保存された単語数がバッジで表示されます）。

### CaptureView (担当者 A)
- `PhotosPicker` (PhotosUI) を介して `UIImage` を読み込みます。
- 選択された画像のプレビューを大きく表示し、**「Identify (識別)」** ボタンをタップすると ViewModel を介して処理が走り、ローディングスピナーが表示されます。
- 結果は `VocabCardView` のスクロール/グリッド表示としてレンダリングされます。
- あらかじめ最適なデモ用写真をアセットにバンドルしておき、「サンプル写真を使用する」ボタンを配置してフォールバックとして利用可能にします。

### VocabCardView
- 単語（大きく表示）、発音表記（`romanization` が nil の場合はこの行を非表示）、英語、例文を表示します。
- **スピーカーボタン**: `SpeechPlayer.speak(word)` を呼び出します。
- **保存の切り替え（ブックマーク）**: `wordBank.toggle(card)` を呼び出します。保存されている場合はアイコンが塗りつぶされます。

### WordBankView (担当者 B)
- 保存された `VocabCard` のリストを表示し、スワイプで削除可能にします。
- **Forge (結合)** ボタン（単語が2つ以上になるまでタップ不可）を配置し、タップすると **ForgeView** に遷移します。

### ForgeView (担当者 B) — メイン演出
- ローディング中：「Forging… (作成中)」の文字とシャイニーアニメーションを表示します。
- 結合が完了したら、まず文章（テキストアニメーションで表示）を出し、その後、画像の生成完了とともにイラストを**フェードイン**（不透明度とスケールの `.transition`）させます。
- デモ用キャプション：「…provenance-watermarked with SynthID」（※Geminiで生成された場合のみ表示、デモモード時は非表示、§6.5）。
- 状態遷移マシン（このアスキー図を `ForgeViewModel` のコメントとして埋め込んでください）：

```
                 forge(words) ──ok──> sentence+romanization+image_prompt
    .idle ──tap──> .loading ──────────────────────────────────────┐
                    │ err                                          │
                    ▼                                              ▼
                 .error <──err── generateImage(image_prompt)   .sentenceReady
                    ▲                     │ ok                     │ (sentence on screen,
                    │                     ▼                        │  image still loading)
                    └──── retry ──── .imageReady (bloom) <─────────┘
```
- 2つの連続したネットワーク呼び出し（文章結合 → 画像生成）が発生します。結合処理が成功した時点で先にテキストを表示し、画像の生成完了を待つ必要はありません。どちらのフェージングでエラーが発生しても `.error` 状態へ遷移し、再試行（retry）が可能です。

---

## 8. ビルド手順 — 動作する垂直スライスを最優先で作成する

**まずは固定データを使ってデモパス全体を構築**します。これにより、開始後約1時間でデモ可能なアプリが手元に存在することになり、最もリスクの高いAPI（画像生成）を最後に切り替えるだけで済むように分離できます。これにより、メインとなる演出の安全性を早い段階で確保できます。

**フェーズ 0 — スキャフォールディング ＋ モックデータの実装（共通、約50分）**
1. `Item.swift` を削除し、`LensLearnApp` と `RootView` を書き換えます。`.gitignore` を設定します。
2. `AppConfig` (デモモードフラグ付き), `WordBank`, `VocabCard`/`VocabCardDTO`, `DemoData` を追加します。
3. **固定データによるエンドツーエンドの構築**: CaptureView でモックカードを表示 → 保存 → WordBankView → Forgeをタップ → ForgeViewでモック文章と**同梱の画像**を表示します。この段階ではネットワーク接続は不要です。
   - ✅ フェーズ0の時点で、オフラインで実行可能な「75秒間のデモパス」がすでに完成しています。
4. `WordBankTests`（追加/削除、重複判定、結合条件）を実装します。

**フェーズ 1 — ネットワーク基盤の実装（共通、約40分）**
5. **事前確認**: API Studio でモデル ID を確認し、ListModels で疎通テストを行い、かつ**画像生成用エンドポイントの形式**（§5c の注意点）を確定させてからコーディングに入ります。
6. `GeminiService`（テキスト/ビジョン用処理） ＋ `DTOs` ＋ 共通デコード関数 `decode<T>` を実装します。`demoMode` 分岐ロジックも含めます。
7. 固定の単語配列を用いて、`forge(words:)` の疎通テストを実行します。
8. `GeminiDecodingTests` を実装し、モックJSONからモデルへのマッピングを検証します（Codableに関するP1問題を検出するため）。

**フェーズ 2 — ライブ接続への切り替え（並行作業）**
- **レーン A (担当者 A):** PhotosPicker → 画像の縮小 → `identifyVocab` による画像認識処理をモックから差し替えます。`SpeechPlayer` による音声再生機能を接続します。
- **レーン B (担当者 B):** 実際の `forge` API を ForgeView に接続します（モック文章の差し替え）。

**フェーズ 3 — 画像生成の接続と仕上げ（共通、約40分）**
9. 確認済みのエンドポイントに対して `generateImage` を実装し、同梱のイラストから動的な生成画像に切り替えます。同梱イラストはデモモードおよびエラー時のフォールバック用として残します。
10. SynthIDキャプションの表示条件、エラーバナー、バッジカウントの処理を記述します。
11. 75秒のデモシナリオを通して実行します。通信が不安定な場合は、すぐに `demoMode` に切り替えて確実にデモが通るようにします。

---

## 9. リスクと対策

| リスク | 対策 |
|---|---|
| モデルIDが変更または廃止されている | `AppConfig` にIDを集約し、AI Studio および ListModels で事前疎通テストを行う。廃止されている場合は、現在提供されている最新のFlashモデル（`gemini-2.0-flash` は廃止されているため `gemini-2.5-flash` など）に差し替える |
| 画像生成APIのエンドポイントやパラメータ形式が異なる | 事前に `:generateContent` と `/interactions` の違いを確認し、画像生成専用の処理フローを構築する（無理に共通DTOに統合しない） |
| Nano Banana 2 が課金設定を要求する | すぐに切り替えられるように、定数 `gemini-2.5-flash-image` をフォールバックとして準備しておく |
| Gemini が JSON をマークダウンで囲って返す | `responseMimeType: application/json` と `responseSchema` を指定して、構造化JSON出力を強制する |
| 画像生成モデルが文字を崩して描画する | ターゲット言語のテキストは送信せず、シーンを英語で描写した `image_prompt` のみを画像モデルに渡す |
| **本番ステージ上でネットワークが切断される** | **`demoMode` フラグによるオフライン動作（固定の単語カード、文章、同梱イラスト）をセーフティネットとして用意する** |
| Cloud TTSの認証でエラーになる | デバイスローカルの `AVSpeechSynthesizer` を使用し、認証トラブルを未然に防ぐ |
| Swift 6 のスレッドセーフに関する警告が出る | `@Observable` ストアに `@MainActor` を注記し、通信処理は Main スレッド外（`async`）で動作させる |

---

## 10. 定義する「完了基準」 (Definition of Done)

- 写真を選択すると、音声再生機能付きの単語カードが表示されること。
- 2つ以上の単語を保存し、Forgeを実行した際に、1つのターゲット言語の文章と生成されたイラストが表示されること。
- デモ全体のフローでクラッシュが発生しないこと。API キーがコミットされていないこと。SwiftData が完全に排除されていること。
- `WordBankTests` と `GeminiDecodingTests` がすべてパスすること。

---

## 11. テスト計画

| テストファイル | テスト内容 | 検証項目 |
|---|---|---|
| `WordBankTests` | `toggle` / `contains` / `canForge` | 追加と削除、トグルの冪等性、**単語名による重複排除**（同じ単語を2回追加しても1エントリーのまま）、単語数が2個未満で `canForge` が false、2個以上で true になること |
| `GeminiDecodingTests` | JSON通信データからモデルへのマッピング | `vocab_response.json` → `[VocabCard]` のデコード検証（件数とフィールド値）、結合結果モックJSON → `(sentence, pinyin, image_prompt)` への変換検証、**`id` フィールドが存在しなくてもデコードで例外が発生しないこと** (P1の検証) |

テスト対象外：実際の Gemini/TTS への通信（モック化推奨、時間の節約のため）、`SpeechPlayer` による音声再生（実機オーディオが必要なため）、SwiftUI の画面レンダリング。

---

## 12. 既存コードの再利用と再構築

- **XcodeのSwiftDataテンプレート**: `Item.swift`, `@Query`, `ModelContainer` は一切利用せず、すべて削除します。
- **再利用するフレームワーク機能**: `PhotosPicker` (PhotosUI), `AVAudioPlayer`/`AVAudioSession`, `URLSession`, `Codable`, Geminiの `responseSchema` による構造化出力。
- **Gemini SDK は使用しない**: `google-generative-ai-swift` SDK は現在 Firebase AI Logic を経由する構成になっており、Firebase プロジェクトや plist 設定などの認証手順が複雑になります。シンプルなハッカソン用途では、生の REST API を叩くのが最もシンプルで正しい選択肢です。 **[解決策]**

---

## 13. スコープ外（実装を見送る事項）

- **データの永続化 / ログイン**: メモリ内管理に限定し、SwiftData やユーザー認証は実装しません。
- **本番環境を用いたE2Eテスト**: 4時間の限られた時間では投資対効果が低いため実施しません。
- **APIキーの秘匿化保護**: アプリバイナリにキーを含める形を取ります（IPAから抽出可能な状態）。ハッカソンのデモ用途としては許容とし、本番環境で運用する場合はバックエンドプロキシを構築する必要があります。
- **多言語対応のアプリ内切り替えUI**: パイプライン自体は言語に依存せず設計し（§0.5）、`AppConfig.targetLanguage` を変更することでスペイン語などへ切り替え可能ですが、デモ用として中国語をデフォルトとし、アプリ内に動作切り替え用のUI画面自体は作成しません（機能は提供しますが、切り替えUIは後回しにします）。
- **カメラによるリアルタイム撮影**: `PhotosPicker` による写真の選択またはその場での撮影に限定します。リアルタイムのAR空間への追従などは行いません。
- **Cloud TTS / Wavenet 音声の導入**: デバイスローカルの `AVSpeechSynthesizer` で代用し、複雑な GCP 設定を回避します。
- **配信パイプライン (TestFlight/CI)**: Xcode から実機に直接転送してデモを行います。
- **エラーハンドリングの作り込み**: 基本的にエラーバナーの表示と再試行、およびサンプル写真へのフォールバックに限定します。

---

## 14. 各コードパスの想定される失敗モード

| コードパス | 想定される現実的な障害 | 検証方法 | エラー処理 | ユーザー側の表示 |
|---|---|---|---|---|
| `identifyVocab` | モデルIDの指定間違いによる404エラー | 事前テスト (§5d) | `GeminiError` バナー | エラーメッセージとリトライボタン |
| `identifyVocab` | モデルが不正な形式のJSONを返却 | `GeminiDecodingTests` | デコードエラー検知 → バナー表示 | エラーメッセージ表示 |
| `generateImage` | エンドポイントやパラメータの不整合によるエラー | 事前テスト (§5c) | バナー表示とデモモードへの移行 | エラーメッセージ、または固定画像表示 |
| `generateImage` | リクエストの応答ハング（フリーズ） | — | 30秒タイムアウト処理とキャンセル | 読み込み中表示 → タイムアウトバナー |
| `forge` | ワードバンクに単語が1つしかない状態で呼び出し | `WordBankTests` (`canForge`) | ボタンをタップ不可にする | ボタンがグレーアウトされタップできない |
| `SpeechPlayer` | デバイスに要求された音声データがない | — | `voice != nil` の判定 | 「音声データが利用できません」の警告文表示 |
| すべての通信 | 本番中のネットワーク遮断 | — | `demoMode` によるモックデータ利用 | オフラインで最後まで動作 |

---

## 15. 作業の並行化設計

| ステップ | 担当モジュール | 依存するタスク |
|---|---|---|
| 土台構築 (フェーズ0) | ルート, `Config/`, `State/`, `Models/` | — |
| 通信基盤 (フェーズ1) | `Networking/` | 土台構築 |
| 画像認識＋単語 (フェーズ2) | `Features/Capture/`, `Audio/` | 通信基盤 |
| 結合＋画像生成 (フェーズ3) | `Features/Forge/` | 通信基盤 |

- **レーン A:** フェーズ2 (`Features/Capture/` ＋ `Audio/`) — 担当者 A
- **レーン B:** フェーズ3 (`Features/Forge/`) — 担当者 B

**進め方:** 土台構築 → 通信基盤の実装までは順次行います。その後、レーンAとレーンBに分かれて並行して実装を進めます。Capture と Forge の間で共通で編集するファイルはないため、マージ競合のリスクは極めて低いです。どちらも `Networking/` と `State/` のファイルを参照しますが、フェーズ1以降でこれらを編集することはありません。Xcode の `.pbxproj` ファイルはファイルを新規追加する際に競合が発生しやすい唯一の場所ですので、追加する順番を調整するか、簡単なプロジェクトファイルの競合解消を行ってください。

---

## 16. 実装タスク項目 (Implementation Tasks)

ここまでのレビュー結果から抽出した具体的なタスクリストです。

- [ ] **T1 (P1, 作業想定: 約30分 / AI変換: 約5分)** — `AppConfig`/フェーズ1 — モデルIDの疎通、画像生成APIのエンドポイント確認、疎通テスト、フォールバック定数の確認
  - 抽出元: アーキテクチャ A1 / D2 + Codex #1/#2/#9
  - 編集ファイル: `Config/AppConfig.swift` など
  - 検証: `GET /v1beta/models` でID一覧を確認、画像生成の動作検証、`forge()` 疎通テスト
- [ ] **T9 (P1, 作業想定: 約30分 / AI変換: 約10分)** — `DemoData`/`GeminiService` — デモモード（オフライン動作）の実装
  - 抽出元: D5 / Codex #6
  - 編集ファイル: `DemoData.swift`, `Networking/GeminiService.swift`, `Config/AppConfig.swift`, アセット (同梱画像)
  - Verify: `demoMode=true` にて、CaptureからForgeまでが完全オフラインで動作すること、SynthIDキャプションが非表示であること
- [ ] **T10 (P2, 作業想定: 約20分 / AI変換: 約5分)** — `Audio` — `AVSpeechSynthesizer` を用いた音声再生の実装（Cloud TTSの廃止）
  - 抽出元: D4 / Codex #3
  - 編集ファイル: `Audio/SpeechPlayer.swift`
  - Verify: 単語タップ時に音声が再生されること、音声データがない場合に警告メッセージが出ること

---

## GSTACK レポート (GSTACK REVIEW REPORT)

| レビュー名 | トリガーコマンド | 目的 | 実行回数 | ステータス | 検出事項 |
|--------|---------|-----|------|--------|----------|
| CEO レビュー | `/plan-ceo-review` | 開発範囲と戦略の検証 | 0 | — | 未実行 |
| Codex レビュー | `/codex review` | 第三者AIによる独自レビュー | 1 | issues_found | Web調査から13件の新規指摘、モデル間の意見不一致3件を解消 |
| Eng レビュー | `/plan-eng-review` | アーキテクチャおよびテストの確認 | 1 | CLEAR | 9件の指摘、致命的な設計漏れは0件 |
| Design レビュー | `/plan-design-review` | UI/UXの課題抽出 | 0 | — | 未実行 |
| DX レビュー | `/plan-devex-review` | 開発体験の課題抽出 | 0 | — | 未実行 |

**決定された方針 (D1–D7):** D1 最小限のシミュレータ動作保証 · D2 モデルIDの事前疎通とフォールバック · D3 テスト対象ファイルの維持 · D4 AVSpeechSynthesizerの採用 (CLAUDE.mdの仕様を上書き) · D5 オフラインデモモードの実装 · D6 動作スライス優先のビルド順序 · D7 単体テストの維持。

**Codex指摘内容:** Cloud TTS 認証の罠を回避しオンデバイスTTSに変更、廃止された `gemini-2.0-flash` 参照を削除、画像生成APIは別構造にする、モックデモではなく完全オフラインデモモードの実装、SynthIDキャプションの表示条件制御。

**モデル間調整事項:** TTS（音声再生）、オフラインデモ、ビルド順序の3つの対立点を調整し、すべてCodexのアドバイスを適用。テスト範囲に関する議論はテストを維持する方向で決着。

**最終評価:** ENGクリア（開発着手可能）。CEO/Design レビューは小規模ハッカソン用途のため省略。

未解決の課題はありません。

- [ ] **T2 (P1, 作業想定: 約30分 / AI変換: 約5分)** — `Models`/`Networking` — `VocabCardDTO` と `VocabCard` の分離およびマッピング処理
  - 抽出元: コード品質 Q2
  - 編集ファイル: `Models/VocabCard.swift`, `Networking/GeminiService.swift`
  - Verify: `GeminiDecodingTests` でデコード時に例外がスローされないこと
- [ ] **T3 (P1, 作業想定: 約1.5時間 / AI変換: 約15分)** — `LensLearnTests` — `WordBankTests`、`GeminiDecodingTests` およびモックJSONの追加
  - 抽出元: テストレビュー / D3
  - 編集ファイル: `LensLearnTests/*`
  - Verify: すべての単体テストがパスすること
- [ ] **T4 (P2, 作業想定: 約20分 / AI変換: 約5分)** — `Networking` — `decode<T>` の共通化、30秒タイムアウト、キャンセル可能タスクの実装
  - 抽出元: コード品質 Q1 (重複排除) + アーキテクチャ A3 (タイムアウト)
  - 編集ファイル: `Networking/GeminiService.swift`
  - Verify: 接続ハング時にタイムアウトバナーが表示され、画面がフリーズしないこと
- [ ] **T5 (P2, 作業想定: 約20分 / AI変換: 約5分)** — `Features/Capture` — base64エンコード前に画像を ~1024px に縮小する処理
  - 抽出元: パフォーマンス向上 (大容量データの送信抑止)
  - 編集ファイル: `Features/Capture/CaptureViewModel.swift`
  - Verify: 12MPの写真を選択した際に、送信ペイロードサイズが適切なサイズに縮小されていること
- [ ] **T6 (P2, 作業想定: 約15分 / AI変換: 約3分)** — `Networking` — 画像生成コールでの `responseModalities: ["IMAGE"]` 設定
  - 抽出元: アーキテクチャ A2
  - 編集ファイル: `Networking/GeminiService.swift`
  - Verify: `generateImage` がテキストではなく `UIImage` を返すこと
- [ ] **T7 (P3, 作業想定: 約10分 / AI変換: 約3分)** — `State` — 単語文字列による Word Bank の重複排除
  - 抽出元: コード品質 Q3
  - 編集ファイル: `State/WordBank.swift`
  - Verify: `WordBankTests` で同じ単語を2回追加しても1つのままであること
- [ ] **T8 (P3, 作業想定: 約10分 / AI変換: 約2分)** — `Features/Forge` — `ForgeViewModel` へのアスキーアート状態遷移図コメントの追加
  - 抽出元: アーキテクチャ A4
  - 編集ファイル: `Features/Forge/ForgeViewModel.swift`
  - Verify: コード内にアスキーアート図が存在し、記述された4つの状態遷移と一致していること
