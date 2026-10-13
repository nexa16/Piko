# Design foundations and shared copy

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
