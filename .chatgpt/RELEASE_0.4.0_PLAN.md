# v0.4.0 continuation plan

Updated: 2026-09-15
Working branch: `release/0.4.0`
Base: main at `0bd7646` (merged v0.3.0 PR #3).

## Goal

Deliver the existing binary comparison and editing application on Windows x64/Arm64 and Ubuntu x64/Arm64 while preserving macOS behavior and file safety. Keep one Flutter/Dart application. The detailed source review and proposed interfaces are in [CROSS_PLATFORM_DESIGN.md](CROSS_PLATFORM_DESIGN.md).

## Confirmed requirements

- Linux targets Ubuntu only, with both x64 and native Arm64 included from the initial Linux release.
- Windows targets x64 and native Arm64.
- Preserve the existing macOS application, two panes, hexadecimal editing/saving, drag-and-drop, synchronized scrolling, SHA-1/MD5 selection and differing-hash highlighting.
- Application name: Mushagaeshi Binary Editor. All application UI and public documentation stay English.
- License remains GPL-3.0-or-later. Keep required dependency notices and corresponding-source/build references with distribution artifacts.
- Work on release/0.4.0. Do not change a published v0.3.0 tag or asset as part of development.

## Proposed defaults and unresolved environment details

- Windows 11 and Ubuntu 22.04/24.04 LTS are the proposed validation baselines; macOS 15/26 support remains unchanged.
- Start with portable Windows ZIP and Ubuntu tar.gz bundles, separately for x64 and Arm64.
- Establish available native Windows Arm64 and Ubuntu x64/Arm64 build/test environments. Do not equate x64 emulation with native Arm64 validation.
- Validate candidate file_selector, desktop_drop and window_manager dependencies on all selected targets before adopting versions.
- Store integration, installers, Linux distributions other than Ubuntu, localization, unrelated editor features and a language rewrite are outside this milestone.

## Ordered work checklist

- [x] Review v0.3.0 sources and document portability concerns.
- [x] Record Ubuntu-only x64/Arm64 scope and create release/0.4.0 from merged main.
- [ ] Prove pinned Flutter/toolchain and plugin builds on Windows x64/Arm64 and Ubuntu x64/Arm64; record actual versions and commands.
- [x] Add Windows/Linux runners without replacing the existing macOS customization.
- [x] Extract file dialogs, pane-drop events, window lifecycle and safe-save backend interfaces; retain working macOS implementations.
- [x] Coordinate document operations: per-pane open generations, immutable save snapshots and cancellation/handle closure before replacement.
- [ ] Replace unsafe rename-to-direct-copy fallback with OS-specific staged installation and recoverable failure handling. Recheck source and destination changes for Save and Save As.
- [x] Make filename/path handling, Ctrl/Command shortcuts, font metrics and DPI/hit testing portable.
- [ ] Validate real native drop/open/close behavior, wheel/touchpad behavior and hashes on all targets.
- [ ] Split portable tests from OS-specific chmod/link/native tests; add save-failure and concurrency coverage.
- [ ] Add native CI/build/package jobs and inspect complete runtime bundles and architecture of executable/plugins.
- [ ] Perform clean-system acceptance on all selected targets, including macOS regressions; document failures and limitations.
- [ ] Prepare version metadata and release artifacts from one validated commit. Publish only when requested.

## Completion criteria

All selected target architectures must build and run. Manual acceptance must include open/drop on both panes, edit, Save/Save As, reopen and byte verification, unsaved-close Save/Discard/Cancel, hashes and colors, and scrolling/layout. On Ubuntu check supported versions plus Wayland/X11 behavior. Save failures must not silently truncate the original file; recoverable partial installation must retain complete data and report its location. Report any platform lacking runtime validation as unverified, not complete.

Expected proposed assets:
- musha-bin-edit-windows-x64.zip
- musha-bin-edit-windows-arm64.zip
- musha-bin-edit-linux-x64.tar.gz
- musha-bin-edit-linux-arm64.tar.gz
- Existing macOS artifact naming retained.

## Resume here

Implementation and local verification progressed on 2026-09-15 under GPT-5.6 Terra delegation. Platform adapters/runners, measured rendering/scroll geometry, save coordination, cancellable workers and native save installers are implemented. Native build/package CI has been written but not run. Shared Flutter analysis and all 29 tests passed at the integration checkpoint; macOS Release build/package succeeded; the executable is arm64 and strict deep signature verification passed. The development bundle still reports 0.3.0 build 3.

Next: establish successful Windows/Ubuntu native CI builds on all selected architectures, resolve native compile failures, then execute desktop acceptance and save-failure tests. Do not mark the port complete based only on local Dart tests. Preserve the existing Flutter 3.47.4 pin and bootstrap native Arm64 SDK artifacts from the official pinned source checkout. Package metadata remains 0.3.0 until release preparation.

Ubuntu metadata limitation: existing-file replacement rejects special mode bits, owner/group differences, ACLs and all xattrs (or inspection failure). Ordinary rwx bits are preserved. This conservative behavior avoids silently losing access restrictions and needs real Ubuntu validation. macOS 15 and all Windows/Ubuntu desktop runtime checks remain outstanding.

At each work stop, update this checklist and append exact changes, validation, unresolved blockers and the next concrete action to WORK_PLAN.md. Consult this plan first; use CROSS_PLATFORM_DESIGN.md for the rationale. Do not carry obsolete historical release status forward as the current goal.
