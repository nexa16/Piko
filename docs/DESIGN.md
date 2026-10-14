# Design foundations and shared copy

## Reference fidelity and usability — UX-SYSTEM-001

Owner clarification, 2026-10-14: the mockups are useful design references, not pixel-perfect requirements. Preserve confirmed choices such as soft-filled rounded buttons, shared tokens, Lucide icons and safe top-right popup dismissal. Do not reproduce a layout merely because it exists in the mockup when it is awkward, incorrect or less usable. Prefer readable, accessible, consistent production layouts; record meaningful deviations and ask before materially changing the intended design. Earlier “binding” wording describes the reference and accepted interaction intent, not a requirement to preserve its defects.

## Actual session counters and progress — UX-CARD-012

Above each real hidden/revealed card and pending wait, retain a single fixed direction, completed/total unique launch members and first-try correct text. Use existing shared copy and semantic muted text; do not expose the current round's error count. Canonical `components.reviewContext` and `components.progress` adapt the binding's context gap/type/breakpoint and 7px ink-on-tint bar with 9px radius and 16px margins. Narrow metadata wraps naturally without clipping. Numeric progress-bar semantics include min/max/value and localized description.

English/German 320px/200% host tests verify counter containment, shared edges and margins above the card, accessible role/value and exact zero/half fill after accepted success. Browser adapter tests preserve reference dimensions. Scrolling is expected when context and enlarged cards exceed the viewport; prior reveal/grading fixtures now scroll before activating the same targets. Android rendering remains pending.

## Language-only Settings presentation — UX-SETTINGS-001

Use one shared level-one page title, ghost Back and language card/dropdown; English and Deutsch are the canonical option autonyms. No learning, direction, Hint, developer or theme preference appears in the first-release route. Growable shared controls and page scrolling retain keyboard and touch access at English/German 320px/392px with 200% text; host tests verify single heading, menu/control containment, ≥44px targets and return to the same Home.

Actual binding measurements identified a 23px title-content-to-card gap (collapsed h1/card margins), not a literal 23px extra Flutter spacer. Reuse the canonical heading margin 7px plus `spacing.4` 16px; scoped browser Settings content uses the same sum. The binding card has 19px padding/1px border and a field with 17px outer vertical margins. Lift only that Settings field margin to `components.settings.fieldMarginY` and apply it around the Flutter dropdown, without changing shared PikoField or other screens. The resulting card-edge/field inset is 37px on both sides. This corrects measured host box geometry; font raster/glyph metrics and Android acceptance are not inferred from it.

## Hard aligned above real Correct — CARD-UI-015

The revealed card's action block has an empty left half and the shared Hard target in the right half, directly above Correct with the canonical grading gap. Align the full clickable label target, not the inset visual box: left/right edges and width equal Correct; the existing 8px inset remains. Labels wrap and targets grow at English/German 320px/200%; the decorative checkbox still renders 24px. The two grade buttons stretch to their maximum natural row height, preserving a common top/bottom when localized labels wrap differently, as the binding grid does. No new tokens, separate grade button or dynamic-width policy is added.

One semantic checkbox and Tab/Space/Enter control the modifier only. The actual session port disables pending/stale actions, while the child-owned successful revealed snapshot guards read/owner/covered lifetime changes. Failed grading retains selected Hard; next-card activation resets it. Host route acceptance is implemented, not Android or the later retry/progress/correction layout.

## Real equal-width grading — CARD-UI-025

Below a successful revealed card, use one equal-column row: solid semantic danger Incorrect left and success Correct right, with existing onPrimary contrast and shared growable 48px targets. `components.reviewGrading` lifts the binding 10px gap, 18px top margin, 8px/12px padding and numeric 650 weight into the canonical adapters. The effective browser label is the later `.btn` 14px font-label override, which matches Flutter. English/German 392px/200% tests verify equal physical widths, order, reachable targets, colors and semantics.

Grading is separate from card activation and remains absent until a valid stored answer is revealed. Pending controls disable together with localized live-region saving feedback; failed writes retain the answer and offer another explicit grade choice with canonical failure text. No Hard/progress/retry/correction placeholder is rendered. Host geometry does not establish Android or the later integrated layout requirements.

## Default tag policy — CARD-004

Neither the real hidden nor revealed default card adds category pills, tags or placeholder labels. Preserve literal stored vocabulary, even if it resembles a UI heading or hashtag; do not sanitize it as metadata. The hidden side contains its stored prompt and the accepted reveal cue, while the revealed side contains only the two stored language values. Four English/German, both-direction host route tests verify exact text/semantics and unchanged storage through return/relaunch. No visual/token change or category feature is introduced; Android acceptance remains pending.

