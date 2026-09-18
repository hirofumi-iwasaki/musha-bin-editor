import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @languageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The saved language preference could not be read. System language is in use.'**
  String get languageLoadFailed;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The language preference could not be saved.'**
  String get languageSaveFailed;

  /// No description provided for @openLeft.
  ///
  /// In en, this message translates to:
  /// **'Open Left'**
  String get openLeft;

  /// No description provided for @openRight.
  ///
  /// In en, this message translates to:
  /// **'Open Right'**
  String get openRight;

  /// No description provided for @previousDiff.
  ///
  /// In en, this message translates to:
  /// **'Previous Diff'**
  String get previousDiff;

  /// No description provided for @nextDiff.
  ///
  /// In en, this message translates to:
  /// **'Next Diff'**
  String get nextDiff;

  /// No description provided for @goToOffset.
  ///
  /// In en, this message translates to:
  /// **'Go to Offset'**
  String get goToOffset;

  /// No description provided for @bytesPerRow.
  ///
  /// In en, this message translates to:
  /// **'{count} B/row'**
  String bytesPerRow(int count);

  /// No description provided for @compareAgain.
  ///
  /// In en, this message translates to:
  /// **'Compare Again'**
  String get compareAgain;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// No description provided for @noFile.
  ///
  /// In en, this message translates to:
  /// **'No file'**
  String get noFile;

  /// No description provided for @noFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get noFileSelected;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculating;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @desktopUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Desktop integration is not available.'**
  String get desktopUnavailable;

  /// No description provided for @dropTooManyFiles.
  ///
  /// In en, this message translates to:
  /// **'Drop exactly one file at a time.'**
  String get dropTooManyFiles;

  /// No description provided for @dropNotFinderFile.
  ///
  /// In en, this message translates to:
  /// **'Only files from Finder can be dropped here.'**
  String get dropNotFinderFile;

  /// No description provided for @dropNotReadableFile.
  ///
  /// In en, this message translates to:
  /// **'The dropped item is not a readable file.'**
  String get dropNotReadableFile;

  /// No description provided for @dropCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the dropped file.'**
  String get dropCouldNotOpen;

  /// Instruction for a file that missed both panes.
  ///
  /// In en, this message translates to:
  /// **'Drop the file on the left or right binary pane.'**
  String get dropOnPane;

  /// No description provided for @statusOpenTwoFiles.
  ///
  /// In en, this message translates to:
  /// **'Open two files to compare'**
  String get statusOpenTwoFiles;

  /// No description provided for @statusOneFilePreview.
  ///
  /// In en, this message translates to:
  /// **'One file open · Read-only preview'**
  String get statusOneFilePreview;

  /// No description provided for @statusReadError.
  ///
  /// In en, this message translates to:
  /// **'Read error · Reopen the file'**
  String get statusReadError;

  /// No description provided for @statusComparisonError.
  ///
  /// In en, this message translates to:
  /// **'Comparison error · Reopen the files'**
  String get statusComparisonError;

  /// No description provided for @statusComparing.
  ///
  /// In en, this message translates to:
  /// **'Comparing files…'**
  String get statusComparing;

  /// No description provided for @statusFindingDifference.
  ///
  /// In en, this message translates to:
  /// **'Finding difference…'**
  String get statusFindingDifference;

  /// No description provided for @statusComparisonComplete.
  ///
  /// In en, this message translates to:
  /// **'Comparison complete'**
  String get statusComparisonComplete;

  /// No description provided for @statusFilesIdentical.
  ///
  /// In en, this message translates to:
  /// **'Comparison complete · Files are identical'**
  String get statusFilesIdentical;

  /// No description provided for @statusNoLaterDifferences.
  ///
  /// In en, this message translates to:
  /// **'No later differences'**
  String get statusNoLaterDifferences;

  /// No description provided for @statusNoEarlierDifferences.
  ///
  /// In en, this message translates to:
  /// **'No earlier differences'**
  String get statusNoEarlierDifferences;

  /// No description provided for @statusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled · Visible differences remain available'**
  String get statusCanceled;

  /// No description provided for @statusEditingEnabled.
  ///
  /// In en, this message translates to:
  /// **'{side} editing enabled'**
  String statusEditingEnabled(Object side);

  /// No description provided for @statusEditingDisabled.
  ///
  /// In en, this message translates to:
  /// **'{side} editing disabled'**
  String statusEditingDisabled(Object side);

  /// No description provided for @statusEnterSecondHexDigit.
  ///
  /// In en, this message translates to:
  /// **'Enter second hex digit: {digit}_'**
  String statusEnterSecondHexDigit(Object digit);

  /// No description provided for @statusEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited 0x{offset}'**
  String statusEdited(Object offset);

  /// No description provided for @statusHexInputCanceled.
  ///
  /// In en, this message translates to:
  /// **'Hex input canceled'**
  String get statusHexInputCanceled;

  /// No description provided for @statusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String statusSaved(Object name);

  /// No description provided for @statusOffset.
  ///
  /// In en, this message translates to:
  /// **'Offset 0x{offset}'**
  String statusOffset(Object offset);

  /// No description provided for @statusDifferenceAt.
  ///
  /// In en, this message translates to:
  /// **'Difference at 0x{offset}'**
  String statusDifferenceAt(Object offset);

  /// No description provided for @statusComparisonStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to start comparison'**
  String get statusComparisonStartFailed;

  /// No description provided for @hexPaneNotCompared.
  ///
  /// In en, this message translates to:
  /// **'not compared'**
  String get hexPaneNotCompared;

  /// No description provided for @hexPaneEqual.
  ///
  /// In en, this message translates to:
  /// **'equal'**
  String get hexPaneEqual;

  /// No description provided for @hexPaneDifferent.
  ///
  /// In en, this message translates to:
  /// **'different'**
  String get hexPaneDifferent;

  /// No description provided for @hexPaneSelectedByte.
  ///
  /// In en, this message translates to:
  /// **'Offset {offset}, value {value}, {comparison}'**
  String hexPaneSelectedByte(Object offset, Object value, Object comparison);

  /// No description provided for @hexPaneEditingEnabled.
  ///
  /// In en, this message translates to:
  /// **'editing enabled'**
  String get hexPaneEditingEnabled;

  /// No description provided for @hexPaneEditingDisabled.
  ///
  /// In en, this message translates to:
  /// **'editing disabled'**
  String get hexPaneEditingDisabled;

  /// No description provided for @hexPaneSemantics.
  ///
  /// In en, this message translates to:
  /// **'{side} binary pane, {editing}. {selected}'**
  String hexPaneSemantics(Object side, Object editing, Object selected);

  /// No description provided for @hexPaneOffsetHeader.
  ///
  /// In en, this message translates to:
  /// **'OFFSET'**
  String get hexPaneOffsetHeader;

  /// No description provided for @hexPaneAsciiHeader.
  ///
  /// In en, this message translates to:
  /// **'ASCII'**
  String get hexPaneAsciiHeader;

  /// No description provided for @hexPaneDragFileHereToOpen.
  ///
  /// In en, this message translates to:
  /// **'Drag file here to open'**
  String get hexPaneDragFileHereToOpen;

  /// No description provided for @hexPaneFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'This file is empty'**
  String get hexPaneFileEmpty;

  /// No description provided for @desktopInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Desktop integration could not be initialized.'**
  String get desktopInitializationFailed;

  /// No description provided for @saveChangesToFile.
  ///
  /// In en, this message translates to:
  /// **'Save changes to the {side} file?'**
  String saveChangesToFile(Object side);

  /// No description provided for @discardEditsWarning.
  ///
  /// In en, this message translates to:
  /// **'Unsaved edits will be lost if you discard them.'**
  String get discardEditsWarning;

  /// No description provided for @openFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open file.'**
  String get openFileFailed;

  /// No description provided for @readFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read file.'**
  String get readFileFailed;

  /// No description provided for @comparisonFailed.
  ///
  /// In en, this message translates to:
  /// **'Comparison failed.'**
  String get comparisonFailed;

  /// No description provided for @fileChangedOutsideApp.
  ///
  /// In en, this message translates to:
  /// **'File changed outside the app'**
  String get fileChangedOutsideApp;

  /// No description provided for @overwriteChangedFilePrompt.
  ///
  /// In en, this message translates to:
  /// **'Overwrite the externally changed file with the current edited content?'**
  String get overwriteChangedFilePrompt;

  /// No description provided for @destinationChangedSaveAs.
  ///
  /// In en, this message translates to:
  /// **'The destination changed outside the app. Choose Save As again.'**
  String get destinationChangedSaveAs;

  /// No description provided for @saveFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save file.'**
  String get saveFileFailed;

  /// No description provided for @saveNoFileOpen.
  ///
  /// In en, this message translates to:
  /// **'No file is open.'**
  String get saveNoFileOpen;

  /// No description provided for @saveInProgress.
  ///
  /// In en, this message translates to:
  /// **'A save is already in progress.'**
  String get saveInProgress;

  /// No description provided for @saveOtherPaneHasDestination.
  ///
  /// In en, this message translates to:
  /// **'The other pane already has this file open. Choose another destination.'**
  String get saveOtherPaneHasDestination;

  /// No description provided for @saveCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Unable to start save.'**
  String get saveCouldNotStart;

  /// No description provided for @saveNoBackend.
  ///
  /// In en, this message translates to:
  /// **'No safe save backend is available for this platform.'**
  String get saveNoBackend;

  /// No description provided for @saveDestinationDirectoryMissing.
  ///
  /// In en, this message translates to:
  /// **'The destination directory does not exist.'**
  String get saveDestinationDirectoryMissing;

  /// No description provided for @saveInstallationAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'The save result is ambiguous. A recovery copy was retained.'**
  String get saveInstallationAmbiguous;

  /// No description provided for @saveInstallationFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to install the saved file.'**
  String get saveInstallationFailed;

  /// No description provided for @saveSavedButCouldNotReopen.
  ///
  /// In en, this message translates to:
  /// **'The file was saved, but could not be reopened.'**
  String get saveSavedButCouldNotReopen;

  /// No description provided for @invalidHexOffset.
  ///
  /// In en, this message translates to:
  /// **'Enter a hexadecimal offset within the file'**
  String get invalidHexOffset;

  /// No description provided for @hexOffsetHint.
  ///
  /// In en, this message translates to:
  /// **'Hex offset (e.g. 400 or 0x400)'**
  String get hexOffsetHint;

  /// No description provided for @fileDropTarget.
  ///
  /// In en, this message translates to:
  /// **'{side} file drop target. Drop one binary file to open it on the {side}.'**
  String fileDropTarget(Object side);

  /// No description provided for @paneFileLabel.
  ///
  /// In en, this message translates to:
  /// **'{side} · {name}'**
  String paneFileLabel(Object side, Object name);

  /// No description provided for @chooseOpen.
  ///
  /// In en, this message translates to:
  /// **'Choose Open {side}'**
  String chooseOpen(Object side);

  /// No description provided for @fileSizeDetails.
  ///
  /// In en, this message translates to:
  /// **'{size} · {bytes} bytes'**
  String fileSizeDetails(Object size, int bytes);

  /// No description provided for @editingOn.
  ///
  /// In en, this message translates to:
  /// **'Edit ON'**
  String get editingOn;

  /// No description provided for @editingOff.
  ///
  /// In en, this message translates to:
  /// **'Edit OFF'**
  String get editingOff;

  /// No description provided for @savePane.
  ///
  /// In en, this message translates to:
  /// **'Save {side}'**
  String savePane(Object side);

  /// No description provided for @savePaneAs.
  ///
  /// In en, this message translates to:
  /// **'Save {side} As'**
  String savePaneAs(Object side);

  /// No description provided for @hashPaneLabel.
  ///
  /// In en, this message translates to:
  /// **'{side}: '**
  String hashPaneLabel(Object side);

  /// No description provided for @openingBlockedBySave.
  ///
  /// In en, this message translates to:
  /// **'A save is in progress. Wait before opening another file.'**
  String get openingBlockedBySave;

  /// No description provided for @alreadyOpenInOtherPane.
  ///
  /// In en, this message translates to:
  /// **'This file is already open in the other pane. Open a copy to edit it independently.'**
  String get alreadyOpenInOtherPane;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @hash.
  ///
  /// In en, this message translates to:
  /// **'Hash'**
  String get hash;

  /// No description provided for @sameOffsetComparison.
  ///
  /// In en, this message translates to:
  /// **'Same-offset comparison'**
  String get sameOffsetComparison;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update {version} available'**
  String updateAvailable(Object version);

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownload;

  /// No description provided for @updateViewRelease.
  ///
  /// In en, this message translates to:
  /// **'View release'**
  String get updateViewRelease;

  /// No description provided for @binaryFiles.
  ///
  /// In en, this message translates to:
  /// **'Binary files'**
  String get binaryFiles;

  /// No description provided for @differenceSummary.
  ///
  /// In en, this message translates to:
  /// **'{label} {bytes} bytes / {ranges} ranges'**
  String differenceSummary(Object label, int bytes, int ranges);

  /// No description provided for @differences.
  ///
  /// In en, this message translates to:
  /// **'Differences'**
  String get differences;

  /// No description provided for @foundSoFar.
  ///
  /// In en, this message translates to:
  /// **'Found so far'**
  String get foundSoFar;

  /// No description provided for @selectedOffset.
  ///
  /// In en, this message translates to:
  /// **'{side} 0x{offset}'**
  String selectedOffset(Object side, Object offset);

  /// No description provided for @differenceLegend.
  ///
  /// In en, this message translates to:
  /// **'Red: different · Orange: one side only'**
  String get differenceLegend;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
