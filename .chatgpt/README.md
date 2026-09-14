# Mushaaeshi Binary Editor — Project Records

Updated: 2026-09-14

This directory is the canonical record of design decisions, implementation plans and progress for the repository `hirofumi-iwasaki/musha-bin-editor`.

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

The read-only comparison preview is implemented. Editing/saving and macOS 15 hardware validation remain outstanding. The active release-preparation branch is `release/0.1.0`.