## Real card reveal — CARD-UI-007

The whole hidden card is one reveal target; use the existing localized cue with a muted book icon near the lower-right corner, not a separate button. Canonical `components.learningCard` now owns the binding 58px bottom padding, 12px/400 cue, 16px icon, 7px gap and 18px-right/16px-bottom offsets. Flutter constrains and measures wrapped cue text so enlarged labels remain inside the card without overlapping the prompt; normal binding geometry stays unchanged. The keyboard focus outline overlays the shared card rather than moving its contents.

On reveal, remove the cue and action. Center the stored original prompt at 22px/500 muted, then the 64%-width divider with 15% ink, 18px gaps and the primary translation at 37px/650 ink. Browser CSS and Flutter consume the same configuration, including the accepted numeric-weight adapter. No Question/Answer heading, revealed-status label or category placeholder appears. Host tests establish both-direction content, focus geometry and English/German 320px/200% cue containment; Android, grading/progress and independent default-tag acceptance remain separate.

## Stored uncluttered prompt card — CARD-UI-004

The real current-entry card centers only the selected direction's stored prompt. Reuse shared card padding/radius/border/surface and ink text; promote the existing binding `.learning` 290px minimum and `.word` 37px/750 style to `components.learningCard.minHeight`, `promptSize` and `promptWeight`. Browser and Flutter adapters consume those values; Flutter's accepted numeric-weight mapping still applies. Minimum height grows for long text rather than clipping 392px/200% English/German content.

The initial prompt increment added no synthetic Question/Answer heading, tag placeholder or example. Loading/error feedback stays outside the successful card. Live stored text may update while the current handle remains fixed; locale rebuild does not resubscribe. CARD-UI-007 now supplies real reveal and revealed-side absence evidence, and CARD-004 independently verifies the default-tag policy. CARD-UI-004 is implemented at host level across both sides; progress integration and Android acceptance remain pending.

## Session Exit versus previous-review correction — CARD-UI-001

The nonempty real session's navigation action explicitly says `learn.exit`; the initial no-due screen retains `common.back`. Reuse the shared ghost-button target, navigation arrow and localized semantics/keyboard activation with no new geometry or styling. The binding mockup consumes the same Exit key without changing other Back labels or expanding its sample correction. The production previous-review action remains absent until transactional correction exists; its separate `learn.correctPrevious` wording is not replaced or used for Exit. English/German 200% host tests verify the leave action, while visible coexistence with real correction and Android acceptance remain pending.

## Initial no-due review card — REVIEW-002

The initial empty selected-direction session uses the shared card, one existing Back and fixed direction context. The binding heading matches global body-size bold h2; description uses semantic muted, canonical `components.emptyState.descriptionSize` (15px) and existing `descriptionLineHeight` (1.6), with `spacing.5` (20px) top margin. Browser/Flutter adapters consume these values together, without changing the existing homepage description size. English/German content wraps at actual app-level 200% scale and 392px width, and Back remains reachable. No sample question, grading or completion view is added; Android and future pending-retry presentation checks remain separate.

## Explicit review direction popup — REVIEW-001

Use the binding mockup's shared popup with localized `learn.setup`, `settings.direction`, `learn.start` and close X. The growable shared dropdown has exactly the Collection's two code-arrow-code directions, using the canonical 8px label/control gap and existing dropdown geometry. It receives initial focus through an optional shared autofocus adapter; native Space/arrow/Enter selection and Tab/Enter Start are host-tested. Selection survives English/German rebuilds. Preparation wording/failure lives only in shared copy, and pending/readiness states disable Start without introducing an alternate design source. X/Escape/backdrop remain safe dismissal of read-only setup.

The interim runtime session route reuses the shared page/heading/Back and shows the captured direction as noninteractive context. It deliberately has no invented card, sample question, progress or no-due view; those layouts remain with subsequent requirements. Enlarged 392px German popup checks and real-session lifecycle evidence are host-level only, not Android acceptance.

## Optional Hard checkbox — ANSWER-004

The shared checkbox uses one full-width clickable/semantic label, the canonical 44px control minimum, 8px horizontal padding/gap and 14px label typography. The binding 24px checkbox and 10px vertical padding are now `components.checkboxes.size` and `paddingY`, consumed by browser variables and the generated Flutter adapter. Remove overridden independent checkbox dimensions from CSS. Labels wrap without a fixed height, including a 170px German column at 200% text size. Selected Hard uses semantic success and the existing onPrimary check contrast; scale the decorative checkbox without scaling the canonical border width. Focus uses the shared border/radius policy without moving layout; disabled presentation uses the shared opacity.

