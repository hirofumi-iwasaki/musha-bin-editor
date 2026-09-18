// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get languageLoadFailed => '保存済みの言語設定を読み込めませんでした。システム言語を使用しています。';

  @override
  String get languageSaveFailed => '言語設定を保存できませんでした。';

  @override
  String get openLeft => '左を開く';

  @override
  String get openRight => '右を開く';

  @override
  String get previousDiff => '前の差分';

  @override
  String get nextDiff => '次の差分';

  @override
  String get goToOffset => 'オフセットへ移動';

  @override
  String bytesPerRow(int count) {
    return '$count バイト/行';
  }

  @override
  String get compareAgain => '再比較';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get discard => '破棄';

  @override
  String get overwrite => '上書き';

  @override
  String get go => '移動';

  @override
  String get retry => '再試行';

  @override
  String get left => '左';

  @override
  String get right => '右';

  @override
  String get noFile => 'ファイルなし';

  @override
  String get noFileSelected => 'ファイルが選択されていません';

  @override
  String get calculating => '計算中…';

  @override
  String get unavailable => '利用できません';

  @override
  String get desktopUnavailable => 'デスクトップ連携を利用できません。';

  @override
  String get dropTooManyFiles => '一度にドロップできるファイルは 1 つです。';

  @override
  String get dropNotFinderFile => 'Finder のファイルだけをここにドロップできます。';

  @override
  String get dropNotReadableFile => 'ドロップされた項目は読み取り可能なファイルではありません。';

  @override
  String get dropCouldNotOpen => 'ドロップされたファイルを開けません。';

  @override
  String get dropOnPane => '左または右のバイナリペインにファイルをドロップしてください。';

  @override
  String get statusOpenTwoFiles => '比較する 2 つのファイルを開いてください';

  @override
  String get statusOneFilePreview => '1 つのファイルを開いています · 読み取り専用プレビュー';

  @override
  String get statusReadError => '読み取りエラー · ファイルを開き直してください';

  @override
  String get statusComparisonError => '比較エラー · ファイルを開き直してください';

  @override
  String get statusComparing => 'ファイルを比較中…';

  @override
  String get statusFindingDifference => '差分を検索中…';

  @override
  String get statusComparisonComplete => '比較が完了しました';

  @override
  String get statusFilesIdentical => '比較が完了しました · ファイルは同一です';

  @override
  String get statusNoLaterDifferences => 'これより後の差分はありません';

  @override
  String get statusNoEarlierDifferences => 'これより前の差分はありません';

  @override
  String get statusCanceled => 'キャンセルしました · 表示中の差分は引き続き利用できます';

  @override
  String statusEditingEnabled(Object side) {
    return '$sideの編集を有効にしました';
  }

  @override
  String statusEditingDisabled(Object side) {
    return '$sideの編集を無効にしました';
  }

  @override
  String statusEnterSecondHexDigit(Object digit) {
    return '2 桁目の 16 進数を入力: ${digit}_';
  }

  @override
  String statusEdited(Object offset) {
    return '0x$offset を編集しました';
  }

  @override
  String get statusHexInputCanceled => '16 進入力をキャンセルしました';

  @override
  String statusSaved(Object name) {
    return '$name を保存しました';
  }

  @override
  String statusOffset(Object offset) {
    return 'オフセット 0x$offset';
  }

  @override
  String statusDifferenceAt(Object offset) {
    return '差分 0x$offset';
  }

  @override
  String get statusComparisonStartFailed => '比較を開始できません';

  @override
  String get hexPaneNotCompared => '未比較';

  @override
  String get hexPaneEqual => '一致';

  @override
  String get hexPaneDifferent => '異なる';

  @override
  String hexPaneSelectedByte(Object offset, Object value, Object comparison) {
    return 'オフセット $offset、値 $value、$comparison';
  }

  @override
  String get hexPaneEditingEnabled => '編集有効';

  @override
  String get hexPaneEditingDisabled => '編集無効';

  @override
  String hexPaneSemantics(Object side, Object editing, Object selected) {
    return '$sideのバイナリペイン、$editing。$selected';
  }

  @override
  String get hexPaneOffsetHeader => 'オフセット';

  @override
  String get hexPaneAsciiHeader => 'ASCII';

  @override
  String get hexPaneDragFileHereToOpen => 'ファイルをここへドラッグして開く';

  @override
  String get hexPaneFileEmpty => 'このファイルは空です';

  @override
  String get desktopInitializationFailed => 'デスクトップ連携を初期化できませんでした。';

  @override
  String saveChangesToFile(Object side) {
    return '$sideのファイルへの変更を保存しますか？';
  }

  @override
  String get discardEditsWarning => '破棄すると未保存の編集は失われます。';

  @override
  String get openFileFailed => 'ファイルを開けません。';

  @override
  String get readFileFailed => 'ファイルを読み取れません。';

  @override
  String get comparisonFailed => '比較に失敗しました。';

  @override
  String get fileChangedOutsideApp => 'ファイルがアプリ外で変更されました';

  @override
  String get overwriteChangedFilePrompt => '外部で変更されたファイルを現在の編集内容で上書きしますか？';

  @override
  String get destinationChangedSaveAs =>
      '保存先がアプリ外で変更されました。もう一度「名前を付けて保存」を選んでください。';

  @override
  String get saveFileFailed => 'ファイルを保存できません。';

  @override
  String get saveNoFileOpen => '開いているファイルがありません。';

  @override
  String get saveInProgress => 'すでに保存中です。';

  @override
  String get saveOtherPaneHasDestination =>
      'もう一方のペインでこのファイルを開いています。別の保存先を選んでください。';

  @override
  String get saveCouldNotStart => '保存を開始できません。';

  @override
  String get saveNoBackend => 'このプラットフォームでは安全な保存機能を利用できません。';

  @override
  String get saveDestinationDirectoryMissing => '保存先のフォルダーがありません。';

  @override
  String get saveInstallationAmbiguous => '保存結果を確認できません。復旧用コピーを保持しました。';

  @override
  String get saveInstallationFailed => '保存済みファイルを配置できません。';

  @override
  String get saveSavedButCouldNotReopen => 'ファイルは保存されましたが、開き直せませんでした。';

  @override
  String get invalidHexOffset => 'ファイル内の16進オフセットを入力してください';

  @override
  String get hexOffsetHint => '16進オフセット（例: 400 または 0x400）';

  @override
  String fileDropTarget(Object side) {
    return '$sideファイルのドロップ先。バイナリファイルを1つドロップして開きます。';
  }

  @override
  String paneFileLabel(Object side, Object name) {
    return '$side · $name';
  }

  @override
  String chooseOpen(Object side) {
    return '$sideを開く';
  }

  @override
  String fileSizeDetails(Object size, int bytes) {
    return '$size · $bytes バイト';
  }

  @override
  String get editingOn => '編集オン';

  @override
  String get editingOff => '編集オフ';

  @override
  String savePane(Object side) {
    return '$sideを保存';
  }

  @override
  String savePaneAs(Object side) {
    return '$sideに名前を付けて保存';
  }

  @override
  String hashPaneLabel(Object side) {
    return '$side: ';
  }

  @override
  String get openingBlockedBySave => '保存中です。別のファイルを開く前に完了を待ってください。';

  @override
  String get alreadyOpenInOtherPane =>
      'このファイルはもう一方のペインですでに開かれています。個別に編集するにはコピーを開いてください。';

  @override
  String get error => 'エラー';

  @override
  String get hash => 'ハッシュ';

  @override
  String get sameOffsetComparison => '同一オフセット比較';

  @override
  String updateAvailable(Object version) {
    return '更新 $version を利用できます';
  }

  @override
  String get updateDownload => 'ダウンロード';

  @override
  String get updateViewRelease => 'リリースを見る';

  @override
  String get binaryFiles => 'バイナリファイル';

  @override
  String differenceSummary(Object label, int bytes, int ranges) {
    return '$label $bytes バイト / $ranges 範囲';
  }

  @override
  String get differences => '差分';

  @override
  String get foundSoFar => '現時点の検出';

  @override
  String selectedOffset(Object side, Object offset) {
    return '$side 0x$offset';
  }

  @override
  String get differenceLegend => '赤: 差分 · 橙: 片側のみ';
}
