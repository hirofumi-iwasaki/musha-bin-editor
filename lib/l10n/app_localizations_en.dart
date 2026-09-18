// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageLoadFailed =>
      'The saved language preference could not be read. System language is in use.';

  @override
  String get languageSaveFailed =>
      'The language preference could not be saved.';

  @override
  String get openLeft => 'Open Left';

  @override
  String get openRight => 'Open Right';

  @override
  String get previousDiff => 'Previous Diff';

  @override
  String get nextDiff => 'Next Diff';

  @override
  String get goToOffset => 'Go to Offset';

  @override
  String bytesPerRow(int count) {
    return '$count B/row';
  }

  @override
  String get compareAgain => 'Compare Again';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get discard => 'Discard';

  @override
  String get overwrite => 'Overwrite';

  @override
  String get go => 'Go';

  @override
  String get retry => 'Retry';

  @override
  String get left => 'Left';

  @override
  String get right => 'Right';

  @override
  String get noFile => 'No file';

  @override
  String get noFileSelected => 'No file selected';

  @override
  String get calculating => 'Calculating…';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get desktopUnavailable => 'Desktop integration is not available.';

  @override
  String get dropTooManyFiles => 'Drop exactly one file at a time.';

  @override
  String get dropNotFinderFile => 'Only files from Finder can be dropped here.';

  @override
  String get dropNotReadableFile => 'The dropped item is not a readable file.';

  @override
  String get dropCouldNotOpen => 'Unable to open the dropped file.';

  @override
  String get dropOnPane => 'Drop the file on the left or right binary pane.';

  @override
  String get statusOpenTwoFiles => 'Open two files to compare';

  @override
  String get statusOneFilePreview => 'One file open · Read-only preview';

  @override
  String get statusReadError => 'Read error · Reopen the file';

  @override
  String get statusComparisonError => 'Comparison error · Reopen the files';

  @override
  String get statusComparing => 'Comparing files…';

  @override
  String get statusFindingDifference => 'Finding difference…';

  @override
  String get statusComparisonComplete => 'Comparison complete';

  @override
  String get statusFilesIdentical =>
      'Comparison complete · Files are identical';

  @override
  String get statusNoLaterDifferences => 'No later differences';

  @override
  String get statusNoEarlierDifferences => 'No earlier differences';

  @override
  String get statusCanceled =>
      'Canceled · Visible differences remain available';

  @override
  String statusEditingEnabled(Object side) {
    return '$side editing enabled';
  }

  @override
  String statusEditingDisabled(Object side) {
    return '$side editing disabled';
  }

  @override
  String statusEnterSecondHexDigit(Object digit) {
    return 'Enter second hex digit: ${digit}_';
  }

  @override
  String statusEdited(Object offset) {
    return 'Edited 0x$offset';
  }

  @override
  String get statusHexInputCanceled => 'Hex input canceled';

  @override
  String statusSaved(Object name) {
    return 'Saved $name';
  }

  @override
  String statusOffset(Object offset) {
    return 'Offset 0x$offset';
  }

  @override
  String statusDifferenceAt(Object offset) {
    return 'Difference at 0x$offset';
  }

  @override
  String get statusComparisonStartFailed => 'Unable to start comparison';

  @override
  String get hexPaneNotCompared => 'not compared';

  @override
  String get hexPaneEqual => 'equal';

  @override
  String get hexPaneDifferent => 'different';

  @override
  String hexPaneSelectedByte(Object offset, Object value, Object comparison) {
    return 'Offset $offset, value $value, $comparison';
  }

  @override
  String get hexPaneEditingEnabled => 'editing enabled';

  @override
  String get hexPaneEditingDisabled => 'editing disabled';

  @override
  String hexPaneSemantics(Object side, Object editing, Object selected) {
    return '$side binary pane, $editing. $selected';
  }

  @override
  String get hexPaneOffsetHeader => 'OFFSET';

  @override
  String get hexPaneAsciiHeader => 'ASCII';

  @override
  String get hexPaneDragFileHereToOpen => 'Drag file here to open';

  @override
  String get hexPaneFileEmpty => 'This file is empty';

  @override
  String get desktopInitializationFailed =>
      'Desktop integration could not be initialized.';

  @override
  String saveChangesToFile(Object side) {
    return 'Save changes to the $side file?';
  }

  @override
  String get discardEditsWarning =>
      'Unsaved edits will be lost if you discard them.';

  @override
  String get openFileFailed => 'Unable to open file.';

  @override
  String get readFileFailed => 'Unable to read file.';

  @override
  String get comparisonFailed => 'Comparison failed.';

  @override
  String get fileChangedOutsideApp => 'File changed outside the app';

  @override
  String get overwriteChangedFilePrompt =>
      'Overwrite the externally changed file with the current edited content?';

  @override
  String get destinationChangedSaveAs =>
      'The destination changed outside the app. Choose Save As again.';

  @override
  String get saveFileFailed => 'Unable to save file.';

  @override
  String get saveNoFileOpen => 'No file is open.';

  @override
  String get saveInProgress => 'A save is already in progress.';

  @override
  String get saveOtherPaneHasDestination =>
      'The other pane already has this file open. Choose another destination.';

  @override
  String get saveCouldNotStart => 'Unable to start save.';

  @override
  String get saveNoBackend =>
      'No safe save backend is available for this platform.';

  @override
  String get saveDestinationDirectoryMissing =>
      'The destination directory does not exist.';

  @override
  String get saveInstallationAmbiguous =>
      'The save result is ambiguous. A recovery copy was retained.';

  @override
  String get saveInstallationFailed => 'Unable to install the saved file.';

  @override
  String get saveSavedButCouldNotReopen =>
      'The file was saved, but could not be reopened.';

  @override
  String get invalidHexOffset => 'Enter a hexadecimal offset within the file';

  @override
  String get hexOffsetHint => 'Hex offset (e.g. 400 or 0x400)';

  @override
  String fileDropTarget(Object side) {
    return '$side file drop target. Drop one binary file to open it on the $side.';
  }

  @override
  String paneFileLabel(Object side, Object name) {
    return '$side · $name';
  }

  @override
  String chooseOpen(Object side) {
    return 'Choose Open $side';
  }

  @override
  String fileSizeDetails(Object size, int bytes) {
    return '$size · $bytes bytes';
  }

  @override
  String get editingOn => 'Edit ON';

  @override
  String get editingOff => 'Edit OFF';

  @override
  String savePane(Object side) {
    return 'Save $side';
  }

  @override
  String savePaneAs(Object side) {
    return 'Save $side As';
  }

  @override
  String hashPaneLabel(Object side) {
    return '$side: ';
  }

  @override
  String get openingBlockedBySave =>
      'A save is in progress. Wait before opening another file.';

  @override
  String get alreadyOpenInOtherPane =>
      'This file is already open in the other pane. Open a copy to edit it independently.';

  @override
  String get error => 'Error';

  @override
  String get hash => 'Hash';

  @override
  String get sameOffsetComparison => 'Same-offset comparison';

  @override
  String updateAvailable(Object version) {
    return 'Update $version available';
  }

  @override
  String get updateDownload => 'Download';

  @override
  String get updateViewRelease => 'View release';

  @override
  String get binaryFiles => 'Binary files';

  @override
  String differenceSummary(Object label, int bytes, int ranges) {
    return '$label $bytes bytes / $ranges ranges';
  }

  @override
  String get differences => 'Differences';

  @override
  String get foundSoFar => 'Found so far';

  @override
  String selectedOffset(Object side, Object offset) {
    return '$side 0x$offset';
  }

  @override
  String get differenceLegend => 'Red: different · Orange: one side only';
}
