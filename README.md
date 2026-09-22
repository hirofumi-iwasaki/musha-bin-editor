# Mushagaeshi Binary Editor

**English** | [日本語](README.ja.md)

A side-by-side hexadecimal binary viewer, comparison tool, and fixed-size byte editor for macOS, Windows, and Ubuntu.

Repository: [hirofumi-iwasaki/musha-bin-editor](https://github.com/hirofumi-iwasaki/musha-bin-editor)

[v0.7.0](https://github.com/hirofumi-iwasaki/musha-bin-editor/releases/tag/v0.7.0) is published. It adds Japanese/English UI localization and a persistent language choice. The preceding v0.6.0 work added the Mushagaeshi application icon to macOS, Windows, and Linux packages; v0.5.0 added quiet background checks for newer releases. Binary comparison, editing, and safe-save behavior are unchanged by localization.

Version 0.7.2 fixes macOS Finder drop routing by disabling the competing native `desktop_drop` overlay after plugin registration, so the app's AppKit drop host receives the drag and retains the Finder security scope. Native regression and Flutter drop tests cover this routing; a physical Finder drag on the release bundle has not been verified.

## Release status

The five v0.7.0 binary archives are published with their required licenses and source/build references. The release package matrix completed successfully in [GitHub Actions run 35310954380](https://github.com/hirofumi-iwasaki/musha-bin-editor/actions/runs/35310954380) for source revision `629eba1`. It covers Windows x64/Arm64, Ubuntu 22.04/24.04 x64/Arm64, and macOS Arm64 builds, packaging, architecture inspection, static analysis, and tests.

Automated builds and package checks do not cover every native failure path or GUI scenario. Cross-platform launch, file-dialog, drag-and-drop, save-recovery, and accessibility acceptance remain separate evidence. Public binaries are unsigned on Windows and Linux; the macOS package uses local ad-hoc signing and is not notarized.

## Requirements

- macOS 15 Sequoia or macOS 26 Tahoe on Apple Silicon (M1 or later)
- Windows 11 x64 or Arm64
- Ubuntu 22.04 or 24.04 LTS x64 or Arm64
- No Flutter installation is needed to run a packaged application

Development uses Flutter 3.47.4 and Dart 3.13.3. macOS development also uses Xcode. See [.flutter-version](.flutter-version) for the pinned Flutter SDK.

## UI language support

**Language / 言語** at the top left offers **System / システム**, **English**, and **日本語**. A manual selection updates the application immediately and is restored at the next launch. System mode uses only the first operating-system preferred language: `ja` (including a regional Japanese locale) selects Japanese, and every other primary language selects English. A Japanese fallback later in the OS list does not switch the application to Japanese.

Changing a manual selection does not replace open files, unsaved edits, the current offset, or an active comparison. macOS application-menu titles follow the selected app language. Native file pickers, Services, and other OS-owned chrome can remain in the operating-system language.

## Download and run

Download the archive for the current system from [Releases](https://github.com/hirofumi-iwasaki/musha-bin-editor/releases), extract the entire archive, and start the bundled application. Keep every extracted file together.

| Platform | Archive |
| --- | --- |
| Windows x64 | `musha-bin-edit-windows-x64.zip` |
| Windows Arm64 | `musha-bin-edit-windows-arm64.zip` |
| Ubuntu x64 | `musha-bin-edit-linux-x64.tar.gz` |
| Ubuntu Arm64 | `musha-bin-edit-linux-arm64.tar.gz` |
| macOS Apple Silicon | `musha-bin-edit-macos.zip` |

On macOS, open **Mushagaeshi Binary Editor.app** after extraction. A locally packaged app is at `dist/Mushagaeshi Binary Editor.app` and can be opened with:

```sh
open 'dist/Mushagaeshi Binary Editor.app'
```

The Linux archive includes a GTK window icon, a freedesktop desktop entry, and hicolor icon-theme files under `share/`. An installer can place those files in XDG data directories and make `mushagaeshi_binary_editor` available on `PATH`; extracting the archive alone does not register a launcher. Start the bundled executable directly before installation.

Select **Open Left** and **Open Right** to compare files, or drop one file on each binary pane. Opening and comparing files never changes their contents.

## Features

- Side-by-side offsets, hexadecimal bytes, and ASCII characters
- Red backgrounds for differing bytes and orange for bytes present on only one side
- Missing bytes shown as `--`, distinct from a zero byte
- Synchronized vertical and horizontal scrolling
- Native file selection and one-file-per-pane drag and drop on macOS, Windows, and Linux
- Per-file SHA-1 or MD5 hash display; SHA-1 is selected by default
- Eight or sixteen bytes per row
- Previous/next difference-range and hexadecimal-offset navigation
- Click to select a byte; keyboard navigation with arrow keys, Page Up/Down, and Home/End
- Per-pane Edit ON/OFF; enter two hexadecimal digits to overwrite a selected byte
- Unsaved-change indicators and immediate comparison updates
- Save and Save As with staged replacement and external-change confirmation
- Save / Discard / Cancel protection when replacing an edited file or closing the window
- Comparison progress, cancellation, re-comparison, and external-change detection
- Japanese and English controls, status messages, dialogs, tooltips, and accessibility labels
- A quiet background update check that offers a validated GitHub download or release-page link when a newer compatible release is available

Windows and Linux use Ctrl where the shortcuts below show Command. The application icon is included in native macOS, Windows, and Linux packages.

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

Offsets are hexadecimal, for example `400` or `0x400`. The hash bar reports saved file contents on disk; choose **SHA-1** or **MD5** from its dropdown. Opening or saving a file recalculates the value.

## Update checks

After the window first appears, the app can silently check GitHub for a newer stable release. It sends no file contents, paths, hashes, edits, account identity, or telemetry. A check uses GitHub's public releases API and validates the version, release page, and exact archive name before it displays a non-modal status-row link. The app never downloads, installs, extracts, or restarts itself.

See the [update-check design](.chatgpt/UPDATE_CHECK_DESIGN.md) for the network, cache, rate-limit, and link-validation rules.

## Development and packaging

With Flutter 3.47.4 installed, run from the repository root:

```sh
flutter pub get
flutter run -d macos
```

This workspace can contain a project-local SDK in `.tooling/flutter`. It is excluded from Git, and the system-wide PATH is unchanged.

Build and package a standalone macOS app:

```sh
./tool/build_macos.sh
```

Build the native Windows or Linux packages on the corresponding host:

```sh
tool/build_windows.ps1 -Architecture x64
bash tool/build_linux.sh x64
```

Use `arm64` for the Arm64 target. Each archive includes the runtime bundle, `LICENSE`, `THIRD_PARTY_NOTICES.txt`, `THIRD_PARTY_LICENSES/`, and `SOURCE_AND_BUILD.txt`. Arm64 CI bootstraps the pinned official Flutter source checkout to obtain native Dart and engine artifacts.

## Validation

```sh
flutter analyze
flutter test
dart run tool/benchmark.dart 1 100 1024
flutter run -d macos --profile --dart-define=BENCHMARK=true
```

Tests cover comparison boundaries, editing, safe saves, external changes, navigation, stale display requests, file drops, scrolling, localization, and update-check validation. The comparison benchmark creates temporary file pairs and removes them afterwards. Its 1 GiB case needs about 2 GiB of free space. The rendering benchmark uses an internal generated fixture; it is not exposed in the product UI.

## Architecture and limitations

- `lib/core`: Flutter-independent comparison rules, range counting, and navigation
- `lib/infrastructure`: paged file reads, change checks, safe saves, and background comparison
- `lib/application`: comparison session, cancellation, and viewport request generations
- `lib/presentation`: visible hexadecimal-row painting
- `lib/platform`: native desktop integration boundaries
- `macos/Runner`, `windows/runner`, and `linux/runner`: native window, file, save, and package integration

Comparison uses absolute offsets; insertions and deletions are not realigned. Text display is ASCII only. Difference navigation currently scans from the start to the needed range, so a jump near the end of a large file can take time. Display reads use a 64 KiB page cache, comparison reads use 1 MiB blocks, and the bounded text-layout cache holds up to 2,048 entries.

External-change detection checks size and timestamps during reads, comparisons, and saves. Save refuses an externally changed source until the user confirms overwrite. On Ubuntu, replacement rejects special permission bits, owner/group changes, ACLs, or other extended attributes rather than discard metadata; ordinary rwx permissions are preserved. File change detection cannot detect every possible external rewrite.

Accessibility labels identify editing state, the selected byte, and each file-drop target. Full VoiceOver operation remains unverified. Range selection, copy/paste, undo/redo, insertion, and deletion are not implemented; editing is fixed-size byte overwrite only.

## License

Project-authored code is licensed under **GNU GPL version 3 or later (GPL-3.0-or-later)**. See [LICENSE](LICENSE) and the [license policy](.chatgpt/LICENSE_POLICY.md). Third-party code and assets retain their respective licenses. Design decisions and work records are maintained in `.chatgpt/`.
