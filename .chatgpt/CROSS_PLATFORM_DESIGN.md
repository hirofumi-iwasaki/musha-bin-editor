# Windows and Linux port design

Status: proposed design; implementation and platform validation pending.
Reviewed baseline: v0.3.0, commit `10ba5cd` (2026-09-14).
The application continues to use English and GPL-3.0-or-later.

## Scope and proposed support matrix

Retain one Flutter application and one shared Dart comparison/editing implementation. Add native desktop runners and narrow platform adapters. A rewrite in another language is unnecessary.

| Target | Proposed initial scope | Build/test environment |
| --- | --- | --- |
| macOS | Existing macOS 15/26, Apple Silicon | Existing Mac; regression tests |
| Windows x64 | Windows 11 | Windows x64 with Visual Studio C++ tooling |
| Windows Arm | Windows 11 Arm64, native executable; not Arm32 | Windows Arm64 with compatible Flutter and Visual Studio tooling |
| Linux x64 | Ubuntu 22.04/24.04 LTS; initial release target | Build against oldest supported baseline; test both versions |
| Linux Arm64 | Ubuntu 22.04/24.04 LTS; initial release target | Separate native Arm64 build and execution validation on both versions |

Windows 10 and other Linux distributions are not initial product support commitments. The user confirmed Ubuntu-only Linux support, with both x64 and Arm64 included in the initial release. Windows Arm is interpreted as Arm64. Flutter's published deployment support includes Windows x64/Arm64 and Debian/Ubuntu x64/Arm64, but plugin support and successful native builds must be verified independently [1].

The checked-in SDK pin is Flutter 3.47.4. Its local `build_windows.dart` requires a Windows host and chooses x64/Arm64 from the host architecture. Do not assume a `--target-platform` flag or cross-compilation recipe from a different Flutter release. Establish native jobs for each Windows architecture first. A deployment-support table does not guarantee every host SDK/toolchain combination works.

## Source review

| Source | Finding | Design action |
| --- | --- | --- |
| `lib/core/comparison.dart` | Pure Dart byte comparison, range counting and navigation | Reuse; no OS-specific rewrite |
| `lib/infrastructure/file_comparison.dart` | Paged reads, bounded buffers, isolate worker; FileStamp compares size and mtime | Reuse algorithm; strengthen lifecycle and define external-change limitations |
| `lib/application/compare_controller.dart` | Editing overlay, worker lifecycle, saved-file hashes | Reuse behavior; coordinate open/save/hash operations |
| `lib/main.dart` | Direct `mushagaeshi/files` calls for open, save dialog, installation, close; global native drag events | Extract desktop integration interfaces; leave dialogs and state decisions in Dart |
| `macos/Runner/MainFlutterWindow.swift` | Actual native dialogs, Finder drop receiver, security-scoped access, replacement and window-close interception | Keep as macOS adapter; not portable code |
| `lib/infrastructure/safe_save.dart` | System-temp staging; fallback from any rename failure to direct destination copy | Replace fallback before enabling Windows/Linux saving |
| `lib/infrastructure/file_hash.dart` | Independent streaming isolate; no stamp checks or cancellation handle | Add cancellation and snapshot validation, especially before saving |
| `lib/presentation/hex_pane.dart` | Menlo and hard-coded glyph geometry used for painting and hit testing | Shared font and measured layout metrics |
| `test/*` | Native channel mocks; real `chmod` and `ln` subprocess calls | Separate portable tests from OS-specific integration tests |
| `tool/build_macos.sh` | macOS-only bundle/signing; no Windows/Linux runners or CI workflows found | Add per-platform builds and packaging |

Specific correctness concerns exposed by the review:

- `path.split('/').last` is unsuitable for Windows backslash paths. Use the `path` package for display names and path composition. Keep filesystem identity checks; string lowercasing alone is not a valid identity test.
- `_openGeneration` is global to both panes: near-simultaneous left/right opens can discard one another. Use per-pane generations and serialize commits of document state, including the same-file check.
- Saving currently receives live edit maps. Freeze edits and the source revision at save start, and prevent replacement/editing of that document until save completes.
- Comparison workers and hash workers can still hold handles while saving. Windows sharing rules make this especially relevant. Workers must acknowledge handle closure before replacement.
- Hash generation counters suppress old results, but do not stop old I/O. Add cancellable jobs; only publish a digest if the source stamp is consistent before/after reading. Continue to define hashes as saved on-disk bytes, not unsaved edits.
- `FileStamp` size/mtime cannot detect every external change (e.g. same-size changes with preserved timestamps). Add identity where practical, retain conservative conflict behavior, and document that it is not an exclusive filesystem lock.
- Save As currently does not recheck the source after reading unless destination text equals source text. Check source stability for every save, and separately check the destination snapshot accepted by the overwrite dialog.
- Native macOS security scopes currently remain held until window/view destruction. Preserve required access while a document or worker uses it, then release through a reference-counted document lease.

