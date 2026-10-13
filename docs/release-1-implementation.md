# Release 1 implementation ledger

## FOUNDATION-005 — Spec-by-spec implementation traceability

**Status: implementation in progress.** This ledger records the accepted implementation sequence and verification evidence. It does not replace the functional or UX specifications or make an implementation complete by listing it. The coordinator updates the relevant canonical requirement's release assignment and decision record in that requirement's own commit. Each commit represents one specification ID; related functional and UX IDs remain separate commits.

Implementation uses one `codex/release-1-implementation` branch based on the latest `develop`, with one draft implementation PR targeting `develop`. Checked commits can be pushed after public-data review. The owner retains merge and release publication decisions.

## Accepted implementation constraints

- Flutter application under `app/`, local-first storage, Android-only Release 1 verification. Android application ID: `io.github.nexa16.piko`. No web or iOS verification is claimed.
- Feature controllers and repository boundaries separate Flutter presentation from storage. Drift/SQLite provides transactional local storage, stable IDs and versioned migrations.
- The FSRS 2.0.1 library supplies scheduling through an adapter. Translation directions have independent learning state. Short-term reinforcement retries do not independently advance FSRS. LEARN-001 must record the technical configuration: empty learning/relearning steps and no fuzz, retaining the library's default mathematical parameters and 0.9 retention. This avoids default minute-based library steps competing with Piko's separate retry queue; implementation and verification are still pending.
- `shared/design-config.js` and `shared/copy.js` remain the canonical design and English/German interface sources; generated Dart adapters are not independently maintained defaults. The HTML/CSS mockup remains the visual and interaction reference.
- Duplicate pairs are checked within a Collection after surrounding whitespace trimming, Unicode NFC normalization and case-insensitive comparison. Different meanings sharing only one language text and identical pairs in different Collections remain allowed.
- Vocabulary deletion offers eight seconds of Undo. Future trash retention is excluded.
- Retry gaps are 20, 10, 5, 3 and then 1 intervening vocabulary presentations after successive errors. Other retry presentations count. If insufficient other items are available, use a ten-second wait; do not insert filler vocabulary.
- The local learning day ends at 04:00. Pending retries expire without becoming successes. Previous-grade correction restores the prior state and replaces the affected regular review transactionally rather than appending a second review.
- Confirmed entries survive application termination; unconfirmed entry-session drafts do not require crash recovery.

These are accepted implementation decisions, not evidence that storage, scheduling, UI or verification already works.

## Ordered implementation and evidence

Every row starts pending. Record the commit, relevant test or runtime evidence, and any remaining limitation before marking a row verified. A later overlapping requirement needs its own specific behavior or acceptance evidence; do not claim its expanded scope from a narrower predecessor.

