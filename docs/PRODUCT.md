# Product brief

**Round-4 planning selection, 2026-10-16:** Shared popup corrections, the approved book launcher with remaining palette cleanup, the simplified JSON import example/template, and category-based vocabulary grouping with Compact/Detailed modes, language display order and per-Collection persistence are selected for planning (GROUP-001–003, COLL-004–006, COLL-009–011). The owner is gathering more items before implementation. Manual Speed selection remains deferred pending reconsideration of its learning-state reset consequence; no replacement learning rule is accepted. See [the round-4 ledger](implementation-round-4.md#selected-planning-scope--2026-10-16).

**Round-4 initialization, 2026-10-16:** The owner requested retention of the already completed Collection Detail scrolling change on a round-4 branch. Owner phone testing is deferred until more work has been implemented. No additional round-4 feature implementation is authorized by this request; see [the round-4 ledger](implementation-round-4.md).

**Execution update, 2026-10-16:** The owner authorized round-2 production implementation on 2026-10-15 under [the execution ledger](implementation-round-2.md), with accepted UX refinements integrated at batch boundaries. Older overall mockup-approval gates below are superseded. Reading-mascot placement is approved, integrated and host/device-verified in the recorded states. No publication is authorized.

**Status: Round-3 checkpoints 1–4 are implemented and verified for owner testing. The [round-3 ledger](implementation-round-3.md) records the final APK, host regression repairs, scoped Android evidence and verification limits. Not a published product release.**

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

The current [round-4 branch](implementation-round-4.md) retains completed [round-3 checkpoints](implementation-round-3.md) and the Collection Detail scrolling correction. Owner phone testing is deferred; additional feature implementation requires explicit authorization. Local APK checkpoints, precise verification evidence and explicitly deferred work determine delivery; an implementation round is not a published version. The following round-1 scope remains historical context.

The owner has authorized implementation round 1: collections, focused manual entry, inline vocabulary editing, deletion with Undo, single-direction self-assessment with FSRS and reinforcement retries, previous-grade correction, a summary popup, and English/German language settings. The [implementation ledger](implementation-round-1.md) records dependency order and verification evidence. Earlier discovery questions and incomplete planning tags do not override that accepted scope. The prototype itself remains illustrative and does not establish production persistence or scheduling.

- [Functional specification](piko-functional.md): behavior, data, validation, learning rules, and open functional decisions.
- [UX specification](piko-ux.md): screens, controls, interaction, and pending browser feedback.
- [Navigation mockup](../mockups/piko-mockup.html): existing mobile-first, English prototype using sample data.

Implementation round 2 includes reported UX/Android fixes, JSON import/export preserving learning, rotating-pool Speed Learning for filtered new words, categories and search. Those accepted features are implemented; their verification and remaining gates are recorded in the [round-2 ledger](implementation-round-2.md). Manual vocabulary selection and Speed launch from that selection remain explicitly Later. Priorities and dependency order are in the roadmap. The owner authorized production implementation while accepted UX refinements continue at batch boundaries. Legacy expanded previews do not expand accepted scope. The round-1 ledger remains its historical evidence; changing the mockup alone does not establish fixes in the Android APK.

The 2026-10-15 mascot decision added source frame 1 as the initial launcher and reading Piko on Collection Detail when normal review is available (frame 3). The accepted 2026-10-16 plain-book choice supersedes only the launcher under UX-BRAND-001 revision 3. Its Android resource package is prepared; app integration and installed-device verification remain pending. The sleeping (5), new-Speed-vocabulary (6), session-completion excited (2) and homepage-statistics star (4) poses are specified for Later. Collection Detail displays at most one contextual Piko; when the later states are enabled, new Speed vocabulary takes priority over normal review. See MASCOT-001–004 in the functional specification and UX-BRAND-001 / UX-MASCOT-001–004 in the UX specification. Existing launcher integration and visual evidence cover the earlier frame-1 icon, not the newer plain-book revision. On 2026-10-16, the owner approved one reading Piko inside the first visible positive normal-review card, to the right of its left-aligned text and before its trailing review icon, at 64px square with an 8px gap. If only the reverse direction is available, that card receives it. This placement is integrated and covered by host tests and reviewed Android captures; the manually corrected source artwork is preserved. Homepage statistics are not added to round 2 by this decision.

Category Values use an accepted alphabetical display default within each group (CAT-009 revision 5 / UX-CAT-001 revision 7); manual moving into a custom value order is deferred to Later. This sorting follow-up is specification-only, with implementation and verification pending.

The [UX quality workflow](ux-quality.md), [accepted criteria](ux-consolidation-proposals.md) and [findings register](ux-findings.json) preserve the accepted preparation package. The register retains historical observations and maps related round-3 checkpoints without claiming all findings fixed. The [historical mockup ledger](implementation-round-3-mockup.md) remains distinct from current application evidence.

The approved Piko UI palette is the common target for every preview round and the application. Older previews retain their feature/sample-state differences, not historical colors (UX-SYSTEM-001 revision 7; UX-LAB-001 revision 4). The owner requested specifications only for this migration; code and visual/Android verification remain pending. This does not change functional scope or authorize a release.

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
