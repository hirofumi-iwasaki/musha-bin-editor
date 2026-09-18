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
}
