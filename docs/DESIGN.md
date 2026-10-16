# Design foundations and shared copy

## Compact vocabulary editor — accepted for Later, 2026-10-16

UX-COLL-011 r2 / F19 keep required vocabulary fields visible and place optional Examples/Hint behind compact entry points or populated summaries. Hint uses one Show hint automatically switch (on = always visible, off = reveal on tap), with the independent new-vocabulary-default choice inside that section. Preserve drafts, errors, autosave/Discard, learning and accessible targets. The owner explicitly excludes this redesign from round 4; no implementation round is assigned. The canonical requirement owns acceptance and the bounded installed-emulator observation. The existing [accepted criteria](ux-consolidation-proposals.md#f19--shorten-the-vocabulary-editor) is the reference summary; no app/mockup, catalog or studio interaction changes are authorized.

## Vocabulary activity — requested behavior and visual proposal, 2026-10-16

VOCAB-ACTIVE-001 r2 / UX-VOCAB-ACTIVE-001 r1 separate a manual Active/Inactive boolean from deferred proficiency/Mastered concepts. Inactive vocabulary stays visible, has a visual state indication and is excluded from normal and Speed learning in both directions until reactivated; activity adds no filter and preserves learning history. Proposed, not accepted: put an Active switch in the existing editor and a small Inactive label in an existing subtle color role on saved cards, keeping the vocabulary text readable and editable. Do not communicate state by color alone. Exact visuals, current-session transitions, readiness-label presentation and round assignment remain open; both-mode/both-direction exclusion is accepted. Implementation belongs in the canonical copy/design catalogs only after separate authorization; no runtime studio/mockup/app changes or Android verification are claimed.

## Answer-card editing — accepted for Later, 2026-10-16

On revealed normal and Speed answer cards, expose editing through a single small, low-emphasis pencil icon while preserving the shared accessible touch target. It opens the vocabulary-list editor in that same card, retaining the header and session context. Reuse its fields, autosave feedback and distinct Finish/Discard actions; return to the same revealed answer before grading resumes. UX-CARD-014 / VOCAB-EDIT-003 own this accepted addition. Exact icon placement and editor-specific Exit/system-Back behavior remain to be specified; implementation and Android checks are pending. This is a general specification for later, explicitly outside round 4 with no implementation round assigned.

## Round-4 interaction additions — accepted, 2026-10-16

Use progressive disclosure for adding vocabulary: an extensible choice of Manual entry or Import comes before either method's details. Manual opens the existing editor; Import opens the shared Import/Export popup. Collection menu → Import/Export opens that same popup without a new vocabulary draft. The method chooser is not a binary tab toggle. Apply shared modal, focus, pending-write and long-text rules; exact chooser arrangement and the popup's operation switch remain open under UX-IMPORT-JSON-001 r4. This supersedes the historical JSON-page-only arrangement below.

In the grouped vocabulary view, begin with all groups collapsed and provide Collapse all / Expand all beside Filters; hide them when ungrouped. There is no setting for an initially expanded view. Retain the separate grouping/sort preferences, shared touch targets and responsive action wrapping under UX-COLL-001 r2. Category-editor ordering/configurable expansion remain deferred. Sort vocabulary by the accepted target/native text or added-date options under COLL-008; category-value alphabetical order stays governed by CAT-009.

Support multiple example pairs with clear sentence/translation association, reachable controls and an optional global question-side hiding preference; answers retain every pair. Detailed long-list/editor layout remains open. Existing readiness labels do not represent proficiency. Proficiency levels and Mastered remain deferred in full. The independent vocabulary activity request and its proposed visual treatment are recorded separately above. New copy/controls must use shared/copy.js and shared/design-config.js during later implementation; this documentation update does not change the running studio, mockup or application. The existing [accepted criteria](ux-consolidation-proposals.md) remain the reference handoff, with no new studio panel.

## Accepted design contract — 2026-10-16

The owner accepted the new copy proposals and text-style changes after inspecting the interactive style review. Nunito Sans and F04/F10/F11/F13 were already accepted. The following rules supersede conflicting older design trials; they remain the accepted design contract. Round-3 checkpoint 1 records canonical token/copy/font integration and scoped Android checks. That evidence does not close all F01–F18 acceptance criteria.

### Color roles

Only these nine UI colors, plus documented alpha compositing of them, are allowed: action blue `#4D64AE`, pale blue `#E8EFFA`, page `#F6F7FB`, cream surface `#FFFDF8`, navy text/icons `#34365B`, supporting text `#62657D`, restrained gold `#FFE08A`, danger `#B42318` and success `#166534`. Original Piko artwork and OS-owned interfaces retain their own colors. No extra grey, orange, pink or white UI token.

Use cream on blue/red/green, navy on gold, and primary/navy on pale or cream. Speed cards and category tags use gold. Secondary review uses pale blue. Warnings use 12% red over cream, red icon/heading/border and navy body; they remain distinct from solid destructive/grading actions. Labels carry meaning independently of color. Essential fields use the supporting-text boundary, focus blue and error red with explicit text; decorative borders use navy alpha. Use navy for dialog backdrops at the existing opacity initially. Safe dismissals use the existing low-emphasis shared role. Pressed/hover/focus/disabled variants derive from allowed roles and documented alpha, not new swatches. Verify each pair in context, including the framework's complete theme mapping.

### Palette migration across preview rounds — 2026-10-16

The owner explicitly requested this palette migration to be recorded in specifications only. UX-SYSTEM-001 revision 7 and UX-LAB-001 revision 4 own the accepted change; source migration, rendered mockup checks and Android verification remain pending. The source findings below describe the preserved planning checkout at baseline 862a96b. Round-3 checkpoint 1 records later application palette integration; the remaining migration must preserve that evidence and reconcile preview consumers without reverting current application values. The color inventory is a configuration listing, not evidence that every listed color belongs to the accepted design.

| Existing definition / consumer | Required migration |
| --- | --- |
| `studioPalettes.piko` and Cobalt `colors` | Consolidate into one canonical active Piko palette and update all consumers, including generated application adapters. Keep role aliases where several roles intentionally share a color; do not delete Piko's still-used red/green. |
| Round-2 grading overrides | Semantic danger/cream for Incorrect and success/cream for Correct, as in the accepted round-3 design. |
| Round-2 secondary review overrides | Approved tint background with navy text. |
| Round-2 warning overrides | Documented 12% red over cream, red heading/icon/border and navy body; retain each flow's existing warning condition. |
| Independent dialog backdrop | Palette navy at the existing opacity (approximately 53.33%); remove the old green color after consumers use the shared role. |
| Studio Cobalt comparison and inventory | Remove the historical preset and obsolete active entries. Default/reset and every preview round use Piko; explicit editor experiments stay unaccepted drafts. |

Only the nine base UI colors above and their documented blends/transparency are approved. Original artwork and OS-owned interfaces retain their existing exceptions. This migration does not change typography, spacing, feature scope, learning behavior, sample-state isolation or artwork. Remove obsolete values only after dependent adapters/styles/components are migrated, retaining needed non-color `previews.round2` settings. Historical documentation and decision evidence may retain superseded hex values; running configuration must not retain a legacy palette solely for comparisons.

See [round-3 prototype progress and open boundaries](implementation-round-3-mockup.md) and UX-LAB-001 for source-inspection evidence and pending acceptance scenarios. Browser preview is not Android verification.

### Typography and geometry

Use Nunito Sans for interface text with the reviewed Noto Sans KR Korean fallback. Bundle required weights and license notices for offline use. Preserve font scaling and verify actual Android glyph metrics; do not substitute the browser screenshot for that check.

| Role | Size / weight / line height |
| --- | --- |
| Page title | 26 / 700 / 1.2 |
| Dialog title | 20 / 700 / 1.3 |
| Section heading | 18 / 700 / 1.35 |
| Body / input value | 16 / 400 / 1.5 |
| Field label | 14 / 600 / 1.4 |
| Control label | 14 / 700 / 1.4 |
| Supporting text | 14 / 400 / 1.45 |
| Learning answer | 37 / 600 / 1.3 |
| Revealed original prompt | 22 / 400 / 1.4 |

Remove decorative negative title tracking. Use shared 4/8/12/16/24 spacing steps; keep existing 20/32 steps only where an owning accepted component requires them rather than blanket replacing dimensions. Radii: card 16, dialog 20, field 12 and action 24. Lucide icons remain 20; 48 logical pixels is the target for new/shared controls. The reading mascot's accepted 64px slot is unchanged.

Titles and actions rearrange before clipping or character-level breaking; long unspaced user content may break as a last resort. Do not reduce accessibility text to make it fit. Input values may scroll inside their field; readonly content needs wrapping or an explicit full-value access rule. Keep label/value groups together. Input values never inherit a field label's bold weight. State-specific details belong to their existing UX requirements.

### Wording

Keep EN/DE meaning and placeholders equivalent. Prefer vocabulary/Vokabeln over technical entry-session wording. Use Category group/Kategoriegruppe for the user-facing dimension and Value/Wert within a named group; internal IDs and serialized names remain unchanged. Completed is a session outcome; currently due is time-dependent; neither asserts durable mastery. Use explicit action outcomes and natural verbs. Retain Collection/Sammlung, Review/Wiederholen, Speed/Intensiv lernen and explicit grading labels. New labels must pass targeted long-text checks.

The reviewed copy changes are accepted for canonical integration in the owning packages. `shared/copy.js` remains the only runtime wording source; `shared/design-config.js` remains the only runtime design source. Keep tokens/copy and generated application adapters synchronized. The preserved historical round-3 mockup uses older profile/alias adapters and still needs compatibility integration with the current catalogs; do not overwrite current runtime values to restore that preview. No second production catalog or unreviewed seeded palette is authorized.

## Reconciled verification and historical references — 2026-10-16

The [quality workflow](ux-quality.md), [criteria](ux-consolidation-proposals.md) and [finding register](ux-findings.json) preserve the accepted design handoff. Finding-level closure remains separate from the implementation ledger. Older Cobalt, white-on-action, orange-warning and pending-integration statements below record their dated checkpoints; the accepted contract above and current canonical requirements supersede conflicting active design values. Dark-mode and unaccepted global navigation choices remain open.

## Piko app icon and contextual mascot — accepted, 2026-10-15

The owner clarified that the Piko character is purely decorative. Its context-dependent appearance adds no function, interaction, action or learning effect. Do not make it a control or status indicator: exclude it from focus/accessibility announcements and keep all existing state text/actions independently understandable. This applies to every in-app pose; the app icon retains ordinary OS launcher behavior.
**Launcher supersession, 2026-10-16:** UX-BRAND-001 revision 3 replaces the frame-1 launcher choice below with the owner-refined plain book (one-pixel spine, 23×18 silhouette on 32×32). Use its prepared centered Android foreground/background, monochrome and legacy resources without trimming or an extra inset. The four-color book palette is cream #FFF9F0, navy #34365B, medium blue #7FA6DF and light blue #B7D1F4. Resource preparation checks are not installed-app verification; integration remains pending. The following reading-mascot placement and geometry stay accepted and unchanged.

Use the refined Piko artwork while preserving the owner's manual pixel edits. The historical round-2 application uses source frame 1 for the launcher; that choice is superseded by UX-BRAND-001 revision 3, whose integration remains pending. Source frame 3 (reading) appears once inside the first visible positive normal-review card on Collection Detail when normal review is available. The reading Piko sits to the right of the card's left-aligned text and before its trailing review icon. If only the reverse-direction card is visible, it receives the mascot. The app icon includes its background; the reading sprite requires a transparent, lossless export. Keep the 64×64 masters, crisp pixel edges and the eight illustration colors recorded in UX-BRAND-001 / UX-MASCOT-001; illustration colors do not replace semantic UI/action tokens. Lucide remains the icon family for controls and navigation.

Collection Detail displays at most one contextual mascot, independent of the number of language-direction buttons. Round 2 shows reading Piko for normal review, including normal-plus-Speed availability, and no mascot otherwise. Its approved card treatment uses the canonical `components.collectionReview.mascotSize` of 64px square and `components.collectionReview.mascotGap` of 8px. Later, new-vocabulary frame 6 takes priority over reading frame 3 when both Speed and normal review are available; sleeping frame 5 represents a genuine nothing-to-learn state. Their precise placement remains a later design decision. Derive those states from the existing search/filter scope and availability rules, preserving honest loading, error, no-result and retry-wait states. Excited frame 2 belongs to completed learning sessions; star-holding frame 4 belongs to the future homepage statistics view. These other poses are specifications only and do not enter round 2. MASCOT-001–004 and UX-MASCOT-002–004 own the behavior and later boundaries.

Keep one shared asset mapping/component and use the canonical 64px size and 8px gap for the approved reading placement. The art supplements explicit status text/actions, remains decorative and noninteractive, and must not introduce extra focus stops or duplicated status announcements. The first positive card's text and trailing review icon remain visible and reachable at narrow widths and enlarged text. Later Speed-completion feedback placement/lifetime must preserve the existing direct return with no new summary popup and the one-mascot limit; it remains open rather than inventing a timer or CTA. The existing summary is the normal-review completion location, with the underlying Collection mascot suppressed while visible.

The 2026-10-15 asset-selection pass did not export or integrate the reading pose. The 2026-10-16 placement approval resolves its card location and scale; the round-2 ledger records later integration and scoped host/Android evidence. Do not regenerate or overwrite the manually edited source when preparing the two round-2 assets.

## Speed short-pool passes — accepted, 2026-10-15

Current clarification: SPEED-007/010 revision 3 requires every remaining pool word to have an answered attempt before a game is eligible. Unseen replacements run in the next complete pass first. Round-3 checkpoint 1 records implementation and scoped checks; the revision-2 text and verification below are historical.

SPEED-007/010 revision 2 uses one complete vocabulary pass, then one untimed numbers game, then the next complete pass whenever the configured pool cannot be refilled and has fewer than N unfinished words. Never put games between different words in a pass. Start with a vocabulary pass even when initially short; finish immediately when all words complete. One remaining word gets one game between attempts; configured N=1 never gets games. Completed slots refill in order, with replacements first appearing in the next rotation. Only Correct/Incorrect advances a pass, not reveal.

The existing game presentation remains shuffled 1–10 with ascending taps, no timer, and automatic continuation. Wrong taps do not advance. The shared bilingual setup explanation now describes whole passes. No new page, progress metric or setup control is introduced. Normal review's ten-second retry countdown and Speed completion/reset effects remain unchanged. This is sample-prototype scope; Android implementation/acceptance remains pending.

Verification: 97 combined Node checks pass, including the exact 4→3→3→1→1→0 pass sequence, initial short pools, mid-pass shrink, next-rotation replacements, N=1, five one-word attempts with four games, and actual controller handlers for reveal, wrong-number taps, whole-pass continuation and unchanged completion/reset effects. Requirements parsing retains revision 2 and the multi-paragraph edge cases in the round-2 filter. The browser renders the updated number-game explanation through the sample-state selector; automated button activation did not take effect, so end-to-end browser click-through is not claimed. Android remains unimplemented for this change.

## One Piko design across platforms — accepted, 2026-10-15

Use a consistent Piko design across platforms. Apple and Android references are inputs for selecting shared rules, not instructions to ship separate visual variants. Keep app-owned popup layouts, button order, close-control policy, navigation presentation, wording, colors and component geometry aligned through the canonical design/copy configuration and reusable components. Choose a coherent shared rule when the references differ rather than switching conventions by operating system.

Allow necessary system integration differences such as safe-area insets, system Back, keyboard behavior, accessibility services and OS-owned interfaces. Responsive layout and enlarged-text adjustments follow common rules. Document any necessary departure from app-owned presentation and its reason. UX-SYSTEM-001 revision 5 includes this accepted policy; Android remains the current verification target, with no additional platform implementation or release authorized here.

The owner subsequently selected right-aligned content-width popup actions and purpose-based dismissal under UX-DIALOG-001 revision 3. These choices apply consistently across platforms. The shared solid action-color pairs, including the swipe-delete surface, are accepted below. Global Back treatment remains proposed.

## Review direction picker — approved, 2026-10-15

The owner approved the round-2 direction picker: a clear title, close X at top-right, and two stacked full-width Soft filled buttons using the shared 24px radius. Each choice combines direction and due count and launches that direction directly, without an additional dropdown, Start or Cancel control. These are body choices rather than confirmation-footer actions. Keep the existing zero/one-direction bypass rules. UX-SETUP-001 revision 2 records this specific visual approval; it does not approve other screens or establish Android implementation.

## Compact collection learning actions and Speed setup — 2026-10-15

Keep normal review actions stacked with an 8px prototype gap, including below the Collection subtitle; remove the extra per-card top margins. The first displayed direction uses Piko blue/cream and the second the approved tint/navy pair. Speed uses a separate two-column row: equal halves with an 8px gap, one remaining action left-aligned at half width. Use the accepted gold/navy Speed pair under UX-SETUP-002; the earlier Tint/Primary and violet trials are superseded. Show each direction and its eligible new-word count visibly; hide zero-count directions. Availability follows filtered new-word eligibility, not normal-review due counts.

Manual vocabulary selection and manual Speed launch are Later (SPEED-004 revision 3), absent from the round-2 list and setup. The clicked Collection button fixes direction. The popup shows that direction as plain context and the filtered new-word count, without a dropdown or another pair of direction choices. Pool size is always visible, without a vocabulary picker or disclosure triangles. A bordered orange message explains the existing completion-time reset rule, not an immediate reset on an incorrect answer. Speed consumes shared palette roles live; slate and orange prototype pairs remain under `previews.round2` in `shared/design-config.js`. UX-COLL-008 revision 3, UX-SETUP-002 revision 4 and SPEED-005 revision 3 own current presentation/eligibility. The approved Overview direction picker is unchanged. Flutter behavior is not implemented by this mockup pass.

Historical verification before the latest deferral: 57 focused Node checks and browser checks covered the earlier learning-action/manual-selection prototype. Those manual-selection checks do not establish the revised scope. Current verification is recorded with the category/Speed refinement below; no browser evidence substitutes for Android acceptance.

## Inline categories and independent search controls — 2026-10-15

Category chips sit beneath the two-language pair, not between word and translation. General management appears only as Edit categories inside the ellipsis menu and expands in place: dimension name, two visible cardinality choices and value controls. No separate management page. A value-assignment popup uses the dimension name beside the existing Lucide layers icon as its sole heading. Empty/short lists have no search; an overflowing list gets a search field and a single scroll region. The prototype uses a shared maximum list-height token capped by available viewport space, not a product-level fixed item threshold.

Assignment and Filters popups stage edits and keep a trailing Apply/checkmark visible, disabled when unchanged or reverted; X/Escape/backdrop cancel pending edits. Filters keeps Clear filters visible alongside Apply and disables it when the pending selection is empty. Enabled-state changes do not move either action; use a compact real footer without an empty reservation, under UX-DIALOG-001 revision 5. Dimension name and cardinality share one changed-only labeled checkmark below both fields. Add value opens a compact inline input with a changed-only adjacent checkmark; validation and saving keep the assignment popup and draft intact. Newly created values are deliberately not autoassigned. Clear filters removes category constraints only, retaining search; the search field's X clears only search. Current category rules are UX-CAT-001 revision 7, CAT-009 revision 5 and FILTER-002 revision 5; the always-visible action decision was accepted on 2026-10-16 and remains unimplemented. Implementation remains a sample-data mockup until separately verified in the Android app.

Alphabetical values — accepted, 2026-10-16: show values A–Z within their existing category group in assignment/filter checklists, management and assigned tags/summaries, following CAT-009 revision 5. Keep search subsets in that order; after a saved create/rename, preserve selections, drafts and usable focus as the value takes its new position. Keyboard/accessibility order follows the visual list. Group ordering is unchanged, and manual value moving/custom ordering is Later. This replaces the value creation-order default in UX-CAT-001; no sort controls or drag handles are introduced now. Collation edge cases and app/mockup implementation/verification remain pending. F07 in the existing studio reference records this accepted addition.

Historical verification before alphabetical sorting: 68 focused Node checks cover category draft retention, duplicate/cardinality validation, independent clearing, adaptive search, popup dismissal, deferred manual selection and directional Speed eligibility. Browser checks cover expanding/creating a dimension within the menu, inline value creation without closing, explicit Single assignment, search appearing at actual list overflow, independent filter/query clearing and a real sample Speed completion that leaves only the reverse action at half width. German 320px controls have no horizontal overflow; Speed uses the live Tint value and displays the filtered count. The shared catalog generator/check passes. This is browser/sample evidence only, not Android verification.

## Shared action-color pairs — accepted, 2026-10-15

Historical color-selection evidence: the nine-color Piko decision above and UX-SYSTEM-001 supersede Cobalt and pure-white foregrounds in this dated comparison. Current filled primary/danger/success actions use cream; its white-pair contrast calculations below are not measurements of the current cream pairs. Preserve the action-role distinctions and verify the approved pairs during migration.

**Accepted selection:** The owner selected stronger backgrounds with white labels from the shared action-color comparison. UX-REVIEW-001 revision 4 and UX-SYSTEM-001 revision 5 require the solid semantic pairs below. The bright grading trial and the proposed soft red/green replacement are superseded. This feedback pass records the accepted specification; canonical token/adapter integration, interactive mockup changes and Android verification remain pending.

**Shared roles:** Keep ordinary Create/Save/Start actions in the Cobalt primary family; use green for Correct and explicitly positive/approval meanings, and red for Incorrect or destructive actions such as Delete/Discard. Keep safe Cancel/Close/Continue editing neutral. Incorrect and Delete share a color family while retaining different action semantics and context-specific emphasis. Preserve labels and existing layout. Feature-specific action palettes retain their owning rules; this decision does not recolor every confirmation green or every dismissal red.

**Accepted filled treatment:** Strong semantic backgrounds with white labels/icons. This is the explicit positive/negative exception to the general soft-button default; retain shared radius, spacing and type.

| Role | Background | Label/icon foreground | Text contrast |
| --- | --- | --- | --- |
| Positive / Correct | `#166534` | `#FFFFFF` | 7.13:1 |
| Negative / destructive | `#B42318` | `#FFFFFF` | 6.57:1 |

Cobalt primary retains the current `#E7EEFC` / `#2956B8` soft pair (5.78:1). Safe dismissals remain neutral; the comparison showed `#EEF0F4` / `#526177` (5.52:1), and existing low-emphasis unfilled controls may use the verified neutral foreground on their actual surface. Filled destructive confirmations and the revealed swipe-delete action use the accepted danger/white pair. Existing ghost/icon-text deletion variants remain red on their surface; a shared palette does not require every destructive control to become filled. The common filled treatment resolves the earlier light-red-versus-strong-red swipe choice under UX-VOCAB-DELETE-001 revision 3.

The configured trial uses `#111827` on `#EF4444` and `#22C55E`, calculating to 4.71:1 and 7.79:1. Its mismatch is a reported visual/style issue, not proof of failing text contrast. White on those same bright fills would be only 3.76:1 and 2.28:1, below the 4.5:1 normal-text threshold. Values are calculated from source hex colors using sRGB relative luminance, not estimated from screenshot pixels. [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) supports checking the actual foreground/background pair; [WCAG use of color](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html) supports retaining explicit labels alongside red/green meaning.

During the implementation pass, define reusable semantic pairs in `shared/design-config.js`, retain role-specific bindings and consume them through existing adapters/components. Verify default/pressed/focused/disabled presentation, readable active labels (at least 4.5:1), meaningful focus/control boundaries, English/German, enlarged text, and consistency across grading, approvals, destructive confirmations, safe dismissals and revealed deletion. Match the accepted popup layout and existing icon/text-only deletion variants. Interactive mockup and Android acceptance remain pending; source-color contrast is not full rendered-state verification.

## Comparable prototype fixtures — 2026-10-15

Both implementation-round previews consume `mockups/sample-data.js`: Korean Basics (5 entries), French A1 (3) and English Notes (3), with the same language pairs, vocabulary and ordering. Counts match the actual sample lists, replacing the old illustrative 128/64/32 totals. Each preview owns its mutable copy; reset restores the round-2 fixture without copying edits between rounds. Round-1 review starts at zero with the actual selected collection size, not a fabricated 12/30 session.

Overview cards retain the full localized target/native language pair and entry count beneath the title in both rounds. The code badge is decorative; accessible card text contains the full pair once. Review counts intentionally differ: round 1 shows distinct words, round 2 counts due directional items, so five new words due both ways produce 5 versus 10. That difference demonstrates the accepted counting change, not different vocabulary data. Categories and new controls remain round-2-only additions.

## Implementation-round-2 accepted changes and review draft — 2026-10-14

These rules supersede the corresponding older presentation descriptions below for Implementation round 2, not the preserved Implementation-round-1 preview:

- Vocabulary uses the same ghost `+ New` action as collection creation. Collection deletion is inside a neutral three-dot actions menu; its confirmation uses Cancel and Delete collection without X under UX-DIALOG-001 revision 3. Rename stays beside the title.
- Detail shows one full-width review action per nonempty direction with its own count, starting directly. Overview keeps one combined quick action; two available directions show a choice with counts, one starts directly, zero hides the action. Only a nonempty, fully caught-up Detail shows the encouraging message. Filter-empty, pending retry and errors are different states.
- Touch does not leave a thick focus outline on buttons/cards. Inputs have a subtle active border; hardware-keyboard focus remains visible. An edited inline card is compact, uses the shared red delete action, and exposes Finish plus Discard after changes.
- Entry scrolling is coordinated with actual visible height: no activation caused by keyboard animation, and no simultaneous competing recenter/scroll commands. Opening a new-entry draft and successful Save & Next always focus its first field and open or retain the keyboard. Prioritize both required fields above the keyboard when they fit, otherwise the complete first field; never inherit second-field focus from the preceding card. Next advances to the next field of the same entry; Done applies only to the final field. UX-ENTRY-001 revision 4 and ENTRY-001 revision 2 record the 2026-10-15 testing feedback; real Android verification is still required.
- The first vocabulary card follows the entry header with only normal shared spacing: no leading centering spacer, viewport-proportional top padding or retained blank scroll area. Apply this at the top of the stack to both draft and saved cards, including after keyboard changes, returning to the top and deletion/Undo. This 2026-10-15 decision resolves the earlier open leading-spacing refinement; mockup and Android acceptance remain pending.
- While another entry is active, the empty draft remains a compact card labeled New vocabulary with no placeholder word pair. Nonempty draft previews use actual input. Duplicate feedback explains the same-Collection pair conflict, offers no blind Retry, and refreshes when the editor is reopened; saved edits resume autosave if the conflict has cleared. ENTRY-005 revision 2 and UX-ENTRY-003/004 define these accepted outcomes. Canonical copy, interactive mockup and application changes are pending; this feedback pass updates specifications and the studio summary only.
- Review navigation uses an accessible icon-only back control. Long-term waiting shows remaining seconds and advances automatically. Progress has a visibly painted fraction, including 0%, 50% and 100%.
- The current `previews.round2` grading values (`#EF4444`, `#22C55E`, `#111827`) are an unaccepted historical trial. The 2026-10-15 color feedback supersedes that target with shared semantic background/foreground pairs under UX-REVIEW-001 revision 4. The current target is semantic red/green with cream under UX-SYSTEM-001; canonical token changes and interactive mockup integration remain pending; do not treat the old bright-fill/dark-label combination as approved.
- round-1/round-2 use one shared token/copy system and shared control primitives. The Implementation-round-2 controller owns isolated sample state; no local persistence, real FSRS, Android keyboard proof or production readiness is implied by its interactive behavior. The preview toolbar is tooling, not part of the future app.

Implementation-round-2 JSON review uses aggregate counts and one confirmation, never per-vocabulary Keep/Add/Replace decisions. Speed setup shows its fixed direction and filtered new-word count, with an editable pool size; manual selection is Later. Category CRUD/assignment/filtering is included, without advanced grouping or AI. See the canonical functional/UX IDs and the roadmap for the implementation sequence.

## Swipe-delete and Back-control research — 2026-10-15

**Accepted swipe correction — UX-VOCAB-DELETE-001 revision 2:** Only one saved vocabulary row exposes Delete at a time; opening another closes the previous reveal. Give the revealed action a red background that extends underneath the rounded foreground card, with continuous coverage and one outer row clip. Swiping only reveals; explicit Delete and eight-second Undo remain unchanged. Application and interactive mockup implementation/verification are pending.

**Accepted swipe color — UX-VOCAB-DELETE-001 revision 3, palette reconciled under UX-SYSTEM-001:** Use semantic danger `#B42318` with cream `#FFFDF8` icon/text. The prior 6.57:1 calculation used white and remains historical evidence only; verify the current pair in its rendered states. Apply this same pair to the revealed Delete surface. The lighter red alternative was not selected. Consume a tested semantic pair from `shared/design-config.js` during implementation; the red label/icon alternative in expanded editors remains separately styled. The continuous underlay, single-open-row and explicit-tap behavior remain unchanged.

Apple's [destructive swipe-button example](https://developer.apple.com/documentation/swiftui/buttonrole/destructive) uses a red background. Android's [swipe example](https://developer.android.com/develop/ui/compose/touch-input/user-interactions/swipe-to-dismiss?hl=en) uses red with a white trash icon and draws foreground content over a full-size background. Its swipe-to-dismiss behavior is not adopted: Piko still requires an explicit Delete tap. Material's [color-role guidance](https://m3.material.io/styles/color/the-color-system) supports deliberate foreground/background pairs; [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) requires at least 4.5:1 for normal text. These support the accepted color/layering choices; the one-open-row policy is the owner's explicit requirement, not a claimed universal platform rule.

**Proposed Back treatment, awaiting owner acceptance:** Use an icon-only Back control in a compact top navigation row, closer to the safe-area leading/top edges, without stacking body-content padding and generic text-button padding around it. Preserve system insets, the accessible localized Back/Exit name, keyboard focus and a 48dp Android target. Useful action labels such as vocabulary deletion can coexist with familiar navigation icons. Keep the current title/subtitle and navigation behavior; exact geometry needs review in the mockup, not a fixed measurement inferred from a screenshot.

Android's [app-bar examples](https://developer.android.com/develop/ui/compose/components/app-bars?hl=en) put an arrow icon in the leading navigation slot with a localized description; its [accessibility guidance](https://developer.android.com/develop/ui/compose/accessibility/api-defaults?hl=en) specifies 48dp interactive targets. Apple's current [toolbar guidance](https://developer.apple.com/design/human-interface-guidelines/toolbars) recommends standard Back/Close symbols without visible Back/Close text. Applying this consistently to Piko is a proposal: review navigation is already icon-only under UX-CARD-010, while Collection, entry and Settings need owner acceptance and coordinated spec revisions. Local code inspection found 18px mobile page padding plus 14px button padding before the Collection Back icon and 20px page-top padding after SafeArea; rendered-device verification remains pending.

## Popup design research and accepted family — 2026-10-15

**Accepted definition:** The owner selected right-aligned content-width actions and purpose-based dismissal after reviewing the alternatives. UX-DIALOG-001 revision 3, Updated 2 replaces the earlier X-on-every-popup rule and includes the previously reported alignment correction. UX-COLL-007 advances to revision 3 for the deletion confirmation. Round-2 prototype integration is recorded in the popup audit below; Android implementation and verification remain pending.

**Accepted shared layout:** Keep Piko's contained popup surface and common title/body edges. Put a present X in the top-right header slot aligned with the first title line, not vertically centered against a wrapping title. Use content-width actions grouped right, safe/secondary first and affirmative/destructive last. If labels cannot fit, stack full-width actions with affirmative above safe dismissal and matching semantic/keyboard order. Equal-width side-by-side actions were considered and not selected. Reuse canonical max-width 430, padding 24, title size 20/weight 700, radius 20, header gap 12, body/action gap 16 and action gap 8; minimum Android interaction targets are 48dp, with text allowed to grow. Implementation must consume these shared values rather than introducing independent defaults.

Use explicit Cancel/action choices without X for deletion confirmations; Continue editing / Discard & exit without X for draft-exit decisions; top-right X plus the primary action for forms/setup; and X without an extra footer for the review summary. Use outcome labels, not generic Yes/No. All dismissal paths retain the owning flow's safe behavior and pending-write guards. This accepted decision supersedes the earlier X-on-every-popup/no-Cancel rule. It does not add confirmation dialogs to reversible vocabulary deletion or turn inline validation into popups. The UX specification lists coverage and pending implementation acceptance checks.

The footer rule applies to footer actions, not body choices. The separately approved review direction picker keeps its two full-width direction/count choices and top-right X under UX-SETUP-001 revision 2, with no additional Start or Cancel footer. Category assignments and filters are editable selection forms, not direct-launch pickers: they keep Apply visible but disabled while unchanged, retaining explicit confirmation and safe cancellation under UX-DIALOG-001 revision 5.

Research consulted on 2026-10-15:

- [WAI modal dialog pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) recommends a visible way to close, which can be a close icon or a Cancel button; both are not required. It also defines contained focus, Escape and focus return, and advises considering initial focus on the least destructive action.
- [Android dialog guidance](https://developer.android.com/develop/ui/compose/components/dialog?hl=en) demonstrates a compact alert with confirm/dismiss actions and a separate custom-dialog path for richer content. The example supports different dialog roles, not a blanket X requirement.
- [Apple alert guidance](https://developer.apple.com/design/human-interface-guidelines/alerts) favors specific action labels and an explicit safe alternative for destructive decisions. This supports the purpose-based distinction; it is not a requirement to copy native Apple styling into Piko.
- [Material's legacy button guidance](https://m1.material.io/components/buttons.html) documents right-aligned standard-dialog actions with content-dependent widths, dismissal before confirmation. Its [legacy dialog guidance](https://m1.material.io/components/dialogs.html) describes stacking when labels do not fit and a leading X for full-screen modal app bars. These are established conventions, not claims about current Material 3 specifications; retain Piko's tokens and accessible targets instead of importing legacy button dimensions. No full-screen popup conversion is proposed.

Local inspection found that the Flutter shared header already uses top alignment, while its footer uses a Wrap without explicit alignment. This is a source-level explanation for possible variation, not a reproduced diagnosis of every screenshot. Review each consuming flow and the rendered Android result before claiming the defect fixed. That inspection was definition-only; the later popup audit below records round-2 prototype integration. Production Android behavior remains unchanged.

### Round-2 popup integration audit — 2026-10-15

Historical evidence: the changed-only visibility described below is superseded by the 2026-10-16 persistent selection-action decision. These checks do not verify revision 5.

The round-2 sample controller now applies the shared family to all eleven popup cases (menu, collection create/rename/delete, review direction, assignment, filters, dimension creation, category deletion, Speed and entry-draft exit), plus the reused review summary. At that round-2 checkpoint JSON transfer remained a page; the accepted round-4 shared popup above supersedes that arrangement. Assignment/Filters use changed-only Apply; a dimension confirms name and mode below the whole form; a single inline value retains its adjacent checkmark. Create collection and Start remain explicit actions even when their prefilled defaults are unchanged.

The shared footer measures available space and stacks affirmative above safe dismissal only when necessary, including DOM/tab order. Confirmations initially focus the safe action. Controls reuse shared tokens and 48px minimum targets, wrapping labels instead of clipping them. Modal viewport listeners and focus handlers are released when closing, replacing a popup or switching implementation rounds. The reused summary receives the same viewport fitting and cleanup.

Verification: 83 combined Node checks pass across shared catalogs, JSON, Speed, requirements parsing, sample data, learning actions and category UX. They include English/German coverage of all popup cases, changed/reverted selections, safe cancellation, draft retention, validation, form submission and listener cleanup. Browser checks verified changed-only assignment Apply and safe X cancellation, whole-form dimension confirmation at 320px, independent search/filter staging and Apply, and the stacked Delete/Cancel confirmation without X at 320px. Screenshots were reviewed locally. This is sample-prototype evidence, not Android or complete accessibility acceptance; enlarged text, assistive technology and real Android keyboard verification remain separate gates.

## Reference fidelity and usability — UX-SYSTEM-001

Owner clarification, 2026-10-14: the mockups are useful design references, not pixel-perfect requirements. Preserve confirmed choices such as soft-filled rounded buttons, shared tokens, Lucide icons and safe popup dismissal, now defined by the accepted purpose-based policy. Do not reproduce a layout merely because it exists in the mockup when it is awkward, incorrect or less usable. Prefer readable, accessible, consistent production layouts; record meaningful deviations and ask before materially changing the intended design. Earlier “binding” wording describes the reference and accepted interaction intent, not a requirement to preserve its defects.

## Actual session counters and progress — UX-CARD-012

Above each real hidden/revealed card and pending wait, retain a single fixed direction, completed/total unique launch members and first-try correct text. Use existing shared copy and semantic muted text; do not expose the current round's error count. Canonical `components.reviewContext` and `components.progress` adapt the binding's context gap/type/breakpoint and 7px ink-on-tint bar with 9px radius and 16px margins. Narrow metadata wraps naturally without clipping. Numeric progress-bar semantics include min/max/value and localized description.

English/German 320px/200% host tests verify counter containment, shared edges and margins above the card, accessible role/value and exact zero/half fill after accepted success. Browser adapter tests preserve reference dimensions. Scrolling is expected when context and enlarged cards exceed the viewport; prior reveal/grading fixtures now scroll before activating the same targets. Android rendering remains pending.

## Language-only Settings presentation — UX-SETTINGS-001

Use one shared level-one page title, ghost Back and language card/dropdown; English and Deutsch are the canonical option autonyms. No learning, direction, Hint, developer or theme preference appears in the implementation-round-1 route. Growable shared controls and page scrolling retain keyboard and touch access at English/German 320px/392px with 200% text; host tests verify single heading, menu/control containment, ≥44px targets and return to the same Home.

Actual binding measurements identified a 23px title-content-to-card gap (collapsed h1/card margins), not a literal 23px extra Flutter spacer. Reuse the canonical heading margin 7px plus `spacing.4` 16px; scoped browser Settings content uses the same sum. The binding card has 19px padding/1px border and a field with 17px outer vertical margins. Lift only that Settings field margin to `components.settings.fieldMarginY` and apply it around the Flutter dropdown, without changing shared PikoField or other screens. The resulting card-edge/field inset is 37px on both sides. This corrects measured host box geometry; font raster/glyph metrics and Android acceptance are not inferred from it.

## Hard aligned above real Correct — CARD-UI-015

The revealed card's action block has an empty left half and the shared Hard target in the right half, directly above Correct with the canonical grading gap. Align the full clickable label target, not the inset visual box: left/right edges and width equal Correct; the existing 8px inset remains. Labels wrap and targets grow at English/German 320px/200%; the decorative checkbox still renders 24px. The two grade buttons stretch to their maximum natural row height, preserving a common top/bottom when localized labels wrap differently, as the binding grid does. No new tokens, separate grade button or dynamic-width policy is added.

One semantic checkbox and Tab/Space/Enter control the modifier only. The actual session port disables pending/stale actions, while the child-owned successful revealed snapshot guards read/owner/covered lifetime changes. Failed grading retains selected Hard; next-card activation resets it. Host route acceptance is implemented, not Android or the later retry/progress/correction layout.

## Real equal-width grading — CARD-UI-025

The following records the round-1 implementation baseline. Round-2 color acceptance follows UX-REVIEW-001 revision 4 and the accepted shared pairs above; the earlier color checks do not verify that revision.

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

Owner feedback on 2026-10-16 identifies intermittent stalling and excessive fast-flick travel in the Android Collection Detail list. Revision 2 requires continuous direct dragging, controllable fling travel and preserved inline drafts. The local correction uses one lazy viewport for header and rows, retaining the active editor offscreen, with a Collection-only 3000 logical-pixels/second release-velocity cap. The cap is an implementation tuning value, not a visual token or product constant. Host regression and Android evidence are retained in the round-4 ledger. The owner deferred phone testing until more work is implemented; physical scrolling feel remains unaccepted.

The production Collection renderer consumes the binding compact row's 16px padding, 12px gaps and equal target/native columns with single-line ellipsis, expanding that same keyed card to the existing 19px card padding and 16px radius. The inline header uses shared body/title typography; language labels and inputs retain the binding 750 label weight. Field columns switch by viewport width at `components.inlineVocabulary.compactBreakpoint` (420px); generated responsive CSS and Flutter share this editable source. `captionSize` extracts the matching 11px muted caption, with existing 8px spacing above it and 12px error spacing. At the UX-COLL-009 stage, no Delete, Finish or Discard placeholder controls were introduced; actual Delete and Finish integration follows under UX-COLL-011. Host checks cover 420/421px layout, keyboard activation/focus visibility and German 392px at 200% with simulated keyboard inset; actual device inline-editor evidence remains pending.

## Shared popup implementation — UX-DIALOG-001

`components.dialogs` centralizes the existing mockup maximum width (430px), title size (20px), backdrop color and opacity. Popup titles reuse the canonical 700 title weight; padding, header gap and radius reuse shared spacing/radius tokens. Both CSS and Flutter consume these values. The round-1 baseline has a flat, untinted surface and scrolls within the available keyboard-safe height. It uses X on every popup and omits generic Cancel; this presentation is superseded for round 2 by UX-DIALOG-001 revision 3. Round-2 prototype integration is recorded in the audit above; Android implementation is pending. Confirmations use explicit safe/action choices without X, forms/setup retain X plus the primary action, and summaries retain X alone. All footer actions follow the shared right-aligned/stacked rule. Safe dismissal and focus restoration, contained Tab navigation, pending-write guards and reduced-motion support remain required. Earlier Android implementation evidence does not verify the revised presentation.

**Historical exploration status:** The older Cobalt, font and platform choices below are superseded by the approved Piko palette, accepted typography and Flutter direction. Catalog/live preview experiments remain drafts; current accepted rules and pending migration are defined above.

## Single design configuration — 2026-10-13

`shared/design-config.js` is the sole editable source for reusable UX configuration. This supersedes earlier directions to edit `theme.js` or `design-tokens.css`: those files are compatibility adapters, not independent configuration sources. `design-runtime.js` maps the data to CSS variables before the prototype loads. The studio and standalone mockup consume exactly the same file; reload them after an accepted source edit. The Flutter adapter is generated from this configuration; reusable Flutter primitives consume its values without independently maintained defaults.

The schema owns `colors`, `spacing`, `typography`, `radii`, `controls`, `components.buttons` and `components.dropdowns`. Numeric dimensions are CSS px, `motionFastMs` is milliseconds, and weights are numeric. Buttons default to Soft filled / 24px. The studio's **Export design config** combines the current palette and both component drafts into one reviewable config file, retaining untouched values. Copy/i18n stays in its separate wording catalog. Local palette favorites remain optional experiment sets rather than canonical design configuration. Partial CSS exports are experiments only; accepted changes must be consolidated into the one config file.

The runtime validates colors, numeric ranges and minimum 44px controls. Recurring field, card, icon, border, focus, disabled and page-inset values are promoted from the binding CSS into component, state and layout configuration. Flutter uses minimum heights rather than clipping enlarged text. The round-1 baseline uses solid red/green grading and red ghost deletion actions; the accepted shared round-2 color treatment is governed by UX-REVIEW-001 revision 4 and awaits integration/verification. CSS media-query breakpoints and feature-specific geometry still remain in CSS; the matching mobile breakpoint is recorded in configuration for Flutter. Reduced motion disables component animations. This infrastructure does not claim completed product screens or icon/dialog integration.

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

## Historical palette candidates — superseded

Retained as decision history only; these alternatives are not active presets in the accepted migration target.

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

- Broader visual tone beyond the accepted Piko mascot usage; placement for later Collection poses and Speed-completion feedback placement/lifetime still need review.
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

Historical 2026-10-13 exploration, superseded by the all-round Piko palette decision above: the owner preferred cooler colors, rejected the green direction, and selected Cobalt as the then-current baseline. Primary, Tint, Background, Surface, Main text, Secondary text, and Text on primary are directly editable in the studio through color pickers and hex inputs. Plum remains an alternative. Export theme.js to persist experiments into shared/theme.js; the standalone mockup consumes those same visual roles.

The visible Minimum flow is accepted: create/open a collection, manually enter vocabulary, and review through Long-term self-assessment. The homepage starts with a compact Piko identity and Settings top-right, then a due-review summary and collection list. Expanded scope adds secondary actions for extension stress-testing. It does not approve all 44 proposed Minimum labels or declare a release milestone.

The owner requested removal of the standalone icon comparison page and its studio panel after reviewing the candidates. Source SVGs and license notices remain under mockups/assets/icons. Lucide is now explicitly selected and implemented for the prototype interface.

## Implementation-round-1 entry stack prototype — 2026-10-13

UX-ENTRY-002's production header follows the effective binding grid, not the earlier superseded flex layout: Back takes its intrinsic width, the title centers in the remaining middle track and a 48px primary global action occupies the right track, with canonical 10px gaps. Header title size is 22px, changing to 18px at the canonical 400px viewport threshold. Back has zero visual padding, weight 750 and body/compact-small text while retaining a minimum 44px hit height. Shared page-top 20px and title margins are reused. The generated CSS responsive block and Flutter adapter share the breakpoint; English/German names distinguish final completion from the card's 48px Save & Next. At large text the title wraps and controls remain available; centering is within the middle track, not an inaccurate promise of viewport-center symmetry.

The production UX-ENTRY-001 adapter now centralizes the effective binding entry geometry: 16px card padding/gap, 5px preview gap, 14px preview top inset, 12px entry numbers, 11px status labels, 1.5 metadata line height, a growable 100px compact minimum and 200ms state transitions. Its primary Save & Next target has a 48px minimum. Reduced motion suppresses transitions. Viewport heights, edge padding and precise activation thresholds remain measured rather than adopting experimental prototype constants. The header arrangement remains separately owned by UX-ENTRY-002. Production persistence is real; the mockup remains an explicitly labelled sample session.

Manual entry now demonstrates three confirmed sample cards and a new draft in a vertically scrollable stack. The nearest central card expands without a tap; scrolling back opens previously confirmed samples for automatic in-memory edits. A localized card checkmark confirms the new entry and opens the next draft. Back stays top-left and warns before discarding a nonempty draft. A distinct global completion checkmark sits top-right outside the cards: it confirms a valid final draft and exits without another card, exits directly for an empty draft, and keeps incomplete nonempty input open with validation. Draft values survive scrolling and live catalog/theme updates. Collection language labels and sample vocabulary follow the selected Collection's language pair. The earlier open refinement for excessive leading blank space is now resolved by UX-ENTRY-001 revision 4: no artificial space before the first vocabulary card. The implementation-round-1 preview remains historical; mockup and application changes are pending.

The stack deliberately does not focus an input or open the keyboard when scrolling. Keyboard users can focus the stack and navigate cards with Up/Down; only active-card fields are in the tab order. Motion respects reduced-motion preferences. Prototype viewport padding and active-card sizes remain experiments, not finalized production animation thresholds. In the mockup only, confirmed edits remain in page memory and reloading loses them. Production repository persistence and focused-screen Android keyboard/safe-area evidence are now established under their respective requirements and UX-ENTRY-001; full release durability gates, routing and deletion/Undo remain separately tracked, not completed by this presentation work.

## Implementation-round-1 self-assessment review prototype — 2026-10-13

Choose one direction in a minimal pre-start dialog; the session shows it once as noninteractive context and cannot change it. The dark progress bar keeps the completed/total counter. The card itself reveals by tap or keyboard; no separate Show Answer button appears. A small Lucide book-open icon sits with the lower-right Tap to reveal cue on the question only. Revealed cards remove the cue/status, show the original prompt smaller/muted (22px), and emphasize the translation (37px) using Collection-specific vocabulary. Incorrect is red on the left and Correct green on the right at equal widths; Hard sits directly above and aligned with Correct, with a full-column clickable label at least 44px high and a 24px checkbox. It applies only to Correct. Previous-review correction has an explicit label and Lucide back arrow, replaces the immediately preceding sample grade and rolls back displayed sample progress before regrading. Its red unfilled outline is a trial, not an accepted final style. Skip and typed-answer controls are not presented in this implementation-round-1 review prototype.

The `noDue=1` mockup query parameter demonstrates the no-due state when opening Review. Counts and corrections are illustrative page-memory changes, not actual review history, retries, persistence or FSRS scheduling. Production queue/state consistency remains required by UNDO-001 but is not implemented by this prototype.

## Local palette generator — 2026-10-13

Named favorite sets store all seven semantic roles locally in this browser's localStorage. Saving does not change shared/theme.js or create an application preference. Selecting a set replaces the whole draft palette and supports palette Undo; generator locks remain unchanged and only constrain generation. Delete requests confirmation. Portable JSON export/import provides backup or transfer between browsers; import validates schema version, unique names, seven hex values and a 40-set limit, and confirms before replacing existing favorites. Browser storage may be unavailable or cleared, so export is the durable backup; failures are reported rather than claiming successful storage. No remote service, account, credentials or automatic repository writes are involved.

The studio offers a local generator inspired by the owner's Coolors reference, without an external API or service. Experimental harmony is the default: complementary, split-complementary and triadic hue relationships give Primary and Tint deliberately contrasting hues, with subtly colored backgrounds/surfaces and readable dark text. Related cool remains an optional quieter Cobalt-through-Plum direction. This supersedes the initial same-hue default, which the owner found too conservative. Generate palette updates the seven existing semantic roles and the preview immediately. Each role can be locked during generation; manual editing remains possible, and Undo restores the preceding palette. Reset and Plum explicitly replace the full palette, regardless of generator locks. Space generates only while the palette tool itself has keyboard focus, never while editing fields or activating controls.

Generation tries a bounded set of harmonious light-theme candidates and prefers the four displayed text pairings at 4.5:1 or better. Locked values can make that impossible; the best candidate is shown with the existing contrast warning rather than changing a locked value or claiming a full accessibility pass. Focus, feedback, borders and all actual component states still need separate checks. Generated colors remain draft experiments; export produces syntactically valid theme.js, and canonical changes still require accepting and replacing shared/theme.js. No generated palette is silently committed or selected as the final design.

## Requirements views

All popups use the same reusable shell and the accepted UX-DIALOG-001 revision 3 policy: explicit safe/action buttons without X for confirmations; localized top-right X plus the primary action for forms/setup; and X alone for summaries. Footer actions are content-width and right-aligned, stacking when needed. Escape/backdrop safely dismiss and restore focus. Dismissing a destructive confirmation never deletes; draft-exit safe dismissal preserves the draft and stays in the editor. This supersedes the earlier all-popup-X/no-Cancel presentation. Round-2 prototype integration is recorded in the audit above; the round-1 comparison retains its baseline and Android changes remain pending.

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

## Persistent selection actions — accepted, 2026-10-16

Use the same visible action set throughout each editable selection popup. Apply is disabled while unchanged/reverted. Filters also keeps Clear filters visible, enabled only for a nonempty pending selection. State changes update enablement and shared disabled styling without moving actions, title or rows; retain the current content-width/right-aligned and narrow-layout stacking rules. Size the popup to its content and real footer with one shared gap, not an additional blank action slot. Preserve labels, non-overlapping 48px targets, readable disabled states and semantic disabled behavior.

The owner also reports misaligned close controls across popups. Align the X glyph with the first title line using the shared header, retaining its full touch target even when the title wraps; this is a fix to the existing rule. The footer choice does not add actions to summaries/direct-launch pickers or change inline save rules. No unconditional stacking decision was made.

UX-DIALOG-001 revision 5 (Fix 3), UX-CAT-001 revision 7, CAT-009 revision 5 and FILTER-002 revision 5 carry this popup change; the latest category revisions also include the separately accepted alphabetical-value default. Reproduction evidence and acceptance scenarios are in the UX specification; the Design Lab reference reads the updated F03 register. Shared component/token integration, mockup/app implementation and Android verification remain pending.

### Standard dialog layout baseline — accepted, 2026-10-16

The owner accepted simplifying the shared popup component around standard framework behavior. Use Flutter AlertDialog title/content/actions and overflow layout where they satisfy the existing Piko contract; use Dialog directly only where a popup purpose needs additional layout control. Keep one shared Piko wrapper and canonical theme rather than separate screen-specific popup layouts. Preserve purpose-based dismissal, the explicit X where required, 48px targets, large-text/body scrolling, focus restoration and pending-write guards. Standard components do not replace the accepted action-state rules or justify platform-dependent product behavior.

Remove the separate hidden-action reservation and competing calculations for possible versus rendered actions. Persistent visible/disabled controls should participate in one real layout. Verify unchanged, changed, cleared and reverted states with an already-visible Reset/Clear action as well as a single Apply action; assert button positions and X glyph alignment, including horizontal/stacked layouts and wrapping titles. Existing tests of title/row bounds and close-target top edges are insufficient for these findings.

This is an implementation approach for UX-DIALOG-001 revision 5, not a further behavior revision. The earlier UX review preserved changed-only Apply; the subsequent persistent-action decision supersedes that choice. App/mockup changes and native verification remain pending a separately explicit implementation scope.
