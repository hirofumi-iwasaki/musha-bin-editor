# 作業計画と進捗

## Current milestone: v0.4.0 (2026-09-15)

- Working branch: `release/0.4.0`, created from merged main `0bd7646`.
- Goal: Windows x64/Arm64 and Ubuntu-only x64/Arm64, preserving macOS.
- Read [the continuation plan](RELEASE_0.4.0_PLAN.md) and [cross-platform design](CROSS_PLATFORM_DESIGN.md) before resuming.
- Completed: design review, scope record, branch creation.
- Validation: documentation consistency only; no platform implementation/build tests performed.
- Next action: prove native toolchain/plugin feasibility and identify target test environments.
- Earlier sections below are historical; the v0.4.0 plan defines current work.

## 0.3.0 hash display

- Changed the empty-pane instruction to “Drag file here to open”.
- Added a hash bar above the status bar with separate values for the left and right files.
- Added SHA-1 and MD5 selection, with SHA-1 as the default.
- Hash saved file contents asynchronously and discard stale results after a file or algorithm change.

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

- Adopted the corrected application name **Mushagaeshi Binary Editor** for the macOS bundle, executable, native window, application menu, Flutter UI and public README. The existing bundle identifier remains unchanged for app identity continuity.
- Converted the README and all application-owned UI, dialog, error, status and accessibility text to English. Localization remains deferred.
- Removed the redundant in-content application title row. Open Sample was retained at this intermediate revision and removed in the final 0.1.0 revision below.
- Added synchronized vertical mouse-wheel and two-finger trackpad scrolling directly over either binary pane, including narrow layouts with horizontal overflow. Added regression coverage for both panes at 1440 px and 980 px window widths.
- Added `tool/build_macos.sh` to create the standalone application at `dist/Mushagaeshi Binary Editor.app`.
- Validation completed: Flutter static analysis reported no issues; all 12 tests passed; a fresh macOS Release build succeeded. Native UI inspection confirmed English labels, the 24-byte/four-range sample result, and synchronized scrolling from each pane.
- Bundle verification completed: display name, bundle name and executable are `Mushagaeshi Binary Editor`; development region is English; the executable is arm64; strict deep code-signature verification passes with the expected local ad-hoc signature. Public distribution signing and notarization remain future release work.

### 2026-09-14 Native scrolling and file drop follow-up

- Replaced custom wheel/trackpad sign handling, fixed row-step accumulation and the hand-built scrollbar with Flutter's standard vertical `ScrollPosition` and `Scrollbar`. Raw macOS/Flutter vertical deltas are forwarded unchanged, preserving the user's natural-scrolling setting and standard sensitivity/physics while both panes share one position.
- Added native macOS file-URL drag/drop. Exactly one regular file is accepted; the window half under the pointer maps to the left or right pane, security-scoped read access is retained, and the existing comparison pipeline reloads automatically.
- Added English invalid-drop/read-failure messages and English accessibility labels identifying each pane as a left/right single-file drop target.
- Confirmed that the existing read-only user-selected-file sandbox entitlement is sufficient; no dependency or additional entitlement was added.
- Final validation: Flutter static analysis reported no issues; all 13 tests passed; the macOS Release package rebuilt successfully after native Swift compilation. Native UI inspection confirmed the English drop-target accessibility labels, the standard macOS scrollbar, and synchronized movement over both left and right panes. The packaged executable is arm64 and strict deep signature verification passes with the expected local ad-hoc signature and read-only user-selected-file sandbox entitlement.

### 2026-09-14 Finder drop event-routing repair

- Reproduced the design flaw in the first drag/drop implementation: registering the `NSWindow` did not make it the effective destination when the Flutter content view occupied the window.
- Added a dedicated AppKit root drop-host view around the Flutter view controller. The host registers file URL types, validates one regular Finder file, retains security-scoped access, and forwards live drag/drop coordinates through the existing method channel.
- Moved left/right selection to Flutter hit-testing against the actual rendered pane rectangles. The full pane header and HEX body are targets; areas outside both panes show an English guidance error.
- Added a primary-color hover border/background for the actual pane under the drag while retaining the English accessibility drop-target labels.
- Extended tests for native message routing, real pane coordinates, left/right selection, English errors, accessibility labels and hover state. Static analysis is clean and all 13 tests pass. The Release Swift build succeeds and the packaged app launches with the Flutter surface hosted correctly.

### 2026-09-14 Final 0.1.0 sample removal

