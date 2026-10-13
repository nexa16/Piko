# Piko — UX Specification

**Version:** 0.4.2 · **Updated:** 2026-10-13

This file defines screens, content hierarchy, controls, layouts, interaction affordances and localization. Functional behavior is defined in [`piko-functional.md`](piko-functional.md); references in parentheses identify the related functional requirements.

Inline `[Flow: collection]`, `[Flow: entry]`, `[Flow: review]`, and `[Flow: settings]` tags associate UX requirements with Collection creation/opening, manual entry, self-assessment review, and basic settings. A comma-separated tag denotes several associations. Flow is a topic filter, not a scope or acceptance label: optional features such as typed answers, import, AI, and statistics stay optional under the functional Scope classification. Mixed UX requirements remain intact; showing their basic portion does not claim the whole requirement is implemented.

## Learning Card — confirmed UX

- **UX-DIALOG-001 [Confirmed]:** [Release: First] [Flow: collection, entry, review, settings] All popups share a title row with a localized close X at top-right and consistent safe Escape/backdrop dismissal with focus restoration. Remove redundant bottom Cancel/Close actions, including Collection creation and deletion; retain the positive Create/Delete/Start action. Closing never creates, deletes, starts review, saves or discards a draft. Draft-exit dialogs retain meaningful Continue Editing and Discard & Exit choices; X/Escape/backdrop means continue editing without data loss. Inline edit cancellation is separate from popup dismissal.

- **UX-REVIEW-004 [Confirmed]:** [Release: First] [Flow: review] Present the session summary as a modal popup, not a separate page: two prominent readable numbers for vocabulary learned and first-try correct, with labels allowed to wrap naturally. Include a short friendly motivational message below the title and above the metrics, without exaggerated performance claims; its wording is editable through shared English/German copy. Use a normal localized close X, Escape and backdrop dismissal; return focus to the underlying Collection. Do not add a Back to Collection CTA. Keep any prototype sample-data note secondary.

- **UX-REVIEW-003 [Confirmed]:** [Release: First] [Flow: review] Show the immediately previous review correction action on the question side only, before the current answer is revealed; hide it on the revealed answer side.

- **UX-REVIEW-002 [Confirmed]:** [Release: First] [Flow: review] Choose the single learning direction before session launch, then show it once as noninteractive context. On reveal, remove the reveal/status cue, keep the original prompt smaller and muted, and emphasize the correct translation as the primary text. Hard remains a checkbox above and aligned with Correct; its entire label is clickable, occupies the Correct-column width, and has at least a 44px-high touch target with a 24px checkbox. Previous-grade correction has a Lucide back/undo arrow beside its explicit label, distinct from Exit. Red unfilled styling is a prototype trial, not yet an accepted final style.

- **UX-REVIEW-001 [Confirmed]:** [Release: First] [Flow: review] Self-assessment uses equal-width red Incorrect and green Correct actions, with a Hard checkbox immediately above and aligned to Correct. Display direction once, completed/total and a progress bar; the answer card shows both languages. Dynamic widths for suggested typed-answer results remain later. Include a no-due empty state and correction of the immediately previous grade, distinct from exit. Skip is later.

