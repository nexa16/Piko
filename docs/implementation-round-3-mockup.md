# Implementation round 3 — historical mockup progress

Recovery boundary, 2026-10-16: this ledger and the complete prototype source/dependencies are preserved in the private recovery snapshot of codex/release-2-spec-mockup at base 862a96b. The source was not transplanted over the newer application catalogs. The current implementation is recorded in implementation-round-3.md; browser results below are historical evidence, not current APK acceptance.

The owner authorized parallel prototype work on 2026-10-16. This is a sample-data design preview, not application implementation, a release or persistence verification.

Follow the accepted [UX package criteria](ux-consolidation-proposals.md). Canonical behavior and presentation remain in [functional specifications](piko-functional.md) and [UX specifications](piko-ux.md).

| Package | Prototype scope |
| --- | --- |
| Foundation | Accepted palette, licensed offline Nunito Sans / Noto Sans KR, type roles, control sizing, shared copy |
| Entry/dialogs | Visible Save & Next / Finish, stable changed-only selection footer |
| JSON | Separate Import/Export, ordered input/check/confirmation, compact expandable input, pending/success feedback and Collection return |
| Collections | Compact spacing, aligned Speed actions, empty state, filter count/clear, preferred-direction Detail filtering |
| Review | Grouped progress and correction context |
| Speed | Rules/exit explanation, conditional reset warning, unseen replacement before minigame, dismissible completion notice |

Round 1/2 comparisons keep separate sample-state snapshots. Preferred direction is prototype-only session state; Overview remains unaffected.

Open at this prototype checkpoint, subsequently resolved for the app: examples/Hint editing and interchange, learning-status mapping and existing-installation preference migration. See the current functional specification and round-3 implementation ledger; the preserved prototype does not demonstrate those later features. No new status thresholds, percentages or additional functionality are assumed. Simplified import template remains deferred.

Verification is browser-only. The prototype ledger alone supplies no Android acceptance; later application evidence lives in the implementation ledger.

Final focused result: 77/77 tests pass, including six round-3 regressions for unseen Speed replacements, complete short-pool passes, round-2 isolation, N=1/no final game, conditional warning and distinct filter-value counts.

Browser checks passed for round switching, loaded assets/fonts, preferred-direction Detail actions with unchanged Overview counts, gold Speed actions, new-word setup without warning, JSON view switching/compact input/pending confirmation/success/Collection return and the true-empty Collection state. Phone-size English layouts were inspected for Collection, Speed setup, JSON and entry. The existing five focused mockup suites pass 71 tests after adapting their browser-event stubs.
