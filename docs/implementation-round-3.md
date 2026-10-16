# Round 3 implementation ledger

Owner approved incremental implementation on 2026-10-16. Base: develop 17677e3 (same tree as accepted round-2 b6b840c). No publication or promotion authorized.

## Checkpoints and usage

Reserve 20% account allowance for verification/fixes/APK/handoff. Check before each batch, after integration and before enlarging assignments. Do not start a batch if its conservative estimated usage plus reserve exceeds remaining allowance. If usage becomes unavailable, finish the current small batch and hand off. Keep every verified APK immutable locally. Incomplete specs move explicitly to round 4, never to implemented.

| Checkpoint | Scope | Status |
|---|---|---|
| 0 | Verified round-2 fallback, signing/upgrade path | Existing APK checksum verified; develop tree matches baseline |
| 1 | SPEED-007/010 r3; UX-SYSTEM-001 foundation; Speed setup/completion; review presentation | Focused host and isolated Android acceptance passed; immutable APK preserved |
| 2 | JSON presentation, entry/dialog usability, Collection/filter clarity | Focused host tests and analysis passed; Android checkpoint pending |
| 3 | PREF-005, LEARN-005 / UX-LEARN-005 | Pending |
| 4 | One example pair and Hint, persistence/editor/cards/JSON v2 | Pending |

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
- Remaining allowance after this checkpoint: 68%; reserve unchanged at 20%.
