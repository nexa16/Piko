# UX consolidation — accepted implementation criteria

Reconciliation status, 2026-10-16: this preserves the accepted preparation criteria. Round-3 checkpoints 1–4 now record related implementation and scoped verification in [implementation-round-3.md](implementation-round-3.md). F01–F18 retain their recorded specified status until their complete acceptance criteria receive finding-specific evidence; historical preparation statements are not claims that the current app is unimplemented. New implementation is not authorized by this record.

Design handoff accepted on 2026-10-16. All findings retain specified status; related app implementation is recorded separately in the round-3 ledger. Owning requirement revisions and DESIGN.md are authoritative; this register view is the implementation checklist.

## F01 — Give Save & Next and Finish visibly different names

Status: specified. Requirements: UX-ENTRY-002 r2, UX-SYSTEM-001 r6.

- Visible Save & Next on the draft and Finish in the page action area; preserve validation, persistence and exit behavior.
- Use a growable text action rather than a fixed icon-width slot. On narrow/enlarged layouts the title gets its own row; navigation and Finish stay reachable.
- Inline Finish editing and Discard changes remain distinct; place autosave status beside those controls.

## F02 — Make the JSON workflow’s next action and result obvious

Status: specified. Requirements: UX-IMPORT-JSON-001 r3, UX-IMPORT-JSON-002 r2, UX-SYSTEM-001 r6.

- Follow UX-IMPORT-JSON-001 revision 3 and UX-IMPORT-JSON-002 revision 2: distinct Import and Export views; example → input → replacement choices/check → result/import.
- Make the applicable next action prominent and place success/errors next to the step that produced them.
- Retain stale-preview invalidation, atomic apply, existing learning preservation, pending guards and return to the owning Collection. Pair with IMPORT-JSON-003 only if that feature is scheduled.

## F03 — Keep selection dialogs still while their footer changes

Status: specified. Requirements: UX-DIALOG-001 r4, UX-CAT-001 r5, FILTER-002 r4.

- Changed-only Apply remains absent when unchanged/reverted.
- Selecting an item or exposing Clear filters does not move the title or selected row; reserve footer space inside a bounded shared selection shell.
- At insufficient height the body scrolls, footer/actions remain reachable, and safe dismissal/focus restoration are preserved.

## F04 — Tighten Collection Detail’s vertical rhythm and alignment

Status: specified. Requirements: UX-COLL-008 r4, UX-HEADER-001 r1, UX-HEADER-002 r2, UX-MASCOT-001 r2, UX-COLL-007 r4, UX-SETUP-002 r7.

- Use one leading alignment for title, direction labels, search and list content; retain the useful language/count subtitle. Speed preview: left-align both text lines on a common edge beside the lightning icon; preserve the two-column layout and allow wrapping. Accepted during four-state review.
- Adopt shared 4/8/12/16/24 spacing steps; remove additive margins instead of reducing touch targets.
- Use a compact navigation row with one icon-only Back, 48 logical-pixel target and localized name; retain existing Back behavior and the accepted 64px mascot slot.

## F05 — Move the palette closer to Piko’s blue, cream and navy

Status: specified. Requirements: UX-SYSTEM-001 r6, UX-MASCOT-001 r2.

- Map every app-owned semantic role to the nine allowed colors or documented alpha blends; keep original artwork and OS-owned interfaces exempt.
- Define primary, secondary, safe, disabled, pressed, focus, warning, danger and success states together. Do not rely on unreviewed ColorScheme.fromSeed defaults.
- Use cream text on blue/red/green, navy on gold; grade labels and behavior remain explicit.

## F06 — Give dialog backdrops a neutral navy cast

Status: specified. Requirements: UX-DIALOG-001 r4, UX-SYSTEM-001 r6.

- Use palette navy as dialog backdrop at the existing opacity first; check both text separation and the underlying artwork.
- Change opacity only after a contextual comparison; retain one shared backdrop mapping.

## F07 — Align category rows and clarify management levels

Status: specified. Requirements: UX-CAT-001 r5, UX-SYSTEM-001 r6.

- Align group titles, field labels and value rows to common leading edges.
- Distinguish group/value levels with 8/12/16 spacing and a subordinate text role; avoid divider-per-row decoration.
- Keep in-place management, two visible selection modes, changed-only confirmation and explicit assignment. No new management page or reorder.

## F08 — Wrap review progress deliberately

Status: specified. Requirements: UX-HEADER-001 r1, CARD-UI-002 r1, UX-REVIEW-004 r2.

- Give direction its own row; show completed/total and first-try-correct as complete label/value groups below it.
- Let groups wrap as units, not an orphaned last word. Preserve counts and first-try semantics.
- Use the same first-try wording in progress and summary.

## F09 — Use a correction role instead of a danger role

Status: specified. Requirements: UX-REVIEW-002 r2, UX-REVIEW-003 r2.

