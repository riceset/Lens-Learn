# Lens & Learn

> スマートフォンを被写体に向ける → 見えたものの単語を学ぶ → それらが組み合わさったAI生成の画像を見る。

Google I/O 2026 ハッカソンプロジェクト。開発時間：約4時間。

## 機能

1. **写真を撮影または選択する。** アプリが被写体を識別し、中国語（簡体字、ピンイン、例文、タップして聞く発音）でそれぞれにラベルを付けます。
2. **単語をワードバンク（Word Bank）に保存する。** 記憶したい単語をタップします。
3. **結合（Forge）。** ボタンをタップすると、保存した単語が自然な中国語の文章に編み込まれ、その文章を表すイラストが生成されます。語彙が絵になります。

## プラットフォーム

SwiftUIで構築されたiOSアプリ（Swift 6、iOS 17以上）。

## 技術スタック

| レイヤー | 技術 |
|---|---|
| 画像認識 / 単語抽出 | Gemini 3.5 Flash |
| 文章 ＋ 画像生成プロンプト | Gemini 3.5 Flash |
| イラスト生成 | Nano Banana 2 (`gemini-3.1-flash-image`) |
| 発音再生 | Cloud Text-to-Speech (`cmn-CN-Wavenet-A`) |
| 出所証明 | SynthID ウォーターマーク（自動） |

すべてのAPIは、Google AI Studioの単一のAPIキーを使用します。OAuthは不要です。

## はじめに (Getting started)

1. リポジトリをクローンし、Xcodeで `.xcodeproj` を開きます。
2. キーを設定した `Secrets.xcconfig`（git-ignored）を作成します。
   ```
   GEMINI_API_KEY = your_key_here
   ```
3. デバイスまたはシミュレーター（iOS 17以上）でビルドして実行します。

## プロジェクト構成

```
LensAndLearn/
├── Features/
│   ├── Capture/        # PhotosPicker → Gemini vision呼び出し → 単語カード表示
│   └── Forge/          # ワードバンク → 結合 → Nano Banana呼び出し → 結果画面
├── Networking/         # 共通のAPIクライアント
└── Models/             # VocabWord, ForgeResultなど
```

## Apple ドキュメント

以下のコマンドでAppleのドキュメントを取得できます。

```
npx @nshipster/sosumi fetch https://developer.apple.com/documentation/swift/array
```

## デモスクリプト

1. アプリを開き、部屋の写真を選択します。単語が表示されたら、タップして発音を確認します。
2. 3〜4つの単語を保存します。
3. **Forge** を押します → 文章が組み立てられ、イラストが描かれます。
4. 決め台詞：*"視覚化された文章で覚える、あなたのボキャブラリー。SynthIDによる出所証明付きです。"*