- **UX-CARD-001:** [Flow: review] On a Typed Answer question, focus the answer input and open the appropriate software keyboard automatically; keep the card, input and adjacent submit checkmark visible above the keyboard. Recenter/reflow when keyboard closes. (CARD-UI-009–011)
- **UX-CARD-002:** [Flow: review] On a Self Assessment question, tapping anywhere on the card, including its text, or activating its button with the keyboard reveals the answer; nested controls such as Hint do not flip it. Do not show a separate Show Answer button. (CARD-UI-006, CARD-UI-007)
- **UX-CARD-003:** [Flow: review] Show the vocabulary and example sentence(s) on the question side in the question language; on the answer side show the answer and example pairs in both languages. Do not show redundant Question/Answer labels or Category Tags. (CARD-UI-003–004, EXAMPLE-005)
- **UX-CARD-004:** [Flow: review] Center the Hint within the card. Hidden Hints are revealed once per question and cannot be hidden again during that attempt. (CARD-UI-005, VOCAB-007–011)
- **UX-CARD-005:** [Flow: review] Display a small, visually secondary icon and 'Tap to reveal' affordance near the bottom-right corner of a Self Assessment question card, visually distinct from the example sentence. (CARD-UI-007)
- **UX-CARD-006:** [Flow: review] Show the Self/Type switch only on the question side. Switching answer mode during the session is supported. (CARD-UI-008, CARD-UI-018)
- **UX-CARD-007:** [Flow: review] After Typed Answer submission, show the user's answer and expected answer when different; avoid duplicate identical text. The keyboard closes for grading. (CARD-UI-012–013, MATCH-001–004)
- **UX-CARD-008:** [Flow: review] Place Incorrect on the left in red and Correct on the right in green. Their widths dynamically favor the automatically suggested grade; the user can always choose either. (CARD-UI-014, ANSWER-001–006)
- **UX-CARD-009:** [Flow: review] Put a compact 'Hard' checkbox immediately above the Correct button, left-aligned to that button, moving with its dynamic width. Hard modifies only a Correct grade; it is not a third action button. (CARD-UI-015–016)
- **UX-CARD-010:** [Flow: review] Distinguish app Back/Exit from Previous Review. Previous returns only to the immediately preceding card and exposes its prior grade for correction. (CARD-UI-019–020, UNDO-001)
- **UX-CARD-011:** [Flow: review] Provide an explicit Skip action on the question side, at most once per Learning Item per session. Do not conflate Skip with swipe navigation. (CARD-UI-021)
- **UX-CARD-012:** [Flow: review] Above the card show completed / total unique Learning Items and first-try-correct count; do not show the current item's mistake count as a clue. (CARD-UI-002, CARD-UI-024)
- **UX-CARD-013:** [Flow: review] Keep grading actions reachable when long example content requires scrolling; all examples remain accessible. (EXAMPLE-005)

## Collection and Learning Setup — confirmed UX

- **UX-COLL-001:** [Flow: collection] Collection Overview lists Collections with context-specific Quick Learning Actions; Collection Detail includes learning actions, vocabulary list, search, filters, grouping, Detailed/Compact switch and add-entry action. (COLL-005–007)
- **UX-COLL-002:** [Flow: collection] Collection Detailed view shows both language entries stacked, optional examples and nonredundant category tags; Compact view shows language entries side-by-side with truncation. Display order defaults to Target first and is a per-Collection view preference.
- **UX-SETUP-001:** [Flow: review] Learning Actions supply known collection, mode, direction, answer mode and selection parameters. Skip setup when required parameters are resolved from explicit action or preferences; otherwise show only missing choices. (SETUP-008–009)
- **UX-SETUP-002:** [Flow: review] Speed pool size is under More Options, with default 5 and any positive integer allowed. (SPEED-001–003)
- **UX-STATS-001:** [Flow: review] Show Long-term Daily Summary by default and Speed statistics separately; learning never spans Collections. (SESSION-017, SESSION-020, STATS-005–007)

## Entry Editor, categories and import review — confirmed UX

- **UX-ENTRY-001 [Confirmed]:** [Release: First] [Flow: entry] Manual entry uses a smooth scroll-driven Focused Card Stack; the centered card expands automatically and nearby cards collapse to previews. New Entries require Confirm & Next; already saved Entries auto-save edits. (ENTRY-001–008; deletion details and precise thresholds remain separately tracked in ENTRY-009–010)
- **UX-ENTRY-002 [Confirmed]:** [Release: First] [Flow: entry] Keep Back top-left and a global completion checkmark top-right outside the cards, with distinct localized accessible names and tooltips. Global completion confirms the last valid draft and exits; incomplete input shows validation and remains open. Back warns before discarding a nonempty draft. The active new card has a separate Save & Next checkmark. (ENTRY-007, ENTRY-011)
- **UX-CAT-001:** [Flow: collection, entry, settings] Show up to two Category Dimensions expanded by default, in user-configurable order; selected Values remain visible in collapsed headers. Allow multiple expanded dimensions, two rows of chips before Show more/search picker; avoid nested scrolling. (CAT-006–009; CAT-007–008 remain proposed)
- **UX-CAT-002:** [Flow: collection, entry, settings] Mark AI-preselected Values with a small sparkle icon, including in collapsed Dimension headers; no separate AI Assisted heading is required. Manual edits are never overwritten by delayed AI suggestions. (AI-001–006)
- **UX-IMPORT-001:** [Flow: collection, entry] Every import uses Analyze/Extract → Review Differences → Adjust → Confirm → Apply. Show New, Additions, Unchanged and Conflict states. (IMPORT-028–030)
- **UX-IMPORT-002:** [Flow: collection, entry] For single-value conflicts, retain the existing selected Value and show the imported alternative as a compact inline suggestion. Avoid separate conflict dialogs; explicit user edits may accept a replacement. (IMPORT-029–030)

## Localization