| Order | Spec ID | Implementation focus | Status | Commit | Verification evidence |
| --- | --- | --- | --- | --- | --- |
| 1 | FOUNDATION-001 | Flutter scaffold, application identity and toolchain | Verified | 050c361 | Analysis clean; startup widget test; debug APK built, installed and cold-launched on Android API 36. |
| 2 | FOUNDATION-002 | Test harness and controllable clock | Verified | 642e933 | Analysis clean; four tests pass, including deterministic deadline and clock-change checks. |
| 3 | FOUNDATION-003 | Local storage and migrations | Verified | 117126d | Analysis clean; eight tests pass; real SQLite file reopen, transaction rollback and exported schema v1. |
| 4 | FOUNDATION-004 | Canonical design and copy adapters | Verified | bd5fb4d | Four Node tests, generated-output check, eleven Flutter tests and clean analysis. |
| 5 | FOUNDATION-005 | This traceability ledger and completion audit | Verified | FOUNDATION-005 commit | 95 unique rows; every product ID exists in canonical specs; gates remain pending until full verification. |
| 6 | UX-SYSTEM-001 | Shared components and explicit states | Verified | Pending commit | Reusable token-backed primitives; 392px/200% German layout, semantic icon activation, focus, disabled, grading colors and reduced motion tests; Flutter analyze/test and catalog generation checks. Product-screen integration remains with owning specs. |
| 7 | UX-I18N-002 | Shared editable catalog consumption | Pending | — | — |
| 8 | I18N-001 | English default and German support | Pending | — | — |
| 9 | I18N-002 | Localized interface independent of collection languages | Pending | — | — |
| 10 | UX-I18N-001 | Localized visible and accessible text | Pending | — | — |
| 11 | UX-ICON-002 | Lucide icons and notices | Pending | — | — |
| 12 | UX-DIALOG-001 | Shared safe dismissible popup | Pending | — | — |
| 13 | UX-HEADER-001 | Single clear page title | Pending | — | — |
| 14 | UX-HEADER-002 | Consistent compact header spacing | Pending | — | — |
| 15 | COLL-001 | Create collections with language pairs | Pending | — | — |
| 16 | COLL-017 | Required name defaults to localized target language | Pending | — | — |
| 17 | UX-COLL-010 | Creation field order and name interaction | Pending | — | — |
| 18 | COLL-013 | List and open collections | Pending | — | — |
| 19 | COLL-015 | Honest empty collection state | Pending | — | — |
| 20 | UX-HOME-002 | Empty-state creation invitation | Pending | — | — |
| 21 | UX-HOME-001 | Collection-specific review entry points | Pending | — | — |
| 22 | UX-COLL-005 | Consistent language-code badges | Pending | — | — |
| 23 | COLL-003 | Target-language-first vocabulary order | Pending | — | — |
| 24 | COLL-012 | Rename without changing entries or progress | Pending | — | — |
| 25 | UX-COLL-007 | Inline collection rename and deletion presentation | Pending | — | — |
| 26 | COLL-014 | Confirm collection deletion and cascade data removal | Pending | — | — |
| 27 | DATA-005 | Minimal necessary stored data | Pending | — | — |
| 28 | VOCAB-001 | Separate meanings may share one language text | Pending | — | — |
| 29 | VOCAB-012 | Accepted normalization and duplicate-comparison decision | Pending | — | — |
| 30 | VOCAB-002 | Block normalized duplicate pairs in a collection | Pending | — | — |
| 31 | VOCAB-003 | Allow identical pairs across collections | Pending | — | — |
| 32 | OFFLINE-001 | Durable offline manual vocabulary | Pending | — | — |
| 33 | ENTRY-003 | Temporary unconfirmed drafts | Pending | — | — |
| 34 | ENTRY-006 | Retain drafts while navigating entry session | Pending | — | — |
| 35 | ENTRY-002 | Confirm and next | Pending | — | — |
| 36 | ENTRY-008 | Confirmed entry durability after termination | Pending | — | — |
| 37 | ENTRY-005 | Automatic valid edits to saved stack entries | Pending | — | — |
| 38 | ENTRY-001 | Scroll-focused expanding card stack | Pending | — | — |
| 39 | UX-ENTRY-001 | Focused stack presentation | Pending | — | — |
| 40 | ENTRY-007 | Back and nonempty-draft discard confirmation | Pending | — | — |
| 41 | ENTRY-011 | Global completion validates, saves and exits | Pending | — | — |
| 42 | UX-ENTRY-002 | Distinct global and card checkmarks | Pending | — | — |
| 43 | ENTRY-009 | Delete with eight-second progress-preserving Undo | Pending | — | — |
| 44 | ENTRY-004 | Revisit, edit and delete saved session entries | Pending | — | — |
| 45 | UX-VOCAB-DELETE-001 | Swipe reveals explicit delete; accessible alternative | Pending | — | — |
| 46 | UX-COLL-003 | Accessible inline Add Entry action | Pending | — | — |
| 47 | VOCAB-EDIT-001 | Validated inline vocabulary auto-save | Pending | — | — |
| 48 | UX-COLL-009 | Expand vocabulary in place | Pending | — | — |
| 49 | UX-COLL-011 | Compact fields and red deletion | Pending | — | — |
| 50 | VOCAB-EDIT-002 | Restore opening values on discard | Pending | — | — |
| 51 | UX-COLL-012 | Separate finish and discard controls | Pending | — | — |
| 52 | LEARN-002 | Independent directional learning items | Pending | — | — |
| 53 | LEARN-001 | Real offline FSRS scheduling | Pending | — | — |
| 54 | LEARN-003 | Continuous FSRS memory state | Pending | — | — |
| 55 | DATA-004 | Regular review retention and generation discriminator | Pending | — | — |
| 56 | DATA-001 | No complete retry-attempt history | Pending | — | — |
| 57 | CARD-UI-016 | Again, Hard and Good grade mapping | Pending | — | — |
| 58 | ANSWER-004 | Optional Hard modifier | Pending | — | — |
| 59 | SESSION-017 | Single-collection session boundary | Pending | — | — |
| 60 | SESSION-018 | All due items, with voluntary exit | Pending | — | — |
| 61 | REVIEW-001 | Explicit fixed direction before launch | Pending | — | — |
| 62 | REVIEW-002 | Honest no-due state | Pending | — | — |
| 63 | CARD-UI-001 | Exit separate from previous-review correction | Pending | — | — |
| 64 | CARD-UI-004 | No redundant headings or tags | Pending | — | — |
| 65 | CARD-004 | No default category tags on cards | Pending | — | — |
| 66 | CARD-UI-007 | Card reveal and subordinate cue | Pending | — | — |
| 67 | UX-CARD-005 | Bottom-right reveal icon and cue | Pending | — | — |
| 68 | CARD-UI-026 | Both languages and direction/progress context | Pending | — | — |
| 69 | CARD-UI-025 | Equal-width semantic grading actions | Pending | — | — |
| 70 | CARD-UI-015 | Hard checkbox aligned above Correct | Pending | — | — |
| 71 | RETRY-001 | Incorrect items enter pending retry queue | Pending | — | — |
| 72 | RETRY-002 | Decreasing presentation gaps | Pending | — | — |
| 73 | RETRY-004 | Local 04:00 retry expiry | Pending | — | — |
| 74 | RETRY-005 | Ten-second insufficient-pool wait | Pending | — | — |
| 75 | RETRY-006 | FSRS review separated from reinforcement retries | Pending | — | — |
| 76 | RETRY-003 | Resume same-day retries after leaving | Pending | — | — |
| 77 | SESSION-019 | Regenerate resumed order with early retry priority | Pending | — | — |
| 78 | CARD-UI-023 | Pending until success or learning-day expiry | Pending | — | — |
| 79 | CARD-UI-024 | Do not expose per-question prior error count | Pending | — | — |
| 80 | CARD-UI-002 | Unique completion and first-try counts | Pending | — | — |
| 81 | UX-CARD-012 | Readable session counters | Pending | — | — |
| 82 | UNDO-001 | Replace previous review and recalculate transactionally | Pending | — | — |
| 83 | CARD-UI-020 | Consistent scheduler and retry correction | Pending | — | — |
| 84 | CARD-UI-019 | Only immediately preceding grade is correctable | Pending | — | — |
| 85 | UX-CARD-010 | Distinct previous-review navigation | Pending | — | — |
| 86 | UX-REVIEW-003 | Hide correction after reveal | Pending | — | — |
| 87 | UX-REVIEW-001 | Integrated self-assessment layout | Pending | — | — |
| 88 | UX-REVIEW-002 | Answer emphasis and accessible Hard target | Pending | — | — |
| 89 | UX-COLL-008 | Actual due-count card and compact vocabulary rows | Pending | — | — |
| 90 | UX-COLL-004 | Consistent localized quick-review sizing | Pending | — | — |
| 91 | UX-ICON-001 | Circular review icon | Pending | — | — |
| 92 | REVIEW-003 | Dismissible learned/first-try summary | Pending | — | — |
| 93 | UX-REVIEW-004 | Readable motivational summary popup | Pending | — | — |
| 94 | SETTINGS-001 | Persistent immediate interface language setting | Pending | — | — |
| 95 | UX-SETTINGS-001 | Language-only Settings view | Pending | — | — |

