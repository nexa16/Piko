# UX implementation packages and acceptance gates

Reconciliation status, 2026-10-16: this preserves the accepted preparation criteria. Round-3 checkpoints 1–4 now record related implementation and scoped verification in [implementation-round-3.md](implementation-round-3.md). F01–F18 retain their recorded specified status until their complete acceptance criteria receive finding-specific evidence; historical preparation statements are not claims that the current app is unimplemented. New implementation is not authorized by this record.

Design handoff accepted on 2026-10-16. This order records the accepted package dependencies; it schedules no additional feature, release, API or schema change. Findings are specified, none Fixed. Original review observations refer to the recorded review build; later implementation and scoped verification are tracked separately in the round-3 ledger and each finding's reconciliation record.

## 1. Shared visual and wording foundation

F05/F06/F14/F16, shared parts of F04/F07, and early F17/F18 catalog work. Integrate accepted design/copy values into the canonical configuration and catalog, bundle licensed fonts/fallbacks, update adapters/generated catalogs and the canonical mockup together. Explicitly map Flutter theme roles; remove inherited field bold text, introduce shared type roles, essential field boundaries, header reflow and common leading edges. Update the studio's factual accepted-rule summary. Do not merely replace a font-family string or seed color and assume all consumers comply.

Gate: catalog generation and placeholder checks pass; representative German/Korean/digit glyphs work offline; inspect affected global consumers in English normal size plus targeted German/320/200% and native keyboard entry. Include page/header, field, card, dialog, learning card and feedback consumers. Approved colors and legibility must hold for normal, focus, pressed, disabled, error and success states. No unrelated flow behavior changes.

## 2. Stable shared dialogs and clear entry actions

F03 and F01, after package 1. Follow UX-DIALOG-001 revision 5: keep Apply and applicable Clear filters visible with their defined disabled states, in a compact real footer with stable geometry. Preserve focus/dismissal and pending drafts. Make Save & Next / Finish visible, grow or stack the header, clarify inline finish/discard and keep save status nearby.

Gate: unchanged → changed → cleared → reverted selections change only action enabled states without moving the selected row/title or existing buttons; keyboard, large text and short-height actions remain reachable. Existing draft, save-next, finish validation, autosave and exit-warning behavior passes relevant tests and a named Android sequence.

## 3. JSON workflow clarity

F02, after package 1; can proceed independently of package 2. Follow the latest accepted separate Import/Export flow, primary Check/Import steps, retained expandable input and adjacent feedback. Keep atomic writes, stale-preview invalidation and pending guards. Do not automatically pull IMPORT-JSON-003 or unrelated future features into this package.

Gate: invalid input, valid preview, changed input after preview, confirmed import success/failure and export/system destination are checked. Existing data/learning is preserved; success is never inferred from merely issuing a write. Record native clipboard/file-interface limitations explicitly.

## 4. Collection and categories

Remaining F04/F07 plus F10/F11/F18; after package 1 and package 2's shared selection shell. Complete aligned category levels, genuine-empty CTA, active confirmed-filter count and independent clear action. Follow CAT-009 revision 5 / UX-CAT-001 revision 7 for alphabetical values within each group while retaining group order, membership and drafts; clarify the recorded collation edge cases before implementation. Apply the accepted glossary across success, error and deletion contexts.

Gate: genuine empty versus loading/error/filtered-empty/no-due remain distinct. Filters count selected values only; direct toolbar clear preserves search, popup clear is staged until Apply, and cancellation restores the opening selection. Test assignment/cardinality and category changes without learning-data loss. Existing rename and menu access remain present.

## 5. Normal review clarity

F08/F09 and remaining F17; after package 1. Group direction/progress deliberately, distinguish correction from destructive actions and use accurate completion/first-try wording. Do not change counters, grading, Hard, retry waiting or correction history.

Gate: question/reveal, Hard, previous-grade correction, wrapping progress, retry waiting and immutable summary counts pass relevant tests and Android inspection. Verify text and labels with representative long Collection names.

## 6. Speed setup and completion

F12/F15/F13; after package 1 and the Collection target state in package 4. Separate rules/leaving explanation, apply the red warning only under the newest accepted existing-progress condition, and show the accepted inline completion message/X only after every completion result is committed. Preserve the pool, full-pass minigame and completed-word persistence rules.

Gate: new-only/no-warning, existing-progress warning, valid/invalid pool, short-pool game, exit and successful completion are checked. Verify no success notice on exit or failed write, no timer, no extra mascot, and the specified notice lifetime. Opposite-direction progress stays unchanged.

## Shared closure criteria

Each package records implementation revision, requirement revisions, relevant checks, locale/size/scale, exact Android states, evidence references and remaining limitations in the findings register. Only then move applicable findings through needs_verification to fixed. Partial component work does not close a finding across unverified consumers. Regressions reopen the same ID.

Per-change reviews cover changed states and immediate neighbors. Round-end review adds six anchors: Collection Detail, entry with keyboard, selection dialog, JSON preview, revealed learning card and Speed setup. Expand consumer coverage for global changes; reuse unchanged evidence with its original revision. Preserve normal app data and prioritize implementation's emulator access. No automatic exhaustive capture matrix or extra lifecycle service is required.

New features may join only with separately agreed scope and the components/copy/states/long-text/keyboard acceptance contract in ux-quality.md. Relevant open findings travel with that feature; important existing clarity fixes do not wait indefinitely for new features.