- Removed Open Sample completely from the product UI and removed its user-facing README/status references.
- Removed the `DEMO` launch path. The generated file-pair fixture remains as `loadBenchmarkFixture` because controller regression tests and the opt-in rendering benchmark require deterministic data; it is not reachable from normal product UI.
- Updated widget and scrolling tests to assert that Open Sample is absent while Open Left, Open Right, synchronized scrolling and Finder drop targets remain available.
- Final validation completed: static analysis reported no issues; all 13 tests passed; a clean macOS Release build and package succeeded after regenerating nested signatures. The packaged executable is arm64 and strict deep code-signature verification passes.

### 2026-09-14 Version 0.2.0 editing and saving

- Added independent Edit ON/OFF state, two-digit HEX byte overwrite, pending-nibble cancellation, edited-byte underlines and per-pane dirty indicators.
- Applied sparse edits to viewport reads and background comparison so difference colors/counts update from in-memory content.
- Added Save and Save As with native macOS save panels, staged temporary output, native destination replacement, external-change confirmation and English failure messages.
- Added Save / Discard / Cancel protection for replacing dirty panes and closing the window. Rejects opening or saving over the file in the opposite pane.
- Updated both macOS sandbox configurations from user-selected read-only to narrowly scoped user-selected read/write; no broader filesystem entitlement was added.
- Hardened packaging by applying only `Release.entitlements` to the outer ad-hoc signature, removing the build system's debug-only `get-task-allow` entitlement from the packaged app.
- Repaired Save As after native testing exposed a sandbox failure: the original implementation attempted to create a sibling temporary file outside the exact path authorized by `NSSavePanel`. Output is now staged in the app temporary directory and installed through the native macOS layer. Native Save Left As verification confirmed byte-identical output, destination-name adoption and the Saved status; static analysis and all 19 tests pass.
- Repaired opening the former source in the opposite pane after Save As. File validation no longer treats metadata-only ctime changes from sandbox access or cloud-file attributes as binary-content changes; size and mtime still protect against external content edits.

### 2026-09-14 Product name spelling correction

- Replaced the mistaken “Mushaaeshi” spelling with “Mushagaeshi” throughout repository source, package metadata, tests, scripts, documentation and macOS product settings.
- Kept the existing correctly spelled bundle identifier for compatibility while standardizing the external product name as **Mushagaeshi Binary Editor**.


### 2026-09-15 v0.4.0 implementation checkpoint (Terra delegation)

- Parent task managed scope and integration; GPT-5.6 Terra agents implemented UI/platform portability, save transactions and native CI/backends.
- Added Windows/Ubuntu runners and adapters using file_selector 1.1.0, desktop_drop 0.8.4, window_manager 0.5.2 and path 1.9.1. Existing macOS channel behavior remains.
- Unified measured/scaled glyph geometry, hit testing, scroll calculations and highlights; fixed initialization lifecycle and preserved the macOS metadata entry.
- Replaced unsafe copy fallback, froze edit snapshots, serialized saves through adoption, added worker handle-close acknowledgements, destination-change checks and recovery paths. Tests cover open/save races, source changes during Save As and ambiguous installation.
- Added Windows ReplaceFileW/MoveFileExW and Ubuntu same-filesystem rename backends plus conservative metadata rejection. These native backends have not been executed on their target OS.
- Added pinned native CI/bootstrap and complete-bundle packaging with architecture inspection, notices and source references. No CI run or release publication has occurred.
- Integration checkpoint: flutter analyze clean; all 29 Flutter tests passed. macOS Release build and packaging succeeded (arm64, strict deep code signature valid, development version 0.3.0 build 3). The archive includes LICENSE, third-party notices/licenses and source/build metadata.
- Remaining: native Windows/Ubuntu builds and GUI acceptance on x64/Arm64, OS save-failure validation, macOS regression acceptance and eventual release metadata/publishing.


### 2026-09-15 Parallels native Arm64 builds

