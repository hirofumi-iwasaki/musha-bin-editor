# Mushagaeshi Binary Editor — Project Records

Updated: 2026-09-15

This directory is the canonical record of design decisions, implementation plans and progress for the repository `hirofumi-iwasaki/musha-bin-editor`.

## Current work

Start with [update check design](UPDATE_CHECK_DESIGN.md). The working branch is `release/0.5.0`, created from main at `506bda6`. The update notification is implemented and locally verified; native macOS build validation is blocked until the local Xcode license is accepted.

The [v0.4.0 continuation plan](RELEASE_0.4.0_PLAN.md) and [Windows/Linux design](CROSS_PLATFORM_DESIGN.md) remain historical references.

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

v0.4.0 has been released and merged into main. Current work is the implemented startup update notification for v0.5.0. Native CI compilation does not replace remaining hardware/GUI acceptance checks.
