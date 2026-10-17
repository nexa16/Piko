# Product brief

**Next-round priority, 2026-10-17:** All-page interaction anchoring under UX-ANCHOR-001 r1 is selected first, with high priority, for round 7. The [round-7 ledger](implementation-round-7.md) owns coverage and verification; affected Collection anchoring already authorized in round 6 remains in that scope. Broader execution is pending an explicit request.

**Documentation scope addition, 2026-10-17:** The owner selects DOC-001–007 r1 / UX-DOC-001/002 r1 and UX-LAB-001 r5 for round 6: current-app README/feature and technical documentation, authentic screenshot/build provenance, and preservation-first migration of planning/history to Git-ignored storage. Execution remains pending. The [round-6 ledger](implementation-round-6.md#documentation-rework-handoff--2026-10-17) records the existing specification source and migration boundaries.

**Current round-6 checkpoint, 2026-10-17:** Build 7 includes the vocabulary-list/help changes, transient vocabulary selection (VOCAB-SELECT-001 r1 / UX-COLL-013 r3) and affected Collection anchoring (UX-ANCHOR-001 r1 / UX-COLL-001 r7). Scoped English and narrow/enlarged German Android checks pass; full host regression plus focused repairs is recorded in the [round-6 ledger](implementation-round-6.md#checkpoint-handoff--2026-10-17). Owner review and exact-candidate phone acceptance remain pending. Statistics, the shrinking header and the documentation/planning migration are authorized but deferred from this checkpoint. No bulk vocabulary operation, learning from selection, full export or publication is included.

**Vocabulary selection, 2026-10-17:** VOCAB-SELECT-001 r1 / UX-COLL-013 r3 specify selection only, with the [owner-approved mockup](../mockups/piko-mockup.html?preview=collection-selection&lang=en). Select all includes search/filter matches and collapsed groups; hidden selections persist until explicit clear or page departure. No vocabulary operation or learning launch is included. SPEED-004 r4 keeps learning from selection Later. The approved revision-3 contract is locally implemented and scoped Android checks pass in build 7; the round-6 ledger owns evidence and remaining acceptance gates.


**Statistics readiness, 2026-10-17:** The owner resolved the production data decisions. STATS-005 r2, STATS-006 r1, STATS-007 r2, STATS-008–010 r1, DATA-005 r2 and UX-STATS-005–007 r1 define counting, fresh history, preservation, timezone/correction and loading/error behavior. The approved visual contract is retained. Statistics implementation is authorized but deferred from build 7; app/storage migration and Android/phone evidence remain pending. EXPORT-FULL-001 / UX-EXPORT-FULL-001 r1 define a separate, unscheduled full export of all Collections plus statistics; Collection-only export stays unchanged and import ignores statistics. No full import is selected.


**Round-6 scope, 2026-10-17:** The owner selected and authorized the approved UX-COLL-001 r6 vocabulary-list rework (F20/F21), the accepted LEARN-007 r2 / UX-LEARN-007 r1 FSRS learning-help icon and explanation, plus a bounded investigation of F22 and a focused fix if its cause is established. The owner also added the approved statistics design as a round-6 planning package; its production data contracts are now specified below; separate Flutter implementation authorization is pending. The first current-source host check retained optional-field focus; no matching Android cause was established. The owner subsequently could no longer reproduce F22 and requested its removal: it is withdrawn from active work, without a verified-fix claim. The [round-6 ledger](implementation-round-6.md#selected-scope-and-checkpoints--2026-10-17) owns checkpoints and exclusions; list/help implementation and scoped Android verification are complete for the local candidate; owner acceptance remains pending.

**Round-5 implementation, 2026-10-17:** Compact editors, same-answer editing in normal/retry/Speed, Active/Inactive vocabulary, Collection Hint defaults and schema-4 Activity interchange are locally implemented. Final host regression and scoped English Android checks pass; one build-4 APK is ready for owner review. Owner publication approval and the reported update/appearance check are complete. The owner squash-merged [PR #6](https://github.com/nexa16/Piko/pull/6) into develop at `1e3f520`; detailed phone-flow acceptance remains unverified. The [round-5 ledger](implementation-round-5.md#local-verification-and-candidate--2026-10-17) owns provenance, exact coverage and exclusions. Earlier dated planning entries below are historical.

**Round-4 delivery, 2026-10-16:** The authorized scope is implemented and locally verified: ordered multiple Example Pairs, JSON v3 export with v1/v2/v3 import, shared Import/Export navigation, Collection grouping/view/sort preferences, alphabetical category values, the prepared book launcher and shared dialog/palette corrections. The scrolling correction is retained. The header report was investigated but remains unreproduced; no header fix is claimed. [The final round-4 ledger](implementation-round-4.md#final-verification-and-owner-handoff) owns the candidate, requirement revisions, test/device evidence and limitations. Owner manual review, publication approval and phone acceptance are complete; [PR #5](https://github.com/nexa16/Piko/pull/5) was squash-merged into `develop` at `6541e25`. This is not a product release.

**Round-5 Hint refinement, 2026-10-17:** The compact-editor package now includes a Collection-scoped Hint default, initially off for existing and new Collections, and an optional first-ON offer shown once per Collection. Existing words retain their settings. The further editor refinement places Active last, collapses Categories to selected values, moves Delete into the card menu and uses autosave/collapse without saved-card Finish/Discard. VOCAB-008–010 r3 / UX-COLL-011 r4 and the [round-5 ledger](implementation-round-5.md) own the accepted behavior and current implementation evidence.

**Round-5 planning, 2026-10-16:** The owner selected compact vocabulary editing, editing within revealed normal/Speed answer cards, and Active/Inactive vocabulary. This supersedes their earlier Later/Undecided scheduling below, without authorizing implementation or resolving open session/compatibility rules. The owner also requested an overview of learning-related specifications to consider expanding the batch; no further package is selected yet. [The round-5 ledger](implementation-round-5.md) owns the plan and grouped backlog. Round 4 has a locally verified candidate with owner/publication/phone acceptance complete; [its final ledger](implementation-round-4.md#final-verification-and-owner-handoff) is the current evidence source. Earlier dated entries below retain historical context.

**Historical answer-card editing addition, 2026-10-16:** The general specification includes editing the current revealed vocabulary directly in its answer card in both normal and Speed Learning. The owner explicitly assigns this to Later, outside round 4; no implementation round is scheduled. A small secondary icon opens the same vocabulary-list editor; Finish/Discard returns to that answer without grading, advancement or learning reset. VOCAB-EDIT-003 r1 / UX-CARD-014 r1 own the accepted behavior, remaining interaction details and pending implementation/Android verification.

**Historical round-4 planning selection, 2026-10-16:** Shared popup corrections; the approved book launcher and remaining palette cleanup; simplified JSON template and the new add-method/shared Import/Export flow; category grouping with Compact/Detailed modes, language display order and per-Collection preferences; fixed initially collapsed vocabulary groups with Collapse all / Expand all beside Filters; alphabetical category values; target/native text and added-date vocabulary sorting (record dates for new words; older missing dates stay unknown); multiple Example Pairs; a global option to hide question-side examples; and the reported disappearing-header transition fix are selected for round-4 planning. The owner subsequently deferred proficiency levels entirely: New / Retry pending / Due now / Next review remain readiness information, not knowledge grades. Mastered and manual Speed selection also remain outside round 4. The subsequently requested independent Active/Inactive boolean is specified separately under VOCAB-ACTIVE-001, with exclusion from normal and Speed learning in both directions confirmed; current-session details and round assignment remain open. This records the earlier planning snapshot; the delivery statement above and final ledger supersede its implementation status. See [the round-4 ledger](implementation-round-4.md#selected-planning-scope--2026-10-16) for exact scope, revisions and open decisions.

**Historical round-4 initialization, 2026-10-16:** The owner requested retention of the already completed Collection Detail scrolling change on a round-4 branch. Owner phone testing is deferred until more work has been implemented. No additional round-4 feature implementation is authorized by this request; see [the round-4 ledger](implementation-round-4.md).

**Execution update, 2026-10-16:** The owner authorized round-2 production implementation on 2026-10-15 under [the execution ledger](implementation-round-2.md), with accepted UX refinements integrated at batch boundaries. Older overall mockup-approval gates below are superseded. Reading-mascot placement is approved, integrated and host/device-verified in the recorded states. No publication is authorized.

**Historical round-3 status: Checkpoints 1–4 were implemented and verified for owner testing. The [round-3 ledger](implementation-round-3.md) records the final APK, host regression repairs, scoped Android evidence and verification limits. Not a published product release.**

The owner has authorized local-first Flutter implementation with Android verification. FOUNDATION-001 establishes the application host under `app/`; the requirement alone does not claim any product behavior is complete. See [implementation foundations](implementation-foundation.md). Earlier discovery descriptions below retain planning context and are superseded by newer accepted decisions where applicable.

| Area | Current answer | Question to answer |
| --- | --- | --- |
| User Problem | Existing planning concerns vocabulary organization and learning; the validated user problem is To be decided. | Which specific learner problem should the first version solve? |
| Target Users | To be decided | Who is the first target user and in what context? |
| User Story | To be decided | As which user, do I want what capability, and why? |
| Desired Outcome | To be decided | What is the smallest useful outcome for that user? |
| Core User Flow | Existing navigation prototype covers collections, vocabulary, learning, entry, import review, statistics, and settings; the smallest validated flow is To be decided. | Which part of that flow delivers the first useful outcome? |
| Assumptions | To be decided | Which beliefs need evidence before implementation? |
| Open Questions | To be decided | Which unanswered decisions materially affect scope? |
| Initial Scope | To be decided | What must be included to deliver the first useful outcome? |
| Out of Scope | To be decided | Which product capabilities are deliberately excluded? |
| Success Signals | To be decided | What observable evidence would show that the outcome helps? |
| Risks and Constraints | To be decided | What privacy, data, accessibility, cost, or other constraints apply? |

Accepted choices belong in [DECISIONS.md](DECISIONS.md). Planning sequence belongs in [ROADMAP.md](ROADMAP.md). Research evidence belongs in [RESEARCH.md](RESEARCH.md) only after anonymization.

## Specifications and current phase

The current [round-4 candidate](implementation-round-4.md#final-verification-and-owner-handoff) includes the verified scope summarized above and retains the completed [round-3 checkpoints](implementation-round-3.md) and scrolling correction. Owner review and phone acceptance are complete; additional feature implementation requires explicit authorization. Local APK checkpoints, precise verification evidence and explicitly deferred work determine delivery; an implementation round is not a published version. The following round-1 scope remains historical context.

The owner has authorized implementation round 1: collections, focused manual entry, inline vocabulary editing, deletion with Undo, single-direction self-assessment with FSRS and reinforcement retries, previous-grade correction, a summary popup, and English/German language settings. The [implementation ledger](implementation-round-1.md) records dependency order and verification evidence. Earlier discovery questions and incomplete planning tags do not override that accepted scope. The prototype itself remains illustrative and does not establish production persistence or scheduling.

- [Functional specification](piko-functional.md): behavior, data, validation, learning rules, and open functional decisions.
- [UX specification](piko-ux.md): screens, controls, interaction, and pending browser feedback.
- [Navigation mockup](../mockups/piko-mockup.html): existing mobile-first, English prototype using sample data.

Implementation round 2 includes reported UX/Android fixes, JSON import/export preserving learning, rotating-pool Speed Learning for filtered new words, categories and search. Those accepted features are implemented; their verification and remaining gates are recorded in the [round-2 ledger](implementation-round-2.md). Manual vocabulary selection and Speed launch from that selection remain explicitly Later. Priorities and dependency order are in the roadmap. The owner authorized production implementation while accepted UX refinements continue at batch boundaries. Legacy expanded previews do not expand accepted scope. The round-1 ledger remains its historical evidence; changing the mockup alone does not establish fixes in the Android APK.

The 2026-10-15 mascot decision added source frame 1 as the initial launcher and reading Piko on Collection Detail when normal review is available (frame 3). The accepted 2026-10-16 plain-book choice supersedes only the launcher under UX-BRAND-001 revision 3. Its prepared resources are integrated, with host geometry checks and installed Android circular-mask inspection recorded in the round-4 ledger; owner phone acceptance is complete. The sleeping (5), new-Speed-vocabulary (6), session-completion excited (2) and homepage-statistics star (4) poses are specified for Later. Collection Detail displays at most one contextual Piko; when the later states are enabled, new Speed vocabulary takes priority over normal review. See MASCOT-001–004 in the functional specification and UX-BRAND-001 / UX-MASCOT-001–004 in the UX specification. Earlier frame-1 launcher evidence is historical; the round-4 ledger owns the current plain-book evidence and its device limits. On 2026-10-16, the owner approved one reading Piko inside the first visible positive normal-review card, to the right of its left-aligned text and before its trailing review icon, at 64px square with an 8px gap. If only the reverse direction is available, that card receives it. This placement is integrated and covered by host tests and reviewed Android captures; the manually corrected source artwork is preserved. Homepage statistics are not added to round 2 by this decision.

Category Values use an accepted alphabetical display default within each group (CAT-009 revision 5 / UX-CAT-001 revision 7); manual moving into a custom value order is deferred to Later. The alphabetical default is implemented, with host and scoped Android evidence in the round-4 ledger.

The [UX quality workflow](ux-quality.md), [accepted criteria](ux-consolidation-proposals.md) and [findings register](ux-findings.json) preserve the accepted preparation package. The register retains historical observations and maps related round-3 checkpoints without claiming all findings fixed. The [historical mockup ledger](implementation-round-3-mockup.md) remains distinct from current application evidence.

The approved Piko UI palette is the common target for every preview round and the application. Older previews retain their feature/sample-state differences, not historical colors (UX-SYSTEM-001 revision 7; UX-LAB-001 revision 4). The subsequently authorized round-4 migration is implemented and verified through catalog checks, browser palette inspection and scoped Android evidence. Non-color prototype features remain outside this migration. This does not change functional scope or authorize a release.

Requirement IDs remain stable. Confirmed requirements, proposals, and open questions are distinct. Newer explicit accepted decisions supersede older conflicting statements; superseded IDs remain documented for traceability. Functional behavior and UX presentation have separate specifications. The original handoff is retained locally and excluded from publication.

Implementation rounds are internal planning scopes, not software releases. Development is integrated through thematic feature PRs, each squash-merged into `develop` with spec/revision traceability. Neither round currently authorizes store publication or a promotion to `main`. Only a later explicit release-preparation request creates a release branch from accepted `develop` and assigns a publication version. Existing test APKs do not establish a published product release.

The accepted visible Minimum flow is create/open a collection → manually enter vocabulary → Long-term self-assessment review, with basic settings. Relevant requirement texts carry Flow tags (collection, entry, review, settings). Scope labels remain an independent proposal. The [requirements view](../mockups/requirements.html) reads both original specifications at runtime and filters those tags without maintaining duplicate lists. Use its reload action after editing a source file; bookmarked filters are preserved. UX requirements without scope labels remain explicitly unclassified.

## Glossary

Piko's in-app character is purely decorative: its pose follows the specified context, but it has no interaction or learning function. Existing controls and text remain complete without it.

| Term | Definition |
|---|---|
| Collection | Named vocabulary collection with a pair of languages and independent categorization configuration. |
| Vocabulary Entry | A distinct meaning represented by an entry in each of two languages, with optional examples, hint, and category assignments. |
| Native Language | Language the learner already knows. |
| Target Language | Language the learner is studying. |
| Display Order | Which of the two languages appears first in the Collection vocabulary view. |
| Category Dimension | Independent categorization axis, e.g. Topic, Unit, Difficulty. |
| Category Value | Value belonging to a dimension, e.g. Food under Topic. |
| Tag | Visible representation of an assigned Category Value. |
| Filter | Restriction of visible entries using selected Category Values. |
| Grouping | Display of entries in expandable groups based on a Category Dimension. |
| Entry Session | Continuous manual vocabulary entry workflow using a focused, scroll-driven card stack. |
| Example Pair | Example sentence in both languages. |
| Hint | Optional contextual clue on an entry, distinct from Category Values. |
| Carry-over | Preselection of values from the previously confirmed entry for configured dimensions. |
| AI Bulk Categorization | User-initiated AI analysis and proposed updates to category assignments across existing entries. |

## Planning history

- **0.4.0 — 2026-10-13:** Functional and UX specifications separated; earlier requirements retained for traceability.
- **0.4.1 — 2026-10-13:** Active-day-only average and Long-term streak threshold confirmed.
- **Repository consolidation — 2026-10-13:** Specification index merged into this brief; later minigame and data-minimization decisions moved into the functional specification.