Foundation rows 1–4 are defined in [implementation foundations](implementation-foundation.md). This file defines FOUNDATION-005: maintain an ordered, uniquely identified ledger, distinguish evidence from pending work, and audit all final gates before declaring completion. The ledger mechanism is established; the final product audit remains pending. Final acceptance evidence can reference several specifications, but implementation commits must still remain scoped to one ID.

## Scope reconciliation and exclusions

The release tags in the original specifications predate the implementation agreement. Missing or Undecided tags on dependencies in the table require canonical reconciliation; they are not permission to pull every Base or Minimum requirement into this release.

- Exclude accounts, remote services, cross-device synchronization, AI, import, categories, hints, example pairs, typed answers, Speed Learning, mixed-direction sessions, Skip, advanced statistics and developer parameter controls. Their conditional Base constraints do not introduce these capabilities.
- Defer descriptive learning-level UI and thresholds: LEARN-004–007, OPEN-FSRS-002 and OPEN-LEARN-004. Do not present invented labels derived from FSRS.
- VOCAB-TRASH-001 remains Later; eight-second Undo does not define future trash retention.
- CARD-001 includes typed-answer switching and is not delivered in full by self-assessment. REVIEW-001 and CARD-UI-007 describe this release's behavior.
- CARD-005 and PREF-005 include mixed/both-direction options; REVIEW-001 governs the fixed single direction selected explicitly before launch.
- CARD-UI-006 and UX-CARD-002 include future nested Hint controls. Their basic reveal behavior is covered by CARD-UI-007; do not claim the entire mixed requirement complete.
- CARD-UI-014, ANSWER-003 and UX-CARD-008 include dynamic suggested-grade widths. CARD-UI-025 and UX-REVIEW-001 govern fixed equal widths for this release.
- OFFLINE-004 includes category selection and carry-over. OFFLINE-001 governs the included offline manual-entry capability. OFFLINE-002/003/006 do not introduce synchronization.
- UX-COLL-001/002 combine included collection presentation with excluded filters, grouping, view switching and examples. Use the more specific included Collection requirements; do not claim these mixed requirements fully implemented.
- SETUP-008 and UX-SETUP-001 allow resolved launch parameters to bypass setup; the newer REVIEW-001 explicitly requires direction choice before this release's session. Their expanded behavior is not a completion target.
- SESSION-018's optional active filters apply only when filtering ships. CARD-UI-020's Speed-progress clause applies only when Speed ships.
- ENTRY-010's offline-sync behavior remains deferred. Required Android keyboard/safe-area handling and usable focused scrolling still need verification under ENTRY-001 and UX-ENTRY-001.
- OPEN-CARD-004 is resolved through documented transactional previous-grade correction. OPEN-RETRY-001, RETRY-007 and the relevant retry portion of OPEN-LEARN-002 need the accepted count/wait convention recorded. Personal Difficulty and Speed reset questions remain outside this release.

