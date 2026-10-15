# Implementation round 2 — execution and evidence

Status: implementation authorized on 2026-10-15. Development scope, not a published release.

## Working agreement

- Branch `codex/round-2-implementation`, based on merged develop `d36a285`; all implementation workers share one isolated checkout.
- Leave the original specification/mockup checkout untouched. The documentation/tooling baseline snapshots accepted inputs, not completed Android features.
- One owning spec per implementation commit, with tests; related specs share test batches, not implementation commits. Coordinator alone stages, commits, regenerates shared adapters and runs SDK/device commands.
- Up to three workers: Sol high for data/learning, Sol medium for UI/tests. Luna for bounded clerical checks; Astra for difficult independent review. Capacity handoffs retain contracts and acceptance checks.
- Exclusive file ownership; hand off one spec and wait for commit acknowledgement before continuing in the same files.
- Accepted UX deltas enter at batch boundaries. Prefer simpler reversible/data-preserving choices, log decisions and invent no functionality.
- No release branch, tag, upload, push or store publication is authorized.

## Dependency order

1. CAT-001/002 UUID persistence/cardinality and SPEED-005 marker/eligibility.
2. IMPORT-JSON-001/002 complete export/atomic import, then UX-IMPORT-JSON-001/002 file/clipboard/preview.
3. Parallel pure Speed pool/pass/streak/game work; join SPEED-RESET-001/002 and SPEED-006 completion persistence, then setup/session UI.
4. Shared/entry/review correctness proceeds in parallel within ownership boundaries.
5. Category management/assignment/filter UI, session-scoped search and joined directional availability.
6. Accepted icon/reading mascot, final UX reconciliation, Android acceptance and screenshot catalogue.

## Decisions and safeguards

- Import requires exactly one Collection. Reject zero/multiple Collections, with no merging or extra source-selection workflow.
- Existing learning is never overwritten; new entries initialize fresh. Validate final pair uniqueness and stage key swaps atomically without deleting/recreating vocabulary.
- Additive migration from schema 10 preserves identities/order, cards/history/retries/counters/settings and allocator high-water marks.
- Speed incomplete rounds are ephemeral; atomic completion effects apply per item. A short-pool game unlocks the complete remaining pass.
- One filtered Collection availability contract feeds Review, Speed and reading mascot; Overview is unfiltered.
- File picker/clipboard are adapters. No whole-app backup claim.
- Deferred: manual Speed selection, trash, hints/examples/notes UI, AI, grouping, mixed-direction preferences, extra mascot poses/statistics and publication.

## Verification

Run changed/failing tests while iterating, coherent affected suites at batch boundaries, and full host regression/analysis at final head. Serialize SDK/codegen/device work. Record exact batch/revision evidence; code alone is not verification. Android uses isolated fixtures, no-uninstall, preserved sentinels and same-schema normal APK restoration. Never clear personal app data.

Final captures cover every real route and distinct dialog/key state, EN/DE normal scale plus affected narrow/200% states and native keyboard/picker/launcher screens. Use deterministic synthetic data. Save immutable PNGs, an HTML index and a manifest in local-only design-captures, keyed by timestamp/commit. Manifest records screen/state/spec IDs, device geometry/density, locale/text scale, fixture version and tested revision. Inspect and recapture fixes.

## Specification ledger

Pending means no production completion claimed. Resolved OPEN records link to implementation specs rather than add functionality. UX-LAB-001 covers prototype/tooling, not Android.