- **UX-ICON-002 [Confirmed]:** [Release: First] [Flow: collection, entry, review, settings] Use Lucide as the common UI icon family. Keep size and stroke consistent, use accessible names for icon-only controls, and preserve upstream license notices. Flutter's typed PikoIcon consumes the same pinned SVG originals under `mockups/assets/icons/lucide`, with canonical `components.icons.size`, original 2px view-box strokes and inherited control color (canonical ink fallback). Icons are decorative by default; an optional semantic label names meaningful standalone imagery, while PikoIconButton owns action names and activation. Bundle the full ISC and Feather MIT notice and register it once at application startup. Individual screens integrate these shared icons in their own specification commits.

- **UX-SETTINGS-001 [Confirmed]:** [Release: First] [Flow: settings] First-release Settings shows a single App Language control with English and Deutsch. No learning, Hint, developer, or theme preferences appear in that release view. Keep one page title and usable Back navigation.

- **UX-I18N-002 [Confirmed]:** [Release: First] [Flow: collection, entry, review, settings] Maintain one shared editable catalog for UI naming and English/German translations, consumed by the mockup and the application. The prototype supports live draft editing and export. Flutter consumes generated canonical catalogs through a shared widget context that rebuilds consumers when the interface locale changes.

- **UX-I18N-001:** [Flow: collection, entry, review, settings] Every visible string, including status labels, tooltips, controls and feedback, is localizable. English is default, German is supported initially. (I18N-001–002)


## Learning activity and streak — confirmed 2026-10-13

- **UX-STATS-002 [Confirmed]:** [Flow: review] Label the Daily Average unambiguously as **“Average per active day”** (German: **“Durchschnitt pro aktivem Lerntag”**), not simply “Daily Average” if that could imply inclusion of days without learning. (STATS-005)
- **UX-STATS-003 [Confirmed]:** [Flow: review] Show the current Long-term Learning Streak in consecutive learning days, where at least one regular Long-term review qualifies a day. Keep Speed statistics separate. (STATS-006–007, SESSION-020)
- **UX-STATS-004 [Confirmed]:** [Flow: review] Daily activity history uses relative labels for recent days (Today, Yesterday) and dates for older days, with additional history expandable. This presentation does not change the active-day-only average. (STATS-005)

## Shared prototype components and Collection Detail — accepted 2026-10-13

- **UX-COLL-012 [Confirmed]:** [Release: First] [Flow: collection, entry] After an inline vocabulary edit, show a completion checkmark and a separate X labeled Discard changes. Both have localized accessible names and at least 44px targets. Discard restores both language values captured on opening and collapses; the check preserves valid edits and collapses. Before any changes, one X simply collapses. Invalid drafts cannot be finished, but can be discarded.

- **UX-COLL-011 [Confirmed]:** [Release: First] [Flow: collection, entry] Keep inline vocabulary fields compact: no accumulated field margins between stacked language fields, with the shared field-label gap preserved. Vocabulary deletion uses the same red icon/text treatment as Collection deletion. The inline collapse control is X before edits and changes to a checkmark labeled Finish editing after a change, without interrupting typing; valid edits still auto-save. Invalid or duplicate drafts show validation and cannot be closed as though accepted.

- **UX-COLL-010 [Confirmed]:** [Release: First] [Flow: collection] New Collection creation presents target language, native language, then a required name prefilled with the target-language name localized to the interface. Automatic changes stop once the user edits or clears the name.
- **UX-VOCAB-DELETE-001 [Confirmed]:** [Release: First] [Flow: collection, entry] On mobile, horizontal swiping of a saved vocabulary row reveals a red Delete action; require explicit activation rather than deleting on an incidental gesture. Expanded editors provide a labeled accessible Delete alternative. After deletion, offer time-limited Undo restoring the vocabulary and associated progress. The prototype's eight-second timeout is an experiment, not a final production duration. A future trash area is deferred.

- **UX-COLL-009 [Confirmed]:** [Release: First] [Flow: collection, entry] Activating a compact vocabulary row expands that same card inline in Collection Detail, with the two language texts editable. It does not launch the add-entry session. The plus remains the separate action for adding entries. Use labeled fields, a labeled collapse control, and auto-save valid edits; incomplete or duplicate drafts show validation without corrupting the saved pair. Hints, categories and examples remain excluded from this first-release editor.

