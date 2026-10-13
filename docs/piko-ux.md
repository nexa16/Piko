# Piko — UX Specification

**Version:** 0.4.2 · **Updated:** 2026-10-13

This file defines screens, content hierarchy, controls, layouts, interaction affordances and localization. Functional behavior is defined in [`piko-functional.md`](piko-functional.md); references in parentheses identify the related functional requirements.

## Learning Card — confirmed UX

- **UX-CARD-001:** On a Typed Answer question, focus the answer input and open the appropriate software keyboard automatically; keep the card, input and adjacent submit checkmark visible above the keyboard. Recenter/reflow when keyboard closes. (CARD-UI-009–011)
- **UX-CARD-002:** On a Self Assessment question, tapping anywhere on the card, including its text, reveals the answer; nested controls such as Hint do not flip it. A separate Show Answer action may also be present. (CARD-UI-006)
- **UX-CARD-003:** Show the vocabulary and example sentence(s) on the question side in the question language; on the answer side show the answer and example pairs in both languages. Do not show redundant Question/Answer labels or Category Tags. (CARD-UI-003–004, EXAMPLE-005)
- **UX-CARD-004:** Center the Hint within the card. Hidden Hints are revealed once per question and cannot be hidden again during that attempt. (CARD-UI-005, VOCAB-007–011)
- **UX-CARD-005:** Display a small, visually secondary icon and 'Tap to reveal' affordance near the bottom-right corner of a Self Assessment question card, visually distinct from the example sentence. (CARD-UI-007)
- **UX-CARD-006:** Show the Self/Type switch only on the question side. Switching answer mode during the session is supported. (CARD-UI-008, CARD-UI-018)
- **UX-CARD-007:** After Typed Answer submission, show the user's answer and expected answer when different; avoid duplicate identical text. The keyboard closes for grading. (CARD-UI-012–013, MATCH-001–004)
- **UX-CARD-008:** Place Incorrect on the left in red and Correct on the right in green. Their widths dynamically favor the automatically suggested grade; the user can always choose either. (CARD-UI-014, ANSWER-001–006)
- **UX-CARD-009:** Put a compact 'Hard' checkbox immediately above the Correct button, left-aligned to that button, moving with its dynamic width. Hard modifies only a Correct grade; it is not a third action button. (CARD-UI-015–016)
- **UX-CARD-010:** Distinguish app Back/Exit from Previous Review. Previous returns only to the immediately preceding card and exposes its prior grade for correction. (CARD-UI-019–020, UNDO-001)
- **UX-CARD-011:** Provide an explicit Skip action on the question side, at most once per Learning Item per session. Do not conflate Skip with swipe navigation. (CARD-UI-021)
- **UX-CARD-012:** Above the card show completed / total unique Learning Items and first-try-correct count; do not show the current item's mistake count as a clue. (CARD-UI-002, CARD-UI-024)
- **UX-CARD-013:** Keep grading actions reachable when long example content requires scrolling; all examples remain accessible. (EXAMPLE-005)

## Collection and Learning Setup — confirmed UX

- **UX-COLL-001:** Collection Overview lists Collections with context-specific Quick Learning Actions; Collection Detail includes learning actions, vocabulary list, search, filters, grouping, Detailed/Compact switch and add-entry action. (COLL-005–007)
- **UX-COLL-002:** Collection Detailed view shows both language entries stacked, optional examples and nonredundant category tags; Compact view shows language entries side-by-side with truncation. Display order defaults to Target first and is a per-Collection view preference.
- **UX-SETUP-001:** Learning Actions supply known collection, mode, direction, answer mode and selection parameters. Skip setup when required parameters are resolved from explicit action or preferences; otherwise show only missing choices. (SETUP-008–009)
- **UX-SETUP-002:** Speed pool size is under More Options, with default 5 and any positive integer allowed. (SPEED-001–003)
- **UX-STATS-001:** Show Long-term Daily Summary by default and Speed statistics separately; learning never spans Collections. (SESSION-017, SESSION-020, STATS-005–007)

## Entry Editor, categories and import review — confirmed UX