## Architecture

Keep the existing layers. Introduce small injectable contracts, rather than one large platform class or a new framework:

1. `FileDialogService`: choose an existing file or destination; returns cancellation explicitly and, if needed, an access lease. macOS retains its existing native implementation initially; Windows/Linux use the Flutter-published `file_selector` candidate [2]. Choosing a destination does not perform a safe save.
2. `PaneDropTarget`: each pane receives enter/leave/drop events with one local file. Windows/Linux use `desktop_drop` as a candidate [3]. Convert local file URIs correctly; reject directories and multiple drops with English messages. No whole-file buffering through the UI plugin. macOS keeps the working native host initially, normalized to the same event contract.
3. `WindowLifecycleService`: request close, defer close, and close after confirmation. `window_manager` is a candidate for Windows/Linux [4]; keep existing macOS close interception. All close/menu-quit paths call the same unsaved-change coordinator exactly once. OS-forced termination cannot be guaranteed interceptable.
4. `SaveBackend`: prepare a safe staging location, install completed output, and recover/report failure. Implement OS-specific installation without leaking platform APIs into widgets.

Suggested placement: `lib/platform/` for contracts/adapters, `lib/application/` for document operation coordination, and existing infrastructure for streaming data work. Instantiate adapters at the application composition root; avoid scattered `Platform.isWindows` checks in UI widgets.

Native host code is limited to APIs that plugins cannot safely supply, primarily replacement/recovery and macOS sandbox access. Small Windows C++ and Linux native helpers are acceptable; no Rust dependency is needed. Lock adopted dependency versions after x64/Arm64 compilation, behavior and license review. These packages are candidates, not validated commitments.

## Save transaction

Safety is the highest-priority redesign. Never fall back from a failed replacement to overwriting the destination with a streaming copy.

1. Serialize saves and document replacement. Capture immutable source identity/stamp, edit map, revision and destination state. Keep edits until confirmed success.
2. Cancel relevant comparison/hash jobs and await their file handles closing. Await outstanding viewport reads; reject new document reads until installation ends.
3. Create an exclusive, unpredictable staging file. On Windows/Linux create it on the destination volume, normally in the destination directory. If directory permissions prevent safe staging, fail clearly rather than truncate the destination. macOS keeps a sandbox-aware backend and requires separate testing for external volumes.
4. Stream original bytes plus frozen edits into staging. Check read/write errors, flush and close. Recheck the source for every save, including Save As; recheck destination for newly introduced external changes. An overwrite confirmation applies to the observed revision, not future changes.
5. Install only fully written data. Windows: evaluate `ReplaceFileW` for existing files and a non-overwriting move for new files, with recovery/backup handling. Its documented partial-failure states and same-volume requirement mean a generic success/failure wrapper is insufficient [5]. Linux: same-filesystem replacement through rename semantics, with exclusive destination handling for new paths. Preserve intended permissions and executable bits; explicitly test ACL behavior. macOS: encapsulate the existing native replacement and verify its failure/volume behavior.
6. If installation succeeded, reopen the destination, invalidate caches, adopt the new filename and stamp, clear only the saved revision's edits, and restart comparison/hash. If post-save reopen fails, report 'saved but could not reopen' distinctly from 'not saved'.
7. Remove staging only when known safe. Retain recovery paths when a backend reports an ambiguous/partial replacement. Never delete the only remaining complete copy.

Atomic namespace replacement and power-loss durability are separate guarantees. Define and test flush/fsync behavior for each backend; do not promise crash-proof operation on arbitrary network/cloud filesystems. Initial acceptance targets are local regular files. Network files must either follow validated behavior or fail without silently weakening safety.

Symlink paths should resolve consistently with opening. Do not invent case-folded identity rules. Replacement of one hard-link directory entry does not edit every alias; retain rejection of aliases to the opposite pane and document replace semantics.

## UI and interaction

- Keep the existing Material UI, pane placement, default SHA-1, colors and 13-point byte/hash values.
- macOS uses Command; Windows/Linux use Ctrl for existing O / Shift+O / G shortcuts. Display platform-appropriate shortcut documentation.
- Retain Flutter's standard scroll behavior. Verify wheel, high-resolution touchpad, horizontal scroll and natural scrolling on each OS without manual direction inversion.
- Menlo is not a cross-platform font dependency. Prefer bundling a redistributable monospaced font after license review; measure glyph width, row height and hit-test geometry from one shared metrics object. Preserve existing size as the visual target. An OS-font fallback requires the same measurement work.
- Verify 100%, 150%, 200% DPI/text scaling, 980-pixel minimum window width, long SHA-1 values and light/dark themes. Keep the full hash accessible when text is clipped.
- Test dropping on pane header/body, boundary/outside areas, Unicode/spaces in paths, and Linux Wayland and X11 sessions separately. Widget tests alone cannot establish real desktop drag/drop behavior.
- Initial file association, double-click-to-open registration, store integration and installers are deferred.