The Hard adapter uses `learn.hard`, starts off and only changes the coordinator's modifier. It disables during a pending grade, after acceptance or for a stale card handle, retaining selection after failure. Host composition verifies actual persisted grades, but this component does not implement CARD-UI-015's position above Correct or the full review screen. Those placements and Android verification remain pending.

## Inline Collection name and navigation controls — UX-COLL-007

The wrapping level-one Collection name has its adjacent shared Lucide pencil. Inline editing replaces that title row with a flexible labelled name field and check/X controls, using canonical `spacing.2` (8px) gaps and vertical margins; ordinary headings retain the existing 7px title margin. Shared icon buttons retain ≥44px minimum targets, localized semantics/tooltips and controlled focus. Failure text uses semantic danger and a live region while the raw field/selection stay intact. Pending save disables competing name, deletion and entry-navigation controls.

Back remains left and red trash/text Delete right in a bounded navigation row. The optional shared heading title slot and focus-node adapter introduce no independent typography, color or control defaults. Long titles wrap within the remaining width; the two navigation sides constrain enlarged localized text so Delete retains its right edge. Host evidence covers exact 392px German at 200% and scroll reachability above a simulated keyboard. The binding mockup's existing inline rename and explicit deletion confirmation are unchanged; Android Collection-management acceptance remains pending.

## Distinct inline Finish and Discard — UX-COLL-012

The binding inline header now presents one X before changes, then a Finish check followed by a separate Discard X. Both use the shared ghost icon button, canonical ≥44px targets and existing 12px gap; no new independent geometry is introduced. Distinct localized semantics/tooltips and Tab order match the two different operations. Header text wraps within its remaining width at German 392px/200%, with both actions reachable above a simulated keyboard. Pending rollback keeps both controls visible but disabled and uses localized pending/error feedback. Host evidence is recorded under UX-COLL-012; actual Android editor acceptance remains pending.

## Collection compact editing and deletion — UX-COLL-011

Stacked inline fields retain no outer field margins, the shared field-label gap and existing 12px field separation. A localized ≥44px X changes to a Finish editing check when the raw pair differs from its opening values, even after autosave; invalid edits stay open. Collection compact rows reuse the canonical swipe reveal rather than deleting on a gesture. Expanded editors offer red trash/icon text through the shared danger-ghost button. The latest Undo bar uses shared tint, 12px padding/gap and the existing control-radius adapter, wrapping its action at enlarged text sizes and bounding identifying vocabulary to two visible lines while retaining full semantics. No Discard placeholder is shipped. Host evidence includes 392px German at 200% with a simulated keyboard inset and reduced motion; actual Android evidence remains pending.

## Collection inline vocabulary presentation — UX-COLL-009

The production Collection renderer consumes the binding compact row's 16px padding, 12px gaps and equal target/native columns with single-line ellipsis, expanding that same keyed card to the existing 19px card padding and 16px radius. The inline header uses shared body/title typography; language labels and inputs retain the binding 750 label weight. Field columns switch by viewport width at `components.inlineVocabulary.compactBreakpoint` (420px); generated responsive CSS and Flutter share this editable source. `captionSize` extracts the matching 11px muted caption, with existing 8px spacing above it and 12px error spacing. At the UX-COLL-009 stage, no Delete, Finish or Discard placeholder controls were introduced; actual Delete and Finish integration follows under UX-COLL-011. Host checks cover 420/421px layout, keyboard activation/focus visibility and German 392px at 200% with simulated keyboard inset; actual device inline-editor evidence remains pending.

## Shared popup implementation — UX-DIALOG-001

`components.dialogs` centralizes the existing mockup maximum width (430px), title size (20px), backdrop color and opacity. Popup titles reuse the canonical 700 title weight; padding, header gap and radius reuse shared spacing/radius tokens. Both CSS and Flutter consume these values. Flutter popups have a flat, untinted surface and scroll within the available keyboard-safe height. A localized Lucide X, Escape, backdrop or Android Back dismiss safely and restore opener focus; Tab stays inside the dialog. Generic Cancel buttons are omitted. Explicit positive actions and meaningful Continue Editing / Discard & Exit choices belong to each consuming flow, with safe dismissal returning no action result. Reduced-motion settings suppress transitions.

