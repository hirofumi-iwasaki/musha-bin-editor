# Localization design

Version 0.7.0 provides an English and Japanese interface without changing the
binary data, filenames, paths, hashes, offsets, or comparison behavior.

## Language choice

The top-left **Language / 言語** control always presents **System / システム**,
**English**, and **日本語**. Its selection is stored asynchronously as
`ui.language`. The initial and corrupt-preference fallback is System.

System mode reads only the first preferred operating-system locale. A primary
language code of `ja` (including regional variants) selects Japanese; every
other value selects English. A later Japanese fallback does not affect the
choice. While System is selected, locale notifications update the UI. A manual
choice takes effect immediately, survives restart, and is not superseded by
later OS locale changes. Writes are serialized and revision-checked so a slow
older write cannot replace the latest choice.

## Text ownership

Flutter-visible controls, dialogs, tooltips, accessibility labels, banners,
status, and human-oriented errors are ARB resources. Comparison state uses
`CompareStatus` plus unmodified arguments, so status labels are resolved at
paint time and switch live. File paths, filenames, offsets, byte values, hashes
and raw OS diagnostics are never translated or transformed.

Native drop validation passes stable error codes to Flutter and Flutter chooses
the localized explanation. A raw OS detail may be appended unchanged. Native
macOS menus update app-owned titles through `mushagaeshi/language` when the
active Flutter locale changes. Services and native file-picker chrome remain
owned by macOS and may retain the OS language.

## Verification

Tests cover first-locale-only resolution, persistence, invalid preference
fallback, serial writes, and live widget switching without changing dirty edit
state. Static analysis, Flutter tests, and a clean macOS build verify the
generated localization bindings and native channel.
