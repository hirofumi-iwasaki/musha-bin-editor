# Mushagaeshi Binary Editor — Project Records

Updated: 2026-09-15

This directory is the canonical record of design decisions, implementation plans and progress for the repository `hirofumi-iwasaki/musha-bin-editor`.

## Current work

Start with [v0.4.0 continuation plan](RELEASE_0.4.0_PLAN.md), then [Windows/Linux design](CROSS_PLATFORM_DESIGN.md). The working branch is `release/0.4.0`; implementation is pending.

## Documents

- [Decisions and requirements](DECISIONS.md): adopted requirements, platform support and open questions.
- [Architecture](ARCHITECTURE.md): module boundaries, rendering and data handling.
- [Detailed design](DESIGN.md): comparison, editing, saving and validation plans.
- [Work plan](WORK_PLAN.md): milestones and dated work records.
- [License policy](LICENSE_POLICY.md): GPL-3.0-or-later policy and distribution preparation.
- [Prototype validation](PROTOTYPE_REPORT.md): initial functionality and measured performance.

Earlier design documents retain their original Japanese text as historical records. The application, public README and new user-facing text use English. Localization is deferred.

## Record-keeping rules

- Read these records before starting work and update relevant documents when decisions change.
- Distinguish user-approved decisions from proposals and unresolved details.
- Keep requirements, design and implementation plans consistent.
- Never record unperformed implementation or tests as complete.
- Record work performed, validation, remaining limitations and next steps in WORK_PLAN.md.
- Do not store credentials, private keys or non-public device dumps here.
- Recheck official platform and dependency support information when adopting or upgrading tools.

v0.3.0 includes comparison, editing/saving and hashes and has been merged into main. Current work is the Windows and Ubuntu port for v0.4.0. macOS 15 hardware validation remains outstanding.
