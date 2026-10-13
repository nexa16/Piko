# Roadmap

The owner has authorized the local-first Flutter first release, with Android verification. No release date is implied. The detailed ordered requirements and evidence live in the [implementation ledger](release-1-implementation.md); functional behavior and UX remain defined in their canonical specifications.

## Current implementation sequence

1. Android host, deterministic tests, transactional local storage, and canonical design/copy adapters.
2. Shared accessible interface components and localized controls.
3. Collection creation, listing, naming and deletion; vocabulary integrity and offline persistence.
4. Focused entry, draft handling, saved edits, inline editing and reversible deletion.
5. Independent directional FSRS state, self-assessment, reinforcement retries and previous-grade correction.
6. Session summary, language settings and full Android acceptance verification.

Use one `codex/release-1-implementation` branch and one draft PR into `develop`. Each implementation commit represents one specification ID. Relevant tests accompany behavior; the coordinator reviews and publishes checked commits. The owner controls merging and release publication.

## Verification

Completion requires requirement-specific tests, static analysis, actual Android build/install/runtime checks, comparison with the binding mockup, persistence across restart, offline behavior, scheduling and correction integrity, localization and accessibility checks. Writing code or passing a narrower test does not establish full completion. The ledger records pending checks explicitly.

## Later scope

Accounts and synchronization, AI, import, categories, hints, examples, typed answers, Speed Learning, mixed-direction sessions, Skip, advanced statistics, developer parameters and retained trash are outside this first release. Learning-level labels and thresholds remain deferred. Conditional constraints for these capabilities do not introduce them into the release.

Product research questions remain open without invented findings or target users. GitHub Projects and heavier delivery automation remain deferred until delivery volume justifies them. Store publication and release signing are separate from the current Android development verification.