- Use primary outline/text for the correction action, with the existing undo icon.
- Label context explicitly as Previous grade: Incorrect/Correct; retain Hard when applicable.
- Only expose on the hidden question side; exact history correction and guards are unchanged.

## F10 — Make the empty Collection’s first step more direct

Status: specified. Requirements: UX-COLL-003 r3, UX-COLL-008 r4.

- For a genuinely empty collection show one prominent Add first word action below the Vocabulary heading, following UX-COLL-003 revision 3 and one brief explanation.
- Omit search/filter controls while there are no entries; restore the normal toolbar as soon as entries exist.
- Do not apply this treatment to loading, errors, filtered no-results or nonempty no-due states.

## F11 — Show enough active-filter context outside the popup

Status: specified. Requirements: UX-CAT-001 r5, FILTER-002 r4.

- Show Filters (n) for active confirmed filters, counting distinct selected category-value IDs.
- Use an accessible full label; keep Clear filters separate from clearing the search query.
- Keep selected-value summaries inside the existing dialog in the first implementation; do not add a second chip toolbar.
- When confirmed category filters are active, show Clear filters beside Filters (n) in the toolbar. It clears those filters directly and preserves search; popup Clear filters remains staged until Apply.

## F12 — Make Speed setup easier to scan without hiding its rules

Status: specified. Requirements: UX-SETUP-002 r7, SPEED-006 r1, SPEED-008 r2.

- Keep direction, eligible count, warning and pool-size control visible.
- Separate explanation into Rules and Leaving this round; preserve complete-pass, N=1 and completion-time reset semantics.
- Explicitly distinguish discarded unfinished work from already committed completed-word results.

## F13 — Consider a modest completion cue for Speed

Status: specified. Requirements: SPEED-008 r2, UX-MASCOT-003 r2.

- after all words complete, show one inline completion notice on Collection with count and a top-right X dismiss control (48 logical-pixel target, localized accessible name). Accepted during four-state review.
- Keep it until close, another learning launch or leaving that Collection; no timer, extra summary popup or new mascot.
- No notice on exit, interruption, failed completion write or empty launch. Announce once politely without stealing focus.

## F14 — Separate essential field boundaries from decorative borders

Status: specified. Requirements: UX-SYSTEM-001 r6.

- Use supporting-text color #62657D for essential enabled field boundaries on cream; focus uses primary and error uses red plus explicit text.
- Decorative card borders retain a quieter documented navy alpha; do not reuse that treatment for essential fields.
- The earlier #8A8FA6 proposal is superseded; no additional independent grey token.

## F15 — Give the Speed consequence warning clear visual emphasis

Status: specified. Requirements: UX-SETUP-002 r7, UX-SYSTEM-001 r6, SPEED-006 r1.

- Use 12% red over cream, red icon/heading/border and navy body; solid red remains for Incorrect/destructive actions.
- Use a compact heading; preserve the full condition: completed after a mistake, studied direction only, opposite unchanged.
- Verify large-text warning, control and launch action remain reachable without horizontal page overflow.
- Preserve the newer UX-SETUP-002 conditional trigger: no warning or reserved warning space without actual existing studied-direction progress; no warning for entirely new-word rounds.

## F16 — Consolidate typography and reflow rules

Status: specified. Requirements: UX-SYSTEM-001 r6, UX-HEADER-002 r2, UX-ENTRY-002 r2, UX-I18N-001 r2.

- Use selected Nunito Sans through explicit browser and Flutter family/weight adapters; verify German and Korean glyphs and fallbacks offline.
- Accepted type roles: page title 26/700/1.2; dialog 20/700/1.3; section 18/700/1.35; body and input 16/400/1.5; control 14/700/1.4; helper 14/400/1.45; answer 37/600/1.3; revealed prompt 22/400/1.4.
- Remove inherited bold field-input text and decorative negative title tracking; title/action layout must reflow before forced character-level breaks. Long unspaced content may break as a last resort without shrinking accessibility text.

## F17 — Keep learning-state wording accurate in both languages

Status: specified. Requirements: UX-COLL-008 r4, UX-REVIEW-004 r2, UX-I18N-001 r2.

- No-due text describes current due work, not permanent mastery.
- Completed-count wording describes the session metric without promising durable learning.
- Use equivalent EN/DE meaning; distinguish completed, correct on first try and currently due in every context.

## F18 — Use consistent user-facing vocabulary and category terms

Status: specified. Requirements: UX-CAT-001 r5, UX-ENTRY-002 r2, UX-I18N-002 r2.

- Accepted user-facing pair: Category group / Kategoriegruppe for a dimension, Value / Wert within its named group; the visible assigned representation remains a tag.
- Apply the same terms to create, edit, validation, failure and deletion copy. Internal IDs and JSON names remain unchanged.
- Prefer Vocabulary/Vokabeln in page titles and help; avoid technical entry-session jargon. Keep Speed/Intensiv lernen as existing mode names for now.
