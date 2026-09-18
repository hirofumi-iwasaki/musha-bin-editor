# Localization design for 0.7.0

The UI supports English and Japanese. The fixed bilingual control at the top
left stores `System`, `English`, or `日本語` in `ui.language`. System mode uses
only the first operating-system locale: a primary `ja` selects Japanese; every
other primary language selects English. Manual changes apply immediately,
persist asynchronously, and are protected from delayed writes overwriting a
newer selection.

All application-owned controls, dialogs, status, tooltips, and accessibility
labels resolve through ARB at build time. Comparison status is semantic state
plus unmodified data arguments, so an already-visible message changes language
without changing comparison state. Binary bytes, offsets, hashes, filenames,
paths and raw OS diagnostic details remain data and are never translated.

macOS receives the active locale over `mushagaeshi/language` and translates
application-owned menu titles. Services and file-picker chrome remain macOS
owned. Native file-drop validation sends stable codes and Flutter provides the
localized explanation.
