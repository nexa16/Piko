# Product brief

**Status: Discovery. Product definition is still being developed.**

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

- [Functional specification](piko-functional.md): behavior, data, validation, learning rules, and open functional decisions.
- [UX specification](piko-ux.md): screens, controls, interaction, and pending browser feedback.
- [Navigation mockup](../mockups/piko-mockup.html): existing mobile-first, English prototype using sample data.

The current product work is gradual UX refinement, beginning with Collection Overview. The prototype covers Collection Overview, Collection Detail, Learning, Entry Editor, Import Review, Statistics, Settings, and category management. Placeholder actions remain intentionally incomplete; there is no production persistence, AI, extraction, FSRS integration, or real statistics.

Requirement IDs remain stable. Confirmed requirements, proposals, and open questions are distinct. Newer explicit accepted decisions supersede older conflicting statements; superseded IDs remain documented for traceability. Functional behavior and UX presentation have separate specifications. The original handoff is retained locally and excluded from publication.

## Glossary

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