| Specification | Revision | Owner | State | Commit / verification |
| --- | --- | --- | --- | --- |
| MASCOT-001 | 1 | Collection | Pending | — |
| SPEED-RESET-001 | 1 | Data | Pending | — |
| SPEED-RESET-002 | 1 | Data | Pending | — |
| OPEN-FSRS-001 | 1 | Data | Traceability | — |
| COLL-007 | 2 | Collection | Pending | — |
| CAT-001 | 1 | Data | Host-verified | Schema11; 7 category cases plus cascade/Undo/migration/inventory batch 31/31; Android pending. |
| CAT-002 | 1 | Data | Host-verified | Five cardinality/atomic rollback/Undo conflict cases; joined category/entry batch 35/35. Android pending. |
| CAT-004 | 1 | Collection | Pending | — |
| CAT-005 | 1 | Collection | Pending | — |
| CAT-009 | 3 | Collection | Pending | — |
| FILTER-001 | 2 | Collection | Pending | — |
| FILTER-002 | 3 | Collection | Pending | — |
| FILTER-003 | 1 | Collection | Pending | — |
| ENTRY-001 | 2 | Entry | Host-verified | Three draft focus/settled-scroll/save failure UI cases; joined category/entry batch 35/35. IME geometry follows UX-ENTRY-001; Android pending. |
| ENTRY-005 | 2 | Entry | Host-verified | Seven guarded revalidation cases plus existing autosave/confirmation regressions; B01 29/29. Android pending. |
| SPEED-001 | 2 | Learning | Foundation host-verified | Six immutable ordered-membership tests; B01 feature batch 29/29. Rotation and UI follow dependent specs. |
| SPEED-002 | 2 | Learning | Host-verified | Seven rotation/refill cases; B02 31/31. Replacements wait for next pass; streak/game specs follow. |
| SPEED-003 | 1 | Learning | Host-verified | Error-dependent streak/completion matrix plus pool/rotation regressions; shared/Speed batch 25/25. Persistence/UI pending. |
| SPEED-005 | 3 | Data | Storage host-verified | Schema12 directional marker; 5 new eligibility/migration/preservation cases; data/learning/Speed batch 174/174. UI/Android pending. |
| SPEED-006 | 1 | Learning | Pending | — |
| SPEED-007 | 2 | Learning | Host-verified | Seven short-pool/full-pass boundary cases including accepted shrinking example; joined batch 174/174. Game widget follows. |
| SPEED-008 | 1 | Learning | Controller host-verified | Nine lifecycle/write-drain/stale-callback cases; joined Speed batch 20/20. Durable data callback and route integration pending. |
| RETRY-005 | 2 | Learning | Host-verified | Deadline-based countdown, automatic eligibility refresh, expiry/coverage/lifecycle cases; joined batch 46/46 plus focused review fixes 23/23. Android pending. |
| CARD-UI-026 | 1 | Learning | Pending | — |
| REVIEW-001 | 2 | Collection | Pending | — |
| REVIEW-002 | 2 | Learning | Pending | — |
| SETUP-008 | 2 | Learning | Pending | — |
| IMPORT-JSON-001 | 1 | Data | Export host-verified | Seven raw snapshot/sample/export tests pass, including expired old-generation retries and exact learning preservation. File/clipboard/Android pending. |
| IMPORT-JSON-002 | 1 | Data | Host-verified | 18 atomic analyze/apply cases: UUID ownership, final pair swaps, exact learning preservation, stale previews, bounds, group selection and late rollback/retry. Joined 46/46 plus review-fix batch 23/23; independent critical review found no corruption defect. UI/Android pending. |
| OPEN-LEARN-001 | 1 | Learning | Traceability | — |
| PARAM-005 | 1 | Learning | Pending | — |
| SPEED-010 | 2 | Learning | Boundary host-verified | Shared complete-pass/break transition covered by SPEED-007 b0db38a; no artificial duplicate implementation. UI pending. |
| SPEED-011 | 1 | Learning | Pending | — |
| SPEED-012 | 2 | Learning | Model host-verified | Five numbers-game tests plus membership/rotation/streak/pass regressions pass; tenth correct number unlocks next full pass. UI pending. |
| SPEED-013 | 2 | Learning | Pending | — |
| UX-BRAND-001 | 1 | Coordinator | Pending | — |
| UX-MASCOT-001 | 1 | Collection | Pending | — |
| UX-DIALOG-001 | 3 | Coordinator | Host-verified | Purpose-based confirmations, safe focus, responsive footer/traversal and pending-write guard. Five new family cases plus existing dialog/create/delete/launch/exit regressions pass; Android pending. |
| UX-REVIEW-001 | 4 | Learning | Pending | — |
| UX-CARD-010 | 2 | Learning | Pending | — |
| UX-CARD-012 | 1 | Learning | Host-verified | 8 EN/DE route/paint cases at 320px and 200% text verify visible 0/50/100% width and nonzero fill height. Android pending. |
| UX-SETUP-001 | 2 | Learning | Pending | — |
| UX-SETUP-002 | 4 | Learning | Pending | — |
| UX-ENTRY-001 | 4 | Entry | Host-verified | Five EN/DE keyboard/200%/Next-Done cases plus stack/exit and category regression batch 39/39. Real IME pending. |
| UX-ENTRY-003 | 1 | Entry | Host-verified | Four EN/DE error/reopen UI cases with 7 controller regressions; B02 31/31; Android pending. |
| UX-ENTRY-004 | 1 | Entry | Host-verified | Two EN/DE compact/partial-draft cases plus 8 keyboard/activation regressions pass; Android pending. |
| UX-CAT-001 | 3 | Collection | Pending | — |
| UX-IMPORT-JSON-001 | 1 | JSON UI | Transfer surface host-verified | 11 file/clipboard/page tests in EN/DE: bounded UTF-8 reads, cancellation, exact stored export, failed-copy fallback and stale-owner/input protection. Entry route integration and Android picker pending. |
| UX-IMPORT-JSON-002 | 1 | JSON UI | Pending | — |
| UX-VOCAB-DELETE-001 | 3 | Collection | Pending | — |
| UX-SYSTEM-001 | 5 | Coordinator | Shared controls host-verified | Modality-aware card/button focus, subtle field border, Next/Done API and semantic action pairs; 25/25 shared/Speed batch. Screen integration/Android pending. |
| UX-COLL-007 | 3 | Collection | Pending | — |
| UX-COLL-008 | 3 | Collection | Pending | — |
| UX-COLL-004 | 2 | Collection | Pending | — |
| UX-COLL-003 | 2 | Collection | Pending | — |
| UX-LAB-001 | 2 | Coordinator | Snapshot | — |

## Batch evidence

- Round-1 baseline evidence remains in implementation-round-1.md; no round-2 result is inferred.
- Entry header reflows navigation above a full-width title when the centered track would exceed two lines. This retains labels and scale instead of truncating or shrinking them when German text and the keyboard consume the viewport.

### CAT-002 decision

If an Undo snapshot contains multiple assignments but its dimension has since become Single, restoration fails atomically and keeps the original receipt until its original deadline. No assignment is silently dropped; switching the dimension back permits retry while the receipt is valid.
