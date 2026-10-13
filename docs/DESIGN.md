# Design foundations and shared copy

**Status:** Proposed visual principles; catalog and live preview support exploration. No final palette, icon family, font, or application platform selected.

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

- [Lucide](https://lucide.dev/icons/): restrained outlines; ISC license with Feather-derived notices. Starting recommendation for a calm utility.
- [Phosphor](https://phosphoricons.com/): six weights including fill and duotone; MIT license. Warmer and more expressive.
- [Tabler](https://tabler.io/icons): extensive outline and filled families; MIT license.

Choose one family and consistent size/stroke. Preserve required license notices when adding assets. Label unfamiliar symbols. None is installed; choosing icons does not choose an app framework or repository license.

## Open decisions

- Calm utility versus warmer/playful character.
- Palette and light/dark strategy.
- Neutral versus rounded typography, Korean glyphs, long German labels.
- Collection cards versus compact rows; information and action hierarchy.
- Home identity/title treatment and navigation/back behavior.
- Public names for review and intensive learning. Review / Learn new are experiments. Internal Speed also permits refresh of existing vocabulary, so a new-vocabulary-only label may mislead in some contexts.
- Icon family and size/stroke weight.
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

Accepted wording updates the catalog; accepted visual decisions update this document, UX specification, and mockup in the same focused branch. Preserve Proposed, Confirmed, and Open states. When implementation starts, shared design tokens and components should consume accepted choices. Keep the mockup as a reviewed visual reference.

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
