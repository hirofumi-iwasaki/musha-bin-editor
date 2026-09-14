# Mushagaeshi Binary Editor

A side-by-side hexadecimal binary viewer and comparison app for macOS.

Repository: [hirofumi-iwasaki/musha-bin-editor](https://github.com/hirofumi-iwasaki/musha-bin-editor)

Version 0.2.0 adds explicit per-pane hexadecimal editing and safe saving to the side-by-side comparison viewer. The application and its README use English. Language selection and localization are deferred.

## Requirements

- macOS 15 Sequoia or macOS 26 Tahoe
- Apple Silicon (M1 or later, on a Mac that supports the selected OS)
- No Flutter installation is needed to run the built `.app`.

Development uses Flutter 3.47.4, Dart 3.13.3 and Xcode. See `.flutter-version` for the pinned SDK version. The app has been tested on macOS 26; macOS 15 still needs hardware validation.

## Run the macOS app

The locally packaged application is available at:

```text
dist/Mushagaeshi Binary Editor.app
```

Double-click the app in Finder, or run:

```sh
open 'dist/Mushagaeshi Binary Editor.app'
```

You can copy the `.app` to your Applications folder. The current build is signed for local testing, not yet signed with a distribution identity or notarized for public release.

Select **Open Left** and **Open Right** to compare files, or drop one Finder file onto each binary pane. Opening and comparing files never modifies their contents.

## Features

- Side-by-side offsets, hexadecimal bytes and ASCII characters
- Red backgrounds on differing bytes; orange for bytes present on only one side
- Missing bytes shown as `--`, distinct from a zero byte
- Synchronized vertical scrolling using Flutter's standard macOS mouse-wheel, two-finger trackpad and scrollbar behavior, including the system natural-scrolling direction
- Finder drag-and-drop: drop one file on the left or right binary pane to open it on that side
- Horizontal scrolling when a pane is too narrow to show all columns
- Eight or sixteen bytes per row
- Previous/next difference range and hexadecimal offset navigation
- Click to select a byte; arrow keys, Page Up/Down and Home/End for navigation
- Explicit Edit ON/OFF control for each pane; enter two hexadecimal digits to overwrite the selected byte
- Per-pane unsaved-change indicators and immediate comparison updates
- Save and Save As, with staged native replacement and external-change confirmation
- Save / Discard / Cancel protection when replacing an edited file or closing the window
- Comparison progress, cancellation, re-comparison and external-change detection
- English controls, status messages, dialogs and accessibility labels

The extra in-content title row has been removed to leave more space for binary data. The application name remains in the native macOS title bar and application menu.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Open left file | `Command+O` |
| Open right file | `Command+Shift+O` |
| Go to offset | `Command+G` |
| Select adjacent byte/row | Arrow keys while a pane has focus |
| Scroll by one screen | Page Up / Page Down |
| Go to beginning/end | Home / End |
| Edit selected byte | Two hexadecimal digits while Edit is ON |
| Cancel first hex digit | Escape |

Offsets are hexadecimal, for example `400` or `0x400`.

## Development and packaging

With Flutter 3.47.4 installed, run from the repository root:

```sh
flutter pub get
flutter run -d macos
```

This workspace also contains a project-local SDK in `.tooling/flutter`. It is excluded from Git, and the system-wide PATH is unchanged.

Build and package a standalone macOS app:

```sh
./tool/build_macos.sh
```

The script prefers `.tooling/flutter/bin/flutter`, falling back to `flutter` on PATH. It builds the Release application and copies the signed bundle into `dist/`. Both `build/` and `dist/` are excluded from Git.

For a build without the packaging step:

```sh
.tooling/flutter/bin/flutter build macos --release
open 'build/macos/Build/Products/Release/Mushagaeshi Binary Editor.app'
```

The existing bundle identifier, `dev.mushagaeshi.mushagaeshiBinDiff`, is retained as the app's stable internal identity. Its displayed name and executable are **Mushagaeshi Binary Editor**.

## Validation

```sh
flutter analyze
flutter test
dart run tool/benchmark.dart 1 100 1024
flutter run -d macos --profile --dart-define=BENCHMARK=true
```

Tests cover comparison boundaries, two-digit editing, safe Save As output, external-change refusal, navigation, stale display requests, native file-drop messages and wheel/trackpad scrolling over both binary panes. The scrolling tests also exercise narrow panes with horizontal overflow.

The comparison benchmark creates temporary file pairs and removes them afterwards. The 1 GiB case needs approximately 2 GiB of free disk space. Files are compared immediately after creation, so the measurements are affected by the OS cache. The rendering benchmark loads an internal generated fixture, scrolls it 180 times and logs median and 95th-percentile frame build/raster times. This fixture is not exposed in the product UI.

## Architecture and current limitations

- `lib/core`: Flutter-independent comparison rules, range counting and navigation
- `lib/infrastructure`: paged file reads, change checks and background comparison
- `lib/application`: comparison session, cancellation and viewport request generations
- `lib/presentation`: paints only visible hexadecimal rows
- `macos/Runner`: native file selection and window configuration

Comparison uses absolute offsets. Insertions and deletions are not realigned. Text display is ASCII only.

Difference navigation currently scans from the start to the required range, which can take time near the end of large files. A block index is planned. Display reads use a 64 KiB page cache, comparison reads use 1 MiB blocks, and the bounded text-layout cache holds up to 2,048 entries. The app does not construct a widget for every byte or retain an unbounded list of difference ranges.

External-change detection checks file size and timestamps during reads, comparisons and saving. Save refuses an externally changed source until the user explicitly confirms overwrite. Saving streams the source through an edited-byte overlay into the app's temporary directory, flushes it and asks the native macOS layer to replace the exact user-selected destination only after successful output.

Accessibility labels describe editing state and the selected byte and identify each file-drop target. Full VoiceOver operation remains unverified. Range selection, copying/pasting and undo/redo are not implemented yet; editing remains fixed-size byte overwrite only.

## License

Project-authored code is licensed under **GNU GPL version 3 or later (GPL-3.0-or-later)**. See [LICENSE](LICENSE) and the [license policy](.chatgpt/LICENSE_POLICY.md). Third-party code and assets retain their respective licenses.

Design decisions and work records are maintained in `.chatgpt/`. Distribution signing, notarization, copyright attribution and third-party notices will be finalized before public binary distribution.
