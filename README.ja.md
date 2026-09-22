# Mushagaeshi Binary Editor

[English](README.md) | **日本語**

macOS、Windows、Ubuntu向けの、左右並列表示による16進数バイナリビューアー、比較ツール、固定長バイト編集アプリです。

リポジトリ: [hirofumi-iwasaki/musha-bin-editor](https://github.com/hirofumi-iwasaki/musha-bin-editor)

[v0.7.0](https://github.com/hirofumi-iwasaki/musha-bin-editor/releases/tag/v0.7.0)を公開しています。この版では日本語・英語のUIローカライズと、選択を保存する言語設定を追加しました。v0.6.0ではMushagaeshiのアプリアイコンをmacOS、Windows、Linuxのパッケージへ追加し、v0.5.0では新しいリリースを静かに確認するバックグラウンド更新チェックを追加しています。ローカライズによるバイナリ比較、編集、安全な保存の動作変更はありません。

v0.7.2では、プラグイン登録後に競合するネイティブ`desktop_drop`オーバーレイを無効化し、アプリのAppKitドロップホストがFinderからのドラッグを受け取り、Finderのセキュリティスコープを保持できるようにしました。この経路はネイティブ回帰テストとFlutterのドロップテストで確認していますが、リリースバンドル上での物理的なFinderドラッグは未確認です。

## リリース状況

必要なライセンスとソース／ビルド参照を含むv0.7.0の5つのバイナリアーカイブを公開しています。ソースリビジョン`629eba1`に対する[GitHub Actions run 35310954380](https://github.com/hirofumi-iwasaki/musha-bin-editor/actions/runs/35310954380)では、Windows x64／Arm64、Ubuntu 22.04／24.04 x64／Arm64、macOS Arm64のビルド、パッケージ作成、アーキテクチャ検査、静的解析、テストが成功しています。

自動ビルドとパッケージ検査は、すべてのネイティブ障害経路やGUI操作を確認するものではありません。各OSでの起動、ファイル選択、ドラッグ＆ドロップ、保存復旧、アクセシビリティの受入確認は別の検証です。公開バイナリはWindowsとLinuxでは未署名です。macOSパッケージはローカルのアドホック署名を使用しており、公証は受けていません。

## 動作要件

- Apple Silicon（M1以降）のmacOS 15 SequoiaまたはmacOS 26 Tahoe
- Windows 11 x64またはArm64
- Ubuntu 22.04または24.04 LTS x64またはArm64
- 配布アプリの実行にFlutterのインストールは不要

開発にはFlutter 3.47.4とDart 3.13.3を使用します。macOSでの開発にはXcodeも使用します。固定したFlutter SDKは[.flutter-version](.flutter-version)を参照してください。

## UI言語対応

左上の**Language / 言語**で、**System / システム**、**English**、**日本語**を選べます。手動選択はすぐにアプリ表示へ反映され、次回起動時にも維持されます。SystemではOSの優先言語リストの先頭だけを使用します。先頭が`ja`（地域付きの日本語を含む）なら日本語を選び、それ以外の先頭言語では英語を選びます。日本語が優先リストの後ろにあるだけでは日本語表示になりません。

手動の言語変更で、開いているファイル、未保存の編集、現在のオフセット、実行中の比較は変更されません。macOSのアプリメニューは選択したアプリ言語に従います。ネイティブのファイル選択、ServicesなどOSが管理する部分は、OSの言語のままになることがあります。

## ダウンロードと起動

[Releases](https://github.com/hirofumi-iwasaki/musha-bin-editor/releases)から使用中のシステム向けアーカイブを取得し、アーカイブ全体を展開してから同梱アプリを起動してください。展開したファイルはすべて一緒に保持します。

| プラットフォーム | アーカイブ |
| --- | --- |
| Windows x64 | `musha-bin-edit-windows-x64.zip` |
| Windows Arm64 | `musha-bin-edit-windows-arm64.zip` |
| Ubuntu x64 | `musha-bin-edit-linux-x64.tar.gz` |
| Ubuntu Arm64 | `musha-bin-edit-linux-arm64.tar.gz` |
| macOS Apple Silicon | `musha-bin-edit-macos.zip` |

macOSでは展開後に**Mushagaeshi Binary Editor.app**を開きます。ローカルでパッケージを作成したアプリは`dist/Mushagaeshi Binary Editor.app`にあり、次で開けます。

```sh
open 'dist/Mushagaeshi Binary Editor.app'
```

LinuxアーカイブにはGTKのウィンドウアイコン、freedesktopのデスクトップエントリー、`share/`配下のhicolorアイコンテーマファイルが含まれます。インストーラーはこれらをXDGデータディレクトリーに配置して`mushagaeshi_binary_editor`を`PATH`から起動できるようにできますが、単に展開しただけではランチャーは登録されません。インストール前は同梱実行ファイルを直接起動してください。

**Open Left**と**Open Right**でファイルを選ぶか、各バイナリペーンへ1つずつファイルをドロップして比較します。開く操作と比較はファイル内容を変更しません。

## 機能

- オフセット、16進数バイト、ASCII文字の左右並列表示
- 異なるバイトを赤、片側だけにあるバイトをオレンジで表示
- 0バイトと区別して不足バイトを`--`で表示
- 同期する縦スクロールと横スクロール
- macOS、Windows、Linuxでのネイティブなファイル選択と、各ペーン1ファイルのドラッグ＆ドロップ
- ファイルごとのSHA-1またはMD5ハッシュ表示（初期値はSHA-1）
- 1行あたり8または16バイトの表示
- 前後の差分範囲と16進オフセットへの移動
- クリックでのバイト選択、矢印キー、Page Up／Down、Home／Endによるキーボード移動
- ペーンごとのEdit ON／OFFと、選択バイトを16進数2桁で上書きする編集
- 未保存変更の表示と即時の比較更新
- 一時出力を使うSave／Save As、外部変更の確認
- 編集済みファイルの置換やウィンドウ終了時のSave／Discard／Cancel保護
- 比較進捗、キャンセル、再比較、外部変更検出
- 日本語・英語の操作部、状態表示、ダイアログ、ツールチップ、アクセシビリティラベル
- 新しい互換リリースがある場合、検証済みGitHubダウンロードまたはリリースページのリンクを表示する静かなバックグラウンド更新チェック

以下のCommandショートカットはWindowsとLinuxではCtrlを使用します。ネイティブのmacOS、Windows、Linuxパッケージにはアプリアイコンが含まれます。

## キーボードショートカット

| 操作 | ショートカット |
| --- | --- |
| 左ファイルを開く | `Command+O` |
| 右ファイルを開く | `Command+Shift+O` |
| オフセットへ移動 | `Command+G` |
| 隣のバイト／行を選択 | ペーンにフォーカスがある状態で矢印キー |
| 1画面分スクロール | Page Up / Page Down |
| 先頭／末尾へ移動 | Home / End |
| 選択バイトを編集 | Edit ONで16進数2桁 |
| 1桁目の入力を取り消す | Escape |

オフセットは16進数です。例: `400`または`0x400`。ハッシュバーにはディスク上の保存済みファイル内容を表示します。ドロップダウンで**SHA-1**または**MD5**を選べます。ファイルを開くか保存すると値を再計算します。

## 更新チェック

ウィンドウが最初に表示された後、アプリは新しい安定版をGitHubへ静かに確認できます。ファイル内容、パス、ハッシュ、編集内容、アカウント識別子、テレメトリーは送信しません。GitHubの公開リリースAPIを使用し、バージョン、リリースページ、正確なアーカイブ名を検証してから、ステータス行にモーダルではないリンクを表示します。アプリ自身がダウンロード、インストール、展開、再起動を行うことはありません。

ネットワーク、キャッシュ、レート制限、リンク検証のルールは[更新チェック設計](.chatgpt/UPDATE_CHECK_DESIGN.md)を参照してください。

## 開発とパッケージ作成

Flutter 3.47.4をインストールして、リポジトリのルートから実行します。

```sh
flutter pub get
flutter run -d macos
```

このワークスペースには`.tooling/flutter`のプロジェクトローカルSDKを置けます。Gitの管理対象外で、システム全体のPATHは変更しません。

macOSの単体アプリをビルドしてパッケージ化します。

```sh
./tool/build_macos.sh
```

対応するホスト上でWindowsまたはLinuxのネイティブパッケージを作成します。

```sh
tool/build_windows.ps1 -Architecture x64
bash tool/build_linux.sh x64
```

Arm64では`arm64`を指定します。各アーカイブにはランタイムバンドル、`LICENSE`、`THIRD_PARTY_NOTICES.txt`、`THIRD_PARTY_LICENSES/`、`SOURCE_AND_BUILD.txt`を含めます。Arm64 CIは固定した公式Flutterソースを取得して、ネイティブDartとエンジンの成果物を得ます。

## 検証

```sh
flutter analyze
flutter test
dart run tool/benchmark.dart 1 100 1024
flutter run -d macos --profile --dart-define=BENCHMARK=true
```

テストは比較境界、編集、安全な保存、外部変更、移動、古い表示要求、ファイルドロップ、スクロール、ローカライズ、更新チェックの検証を対象にします。比較ベンチマークは一時的なファイルペアを作り、後で削除します。1 GiBのケースには約2 GiBの空き容量が必要です。描画ベンチマークは内部で生成したフィクスチャを使用し、製品UIからは利用できません。

## アーキテクチャと制限事項

- `lib/core`: Flutterに依存しない比較規則、範囲カウント、移動
- `lib/infrastructure`: ページ読み込み、変更確認、安全な保存、バックグラウンド比較
- `lib/application`: 比較セッション、キャンセル、ビューポート要求世代
- `lib/presentation`: 表示中の16進行だけを描画
- `lib/platform`: ネイティブデスクトップ連携の境界
- `macos/Runner`、`windows/runner`、`linux/runner`: ネイティブのウィンドウ、ファイル、保存、パッケージ連携

比較は絶対オフセットを使用するため、挿入と削除を再配置して比較しません。文字表示はASCIIのみです。差分範囲への移動は現在、必要な範囲まで先頭から走査するため、大きなファイルの末尾付近では時間がかかる場合があります。表示読み込みには64 KiBのページキャッシュ、比較読み込みには1 MiBブロック、文字レイアウトには最大2,048件の上限付きキャッシュを使用します。

外部変更検出は、読み込み、比較、保存時にサイズとタイムスタンプを確認します。外部変更されたソースは、ユーザーが上書きを確認するまで保存を拒否します。Ubuntuでは、メタデータを失わないように、特殊パーミッションビット、所有者／グループ変更、ACL、その他の拡張属性がある場合に置換を拒否します。通常のrwxパーミッションは保持します。ファイル変更検出は、すべての外部書き換えを検出できるわけではありません。

アクセシビリティラベルは編集状態、選択バイト、各ファイルドロップ先を示します。VoiceOverの完全な操作確認は未実施です。範囲選択、コピー／ペースト、undo／redo、挿入、削除は未実装で、編集は固定長のバイト上書きだけです。

## ライセンス

プロジェクト独自のコードは**GNU GPL version 3 or later（GPL-3.0-or-later）**で提供します。[LICENSE](LICENSE)と[ライセンス方針](.chatgpt/LICENSE_POLICY.md)を参照してください。サードパーティーのコードとアセットには、それぞれのライセンスが適用されます。設計上の決定と作業記録は`.chatgpt/`にあります。