- **UX-SYSTEM-001 [Confirmed]:** [Release: First] [Flow: collection, entry, review, settings] The binding HTML/CSS prototype uses shared semantic design tokens and recurring component styles. Maintain clear focus, disabled, error, active and draft states; do not maintain a parallel Figma design source. Flutter uses reusable buttons, labeled fields, dropdowns, cards, headings and responsive page primitives backed by the generated canonical configuration. Controls can grow for large text; keyboard focus and reduced motion remain supported.
- **UX-COLL-007 [Confirmed]:** [Release: First] [Flow: collection] Collection Detail uses a small edit icon beside its name; activation changes the name into a labelled inline text field. Provide confirm/cancel actions, Enter to save and Escape to cancel; empty names stay in edit mode with validation. Deletion is an icon plus red text at top-right, retaining explicit confirmation. (COLL-012, COLL-014)
- **UX-COLL-008 [Confirmed]:** [Release: First] [Flow: collection, review] Collection Detail offers a full-width Review card showing its actual due count and a localized invitation to review. The vocabulary list uses compact side-by-side language values with a decorative edit icon, not a navigation chevron. The whole row opens that entry for editing.
- **UX-HEADER-002 [Confirmed]:** [Flow: collection, entry, review, settings] Reduce the gap between Back and the page title consistently. Keep the meaningful Collection subtitle with a small left inset. Do not add duplicate navigation just because the viewport becomes wider; tablet and desktop layout strategy remains separately undecided.

## Open UX decisions

- **UX-HOME-002 [Confirmed]:** [Release: First] [Flow: collection] For an empty collection overview, show a short friendly explanation of Collections and a Create first collection action, alongside the existing New action. Use shared English/German copy; do not show sample Collections or review statistics in this state.

- **UX-COLL-004 [Confirmed]:** [Flow: collection, review] Collection quick-review buttons share a consistent width and height across cards, independent of due-count digit length. Allow space for localized labels and counts; preserve readable content at larger text sizes rather than clipping it.
- **UX-COLL-005 [Confirmed]:** [Flow: collection] Use consistent uppercase Latin language-code badges such as KO, FR, and EN instead of mixing a Korean glyph with Latin abbreviations. These identify the Collection's target language, not the interface language.
- **UX-COLL-006 [Proposed]:** [Flow: collection] Offer Collection rename from Collection Detail rather than crowding the overview card. First-release inclusion requires owner agreement; changing the language pair of an existing Collection remains a separate open decision.

- **UX-HOME-001 [Confirmed]:** [Flow: collection, review] Do not show a global Ready to review information block on the homepage. Show due-review counts and Review actions on individual Collections; users can open a Collection and start Review there. This supersedes the earlier Minimum homepage summary direction, not the separate Expanded activity/statistics exploration.

- **UX-ICON-001 [Confirmed]:** [Flow: review] Do not use the northeast/external-link arrow for learning or review actions. Use Lucide's circular review arrow; UX-ICON-002 records the accepted common family.

- **UX-COLL-003 [Confirmed]:** [Flow: collection, entry] Place an icon-only Add Entry plus beside the vocabulary heading, in normal flow rather than a floating overlay. Keep a localized accessible name and tooltip and a 44px touch target without obscuring entries.

- **UX-HEADER-001 [Confirmed]:** [Flow: collection, entry, review, settings] Use one clear page title without a decorative eyebrow or redundant explanatory subtitle. Collection Detail retains its useful language-pair and entry-count subtitle. Learning retains session direction and progress context; field-specific instructions and meaningful section headings remain available.

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

**Current pass:** The accepted homepage uses compact identity, Settings top-right, and Collection-specific review actions without the removed global due summary or bottom bar. Additional learning/statistics controls are visible only in Expanded preview scope. The public Speed label remains open; Lucide is selected.

- **0.4.2:** Repaired functional cross-references, recorded Minigame Break presentation, and retained five deferred owner annotations.

## Design exploration

**Accepted button default — 2026-10-13:** Use Soft filled buttons with 24px radius, centrally defined. Keep grading red/green and equal-width. Comparison controls have explicit spacing and wrapping; show real keyboard focus rather than a fake Focus action. Other adjustable dimensions remain prototype drafts.

**Accepted control readability refinement — 2026-10-13:** Dropdown labels must not touch their controls, including the review-direction popup. The shared label/control gap is 8px by default. Dropdown geometry is independently editable in the studio as a draft; native keyboard selection and visible focus remain intact. This planning tool does not add Settings or first-release product functionality.

The proposed principles and unresolved visual choices are in [DESIGN.md](DESIGN.md). The [design studio](../mockups/design-lab.html) edits semantic colors and catalog values live. Cobalt is the editable baseline and Lucide is selected; typography and broader layout refinements remain open. Earlier annotation tables retain historical traceability; newer accepted requirements supersede conflicting directions.
