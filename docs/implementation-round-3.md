# Round 3 implementation ledger

Owner approved incremental implementation on 2026-10-16. Base: develop 17677e3 (same tree as accepted round-2 b6b840c). No publication or promotion authorized.

## Checkpoints

Keep every verified APK immutable locally. Incomplete specs move explicitly to round 4, never to implemented.

| Checkpoint | Scope | Status |
|---|---|---|
| 0 | Verified round-2 fallback, signing/upgrade path | Existing APK checksum verified; develop tree matches baseline |
| 1 | SPEED-007/010 r3; UX-SYSTEM-001 foundation; Speed setup/completion; review presentation | Focused host and isolated Android acceptance passed; immutable APK preserved |
| 2 | JSON presentation, entry/dialog usability, Collection/filter clarity | Host and Android passed; immutable APK preserved; one cosmetic label fix carried into checkpoint 3 |
| 3 | PREF-005, LEARN-005 / UX-LEARN-005 | Host and isolated native upgrade acceptance passed; immutable APK preserved |
| 4 | One example pair and Hint, persistence/editor/cards/JSON v2 | Host regression repaired, scoped Android acceptance passed, final APK and seven inspected captures preserved |

Fallback historical APK: round-2 660f343, SHA256 5cf26e17b15e521e98e7ddc9fc5121225b9d59f98d94f3247952ab041a8afbf6. Its recorded 1022 tests and Android evidence remain historical, not round-3 evidence.

## Ownership

Coordinator owns shared catalogs/generation, integration, documentation and commits. Speed agent owns pure Speed and Speed UI tests; foundation agent owns shared UI/theme/fonts. At most two concurrent implementation agents; file ownership is explicit. Tests run in coherent batches, SDK/device operations serialized.

## Accepted feature decisions

- PREF-005: existing installations without an explicit saved choice default Native → Target; new installations Target → Native. Saved choices survive. Detail actions/status only; Overview remains unaffected.
- LEARN-005: pending retry takes precedence, then New without normal-review history, Due now, or localized Next review date/time. Speed-only completion adds Speed completed; no invented mastery levels or scheduling changes.
- Note means Hint, not a separate field. One optional example pair (both languages required, maximum 1000 characters each), one optional Hint (maximum 2000 characters).
- Question shows prompt-language example and Hint according to its existing visibility rules. Answer shows both example languages and Hint. Applies to normal and Speed.
- Hint visibility is per entry, Always visible or Hidden until tapped. Initial global default Always visible; changes affect new entries only. Entry can explicitly make its choice the global default. Revealing lasts for that question.
- JSON v2 exports examples/Hint including per-entry visibility, accepts v1, omits global settings. Separate import groups; omitted preserves, null clears, unselected unchanged. Missing visibility preserves existing setting or uses global default for a new entry. Learning is never overwritten.
- Multiple examples, simplified import template, manual Speed selection, trash, extra mascot poses and mixed-direction sessions remain Later.

## Verification policy

Changed tests first; affected suites and Android smoke at checkpoints. Final delivered head gets one full host regression. Storage changes require populated upgrade/reopen, rollback and exact preservation. No personal-data clearing or automatic Flutter installation on preserved devices. Main gallery: important pages, English, normal size only.

## Evidence

Implementation/test/Android evidence and exact checkpoint commits are appended as obtained. Writing code alone does not close a finding.

### Checkpoint 1

- App head 1002ba0; isolated Android test added at 41592e1. Commits: SPEED-007 2bc488c; UX-SYSTEM-001 587b618/72e9264; UX-I18N-001 47198be; UX-SETUP-002 6e0ce43; SPEED-008 080af79; UX-REVIEW-004 84ead2c; UX-REVIEW-002 b9b80a9.
- Focused host batches: 62 and 131 passing tests; analysis clean. Native fixture: two passing tests, eight English normal-size captures. Full final host regression remains outstanding.
- Immutable phone APK: piko-round-3-checkpoint-1-1002ba0.apk; SHA256 b80f69a0707de0372f9fd9ca75b8e9d751b1a524239d65a44a7d5a7438ccb330. Same application identity and debug signing certificate as the existing test APK; release-mode build is not store publication.
- Native tests used only isolated synthetic data. Original database and preservation sentinel hashes matched before/after; normal app restored in place. Low emulator disk space required smaller x64 native builds, never uninstalling or clearing personal data.

