# 作業計画と進捗

最終更新: 2026-09-14

## 現在地

- [x] 用途と技術候補を比較する。
- [x] Flutter／Dart採用、macOS優先という方針を決める。
- [x] プロジェクト用の作業管理文書を作成する。
- [x] 公開ライセンスをGPLv3に決定し、GPL-3.0-or-laterとして方針を記録する。
- [x] 初期版の詳細設計を整理し、ユーザーが開発方針として採用する（表示・比較試作まで実装）。
- [x] Flutter／Xcode等の開発環境を確認する。
- [x] Flutterプロジェクトを作成する。
- [x] 初期試作を実装する。
- [x] GitHubの保存先リポジトリーを確定する（hirofumi-iwasaki/musha-bin-editor）。
- [ ] 配布用リリースを整備する。

## 段階1: 開発環境と最小試作

1. このディレクトリーの文書を読み、既存ファイルと開発ツールを確認する。
2. 決定済みのmacOS 15/26に対応するFlutter安定版を選定し、使用SDKを記録する。
3. プロジェクトを作成し、Apple Silicon Macで起動する。
4. 2つのファイルを選択して左右にアドレス・16進数・文字を表示する。
5. 同一アドレスの差分を色分けする。
6. 同期スクロール、次／前の差分への移動を追加する。

完了条件: 内容が既知のファイルで差分位置が正しく表示され、スクロールと移動が操作できる。

## 段階2: 実用的な編集

- 採用した設計に沿って、左右の編集切替、上書き編集、選択・コピーを実装する。
- Undo／Redo、変更状態表示、別名保存を実装する。
- ファイルサイズの違い、空ファイル、末尾、保存失敗を扱う。
- 編集用スナップショット、外部変更検出、安全な上書き保存、未保存での終了操作を実装・検証する。

完了条件: 編集・取り消し・やり直し後の保存内容が期待するバイト列と一致する。

## 段階3: 性能と使い勝手

- 実用的な操作性を確認するためのファイルサイズと測定条件を決める（厳密な性能保証は要求しない）。
- 分割読み込み、表示範囲描画、比較・検索のバックグラウンド処理を評価する。
- フォーカス、キーボード操作、拡大率、日本語ファイル名、アクセシビリティを確認する。
- メモリー使用量とスクロール応答を測り、必要箇所を改善する。

## 段階4: OSS公開と配布

- GPL-3.0-or-laterのLICENSE本文、著作権・ライセンス表示、ソース提供方法を整備し、依存ソフトの条件を確認する。
- README、ビルド手順、対応環境、既知の制限、貢献方法を整理する。
- Git／GitHubの公開先とリリース方法を決める。
- macOS向け配布物、必要な署名・公証の方針を決め、配布状態で起動確認する。

## 後続候補

- 検索、チェックサム、挿入・削除を考慮した比較。
- Windows／Linux対応。
- 共通Dartライブラリ・Flutter表示部品の切り出し。
- 別プロジェクトでのTL866CS連携試作。
- GQ-4X4のSDK・プロトコル調査と実機検証。

## 作業記録

### 2026-09-13

- ユーザー指定の ~/Github/MushagaeshiBinDiff 配下に.chatgptを作成。
- 会話の決定事項、初期実装案、将来候補、未確定事項を分けて文書化。
- アプリ実装、開発環境の動作確認、実機USB検証は未実施。
- 次の作業: 開発環境確認と段階1の初期試作。

### 2026-09-13 詳細設計検討

- 既存の4文書を読み、Flutter/Dart・同一位置比較・上書き編集の方針を継承したDESIGN.mdを作成。
- 画面、左右編集、差分/欠損/未比較状態、Undo/Redo、安全な保存、外部変更、大容量処理、後続拡張を提案として整理。
- Flutterの対応環境・独自描画・IsolateとWinMergeの16進比較の公式資料を確認。
- 文書の作成と相互リンクを確認。アプリ実装・ビルド・性能測定・実機検証は未実施。
- 残課題: 設計案の運用上の好み、サイズ目標、SDK/検証OS、公開条件の確定。
- 次の作業: DESIGN.mdを基準に開発環境確認と左右表示の試作を行う。

### 2026-09-13 ライセンス決定

- ユーザーがGPLv3採用を決定。直前の推奨に沿ってGPL-3.0-or-laterとして記録。
- LICENSE_POLICY.mdを追加し、決定事項・設計案・作業計画の未確定表記を更新。
- 方針文書のみ更新。ルートLICENSE本文の配置と配布時の表示整備は今後の作業。