## Build and distribution

Generate `windows/` and `linux/` runners using the pinned Flutter SDK in an implementation branch after checking main's merge state. Verify generated diffs do not replace the working macOS customization.

Use Windows x64, Windows Arm64, Ubuntu x64, Ubuntu Arm64 and macOS jobs. Choose actual hosted/self-hosted runner availability during implementation; do not promise an unverified CI label. Windows Arm64 must produce an Arm64 PE executable and load Arm64 plugins; x64 emulation is not native-build evidence. Ubuntu Arm64 requires a separate build/test job and verification of Arm64 ELF executables and native libraries.

- Windows: portable ZIP containing the complete Release directory, including DLLs/assets and appropriate runtime deployment instructions. An EXE alone is insufficient [6]. Proposed names: `musha-bin-edit-windows-x64.zip` and `musha-bin-edit-windows-arm64.zip`.
- Linux: initially a complete Flutter bundle in `musha-bin-edit-linux-x64.tar.gz` and `musha-bin-edit-linux-arm64.tar.gz`, with executable permissions preserved and required OS libraries documented. Build on the oldest supported baseline and inspect `ldd`; a newer glibc build is not automatically portable to older systems [7]. AppImage/Flatpak/deb can follow after baseline behavior is validated.
- macOS: retain current bundle workflow and asset name.
- Include LICENSE, dependency notices and build/source reference for the exact tag in every archive. Maintain GPL-3.0-or-later and verify adopted package/font redistribution terms; no new license choice is needed.
- Release promotion requires all selected platform jobs and manual acceptance. Build artifacts from one commit/tag. Keep new platform artifacts as previews until tested on their target systems.

## Implementation sequence and acceptance

1. **Toolchain spike:** minimal Windows x64/Arm64 and Ubuntu x64/Arm64 runners; test plugin compilation, file dialog, one drop and close interception. Resolve unsupported plugin architectures before substantial UI work.
2. **Extract adapters:** preserve macOS behavior; add portable paths/shortcuts, operation coordinator and per-pane generations.
3. **Implement safe saves:** backend failure/recovery tests first; make save/open/hash lifecycle coherent. No new-platform editing release before this passes.
4. **Complete UI portability:** font metrics, scaling, scrolling, hashes, real drag/drop and English messages.
5. **CI and packaging:** native builds and tests, archive inspection, installation on clean systems, manual acceptance and release notes.

Portable tests cover identical/different files, empty files, differing lengths, navigation, editing, save/reopen, hash vectors/algorithm switching, rapid left/right opens and cancellation. Replace shell assumptions in portable tests; keep chmod/link tests as explicit OS integration tests with validated process results.

Save integration matrix: same-path overwrite, Save As new/existing, external change during read, opposite-pane alias, readonly target, permission denial, full disk, locked destination, different destination volume, Unicode/UNC/long paths, cancellation before install and injected replacement failures. Verify output bytes and that original/recovery data remains available after failure.

Manual matrix per selected OS/architecture: open/drop both panes, trackpad/wheel, edit and Save/Save As, unsaved close Save/Discard/Cancel, correct hash/background, DPI/layout and launch without Flutter installed. Existing macOS regressions remain mandatory.

## Decisions needed before implementation

Confirmed Linux scope: Ubuntu only, with x64 and Arm64 in the initial release. Proposed versions remain Ubuntu 22.04/24.04 LTS. Other proposed defaults remain Windows 11 x64 and Arm64 and portable ZIP/tar.gz distribution. Identify available Windows Arm64 and Ubuntu x64/Arm64 desktop test environments during implementation. These do not block the shared design work. Implementation target: v0.4.0 on `release/0.4.0`, branched from main at `0bd7646`. See RELEASE_0.4.0_PLAN.md for the continuation checklist.

## Sources checked

1. Flutter deployment matrix: https://docs.flutter.dev/reference/supported-platforms
2. Flutter file selector: https://pub.dev/packages/file_selector
3. Desktop drop package: https://pub.dev/packages/desktop_drop
4. Window manager package: https://pub.dev/packages/window_manager
5. Microsoft ReplaceFileW behavior: https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew
6. Flutter Windows integration/distribution: https://docs.flutter.dev/platform-integration/windows/building
7. Flutter Linux bundle/distribution: https://docs.flutter.dev/platform-integration/linux/building

Official web documentation currently identifies itself as Flutter 3.47.2; the local SDK pin is 3.47.4. Local SDK source was also inspected for Windows host/architecture selection. No Windows/Linux build or runtime test was performed during this design review.