### Checkpoint 2

- Source snapshot c1f7b54. UX-DIALOG-001 r4 b42cb1e; UX-ENTRY-002 r2 d52e566; UX-IMPORT-JSON-001 r3 d0ba3f6/c1f7b54; UX-COLL-012 1aaa9ee; UX-COLL-003 r3 4df2a37; canonical copy/token adapter 044fbf8.
- Initial affected batch: 103 passed, 12 failed. Fixed stale label expectations and a genuine short-screen IME layout issue without relaxing visibility assertions. Targeted rerun: all 47 passed. Analysis clean.
- Entry JSON return intentionally runs existing draft-exit protection before leaving Collection's entry route. Incomplete raw edits are never silently discarded.
- Selection Apply is absent while unchanged, but its geometry is reserved. Clear filters preserves search. Successful JSON import remains visible until explicit return.
- Native isolated workflow passed (two tests including teardown), covering real IME, persisted Save & Next, stable assignment geometry, JSON preview/apply/return and learning-preserving reopen. Original database/sentinel hashes remained unchanged.
- Immutable APK piko-round-3-checkpoint-2-c1f7b54.apk; SHA256 2301a5dce6279a10b6b9f75f3b7736f4eafd389d4320a25802f6b9209df918bb. Eight English normal-size captures reviewed locally. Known cosmetic defect: Filters label wraps unexpectedly; fix and recapture scheduled for checkpoint 3. Surface captures exclude OS keyboard pixels, though real IME geometry was asserted.

### Checkpoint 3

- Frozen source 3b9835a. PREF-005 r2: ad0a176/496ce81 (schema 13 and upgrade defaults), 3d26bc5 (guarded settings/Detail launch wiring), 3b9835a (native fixture). LEARN-005 r2: 12c28f2 (passive projection), da19e1a (localized status). Canonical copy da1df88.
- All 18 focused data tests and 85 affected UI tests pass. Native fixture SQL matches the frozen schema-12 export in a separate passing host test. Analysis clean before the native test addition; three test-only analyzer warnings corrected afterward.
- Overview remains unfiltered. Pending/stale Detail launches cannot use a direction hidden by a changed preference. A single Speed action remains half width at the left.
- Android native fixture passed two tests including teardown; three English normal-size screenshots inspected. It verified a frozen-schema-12 upgrade, missing preference fallback, both/single statuses, unaffected Overview picker and exact synthetic learning-data preservation after reopen. The Filters wrapping defect is visibly corrected.
- Immutable phone APK piko-round-3-checkpoint-3-3b9835a.apk; SHA256 1814b37c4638366355b04e4de72b629fbc69276f2addaf80c288f7b7b0cb3a74. Normal APK restored in place after testing. Android's emulator-only storage reserve was briefly lowered for installation, then restored in a finally block; no data was deleted.

### Checkpoint 4

