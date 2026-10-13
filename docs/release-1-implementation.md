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

The whole-interface translation audit (UX-I18N-001) follows screen implementation so that it can inspect real controls, errors and navigation. Locale infrastructure tests alone do not prove product-wide coverage.

Execution dependencies refined after COLL-015: language badges can use existing Collection data immediately. Vocabulary display-order acceptance follows the real inline vocabulary renderer. Collection rename and deletion follow stored vocabulary and directional learning state so preservation and cascade checks use actual records; their combined presentation follows those working actions. Homepage review controls follow real due data and Collection review launch. The data-minimization audit follows the final Settings storage. After ENTRY-002, termination verification (ENTRY-008) follows the real entry screen and Collection Add Entry wiring so it can exercise production confirmation rather than a substitute form. These ordering corrections preserve all 95 requirements and one-spec commits; they do not substitute placeholders, reduce scope or mark pending work verified.

Before deletion implementation, LEARN-002 precedes ENTRY-009 so Undo restores actual independent directional records rather than a placeholder progress snapshot. Later scheduling/history/retry requirements must extend preservation tests with the real state they introduce. This dependency refinement retains every included ID and does not claim future progress preservation before those records exist.

| Order | Spec ID | Implementation focus | Status | Commit | Verification evidence |
| --- | --- | --- | --- | --- | --- |
| 1 | FOUNDATION-001 | Flutter scaffold, application identity and toolchain | Verified | 050c361 | Analysis clean; startup widget test; debug APK built, installed and cold-launched on Android API 36. |
| 2 | FOUNDATION-002 | Test harness and controllable clock | Verified | 642e933 | Analysis clean; four tests pass, including deterministic deadline and clock-change checks. |
| 3 | FOUNDATION-003 | Local storage and migrations | Verified | 117126d | Analysis clean; eight tests pass; real SQLite file reopen, transaction rollback and exported schema v1. |
| 4 | FOUNDATION-004 | Canonical design and copy adapters | Verified | bd5fb4d | Four Node tests, generated-output check, eleven Flutter tests and clean analysis. |
| 5 | FOUNDATION-005 | This traceability ledger and completion audit | Verified | FOUNDATION-005 commit | 95 unique rows; every product ID exists in canonical specs; gates remain pending until full verification. |
| 6 | UX-SYSTEM-001 | Shared components and explicit states | Verified | fc11fb5 | Reusable token-backed primitives; 392px/200% German layout, semantic icon activation, focus, disabled, grading colors and reduced motion tests; Flutter analyze/test and catalog generation checks. Product-screen integration remains with owning specs. |
| 7 | UX-I18N-002 | Shared editable catalog consumption | Verified | UX-I18N-002 commit | Application title reads canonical app.name; widget scope lookup and locale-change consumer rebuild tests; Flutter analyze/test and generator check. |
| 8 | I18N-001 | English default and German support | Verified | I18N-001 commit | App locale injection aligns canonical copy and Flutter native labels; German-device English default, explicit German and unsupported fallback widget tests. Analyze clean; all 20 Flutter tests and generator check passed. Persisted selection belongs to SETTINGS-001. |
| 9 | I18N-002 | Localized interface independent of collection languages | Implemented | I18N-002 commit | Live locale controller and canonical label/native locale rebuild preserve Korean input, selection and focus in widget tests. Product-wide text and collection-language coverage remains pending until screens exist. |
| 10 | UX-ICON-002 | Lucide icons and notices | Verified | UX-ICON-002 commit | All 17 pinned SVGs load/parse/rasterize; canonical size, inherited color pixels, decorative/labeled semantics and one-time full license registration tests. Five Node generator tests and --check enforce byte-identical adapters. Android API 36 emulator integration builds/installs and verifies every rendered outline and full notice. Production-screen integration remains with owning specs. |
| 11 | UX-DIALOG-001 | Shared safe dismissible popup | Verified | UX-DIALOG-001 commit | Seven dialog tests cover safe X/barrier/Escape/Android Back, explicit result, preserved draft/focus, Tab containment, live German close label, canonical title and 392px/200% text with keyboard-safe scrolling. Product-specific dialog integration belongs to owning specs. |
| 12 | UX-HEADER-001 | Single clear page title | Verified | UX-HEADER-001 commit | Shared heading exposes one semantic level-one title and optional useful small/muted subtitle. Three widget tests verify default title count, context/section semantic hierarchy and 392px/200% German wrapping. All 37 Flutter tests pass; analysis and generator check clean. Product-page integration remains with owning specs; spacing remains UX-HEADER-002. |
| 13 | UX-HEADER-002 | Consistent compact header spacing | Verified | UX-HEADER-002 commit | Five geometry tests verify 4px navigation-row gap, 7px title margins, 8px subtitle inset, 392px/1100px at 100%/200% text, one Back at wide widths and title-only spacing. Browser adapter test proves canonical-token consumption. All 42 Flutter and six Node tests pass; analysis and generator check clean. Product-screen integration and cross-platform font-baseline comparison remain with owning screens. |
| 14 | COLL-001 | Create collections with language pairs | Verified | COLL-001 commit | SQLite UUID creation, duplicate names/pairs, validation, schema1 settings migration and file reopen tests; runnable form with retry, guarded submission and safe dismissal tests; Android UI creation and file reopen fixture. Listing/detail/default-name specs remain separate. |
| 15 | COLL-017 | Required name defaults to localized target language | Verified | COLL-017 commit | Seven widget tests cover EN/DE defaults for every offered target, sticky customization/clearing/retyping, native changes and live locale preservation of text/selection/focus; later target changes use current locale. Creation validation explicitly clears the prefill before checking required-name errors. All 56 Flutter tests pass; analysis and generator checks clean. Field-order presentation remains UX-COLL-010. |
| 16 | UX-COLL-010 | Creation field order and name interaction | Verified | UX-COLL-010 commit | Four widget tests verify physical target/native/name reading order, binding option sequences, localized names on actual input controls, Tab traversal, and 392px/200% German scroll reachability above a simulated 300px keyboard inset with edited/cleared names preserved. All 60 Flutter tests pass; analysis and generator checks clean. Default-name state remains COLL-017; final Android keyboard acceptance remains pending. |
| 17 | COLL-013 | List and open collections | Verified | COLL-013 commit | Reactive SQLite insertion-order list, exact-ID lookup and file-reopen tests; six navigation tests cover duplicate names, creation updates, whole-card padding, semantic/keyboard activation and visible focus, read retry/missing state, German 392px/200% text and preserved subscriptions. All 67 Flutter tests and six Node tests pass; generator check clean. Android API 36 isolated create/reopen/list/open/Back fixture passes. Final production force-stop durability remains pending. |
| 18 | COLL-015 | Honest empty collection state | Verified | COLL-015 commit | Four widget tests verify a real empty SQLite database, first-action creation and reactive invitation removal, ordinary New availability, safe dismissal through both actions, and pending/error/retry distinctions without fabricated Collections or review UI. All 71 Flutter tests pass; analysis and generator check clean. Specific card presentation remains UX-HOME-002. |
| 19 | UX-HOME-002 | Empty-state creation invitation | Verified | UX-HOME-002 commit | Six widget tests cover canonical card/text/gap, EN/DE semantic and keyboard activation of both actions, 392px/200% German wrapping and scroll reachability, and locale updates retaining the existing watch. All 77 Flutter and seven Node tests pass; analysis and generator check clean. COLL-015 gating remains unchanged. |
| 20 | UX-COLL-005 | Consistent language-code badges | Verified | UX-COLL-005 commit | Four widget tests verify all four stored target codes, live EN/DE independence retaining the watch, exact normal 42px bounds and canonical font/weight/tracking/colors, full localized card semantics without decorative-code duplication, and 392px/200% German growth/glyph containment. All 81 Flutter and eight Node tests pass; analysis and generator check clean. Browser adapters consume effective tokens without obsolete 48px defaults. Due counts and review controls remain separately scoped. |
| 21 | VOCAB-001 | Separate meanings may share one language text | Verified | VOCAB-001 commit | Schema 3 and UUID repository storage; five tests verify separate meanings sharing either side, required-text/missing-owner typed validation and SQL constraints, reactive scoped identity reads, ownership cascade and exported-v2 migration/file reopen retaining settings/Collections. Existing v1 migration still passes. All 86 Flutter and eight Node tests pass; analysis and generator check clean. Storage-layer behavior only; manual-entry UI, comparison policy and learning state remain separate specifications. |
| 22 | VOCAB-012 | Accepted normalization and duplicate-comparison decision | Verified | VOCAB-012 commit | Seven pure-function tests verify Latin/Hangul NFC, display case, ordinary lowercase comparison, ẞ/ß equality with ss distinction, surrounding Unicode whitespace, preserved internal spacing/punctuation/accents/compatibility forms, empty results and idempotence. Locked unorm_dart 0.3.3 primary NFC source and MIT license inspected. All 93 Flutter and eight Node tests pass; analysis and generator check clean. Stored-text/uniqueness wiring remains VOCAB-002. |
| 23 | VOCAB-002 | Block normalized duplicate pairs in a collection | Verified | VOCAB-002 commit | Schema 4 generated/exported; nine tests verify required keys/no defaults/exported composite uniqueness, normalized create/self-update, last-valid preservation on invalid/duplicate/trigger failure, concurrent duplicate writes, ß/ss distinction, direct v1/v2 upgrades, exact v3 ID/owner/raw-text/rowid retention, collision retry safety and post-rebuild foreign-key failure rollback. All 102 Flutter and eight Node tests pass; analysis and generator check clean. Storage/repository behavior; editor UI remains separate. |
| 24 | VOCAB-003 | Allow identical pairs across collections | Verified | VOCAB-003 commit | Two dedicated repository acceptance tests verify matching Collection names/languages, identical normalized pairs with distinct Entry IDs, owner-scoped reads, isolated updates and cross-owner matching edits, continued within-owner blocking, and retained Collection/Entry identities, texts and metadata across file reopen. All 104 Flutter tests pass; analysis and generator check clean. Existing production/schema behavior unchanged; manual-entry UI remains separate. |
| 25 | OFFLINE-001 | Durable offline manual vocabulary | Implemented | OFFLINE-001 commit | Android API 36 isolated application-support fixture saves through production repositories with a self-checked HTTP block and no active default network; file reopen retains IDs, canonical texts, Collection ownership and comparison keys with zero save-path HTTP attempts. Original airplane/Wi-Fi/mobile settings restored. Analysis clean, all 104 Flutter tests and generator check pass. Actual manual-entry UI and vocabulary termination/relaunch durability remain pending. |
| 26 | ENTRY-003 | Temporary unconfirmed drafts | Implemented | ENTRY-003 commit | Five controller tests verify immutable raw target/native snapshots, change notifications, independent sessions/Collections, lifetime reset and rejection of late mutations; real SQLite saved vocabulary stays unchanged across draft typing/disposal and file reopen. All 109 Flutter tests pass; analysis and generator check clean. Controller layer implemented; actual manual-entry screen integration remains pending. |
| 27 | ENTRY-006 | Retain drafts while navigating entry session | Implemented | ENTRY-006 commit | Five real-record controller tests verify ordered immutable saved snapshots, raw partial/decomposed/whitespace draft retention across saved/draft selection, no vocabulary writes, foreign/unknown rejection, no-op notifications and disposal isolation. All 114 Flutter tests pass; analysis and generator check clean. Controller layer implemented; focused stack and actual screen navigation remain pending. |
| 28 | ENTRY-002 | Confirm and next | Implemented | ENTRY-002 commit | Seven confirmation tests verify real SQLite normalized save and atomic advancement, no typing writes, required/duplicate/storage failures retaining draft/selection, shared-Future single write, pending editing/navigation guards, retry, disposal success/error and foreign-record rejection. Existing draft/navigation tests now confirm actual records through the controller; all 121 Flutter tests pass, analysis and generator check clean. Controller layer implemented; actual card checkmark/focused-stack integration remains pending. |
| 29 | ENTRY-005 | Automatic valid edits to saved stack entries | Implemented | ENTRY-005 commit | Nine tests verify automatic normalized SQLite updates with raw-buffer retention, required/duplicate/storage last-valid preservation, unchanged retry/invalid retry blocking, serialized/coalesced interleaved fields, stale success/error guards, queued valid save after newer invalid input, independent Entries/reliable draining, session identity/order/new-draft isolation, no-op/unknown edits and accepted-write persistence after disposal without late notifications. All 130 Flutter tests pass; analysis and generator check clean. Controller layer implemented; actual entry-screen integration remains pending. |
| 30 | ENTRY-001 | Scroll-focused expanding card stack | Implemented | ENTRY-001 commit | Ten widget tests cover real SQLite UI confirmation/autosave, measured no-tap activation, compact neighbors and raw draft retention, expansion-frame stability, held-drag autosave, active-field Tab order, nested-scroll isolation, bounded stack keys, pending/errors/retry, late-session error isolation/replacement, and 392px/200% German keyboard/locale/reduced-motion state. Analysis clean; all 140 Flutter and eight Node tests pass; generator check clean. Android acceptance and exact UX-ENTRY-001 presentation remain pending; route/exit/global-completion/deletion belong to their own specs. |
| 31 | UX-ENTRY-001 | Focused stack presentation | Verified | UX-ENTRY-001 commit | Canonical binding card/preview/metadata geometry and primary 48px Save & Next target are tested, including growable compact minimum and reduced motion. Clean analysis; all 142 Flutter and nine Node tests pass; generator check clean. Isolated production-screen Android fixture passes at 200% German with actual IME inset 226.67dp, swipe activation opening no keyboard, raw draft/selection retention, locale reflow and real SQLite confirmation. Header actions, routing, exit and deletion remain separately owned. |
| 32 | ENTRY-007 | Back and nonempty-draft discard confirmation | Pending | — | — |
| 33 | ENTRY-011 | Global completion validates, saves and exits | Pending | — | — |
| 34 | UX-ENTRY-002 | Distinct global and card checkmarks | Pending | — | — |
| 35 | LEARN-002 | Independent directional learning items | Pending | — | — |
| 36 | ENTRY-009 | Delete with eight-second progress-preserving Undo | Pending | — | — |
| 37 | ENTRY-004 | Revisit, edit and delete saved session entries | Pending | — | — |
| 38 | UX-VOCAB-DELETE-001 | Swipe reveals explicit delete; accessible alternative | Pending | — | — |
| 39 | UX-COLL-003 | Accessible inline Add Entry action | Pending | — | — |
| 40 | ENTRY-008 | Confirmed entry durability after termination | Pending | — | — |
| 41 | VOCAB-EDIT-001 | Validated inline vocabulary auto-save | Pending | — | — |
| 42 | UX-COLL-009 | Expand vocabulary in place | Pending | — | — |
| 43 | COLL-003 | Target-language-first vocabulary order | Pending | — | — |
| 44 | UX-COLL-011 | Compact fields and red deletion | Pending | — | — |
| 45 | VOCAB-EDIT-002 | Restore opening values on discard | Pending | — | — |
| 46 | UX-COLL-012 | Separate finish and discard controls | Pending | — | — |
| 47 | COLL-012 | Rename without changing entries or progress | Pending | — | — |
| 48 | COLL-014 | Confirm collection deletion and cascade data removal | Pending | — | — |
| 49 | UX-COLL-007 | Inline collection rename and deletion presentation | Pending | — | — |
| 50 | LEARN-001 | Real offline FSRS scheduling | Pending | — | — |
| 51 | LEARN-003 | Continuous FSRS memory state | Pending | — | — |
| 52 | DATA-004 | Regular review retention and generation discriminator | Pending | — | — |
| 53 | DATA-001 | No complete retry-attempt history | Pending | — | — |
| 54 | CARD-UI-016 | Again, Hard and Good grade mapping | Pending | — | — |
| 55 | ANSWER-004 | Optional Hard modifier | Pending | — | — |
| 56 | SESSION-017 | Single-collection session boundary | Pending | — | — |
| 57 | SESSION-018 | All due items, with voluntary exit | Pending | — | — |
| 58 | REVIEW-001 | Explicit fixed direction before launch | Pending | — | — |
| 59 | REVIEW-002 | Honest no-due state | Pending | — | — |
| 60 | CARD-UI-001 | Exit separate from previous-review correction | Pending | — | — |
| 61 | CARD-UI-004 | No redundant headings or tags | Pending | — | — |
| 62 | CARD-004 | No default category tags on cards | Pending | — | — |
| 63 | CARD-UI-007 | Card reveal and subordinate cue | Pending | — | — |
| 64 | UX-CARD-005 | Bottom-right reveal icon and cue | Pending | — | — |
| 65 | CARD-UI-026 | Both languages and direction/progress context | Pending | — | — |
| 66 | CARD-UI-025 | Equal-width semantic grading actions | Pending | — | — |
| 67 | CARD-UI-015 | Hard checkbox aligned above Correct | Pending | — | — |
| 68 | RETRY-001 | Incorrect items enter pending retry queue | Pending | — | — |
| 69 | RETRY-002 | Decreasing presentation gaps | Pending | — | — |
| 70 | RETRY-004 | Local 04:00 retry expiry | Pending | — | — |
| 71 | RETRY-005 | Ten-second insufficient-pool wait | Pending | — | — |
| 72 | RETRY-006 | FSRS review separated from reinforcement retries | Pending | — | — |
| 73 | RETRY-003 | Resume same-day retries after leaving | Pending | — | — |
| 74 | SESSION-019 | Regenerate resumed order with early retry priority | Pending | — | — |
| 75 | CARD-UI-023 | Pending until success or learning-day expiry | Pending | — | — |
| 76 | CARD-UI-024 | Do not expose per-question prior error count | Pending | — | — |
| 77 | CARD-UI-002 | Unique completion and first-try counts | Pending | — | — |
| 78 | UX-CARD-012 | Readable session counters | Pending | — | — |
| 79 | UNDO-001 | Replace previous review and recalculate transactionally | Pending | — | — |
| 80 | CARD-UI-020 | Consistent scheduler and retry correction | Pending | — | — |
| 81 | CARD-UI-019 | Only immediately preceding grade is correctable | Pending | — | — |
| 82 | UX-CARD-010 | Distinct previous-review navigation | Pending | — | — |
| 83 | UX-REVIEW-003 | Hide correction after reveal | Pending | — | — |
| 84 | UX-REVIEW-001 | Integrated self-assessment layout | Pending | — | — |
| 85 | UX-REVIEW-002 | Answer emphasis and accessible Hard target | Pending | — | — |
| 86 | UX-COLL-008 | Actual due-count card and compact vocabulary rows | Pending | — | — |
| 87 | UX-HOME-001 | Collection-specific review entry points | Pending | — | — |
| 88 | UX-COLL-004 | Consistent localized quick-review sizing | Pending | — | — |
| 89 | UX-ICON-001 | Circular review icon | Pending | — | — |
| 90 | REVIEW-003 | Dismissible learned/first-try summary | Pending | — | — |
| 91 | UX-REVIEW-004 | Readable motivational summary popup | Pending | — | — |
| 92 | SETTINGS-001 | Persistent immediate interface language setting | Pending | — | — |
| 93 | UX-SETTINGS-001 | Language-only Settings view | Pending | — | — |
| 94 | DATA-005 | Minimal necessary stored data | Pending | — | — |
| 95 | UX-I18N-001 | Localized visible and accessible text across implemented screens | Pending | — | — |

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
- ENTRY-010's offline-sync behavior remains deferred. UX-ENTRY-001 verifies focused-screen Android keyboard/safe-area handling and usable focused scrolling with isolated data; production route/exit integration and full release durability gates remain separately tracked.
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