**Status:** Proposed visual principles; catalog and live preview support exploration. Cobalt is the current adjustable color baseline; Lucide is the selected UI icon family. Font and application platform remain undecided.

## Single design configuration — 2026-10-13

`shared/design-config.js` is the sole editable source for reusable UX configuration. This supersedes earlier directions to edit `theme.js` or `design-tokens.css`: those files are compatibility adapters, not independent configuration sources. `design-runtime.js` maps the data to CSS variables before the prototype loads. The studio and standalone mockup consume exactly the same file; reload them after an accepted source edit. The Flutter adapter is generated from this configuration; reusable Flutter primitives consume its values without independently maintained defaults.

The schema owns `colors`, `spacing`, `typography`, `radii`, `controls`, `components.buttons` and `components.dropdowns`. Numeric dimensions are CSS px, `motionFastMs` is milliseconds, and weights are numeric. Buttons default to Soft filled / 24px. The studio's **Export design config** combines the current palette and both component drafts into one reviewable config file, retaining untouched values. Copy/i18n stays in its separate wording catalog. Local palette favorites remain optional experiment sets rather than canonical design configuration. Partial CSS exports are experiments only; accepted changes must be consolidated into the one config file.

The runtime validates colors, numeric ranges and minimum 44px controls. Recurring field, card, icon, border, focus, disabled and page-inset values are promoted from the binding CSS into component, state and layout configuration. Flutter uses minimum heights rather than clipping enlarged text. Semantic grading stays solid red/green; ghost deletion actions remain red. CSS media-query breakpoints and feature-specific geometry still remain in CSS; the matching mobile breakpoint is recorded in configuration for Flutter. Reduced motion disables component animations. This infrastructure does not claim completed product screens or icon/dialog integration.

Accepted compact header geometry (UX-HEADER-002): `components.headings.titleMargin` extracts the existing 7px h1 block margin into the canonical source. Browser h1 and Flutter page-title boxes consume it. Flutter adds existing `spacing.1` (4px) below navigation and `spacing.2` (8px) subtitle inset, keeping one Back at wide widths. These are box measurements; font metrics and CSS layout can produce different visible glyph gaps. Meaningful subtitles wrap, and actual product-screen integration remains separate.

Empty invitation presentation (UX-HOME-002) uses the shared card, canonical muted body text and `spacing.5` (20px) before the primary creation action. The existing binding description-only 1.6 line-height is now `components.emptyState.descriptionLineHeight`; its browser and Flutter adapters share that value without changing global body line-height. The ordinary New action stays available, and enlarged localized text wraps in normal page scroll flow.

Target-language badges (UX-COLL-005) use canonical `components.languageBadge`: effective binding size 42px, radius 12px, font 15px, weight 800 and .03em tracking. The old overridden 48px cover rule is removed. Browser adapters reproduce the baseline; Flutter uses minimum bounds and centered intrinsic text to let enlarged glyphs grow. Tint/Primary remain semantic colors. Latin codes derive from Collection data, while full localized language names stay in the whole-card accessible action and the code is decorative.

## What needs refinement

The mockup repeats its identity through an eyebrow, title, subtitle, and collection heading. Activity is below collections, and Statistics has two entry points. Secondary text is faint, heavy headings compete, cards and buttons share similar emphasis, and Unicode symbols substitute for a coherent icon family. A different color alone will not solve hierarchy.

## Principles to agree on

1. Quiet, not faint: simplify decoration while maintaining readable contrast.
2. Task first: activity before collections, one route to Statistics, Settings top-right.
3. One visual language: stable spacing, typography hierarchy, restrained radii, and one icon family.
4. Color has a job: brand accent is distinct from correct/incorrect feedback; state never depends on color alone.
5. Realistic sizes: propose 16px body text, 14px secondary labels, and comfortable 44–48px touch targets. Preserve focus, larger text, and reduced motion.
6. Keep design and product aligned: accepted decisions update copy, tokens, specifications, and prototype together.

The 44–48px target is a proposed Piko comfort target. WCAG 2.2 AA's minimum is 24 by 24 CSS pixels with exceptions and spacing provisions. Normal text needs 4.5:1 contrast, large text 3:1, and meaningful non-text control/state cues 3:1. Test actual pairings and states, not just a palette.

## Palette candidates