- VOCAB-004 storage increment 6ee3440: additive schema 14, optional-content validation, legacy-update preservation, atomic default changes, opening/Undo/query preservation. All 78 focused content and affected migration/learning/category tests pass, including the independently identified schema-4 regression. Generated Drift adapter updated.
- Editor increment 8465239/d1fa5c4 and shared card 006d3e1: raw drafts, synchronous save admission, inherited/explicit Hint visibility and one-way per-question reveal. The original admission assertions and new held-read failure/double-submit checks pass (24 focused tests). Real PikoCard integration found and fixed an opaque-decoration/radio painting assertion.
- JSON v2 increment 4c3238e: all 34 focused tests pass, including v1 compatibility, exact empty-Hint visibility round-trip, omitted/null/unselected behavior, relevant-default stale previews, rollback and exact learning preservation. Independent read-only JSON review found no additional concrete defect.
- Final integrated host regression ran once: 1100 passed, 40 failed. Failures were corrected without suppressing assertions: radio painting, explicit additive migration expectations, and selectors/geometry/default assumptions superseded by accepted round-3 behavior. Focused reruns passed for every originally failing test (146/165 first rerun, then 22/22 runtime/JSON, 47/48 presentation and 4/4 final entry-route tests). All 22 shared-adapter tests pass; analysis is clean. No second full suite was needed after these bounded repairs.
- The final entry-route test performs a real scroll gesture and waits for the existing Collection-created snackbar before tapping the lower Save & Next action; it still verifies persisted entries, fresh drafts and file reopen.
- Final Android candidate source: 2bacd76. Android acceptance and visual inspection remain pending at this point.
- Packaging encountered host disk exhaustion. Only disposable `app/build` output in the three coordinator-created earlier checkpoint build copies was removed (about 4.5 GB); immutable APKs, source archives and captures were retained. The interrupted Gradle daemon was stopped before rebuilding. This was an environment repair, not a source change or personal-data deletion.
- Initial packaging candidate piko-round-3-checkpoint-4-2bacd76.apk (SHA256 9ffae884acc300c150b83212e66124911182c006cd9c8f52d727c3d78dee2883) is excluded from delivery: its default build number 1 is below the installed testing baseline 2. Android rejected the test install without modifying data. Build commands now explicitly preserve `--build-number=2`; signing certificate remains unchanged. This is an in-place testing build, not a release/version promotion.
- Final verified APK: **piko-round-3-checkpoint-4-2bacd76-upgrade.apk**, source **2bacd76**, SHA256 **da3e0f0fb3903fab810bcb900dec0af10f184d1e59d1b3ad476bf93d30cbb680**. Application identity and signing certificate match previous checkpoints; versionCode remains 2. The final normal app was installed in place and launched without reported Android/Flutter exceptions.
- Isolated Android content acceptance: two tests passed including teardown. Verified real editor saves, new-entry-only Hint defaults, JSON v2 preview/confirmed apply, normal and Speed reveal behavior, exact existing learning preservation and drained file reopen. Original personal database and sentinel hashes matched before/after the synthetic fixture. No uninstall or data clear occurred.
- Seven 1080×2400, 420-dpi English normal-size PNGs inspected: Home, Collection Detail, optional-content editor, JSON preview, hidden-Hint review question, normal answer and Speed answer. Local index and original manifest retained. Entry/JSON captures are intentional scroll positions; Flutter surfaces omit OS keyboard/system UI. Earlier checkpoint galleries preserve direction settings and other changed workflows with their own source commits.
- All four planned feature checkpoints completed. No push, merge, tag, release or upload was performed.

### Spec traceability for the complete content package

| Spec / revision | Owner and dependency | Implementation / verification |
|---|---|---|
| VOCAB-004 r2 | Data + editor; schema 14 | 6ee3440, 8465239, d1fa5c4; content/migration tests and native fixture 2bacd76 |
| VOCAB-005 r2 | Data + editor; VOCAB-004 validation | Same atomic content package; pair/Unicode validation and native persisted bilingual pair |
| VOCAB-007 r2 | Data + editor; stored visibility | Per-entry radio choice, raw draft and round-trip tests |
| VOCAB-008 r2 | Data; settings repository | Initial Always default and populated upgrade/reopen tests |
| VOCAB-009 r2 | Editor + data; atomic default save | Explicit make-default and failure rollback tests; native editor |
| VOCAB-010 r2 | Data; frozen per-entry visibility | New-entry inheritance and exact existing-entry preservation tests/native checks |
| VOCAB-011 r2 | Learning UI; CARD-003 | 006d3e1; one-way question-scoped reveal/reset tests in both directions |
| CARD-003 r2 | Learning UI; content repository | 006d3e1; shared normal/Speed cards, focused widget tests and native captures |
| IMPORT-JSON-001 r2 | Data + coordinator UI; schema 14 | 4c3238e/f5190d0; v2 export and separate groups, 34 focused tests |
| IMPORT-JSON-002 r2 | Data; atomic confirmed apply | 4c3238e; v1/v2, stale default, omitted/null/groups, rollback and exact learning tests |
| IMPORT-HINT-001 r2 | Data; JSON v2 Hint group | 4c3238e; nullable text plus preserved/exported visibility |