- User provided running Windows 11 Arm64 and Ubuntu 26.04 LTS Arm64 VMs. Used Parallels Tools guest execution with dedicated VM workspaces, not shared host build directories.
- Ubuntu: installed required Clang/CMake/Ninja/GTK development prerequisites; official Flutter 3.47.4 source checkout at 9584c671 with native aarch64 Dart 3.13.3. Workspace: /home/parallels/musha-build/project.
- Windows: installed Git for Windows Arm64 and Visual Studio Build Tools 2022 17.14.40 with C++ Arm64 tooling, plus official pinned Flutter source bootstrap. VM dedicated workspace under C:\musha-build. No existing project files were overwritten.
- Native compile fixes: Linux Flutter messenger API (b3abe05); Windows checked UTF string length conversion and PowerShell reserved variable/bundled Dart invocation (ba2b16c).
- Cross-OS tests exposed asynchronous resource cleanup; added awaitable controller.close(), Windows basename handling and explicit OS-specific test scoping. Final test-only fix: 7c4dc3a.
- Final source for both archives: 7c4dc3a1f4f246b5824408f02f005f59e2a1d215.
- Windows: analyze clean; 25 tests passed / 4 POSIX/macOS-specific skips; native Release and package succeeded; all EXE/DLLs verified PE ARM64 (0xAA64).
- Ubuntu 26.04: analyze clean; 28 tests passed / 1 macOS-specific skip; native Release and package succeeded; executable verified ELF aarch64.
- Host artifacts: dist/musha-bin-edit-windows-arm64.zip (11,165,203 bytes, SHA-256 0c7e763bf2e5e57a01f3447e6ffa7cec25e00ab976d2ab6c9bb6e3d7143f0e29); dist/musha-bin-edit-linux-arm64.tar.gz (SHA-256 74157c5b60f08ce35906c1617315d8c31c3ec70715ea3e2b7d30de590ea9a3c2).
- Both archives contain complete runtime bundles, LICENSE, dependency notices/licenses and exact source/build metadata. Version remains 0.3.0 build 3 during development.
- Unverified: x64 builds, Ubuntu 22.04/24.04 compatibility, GUI launch/drop/save/close acceptance and native save-failure behavior. No push or release publication. Ubuntu 26.04 build is not a substitute for builds against the oldest supported baseline.


### 2026-09-15 GitHub Actions native matrix verified

- User reported normal manual operation of the supplied VM builds and requested Actions Arm64/x64 builds.
- Updated the workflow for clean-runner pub get and Linux liblzma-dev, committed/pushed as 9d15351 on release/0.4.0.
- Successful run: https://github.com/hirofumi-iwasaki/musha-bin-editor/actions/runs/34933106095. All seven jobs passed: Windows x64/Arm64, Ubuntu 22.04/24.04 x64/Arm64, macOS Arm64.
- Every job completed native SDK bootstrap, analysis/tests, Release build, package architecture checks and artifact upload. Seven non-expired artifacts confirmed via API.
- CI results establish native compilation/testing/packaging on the planned Ubuntu baselines. They do not establish all GUI or native save-failure scenarios.
- Trigger: release/0.4.0 pushes, pull requests, workflow_dispatch (UI availability after default-branch merge). No GitHub Release publication performed; development version unchanged.
- Next: record remaining manual acceptance and native failure cases, update release metadata when preparing v0.4.0, then publish upon request.


### 2026-09-15 v0.5.0 update notification design

- Created release/0.5.0 from synchronized main at 506bda6.
- Added UPDATE_CHECK_DESIGN.md covering nonblocking GitHub release discovery, stable version comparison, OS/architecture asset links, caching and rate limits, silent failures, lifecycle and macOS network entitlement requirements.
- Updated the project record index to point to the current design.
- This is documentation only; no update code, dependency changes, builds or runtime tests were performed. Detailed policy defaults remain proposals.
- Next: implement the documented service and status notification, then extend CI to the new branch and verify native behavior.

### 2026-09-15 v0.5.0 update notification implementation

- Implemented the first-frame, unawaited update controller and a separate bottom-status notification. It uses package metadata, a 5-second/1 MiB bounded HTTPS client, persisted cadence/backoff state, exact process-ABI asset matching, and user-initiated, allowlisted GitHub links only.
- Added `package_info_plus`, `shared_preferences`, and `url_launcher`; added `network.client` to both macOS sandbox entitlement files; updated the package version to `0.5.0+5` and the CI push branch to `release/0.5.0`.
- Added update-specific unit and widget tests. Local `flutter analyze` reported no issues and `flutter test` passed all 40 tests.
- The controller caches only a validated offered update and its ETag. A valid 200 response with no newer stable offer or an invalid response clears that cache and records a successful validation, so it waits the normal 24-hour interval. Transient retries use deterministic bounded jitter of 2, 4, or 6 minutes rather than randomized jitter.
- macOS Release build was attempted with `.tooling/flutter/bin/flutter build macos --release` but stopped before compilation because Xcode reported that its license agreements were not accepted and requested `sudo xcodebuild -license`. No entitlement inspection or native package verification was performed. No push or release publication occurred.