## Final acceptance evidence

Completion remains unproven until evidence covers the full scope, including real Android runtime behavior. Record results here when available; no gate is currently passed.

| Gate | Status | Evidence |
| --- | --- | --- |
| Dependency and canonical requirement reconciliation | Pending | — |
| Focused automated tests for every implemented behavior | Pending | — |
| Complete relevant regression suite and static analysis | Pending | — |
| Android build, installation and launch | Pending | — |
| Empty start, collection create/rename/delete and restart durability | Pending | — |
| Focused entry stack with keyboard, scrolling, validation and draft exit | Pending | — |
| Inline editing, finish/discard, swipe deletion and Undo with progress | Pending | — |
| Offline save, restart and confirmed-entry termination durability | Pending | — |
| Independent directions, real FSRS ratings, retries, wait, resume and day expiry | Pending | — |
| Previous-grade replacement, counters and dismissible summary | Pending | — |
| English/German, large text, accessible controls and reduced motion | Pending | — |
| Binding mockup comparison and shared configuration/copy consumption | Pending | — |
| Complete publication content and commit metadata review | Pending | — |
| One-spec commits and final open PR into develop | Pending | — |

Actual blockers requiring an owner decision must be recorded explicitly. Missing implementation or weak verification evidence is unfinished work, not an accepted open decision.