## Delivery limits and next-round queue

No planned checkpoint is half-connected or omitted from the final APK. Retained scope exclusions are the simplified import template, multiple examples, manual Speed selection, trash, mixed-direction sessions and additional mascot poses. These remain Later/round-4 candidates, not implemented features or automatically approved next work.

Verification is scoped: the final content fixture uses synthetic JSON transport, not the OS picker/clipboard; those existing adapters were not rewritten. No claim of a physical-phone, every-locale, every-text-scale or exhaustive accessibility audit is made. The final visual set is deliberately one language and normal size. SDK XML-version skew emitted a non-fatal build warning; toolchain dependencies were not upgraded during feature work.

Resume from `codex/round-3-implementation`, using the latest documentation head and app source 2bacd76. Preserve the immutable final APK first; use `--build-number=2` for compatible local test upgrades, keep SDK/device commands serialized and run only affected tests for new review findings. Publishing requires the repository's separate content/history audit and owner approval.

### Reversible implementation decisions

- JSON v2 retains Hint visibility even with no Hint text by exporting an object with nullable text. Importing explicit null clears text without destroying a stored visibility choice.
- Unsupported stored direction values use the existing-installation Native → Target fallback; migration does not rewrite explicit saved values.
- Unavailable status projections render no invented New badge. Authoritative passive reads own due/retry boundaries; widgets format labels only.

### High-risk review

A short independent read-only review of checkpoint-4 storage found a schema-4 upgrade ordering defect: generated vocabulary reads expected optional columns before migration added them. The backfill now reads only the legacy ID column. Frozen schema-1–4 tests, including schema 4, pass. No other data-loss or concurrency defect was reported in that bounded review. The separate JSON review and preservation/rollback tests above complete the scoped high-risk checks, not a claim of exhaustive device coverage.


## Owner follow-up: Collection Detail scrolling — 2026-10-16

- Agreement: one bounded scrolling correction, balanced execution, sequential work without subagents, one APK checkpoint and one meaningful Android capture. No publication or unrelated feature work.
- Baseline: latest fetched develop 17677e3, fast-forwarded to current round-3 5107327 on focused local branch codex/collection-scroll. Verified fallback APK SHA256 da3e0f0fb3903fab810bcb900dec0af10f184d1e59d1b3ad476bf93d30cbb680 retained unchanged.
- UX-COLL-009 r2: lazy shared header/list viewport, nearby-row rendering with active-editor retention, Android clamping with a local 3000 logical-pixels/second fling cap. Slow direct dragging is unchanged.
- Baseline regression: 400 mounted rows and approximately 7436 logical pixels of fast-flick travel. Focused long-list/end-reachability, slow-drag/fling and invalid-draft cases now pass. The first affected batch passed 176 tests and exposed two failures: short-list Undo anchoring (fixed by measuring sliver content bounds), and a rename fixture missing a frame after ensureVisible. All 17 deletion/rename tests pass after repair, with the original assertions retained.
- Full host regression, analysis, Android acceptance and APK provenance are pending. Android verification will use a separate temporary application identity and synthetic storage because the installed normal app is not debuggable; its personal-data directory will not be opened or replaced.
- Host checkpoint: full suite 1143/1143 passed. A subsequent focused 20/20 run additionally verifies consecutive flings and nonempty invalid raw text/selection retention after scrolling offscreen; static analysis reports no issues. No storage schema or repository behavior changed.
