# Pastable · 日本語 App Store 文案

> App Store Connect の日本語 localization にそのまま貼れる文案。
> プライマリ言語は簡体字中国語のまま。英語版は [en-metadata.md](en-metadata.md)。

---

## フィールド

### 名前
```
Pastable
```

### サブタイトル（30文字以内）
```
呼び出してすぐ貼る。作業を止めない。
```
19文字。

### プロモーションテキスト（170文字以内）
```
画面下に全幅で現れるクリップボード棚。開いてもキーボードフォーカスを奪わないので、書いている文書のカーソルはそのまま。カードを選べばすぐ貼り付き、作業の流れが途切れません。
```

### キーワード（100文字以内、カンマ区切り、アプリ名を含めない）
```
クリップボード,貼り付け,コピー履歴,履歴,ショートカット,効率,検索,フローティング,メニューバー
```

### 説明
```
Pastable は、macOS の画面下に全幅で現れるクリップボード棚です。呼び出してすぐ貼る。作業を止めません。

【フォーカスを奪わないから、本当に止まらない】
・ショートカット（初期値は Command-Shift-V）で、どのアプリの上にも全幅の棚を呼び出せます
・棚を開いてもキーボードフォーカスを奪いません。カーソルも入力も、書いている文書に残ります
・カードを選ぶか Return を押すと、いまのアプリにそのまま貼り付けて棚は閉じます
・スペースを切り替えたりフルスクリーンにしても、棚は勝手に消えません

【3秒で、どこにでも戻れる】
・タイトルと全文を完全一致／あいまい検索。複数のキーワードにも対応
・テキスト、コード、リンク、画像、ファイルを自動分類。ヒット理由もハイライト
・カードはその場でプレビュー。画像はサムネイルを事前生成し、スクロールも軽い

【保存は、節度をもって】
・履歴はこの Mac の中だけ。必要なら、自分の iCloud のプライベート CloudKit に同期
・保存期間と件数の上限を設定可能。初めて超えたときは「整理 / すべて残す / あとで」を確認
・アカウントなし、広告なし、トラッキングなし、解析 SDK なし

【細部まで】
・自動貼り付け（アクセシビリティ権限が必要。未許可ならコピーのみ）
・Command-1…9 / Fn-1…9 のクイック貼り付け。グローバルショートカットは変更可能
・中国トレンド「朱砂（シュシャ）」テーマ。システムのライト／ダークに自動追従
・ログイン時に起動（任意）

macOS 15.5 以降が必要です。
```

### 新機能

1.2.0：
```
1.2.0
・パネルのレイアウトと検索フィールドを改善
・棚の位置とスペース移動時の表示を修正
・テーマの微調整とパフォーマンス改善
```

1.2.1：
```
1.2.1
・「Mac App Store で評価する」を設定に追加
・細かな最適化と安定性の改善
```

### 著作権
```
Copyright © 2026 Qiu ZH
```

---

## スクリーンショット

日本語 localization にこの順でアップロード：

1. `docs/appstore/screenshots/01-hero-ja-2880x1800.png`
2. `docs/appstore/screenshots/02-collection-ja-2880x1800.png`

最初の3秒で伝えること：**画面下の全幅シェルフ + 開いてもキーボードフォーカスを奪わない**。パネルは実際のアプリの日本語 UI、文書と注釈はマーケティング用の合成です。

## URL とその他

| フィールド | 値 |
|---|---|
| サポート URL | `https://qiuzhsgithub.github.io/Pastable/support.html` |
| マーケティング URL | `https://qiuzhsgithub.github.io/Pastable/en/` |
| カテゴリ | ユーティリティ / 仕事効率化 |
| 年齢制限 | 4+ |
| App プライバシー | データを収集していません |
| 価格 | 米国 $1.99 / 中国 ¥12 |

### App Review Notes
```
Thank you for reviewing Pastable, a local-first macOS clipboard manager.

1. No account or login is required. All history is stored locally (SwiftData);
   optional iCloud sync uses the private CloudKit database of the user's own
   iCloud account, which we cannot access.
2. "Auto Paste" simulates Command-V into the frontmost app and therefore needs
   the Accessibility permission. The app guides the user to System Settings →
   Privacy & Security → Accessibility. If it is not granted, the app still
   works normally (copy to clipboard instead). This is not a private API; it
   uses CGEvent + AXIsProcessTrusted, which is standard for MAS clipboard
   managers.
3. No private APIs, no analytics, no third-party SDKs, no adult content.
```
