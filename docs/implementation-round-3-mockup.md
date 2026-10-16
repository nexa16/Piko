# Implementation round 3 — historical mockup progress

Recovery boundary, 2026-10-16: this ledger and the complete prototype source/dependencies are preserved in the private recovery snapshot of codex/release-2-spec-mockup at base 862a96b. The source was not transplanted over the newer application catalogs. The current implementation is recorded in implementation-round-3.md; browser results below are historical evidence, not current APK acceptance.

The owner authorized parallel prototype work on 2026-10-16. This is a sample-data design preview, not application implementation, a release or persistence verification.

Follow the accepted [UX package criteria](ux-consolidation-proposals.md). Canonical behavior and presentation remain in [functional specifications](piko-functional.md) and [UX specifications](piko-ux.md).

| Package | Prototype scope |
| --- | --- |
| Foundation | Accepted palette, licensed offline Nunito Sans / Noto Sans KR, type roles, control sizing, shared copy |
| Entry/dialogs | Visible Save & Next / Finish; historical changed-only selection footer. Revised persistent visible/disabled actions and shared X alignment are accepted, implementation pending |
| JSON | Separate Import/Export, ordered input/check/confirmation, compact expandable input, pending/success feedback and Collection return |
| Collections | Compact spacing, aligned Speed actions, empty state, filter count/clear, preferred-direction Detail filtering |
| Review | Grouped progress and correction context |
| Speed | Rules/exit explanation, conditional reset warning, unseen replacement before minigame, dismissible completion notice |

Round 1/2 comparisons keep separate sample-state snapshots. Preferred direction is prototype-only session state; Overview remains unaffected.

Open at this prototype checkpoint, subsequently resolved for the app: examples/Hint editing and interchange, learning-status mapping and existing-installation preference migration. See the current functional specification and round-3 implementation ledger; the preserved prototype does not demonstrate those later features. No new status thresholds, percentages or additional functionality are assumed. Simplified import template remains deferred.

Verification is browser-only. The prototype ledger alone supplies no Android acceptance; later application evidence lives in the implementation ledger.

Final focused result: 77/77 tests pass, including six round-3 regressions for unseen Speed replacements, complete short-pool passes, round-2 isolation, N=1/no final game, conditional warning and distinct filter-value counts.

Browser checks passed for round switching, loaded assets/fonts, preferred-direction Detail actions with unchanged Overview counts, gold Speed actions, new-word setup without warning, JSON view switching/compact input/pending confirmation/success/Collection return and the true-empty Collection state. Phone-size English layouts were inspected for Collection, Speed setup, JSON and entry. The existing five focused mockup suites pass 71 tests after adapting their browser-event stubs.

## Popup follow-up — 2026-10-16

The owner selected persistent visible/disabled selection actions after reporting blank space and movement of Clear filters when Apply appears. UX-DIALOG-001 r5 (Fix 3), UX-CAT-001 r6, CAT-009 r4 and FILTER-002 r5 supersede the hidden-action footer target. The reported shared X alignment issue remains a fix against the existing header rule. Specifications, design guidance and F03/studio reference are reconciled; mockup and application changes await a separate implementation request.

The focused English round-3 browser check observed a 64px hidden-action slot and unchanged 351px popup height before/after selecting Food from an initially unfiltered Topic group; it did not reproduce the reported clear-action movement. No Android verification was performed. The previous 77/77 result and browser checks remain historical and do not verify the revised requirements.

Specification verification: all six requirements-parser checks pass; all 300 requirement IDs remain unique, and the four changed records retain their original rounds and appear in the round-3 filter with the intended revisions. The studio reference renders the updated F03 decision. These checks verify documentation, not the pending popup behavior.

Further accepted approach, 2026-10-16: simplify the shared popup around standard dialog layout, a real persistent action group and the existing Piko theme/dismissal contract. DESIGN.md and UX-DIALOG-001 revision 5 record the approach; F03/studio reference is aligned. The app checkout is now on its retained round-4 branch, so a later authorized implementation must reconcile only these accepted popup deltas into that newer baseline. No implementation or APK verification is established by this documentation update.

## Palette migration follow-up — 2026-10-16

The owner accepted using only the approved Piko palette in every preview round and explicitly requested specification updates only. UX-SYSTEM-001 revision 7 and UX-LAB-001 revision 4 supersede historical-color preservation while retaining round behavior and separate sample state. DESIGN.md records the consumer mapping; F05 and the existing studio reference are aligned. Grading/swipe foreground wording is editorially reconciled with the already accepted cream foreground from UX-SYSTEM-001 revision 6; their action behavior and revisions are unchanged.

Read-only source inspection found the accepted studio palette, Cobalt base palette, legacy round-2 color overrides and independent green backdrop with active preview/application consumers. This establishes dependencies, not new runtime reproduction. Canonical source consolidation, removal of obsolete values, consumer/adapter migration, rendered preview checks and Android verification remain pending. No application, mockup, shared configuration or generated code is changed by this specification pass. Existing 77/77 prototype evidence and prior screenshots remain evidence for earlier revisions only.

Specification checks: all six requirements-parser tests pass; all 300 IDs remain unique and unchanged. UX-SYSTEM-001 r7 retains Round 1 and UX-LAB-001 r4 retains Round 2; both remain Updated 3 and visible in the round-3 filter with pending implementation status. Full migration acceptance text survives parsing and local document links resolve. These checks verify the documentation only.

## Alphabetical category values follow-up — 2026-10-16

The owner accepted alphabetical display of values within each category group and deferred manual moving/custom order. CAT-009 r5 and UX-CAT-001 r7 retain Round 2 / Updated 3; group and vocabulary order stay unchanged. The functional acceptance cases cover selection, search, create, rename and import without changing identity, assignments or learning. Collation edge cases remain open. DESIGN.md, the existing F07/studio reference, product and roadmap summaries are aligned.

Focused evidence: Node v22.15.0 executed the unchanged mockup assignment and expanded-management renderers with synthetic stored values Zebra, apple, Banana and Banana selected. Both returned stored order on two runs. Filters and tag source inspection shows the same array-order dependency; no browser/Android reproduction or owner build was established. The revised alphabetical target remains pending.

This is specification work only. App/mockup implementation and Android verification require a separate request; when authorized, reconcile these deltas into the retained newer application baseline rather than treating this older prototype checkout as current app evidence. Earlier category and popup tests remain historical and do not verify these revisions.

Specification verification: all six requirements-parser tests pass; all 300 requirement IDs remain unique. CAT-009 r5 and UX-CAT-001 r7 retain their original round and Updated 3, and both full records, including acceptance/evidence paragraphs, appear in the round-2 and round-3 filters. The existing studio reference still reads the updated criteria source. Whitespace checks pass. These are documentation checks, not proof that alphabetical sorting is implemented.
