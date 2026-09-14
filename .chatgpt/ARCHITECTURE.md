# 設計・開発方針

最終更新: 2026-09-14

## 基本方針

初期対象はmacOS 26/15、M1以降のApple Silicon。性能は実用上ほどほどの応答性を目指し、厳密な速度保証や過度な最適化は求めない。正確さ・保存の安全性・保守性を優先する。ライセンスはGPL-3.0-or-later。その他の通常の実装判断は本方針とDESIGN.mdに従う。

Flutterで画面、Dartでバイナリー処理を実装する。初期段階でRustやC++を導入する必要はない。性能測定やUSB連携で必要性が明確になった時点で、FFIや外部プロセス連携を検討する。

最初は1つのFlutterプロジェクト内で責務を分離すればよい。再利用が具体化してから共通パッケージへ切り出し、初期から複雑な構成にしない。

## 責務の分離

| 部分 | 責務 | 依存方針 |
| --- | --- | --- |
| バイナリー中核 | バイト列、アドレス、比較、編集履歴、検索 | Flutterに依存させない |
| ファイルアクセス | 範囲読み込み、キャッシュ、保存、外部変更検出 | 中核とUIから境界を設ける |
| 16進数表示部品 | アドレス・HEX・文字描画、選択、差分色、入力 | 将来の別アプリでも再利用可能にする |
| アプリ操作 | ファイルを開く、比較、編集、保存、画面状態 | 中核処理と画面を接続する |
| OS連携 | ファイル選択、メニュー、配布関連 | OS固有部分を限定する |

## 大容量ファイルへの備え

- ファイル全体を巨大な文字列に変換しない。
- 必要な範囲を分割読み込みし、上限を設けたキャッシュを検討する。
- 全バイト分のWidgetを生成せず、表示範囲を中心に描画する。
- CustomPainter／TextPainter等を使う方式を試作して評価する。
- CPU負荷の高い比較・検索はIsolateで処理する。単にasync化するだけで計算負荷がUIから分離されるとは考えない。
- Isolate間で巨大データを繰り返しコピーしない構成を検討する。
- 同一アドレス比較と挿入・削除対応比較を別の機能として扱う。
- 元データと編集差分を分離し、変更履歴を管理する。

## 操作とデータ保全

- 独自描画ではフォーカス、キーボード移動、選択、コピー、アクセシビリティを個別に設計する。
- 差分、選択、カーソル、編集済みの表示を区別する。
- 保存失敗で元ファイルを失わない保存手順を設計する。
- 未保存編集のある状態での再読み込み・終了を扱う。
- 比較結果の計算中やキャンセル時にもUIが操作できるようにする。

## 将来のUSBアプリ

共通部品は読み出し結果の表示、ファイルとの差分比較、書き込み後の不一致表示に利用する。USB通信、プログラマー固有プロトコル、IC固有アルゴリズムは本エディターから独立させる。

minipro等の利用時は採用バージョンのライセンス・再配布条件を確認する。外部プロセス方式かFFI方式かはUSBアプリ側で決める。

## 表示試作の実装状況（2026-09-14）

表示試作では64KiBの範囲読込キャッシュと、操作単位の比較Isolateを実装。1MiB単位のストリーム比較と上限2048件の文字描画キャッシュを採用した。編集状態を所有する長寿命Isolate、差分ブロック索引、編集用スナップショットは後続とする。機能と測定結果はPROTOTYPE_REPORT.mdを参照。

## 0.2.0 editing and saving

Each pane owns an independent sparse offset-to-byte edit overlay. Viewport reads apply the overlay after paged disk reads, and comparison workers receive immutable copies so edited differences are reflected without writing the source. Saving streams 1 MiB blocks through the overlay to the app's temporary directory, flushes it, rechecks the source stamp and then asks AppKit to install it at the exact user-selected destination. AppKit owns Open/Save panels, security-scoped URLs and the final filesystem replacement; Dart owns validation and file transformation. The sandbox grants read/write only for user-selected files.