- **UX-ENTRY-001:** Manual entry uses a smooth scroll-driven Focused Card Stack; the centered card expands automatically and nearby cards collapse to previews. New Entries require Confirm & Next; already saved Entries auto-save edits. (ENTRY-001–010)
- **UX-CAT-001:** Show up to two Category Dimensions expanded by default, in user-configurable order; selected Values remain visible in collapsed headers. Allow multiple expanded dimensions, two rows of chips before Show more/search picker; avoid nested scrolling. (CAT-006–009; CAT-007–008 remain proposed)
- **UX-CAT-002:** Mark AI-preselected Values with a small sparkle icon, including in collapsed Dimension headers; no separate AI Assisted heading is required. Manual edits are never overwritten by delayed AI suggestions. (AI-001–006)
- **UX-IMPORT-001:** Every import uses Analyze/Extract → Review Differences → Adjust → Confirm → Apply. Show New, Additions, Unchanged and Conflict states. (IMPORT-028–030)
- **UX-IMPORT-002:** For single-value conflicts, retain the existing selected Value and show the imported alternative as a compact inline suggestion. Avoid separate conflict dialogs; explicit user edits may accept a replacement. (IMPORT-029–030)

## Localization

- **UX-I18N-002 [Confirmed]:** Maintain one shared editable catalog for UI naming and English/German translations, consumed by the mockup and the eventual application. The prototype supports live draft editing and export; the app adapter depends on the future platform.

- **UX-I18N-001:** Every visible string, including status labels, tooltips, controls and feedback, is localizable. English is default, German is supported initially. (I18N-001–002)


## Learning activity and streak — confirmed 2026-10-13

- **UX-STATS-002 [Confirmed]:** Label the Daily Average unambiguously as **“Average per active day”** (German: **“Durchschnitt pro aktivem Lerntag”**), not simply “Daily Average” if that could imply inclusion of days without learning. (STATS-005)
- **UX-STATS-003 [Confirmed]:** Show the current Long-term Learning Streak in consecutive learning days, where at least one regular Long-term review qualifies a day. Keep Speed statistics separate. (STATS-006–007, SESSION-020)
- **UX-STATS-004 [Confirmed]:** Daily activity history uses relative labels for recent days (Today, Yesterday) and dates for older days, with additional history expandable. This presentation does not change the active-day-only average. (STATS-005)

## Open UX decisions

- Exact mobile keyboard-safe-area and scrolling behavior; responsive layout breakpoints.
- The final layout and discoverability of Previous, Skip and Exit, including swipe gestures.
- Final wording and German translations for learning statuses.
- Whether very long example lists scroll inside the card or with the whole card while actions remain accessible.

## Change log

- **0.4.0:** Separated UX from functional rules, preserved cross-references and confirmed Learning Card composition.

- **0.4.1:** Confirmed Daily Average label and Long-term streak presentation.

## Minigame Break presentation

The first Minigame Break displays ten randomly arranged numbers to tap in ascending order. The under-ten-second target is not a hard countdown or a graded result. Additional minigames remain deferred. (SPEED-010–014)

## Collection Overview feedback — recorded, implementation deferred

The following five owner annotations were received on 2026-10-13. Preserve them for the next requested UX pass; the mockup has not been changed to implement them.

| ID | Annotation | Status |
| --- | --- | --- |
| UX-FEEDBACK-001 | Move the Today/activity summary above My collections. | Requested direction; implementation deferred |
| UX-FEEDBACK-002 | Reconsider the user-facing label Speed: it should communicate learning new vocabulary quickly. Keep Speed as the internal concept. | Wording open; implementation deferred |
| UX-FEEDBACK-003 | Reconsider the Your space / Collections / subtitle block and whether the home screen needs this heading. | Layout open; implementation deferred |
| UX-FEEDBACK-004 | Activity already links to Statistics; reconsider the duplicate Statistics navigation entry. | Navigation feedback; implementation deferred |
| UX-FEEDBACK-005 | Remove the mobile bottom navigation; put Settings at the top right and reach Statistics through Activity. | Requested direction; implementation deferred |

These annotations do not yet establish final wording, spacing, desktop navigation, or back-navigation behavior. Resolve those details with the owner when implementing the requested UX changes.

- **0.4.2:** Repaired functional cross-references, recorded Minigame Break presentation, and retained five deferred owner annotations.

## Design exploration

The proposed principles, palette and icon options, and unresolved visual choices are in [DESIGN.md](DESIGN.md). The [design studio](../mockups/design-lab.html) compares four color directions and edits catalog values live. None of the palette, typography, or icon candidates is selected yet. The five navigation annotations remain deferred until the next requested visual refinement.
