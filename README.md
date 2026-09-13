# Mushagaeshi Bin Diff

Repository: [hirofumi-iwasaki/musha-bin-editor](https://github.com/hirofumi-iwasaki/musha-bin-editor)

macOS用の左右比較型バイナリービューアー／エディターを開発しています。
現在は **表示・比較の試作（0.1.0）** です。編集・保存は次の段階で実装します。

## 対応環境

- macOS 15 Sequoia / macOS 26 Tahoe
- Apple Silicon（M1以降、対象OSを実行できる機種）
- Flutter 3.47.4 / Dart 3.13.3（`.flutter-version`参照）
- 開発・ビルドにはXcodeが必要です。

macOS 26での検証結果は`.chatgpt/PROTOTYPE_REPORT.md`に記録します。macOS 15実機での確認は別途必要です。

## 試せること

- 左右それぞれのファイル選択（macOS標準ダイアログ）
- オフセット / HEX / ASCIIの左右表示
- 同一オフセットの不一致バイトを赤背景で強調
- 片側にしかない末尾を橙色で表示（欠損側は`--`）
- 左右同期のホイール・スクロールバー操作
- 8 / 16バイト単位の行表示、前 / 次の差分区間、オフセット移動
- バイトをクリックして選択、矢印 / Page Up・Down / Home・End操作
- 比較の進捗、キャンセル、再比較、外部変更時のエラー表示
- 「サンプルを開く」で24バイト / 4区間の差分を確認

起動後は「サンプルを開く」、または「左を開く」「右を開く」を選んでください。表示中のファイルを書き換える操作はありません。

ショートカット: 左を開く `⌘O`、右を開く `⌘⇧O`、オフセット移動 `⌘G`。オフセットは16進数です。

## 開発・起動

Flutter 3.47.4を用意して、プロジェクト直下で実行します。

```sh
flutter pub get
flutter run -d macos
```

この作業環境では、プロジェクト専用のSDKを`.tooling/flutter`に配置しています。シェル全体のPATHは変更していません。

```sh
.tooling/flutter/bin/flutter run -d macos
.tooling/flutter/bin/flutter build macos --release
open 'build/macos/Build/Products/Release/Mushagaeshi Bin Diff.app'
```

`.tooling`はGit管理対象外です。アプリのbundle identifier `dev.mushagaeshi.mushagaeshiBinDiff`はローカル開発用の暫定値です。

## 検証

```sh
flutter analyze
flutter test
dart run tool/benchmark.dart 1 100 1024
flutter run -d macos --profile --dart-define=BENCHMARK=true
```

比較ベンチマークは一時領域にファイルを生成し、終わると削除します。1GiBの計測では左右合わせて約2GiBの空き領域が必要です。作成直後のファイルなのでOSキャッシュの影響を受けます。表示計測はサンプルを180回スクロールし、フレーム構築・描画の中央値と95パーセンタイルをログに出します。

## 構成と制限

- `lib/core`: Flutter非依存の比較規則・差分区間集計・移動判定
- `lib/infrastructure`: ページ読込、外部変更検査、Isolateでの比較
- `lib/application`: 比較セッション、キャンセル、表示要求の世代管理
- `lib/presentation`: 表示中の行だけを描画するHEXペイン
- `macos/Runner`: ファイル選択・ウィンドウ設定

初期試作では2つのファイルを同じ位置で比較します。挿入による位置ずれは補正しません。ASCIIのみを表示します。

差分への移動は必要な区間まで先頭から再走査するため、大容量ファイルの末尾付近では待ち時間があります。差分索引による高速化は後続です。表示側は64KiBページキャッシュ、比較側は1MiB単位で読み込み、全バイトのWidgetや巨大な差分区間配列を保持しません。

外部変更検出はサイズ・更新日時・変更日時を基にしています。同時書き換えから完全なスナップショットを保証するものではありません。検出時はファイルを開き直してください。編集を追加する段階で保存用スナップショットを実装します。

VoiceOver向けに操作中バイトの情報とスクロール操作を用意していますが、実際の読み上げ操作は未検証です。選択範囲・コピー・編集・Undo/Redo・保存・ドラッグ＆ドロップは未実装です。

## ライセンス

本プロジェクトで作成するコードは **GNU GPL version 3 or later（GPL-3.0-or-later）** です。詳細は`LICENSE`と`.chatgpt/LICENSE_POLICY.md`を参照してください。第三者のコード・素材にはそれぞれのライセンスが適用されます。

設計と作業記録は`.chatgpt/`に集約しています。公開配布用の署名・公証、著作権者表記、第三者表示は公開前に整備します。