### 2026-09-13 設計方針の採用・決定事項の記録

- ユーザーが提示済みの設計方針を採用し、決定事項の書き出しを依頼。
- DECISIONS.mdに画面・比較・編集・保存・内部構成・開発順を記録し、解決済みの未確定事項を整理。
- DESIGN.mdの採用状態、README.mdの案内、作業計画を整合させた。
- 数値目標、SDK/対応OS、保存のOS固有動作、公開条件は未確定のまま保持。
- 更新文書の内容と参照を確認。実装、環境確認、ビルド、実機試験は未実施。
- 次の作業: 開発環境確認と左右表示・差分強調の試作。

### 2026-09-13 対応OS・性能方針の確定

- ユーザー指定によりmacOS 26と1世代前の15、M1以降を初期対象として確定。
- 性能は実用的な応答性を重視し、厳密な数値保証を求めない方針へ更新。
- GPLv3採用を再確認し、既存LICENSE_POLICY.mdのGPL-3.0-or-later表記を維持。
- その他は方針書に沿って開発側で判断することを記録。公開先・著作権者名・配布/署名は公開前の確認事項として整理。
- DECISIONS.md、DESIGN.md、ARCHITECTURE.md、WORK_PLAN.mdの整合性を確認。実装・実機試験は未実施。

### 2026-09-14 左右表示・差分強調の試作

- Flutter 3.47.4 / Dart 3.13.3をプロジェクト内に配置し、macOSのみのプロジェクトを生成。最低OS15、arm64に設定。
- 左右HEX/ASCII、差分強調、同期スクロール、差分/オフセット移動、サンプル、外部変更検出を実装。
- 静的検査、10件のテスト、macOSビルド・実機起動・ファイル選択・主要操作を確認。
- 比較と描画を計測し、文字レイアウトのキャッシュで描画処理を改善。値と測定条件はPROTOTYPE_REPORT.mdを参照。
- READMEへ起動/検証手順を記載し、決定済みGPLの本文と指定を配置。
- 未実施: 編集/保存、macOS15実機検証、VoiceOver音声確認、GitHub公開・配布用署名。
- 次の作業: 操作感のフィードバックを反映し、設計の段階Bへ進む。

### 2026-09-14 作業ディレクトリー移動とGit保存

- ユーザーが用意した~/Github/musha-bin-editor（origin: hirofumi-iwasaki/musha-bin-editor）の既存mainへ全ローカル資産を移動。
- ソース、macOSプロジェクト、テスト、設計・作業記録、ライセンス、依存固定ファイルをGit管理対象とした。
- Flutter SDK（.tooling）、ビルド成果物、IDE設定、キャッシュもローカルに移動し、既存の除外方針に従ってGit登録対象外とした。
- 移動先の初期コミットを保持。アプリ名と機能は変更しない。
- 移動後に依存情報を再生成し、静的検査（指摘なし）、10件のテスト、macOS Releaseビルドの成功を確認。
- このコミットを表示・比較試作の保存点とする。GitHubへの送信先はorigin/main。配布用リリースの作成は今回の範囲外。

### 2026-09-14 Release 0.1.0 UI revision

- Adopted the exact application name **Mushaaeshi Binary Editor** for the macOS bundle, executable, native window, application menu, Flutter UI and public README. The existing bundle identifier remains unchanged for app identity continuity.
- Converted the README and all application-owned UI, dialog, error, status and accessibility text to English. Localization remains deferred.
- Removed the redundant in-content application title row and retained Open Sample in the toolbar.
- Added synchronized vertical mouse-wheel and two-finger trackpad scrolling directly over either binary pane, including narrow layouts with horizontal overflow. Added regression coverage for both panes at 1440 px and 980 px window widths.
- Added `tool/build_macos.sh` to create the standalone application at `dist/Mushaaeshi Binary Editor.app`.
- Validation completed: Flutter static analysis reported no issues; all 12 tests passed; a fresh macOS Release build succeeded. Native UI inspection confirmed English labels, the 24-byte/four-range sample result, and synchronized scrolling from each pane.
- Bundle verification completed: display name, bundle name and executable are `Mushaaeshi Binary Editor`; development region is English; the executable is arm64; strict deep code-signature verification passes with the expected local ad-hoc signature. Public distribution signing and notarization remain future release work.