| Direction | Primary | Soft accent | Background | Main text | Secondary text |
| --- | --- | --- | --- | --- | --- |
| Forest | #23634B | #E3F0E8 | #F6F7F2 | #1E2D25 | #52645A |
| Cobalt | #2956B8 | #E7EEFC | #F5F7FB | #1E293B | #526177 |
| Plum | #754281 | #F1E7F5 | #FAF7FB | #302336 | #6A566F |
| Terracotta | #A3432F | #F8E8E1 | #FBF7F2 | #382923 | #725B50 |

All use a white surface in this light-theme experiment. The studio checks white-on-primary and secondary-text-on-background contrast live; this is not a full accessibility audit. Focus, disabled, error, success, and dark-theme roles need defining before design is frozen.

## Icon candidates

**Selected — 2026-10-13:** The owner confirms Lucide for all interface icons. The alternatives below are historical comparison notes, not pending selections. The prototype uses genuine local pinned Lucide SVG originals through current-color CSS masks, with consistent 20px size and the originals' 2px stroke. Required license notices remain alongside the assets; no runtime CDN is used.

- [Lucide](https://lucide.dev/icons/): restrained outlines; ISC license with Feather-derived notices. Starting recommendation for a calm utility.
- [Phosphor](https://phosphoricons.com/): six weights including fill and duotone; MIT license. Warmer and more expressive.
- [Tabler](https://tabler.io/icons): extensive outline and filled families; MIT license.

Use Lucide with consistent size/stroke. Preserve required license notices when adding assets and label unfamiliar symbols. Selecting icons does not select an app framework or grant a license to Piko itself.

## Open decisions

- Calm utility versus warmer/playful character.
- Palette and light/dark strategy.
- Neutral versus rounded typography, Korean glyphs, long German labels.
- Collection cards versus compact rows; information and action hierarchy.
- Home identity/title treatment and navigation/back behavior.
- Public names for review and intensive learning. Review / Learn new are experiments. Internal Speed also permits refresh of existing vocabulary, so a new-vocabulary-only label may mislead in some contexts.
- Further context-specific icon size adjustments beyond the current consistent outline baseline.
- Spacing, radii, focus, motion, and state tokens.

## Canonical naming and translations

shared/copy.js is the single editable source for interface text in the current mockup. Its data-only object contains schemaVersion, defaultLocale, and stable semantic entries with English and German values and optional notes.

- Edit values, not keys; retain both languages and matching named placeholders such as {count}.
- Vocabulary, collection names, example sentences, and fixed sample dates are content, not interface translations. A real app will format actual dates with its locale.
- Keep credentials and personal data out of the catalog.
- The HTML loads a local script so file-based previews need no framework, build, server, or fetch.

Open mockups/design-lab.html to edit labels, switch languages, navigate the preview, and compare palettes. Edits apply immediately inside that preview and last while the tab is open. They do not silently write repository files. Export copy.js, replace shared/copy.js, and reload open mockup tabs to make changes canonical. JSON export is an interchange format, not a second maintained source.

No actual application exists yet. A future web app can load/import this object; a native app can use a build adapter to extract its data into platform localization files. Consumers must use stable keys rather than duplicate labels. That adapter and hot reload depend on the eventual platform. Editing a local document will not automatically update a shipped binary.

## Keeping the design current

**Accepted source of truth:** The HTML/CSS mockup is the binding visual and interaction reference. Do not introduce a separately maintained Figma design. Consolidate recurring controls into shared prototype components and centralize spacing, type, radii and dimensions alongside semantic color roles. Track empty, active, draft, error and disabled states. This consolidation is required work, not a claim that all current inline styles are already centralized. Flutter is preferred for later implementation; the final stack remains undecided. Future Flutter themes/widgets should consume equivalent accepted tokens and copy through an adapter rather than duplicate design decisions.

Accepted wording updates the catalog; accepted visual decisions update this document, UX specification, and mockup in the same focused branch. Preserve Proposed, Confirmed, and Open states. When implementation starts, shared design tokens and components should consume accepted choices. Keep the mockup as a reviewed visual reference.

## Shared prototype implementation

`shared/design-tokens.css` defines semantic colors (with runtime color overrides from theme.js), spacing, typography, radii, control dimensions and feedback colors. `shared/components.css` owns the recurring layout/control/card styles previously embedded in the prototype HTML. The mockup links both files; there is no framework or build requirement. Prototype-specific sizes remain design experiments rather than fixed production constraints.

Collection Detail now uses inline name editing, red deletion at top-right, a full-width due-review invitation, compact side-by-side vocabulary and edit icons. Back-to-title spacing is reduced across pages. Wide screens keep a centered content column without the duplicate sidebar; final tablet/desktop composition remains open. These apply the owner's seven Collection Detail annotations and responsive-navigation feedback.

States remain explicit: focus-visible outlines, disabled buttons, draft/saved entry cards, active-card borders and validation feedback; reduced-motion disables component animation. Changes remain in page memory and are lost on reload. The inspection tool described below is a prototype-only utility, not an application release feature.

## Dev mode layout inspection

Enable **Dev mode** above the studio preview or with the small standalone mockup control. It is off by default. Hovering or focusing an element shows its rendered dimensions, computed padding/margin (top/right/bottom/left), font size/line-height, display/position and parent flex/grid alignment. Colored overlays distinguish margin (orange), padding (green) and content (blue). Lines measure distances to parent content bounds; geometrically separated adjacent siblings have their gap reported. Scroll and resize refresh the measurements. Escape turns inspection off.

Values are CSS pixels at the current viewport, not physical screen pixels. Parent distances are measured geometry, not inferred Figma anchors or production constraints. CSS margins may collapse or participate in flex/grid spacing; their computed values are reported separately rather than misrepresented as actual gaps. Inline/wrapped text uses its element bounding rectangle, not individual glyph metrics. The overlay does not capture pointer events, prevent clicks or modify application layout; disable it for unobstructed Codex annotations. This requires no dependencies or external service.

## Sources

- [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
- [WCAG target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)
- [WCAG non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
- [Material accessibility](https://m3.material.io/foundations/designing/structure)
- [Lucide icon guidance](https://github.com/lucide-icons/lucide/blob/main/docs/how-to/icon-guide.md)
- [Lucide license](https://lucide.dev/license)
- [Phosphor license](https://github.com/phosphor-icons/core/blob/main/LICENSE)
- [Tabler license](https://github.com/tabler/tabler-icons/blob/main/LICENSE)

Accessibility thresholds and icon licensing come from these sources; Piko's proposed palettes and style are design judgments awaiting agreement.

## Current direction — 2026-10-13

The owner additionally requires a separate Discard changes X alongside the inline completion checkmark after editing. This restores both opening values despite provisional auto-save; completion keeps valid edits. Unchanged editors retain a single collapse X. The two actions use localized names and 44px minimum targets.

Inline vocabulary editors use compact field spacing (zero per-field margins within the grid and a shared 12px grid gap). Their Delete action shares the red icon/text danger variant used for Collection deletion. The top-right control switches from X to a completion checkmark when edited; it closes editing rather than introducing an extra save step. Invalid drafts remain open with validation. These are accepted owner refinements, not merely style candidates.

The owner subsequently removed the global Ready to review homepage block as redundant. The Minimum homepage now proceeds directly from Piko/Settings to Collections with their own due counts and Review actions. This supersedes the earlier summary placement below.

Collection Detail uses an icon-only Add Entry plus beside the vocabulary heading, in normal flow without covering content. Its accessible name and tooltip use the shared naming catalog.

Page headers use one clear title, without repeated decorative eyebrows or generic explanatory subtitles. Collection Detail keeps its meaningful language-pair and entry-count subtitle; learning direction and progress remain session context rather than decorative copy. This header simplification is accepted by the owner.

The owner prefers cooler colors, rejects the green direction, and selects Cobalt as the current baseline. Primary, Tint, Background, Surface, Main text, Secondary text, and Text on primary are directly editable in the studio through color pickers and hex inputs. Plum remains an alternative. Export theme.js to persist experiments into shared/theme.js; the standalone mockup consumes those same visual roles.

The visible Minimum flow is accepted: create/open a collection, manually enter vocabulary, and review through Long-term self-assessment. The homepage starts with a compact Piko identity and Settings top-right, then a due-review summary and collection list. Expanded scope adds secondary actions for extension stress-testing. It does not approve all 44 proposed Minimum labels or declare a release milestone.

The owner requested removal of the standalone icon comparison page and its studio panel after reviewing the candidates. Source SVGs and license notices remain under mockups/assets/icons. Lucide is now explicitly selected and implemented for the prototype interface.

## First-release entry stack prototype — 2026-10-13

UX-ENTRY-002's production header follows the effective binding grid, not the earlier superseded flex layout: Back takes its intrinsic width, the title centers in the remaining middle track and a 48px primary global action occupies the right track, with canonical 10px gaps. Header title size is 22px, changing to 18px at the canonical 400px viewport threshold. Back has zero visual padding, weight 750 and body/compact-small text while retaining a minimum 44px hit height. Shared page-top 20px and title margins are reused. The generated CSS responsive block and Flutter adapter share the breakpoint; English/German names distinguish final completion from the card's 48px Save & Next. At large text the title wraps and controls remain available; centering is within the middle track, not an inaccurate promise of viewport-center symmetry.

The production UX-ENTRY-001 adapter now centralizes the effective binding entry geometry: 16px card padding/gap, 5px preview gap, 14px preview top inset, 12px entry numbers, 11px status labels, 1.5 metadata line height, a growable 100px compact minimum and 200ms state transitions. Its primary Save & Next target has a 48px minimum. Reduced motion suppresses transitions. Viewport heights, edge padding and precise activation thresholds remain measured rather than adopting experimental prototype constants. The header arrangement remains separately owned by UX-ENTRY-002. Production persistence is real; the mockup remains an explicitly labelled sample session.

Manual entry now demonstrates three confirmed sample cards and a new draft in a vertically scrollable stack. The nearest central card expands without a tap; scrolling back opens previously confirmed samples for automatic in-memory edits. A localized card checkmark confirms the new entry and opens the next draft. Back stays top-left and warns before discarding a nonempty draft. A distinct global completion checkmark sits top-right outside the cards: it confirms a valid final draft and exits without another card, exits directly for an empty draft, and keeps incomplete nonempty input open with validation. Draft values survive scrolling and live catalog/theme updates. Collection language labels and sample vocabulary follow the selected Collection's language pair. Excessive blank scrolling space remains a pending visual refinement, not an accepted final layout.

The stack deliberately does not focus an input or open the keyboard when scrolling. Keyboard users can focus the stack and navigate cards with Up/Down; only active-card fields are in the tab order. Motion respects reduced-motion preferences. Prototype viewport padding and active-card sizes remain experiments, not finalized production animation thresholds. In the mockup only, confirmed edits remain in page memory and reloading loses them. Production repository persistence and focused-screen Android keyboard/safe-area evidence are now established under their respective requirements and UX-ENTRY-001; full release durability gates, routing and deletion/Undo remain separately tracked, not completed by this presentation work.

## First-release self-assessment review prototype — 2026-10-13

Choose one direction in a minimal pre-start dialog; the session shows it once as noninteractive context and cannot change it. The dark progress bar keeps the completed/total counter. The card itself reveals by tap or keyboard; no separate Show Answer button appears. A small Lucide book-open icon sits with the lower-right Tap to reveal cue on the question only. Revealed cards remove the cue/status, show the original prompt smaller/muted (22px), and emphasize the translation (37px) using Collection-specific vocabulary. Incorrect is red on the left and Correct green on the right at equal widths; Hard sits directly above and aligned with Correct, with a full-column clickable label at least 44px high and a 24px checkbox. It applies only to Correct. Previous-review correction has an explicit label and Lucide back arrow, replaces the immediately preceding sample grade and rolls back displayed sample progress before regrading. Its red unfilled outline is a trial, not an accepted final style. Skip and typed-answer controls are not presented in this first-release review prototype.

The `noDue=1` mockup query parameter demonstrates the no-due state when opening Review. Counts and corrections are illustrative page-memory changes, not actual review history, retries, persistence or FSRS scheduling. Production queue/state consistency remains required by UNDO-001 but is not implemented by this prototype.

## Local palette generator — 2026-10-13

Named favorite sets store all seven semantic roles locally in this browser's localStorage. Saving does not change shared/theme.js or create an application preference. Selecting a set replaces the whole draft palette and supports palette Undo; generator locks remain unchanged and only constrain generation. Delete requests confirmation. Portable JSON export/import provides backup or transfer between browsers; import validates schema version, unique names, seven hex values and a 40-set limit, and confirms before replacing existing favorites. Browser storage may be unavailable or cleared, so export is the durable backup; failures are reported rather than claiming successful storage. No remote service, account, credentials or automatic repository writes are involved.

The studio offers a local generator inspired by the owner's Coolors reference, without an external API or service. Experimental harmony is the default: complementary, split-complementary and triadic hue relationships give Primary and Tint deliberately contrasting hues, with subtly colored backgrounds/surfaces and readable dark text. Related cool remains an optional quieter Cobalt-through-Plum direction. This supersedes the initial same-hue default, which the owner found too conservative. Generate palette updates the seven existing semantic roles and the preview immediately. Each role can be locked during generation; manual editing remains possible, and Undo restores the preceding palette. Reset and Plum explicitly replace the full palette, regardless of generator locks. Space generates only while the palette tool itself has keyboard focus, never while editing fields or activating controls.

Generation tries a bounded set of harmonious light-theme candidates and prefers the four displayed text pairings at 4.5:1 or better. Locked values can make that impossible; the best candidate is shown with the existing contrast warning rather than changing a locked value or claiming a full accessibility pass. Focus, feedback, borders and all actual component states still need separate checks. Generated colors remain draft experiments; export produces syntactically valid theme.js, and canonical changes still require accepting and replacing shared/theme.js. No generated palette is silently committed or selected as the final design.

## Requirements views

All popups use the same reusable modal header with title and localized top-right close X. Escape/backdrop safely dismiss and restore focus. Redundant bottom Cancel/Close buttons are removed, including Collection create/delete; positive Create/Delete/Start actions remain. Closing a destructive dialog never deletes. Draft-exit Continue Editing / Discard & Exit remain explicit data decisions; X/Escape/backdrop preserves the draft and stays in the editor.

The studio's Preview session summary shortcut opens the accepted popup layout with sample counts 30/23 without completing or altering an active review. The popup shows two readable metrics, vocabulary learned and first-try correct, with large numbers and natural label wrapping rather than nested metric cards. Close X, Escape and backdrop dismissal return to the underlying Collection; there is no Back to Collection CTA or separate summary page. Normal sample-session completion uses the current in-memory counts. Sample data remain explicitly marked. The shortcut itself is a planning tool, not an application action. Previous-review correction is shown before reveal only.

## Dropdown draft editor — 2026-10-13

The owner requests a dropdown editor and clearer separation between the learning-direction label and its dropdown. The shared label/control gap defaults to 8px through `--field-label-gap`, including popup fields. Native selects use separate height, radius, horizontal-padding and weight tokens so button experiments do not silently change dropdown geometry. The studio offers a selectable KO → DE / DE → KO sample and validated live drafts: gap 4–20px, height 44–60px, radius 0–24px, padding 8–28px and weight 400–750. Reset restores canonical defaults; export produces a reviewable CSS snippet rather than writing source files.

Selects remain native and keyboard-operable. The appearance of an opened native option menu is browser/operating-system controlled; this editor styles the closed control, not a replacement popup. The existing 160px studio language selector width is preserved. Final draft geometry is not accepted simply by experimenting.

## Button comparison and draft editor — 2026-10-13

**Accepted update:** The owner selects Soft filled and a 24px button radius as the canonical default. The studio reads these from `shared/design-tokens.css`; Reset restores this accepted default. Other height, padding and weight experiments remain unaccepted. Semantic red/green grading and its fixed equal widths remain unchanged.

The owner requested concrete button alternatives and a live editor. The studio compares Flat solid, Soft filled and Outline with the same Primary, Secondary and icon-only examples in spaced, wrapping action rows. Disabled examples occupy a separate row. There is no artificial Focus button or permanently drawn focus ring: real keyboard focus, hover and pressed states can be tried directly. Soft filled is subsequently accepted as the default; the alternatives remain available for draft comparison.

Draft controls adjust radius (0–24px), minimum control height (44–60px), weight (400–750) and horizontal padding (8–28px). Changes apply to the embedded mockup through validated runtime token overrides; the canonical shared tokens remain unchanged until an owner-approved export is adopted. The export is a CSS draft with the exact token names and variant selector, not another maintained source. Future Flutter maps the equivalent radius, minimum size, weight and padding; no Flutter implementation is introduced.

Semantic red/green grading and its fixed equal-width layout remain unchanged. Quick-review widths stay fixed, and existing 48px entry/icon targets are not reduced below 44px. Comparisons use the live color roles and localized action labels. Soft and Outline variants still require testing against the actual selected palette's contrast, focus and disabled states; a successful palette-level contrast display is not a complete button accessibility audit.

In the two-column studio layout, the preview is not sticky: it must not overlap the Requirements section below. Sticky side-by-side panels are reserved for the wide three-column layout.


The studio embeds the existing requirements view as a collapsible third column on wide displays and a full-width section on narrower displays. Both views read the same canonical specifications; no duplicate requirements are maintained. This planning-tool layout is not an application requirement.

Flow tags live directly on requirement texts in the canonical functional and UX specifications. The filterable requirements view fetches those documents on load and on explicit reload, supports source/scope/flow/text filters and bookmarkable filter links, and never stores a separate maintained list. Flow tags describe topic association; they do not promote Additional requirements into the accepted Minimum or change acceptance status. UX scope remains explicitly unclassified where no Scope tag is authored.
