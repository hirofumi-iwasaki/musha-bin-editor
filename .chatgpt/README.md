# Mushagaeshi Binary Editor — Project Records

Updated: 2026-09-18

This directory is the canonical record of design decisions, implementation plans and progress for the repository `hirofumi-iwasaki/musha-bin-editor`.

## Current work

Version 0.7.0 has been released and merged into `main`. It includes the v0.5.0 background update notification, the v0.6.0 native macOS/Windows/Linux icon integration, and Japanese/English runtime localization with native macOS panel/menu localization. The release package matrix passed for source revision `629eba1`; platform GUI acceptance remains separate from CI evidence.

The current documentation branch is `release/0.7.1`, created from merged `main` at `62915103c6db9e9c5d6d72d1df325c66575aa225`. It updates the bilingual README pair to describe the published v0.7.0 release and does not change application, CI, or release metadata.

The [v0.4.0 continuation plan](RELEASE_0.4.0_PLAN.md) and [Windows/Linux design](CROSS_PLATFORM_DESIGN.md) remain historical references.

## Documents

- [Decisions and requirements](DECISIONS.md): adopted requirements, platform support and open questions.
- [Architecture](ARCHITECTURE.md): module boundaries, rendering and data handling.
- [Detailed design](DESIGN.md): comparison, editing, saving and validation plans.
- [Work plan](WORK_PLAN.md): milestones and dated work records.
- [License policy](LICENSE_POLICY.md): GPL-3.0-or-later policy and distribution preparation.
- [Prototype validation](PROTOTYPE_REPORT.md): initial functionality and measured performance.

Earlier design documents retain their original Japanese text as historical records. The application supports Japanese and English; new product text must be localized through ARB resources.

## Record-keeping rules

- Read these records before starting work and update relevant documents when decisions change.
- Distinguish user-approved decisions from proposals and unresolved details.
- Keep requirements, design and implementation plans consistent.
- Never record unperformed implementation or tests as complete.
- Record work performed, validation, remaining limitations and next steps in WORK_PLAN.md.
- Do not store credentials, private keys or non-public device dumps here.
- Recheck official platform and dependency support information when adopting or upgrading tools.

The v0.7.0 release is published. Native CI compilation does not replace remaining platform GUI acceptance checks.
