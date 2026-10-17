# Round 6 planning and implementation ledger

## Expanded execution authorized — 2026-10-17

The owner requested implementation of the selected statistics, vocabulary-selection,
Collection-header and documentation packages, plus UX-ANCHOR-001 r1 / UX-COLL-001 r7
for affected Collection flows. Broader app-wide anchoring and full export remain
excluded. Work proceeds through dependency-complete verified checkpoints; later
packages may be deferred. The first checkpoint addresses Collection anchoring.
Important changed pages receive normal-size English captures, with targeted
narrow/enlarged checks where required. Existing publication and phone gates remain.

Workspace cleanup preserved both old specification worktrees in verified private
archives before retiring their checkouts. Their branches and unique commits remain.
The documentation definitions referenced below are recoverable from the private
archive index; the existing canonical owners remain active until reconciliation.

## Current scope additions — 2026-10-17

The owner added the packages below to the current round-6 implementation scope and will provide further additions. This selects pending implementation work; it does not start app implementation or alter the existing build-5 candidate. Earlier planning-only/unassigned statements below describe the prior scope. Await the owner's explicit request to execute the clarified batch; no new app, migration, APK or Android verification is claimed.

| Added package | Owning definition | Pending outcome and verification |
| --- | --- | --- |
| Current-app documentation rework and private planning | DOC-001–007 r1; UX-DOC-001/002 r1; UX-LAB-001 r5 | Rewrite the README as a concise current-app entry point; provide the extensive feature guide, technical reference, authentic product screenshot gallery, one source/APK manifest, developer setup and maintenance procedure. Move planning/decisions/history into the ignored private store with preservation and link/consumer checks. Documentation implementation remains pending; see the handoff below. |
| Statistics | UX-STATS-001 r2, UX-STATS-002/004 r2, UX-STATS-003; STATS-005 r2, STATS-006 r1, STATS-007 r2, STATS-008–010 r1, DATA-005 r2; UX-STATS-005–007 r1; PARAM-STAT-002 r1; MASCOT-004 / UX-MASCOT-004 r2 | Implement the approved Activity/Long-term/Speed visual contract and now-complete production data definitions. Follow the definition-ready handoff below for migration, atomic credits, preservation, date boundaries, tests and Android comparison. Separate full export remains unscheduled. |
| Vocabulary selection | VOCAB-SELECT-001 r1 / UX-COLL-013 r3; SPEED-004 r4 exclusion | Implement the approved selection-only guide: long press/toggle, matching Select all, global Clear selection, hidden selection retention, navigation reset, three card states and non-overlapping floating panel. See the approved handoff below for tests, Android checks and preserved reference. No bulk operation or learning launch from selection. |
| Collection Detail header | UX-COLL-008 r7 / UX-SETUP-002 r9; REVIEW-001 r4 / SETUP-008 r4 | Implement the persistent shrinking title/count header, compact Review/Speed icon-and-count controls, disabled zero counts and existing direction/setup routing. Preserve list, learning and data state. Exact transition/layout details remain proposals under the owning UX specification; resolve routine details through accepted design autonomy. Add behavior tests and revision-specific Android scrolling, accessibility, enlarged-text and launch/preservation checks. |

The owner is still collecting additions; vocabulary selection is now explicitly selected under the approved handoff below. Other unselected features are not added by inference. Preserve the existing candidate and its evidence until an expanded candidate is built and verified. Owner review, public-data approval and exact-candidate phone acceptance remain required for the expanded result.

**Status, 2026-10-17: the owner selected the approved vocabulary-list rework under UX-COLL-001 r6 / F20–F21 and the accepted FSRS learning-help icon under LEARN-007 r2 / UX-LEARN-007 r1 for round-6 implementation. The approved statistics design is also selected for round-6 planning, with production definitions now complete and separate Flutter authorization pending. F22's bounded first checkpoint did not establish the Android cause; the owner subsequently could no longer reproduce it and withdrew it from pending work. Both app packages are locally implemented and the final isolated Android acceptance passes. One normal build-5 candidate is ready for owner review; owner review/phone acceptance remain pending.**

## Documentation rework handoff — 2026-10-17

The owner explicitly adds the previously specified README/current-feature documentation rework and Git-ignored planning migration to round 6. The owning definitions are preserved in the separate `codex/documentation-specs` checkout: `.local/worktrees/documentation-specs/docs/piko-functional.md` (DOC-001–007 r1), `docs/piko-ux.md` there (UX-DOC-001/002 r1; UX-LAB-001 r5), and its decision record. Reconcile these bounded definitions into the active canonical owners before execution, preserving concurrent work; do not replace whole documents with the older checkout. This selects the package without starting the documentation migration or selecting an APK now.

The current documentation must describe only implemented behavior in one explicitly identified source/APK. Keep current limitations beside their tasks; plans, supersession narratives and round history belong in private planning. Use one authoritative home per topic, stable links, one build/capture manifest and real ordinary-product APK screenshots with synthetic data and truthful provenance. Instrumented/mockup images cannot substitute for product captures. Verify source claims, visible flows, links/anchors, screenshots/checksums, rendered readability and applicable setup commands; retain explicit gaps.

Use the accepted ignored `.local/planning/index.md` with `records/` and `history/` for planning/decisions and preserved originals. Inventory and verify recoverable private copies, original metadata, IDs, evidence and dependency/link mappings before removing their old paths from the next tracked tree. Existing Git history is retained; no history rewrite or retroactive privacy claim. Update agent/contribution instructions and specification-reader consumers during migration. Preserve historical mockups with dependencies; shared assets/configuration used by the app stay tracked. Keep a single execution ledger and avoid duplicate planning registers. The existing `.local/` ignore rule alone does not untrack existing files. No migration, untracking, screenshot capture, app change or publication has been performed for this planning addition.

## Branch and baseline

- Current preparation branch: `codex/round-6-expansion`, created at `57f1ef7` on 2026-10-17 at the owner's request. It retains the existing round-6 implementation and all uncommitted specification/mockup/copy drafts. Statistics, the Collection Detail header and the subsequently owner-selected vocabulary selection remain pending work; branch creation does not start implementation. Interaction anchoring retains its own documented planning status.
- Original implementation branch: `codex/round-6-implementation`, retained at the same source commit.
- Base: latest fetched `develop`, `1e3f520061e8ce4cb07da247b8e6c4b145c5ef98`, the owner's squash merge of [PR #6](https://github.com/nexa16/Piko/pull/6).
- The merged tree exactly matches published PR head `ee59a1d480dcdd8286601a0f0df6e1dc33716771`.
- The [round-5 ledger](implementation-round-5.md#owner-merge-and-next-branch-handoff--2026-10-17) owns prior implementation, candidate provenance, verification boundaries, owner merge and preserved-draft evidence. The candidate update/appearance check passed by owner report; detailed phone-flow acceptance remains unverified.

Both Piko chats share the main checkout on this branch. Existing uncommitted Collection-list specification/mockup/copy preparation is preserved; the retired auxiliary mockup draft and old Git history have verified private backups. Preparation and branch creation do not accept those drafts as implementation scope.

## Selected scope and checkpoints — 2026-10-17

| Package | Owning definition | Outcome and boundary | Status |
| --- | --- | --- | --- |
| Vocabulary-list rework | UX-COLL-001 r6; GROUP-001 r2; FILTER-002 r5; F20/F21 | Implement the fully approved guide in the Flutter Collection Detail list: search and independent Filter/Group/Sort chips, local list menu, contextual group action, left-aligned headers, stable result-start geometry and preserved Compact/Detailed cards. Keep stored preferences, vocabulary, editor and learning behavior intact. | Locally implemented and scoped Android-verified; owner acceptance remains pending. |
| Learning-help info icon | LEARN-007 r2; UX-LEARN-007 r1 | Add the single info trigger to Collection Detail's language/count metadata row and its accepted two-section How learning works dialog. Integrate equivalent EN/DE copy through the shared catalog, with accessible controls and responsive text. Opening help must not change learning, vocabulary or list state. No scheduler, grading, statistics or proficiency changes. | Locally implemented with shared EN/DE copy and scoped Android verification; owner acceptance remains pending. |
| Statistics planning | UX-STATS-001 r2, UX-STATS-002/004 r2, UX-STATS-003; STATS-005 r2, STATS-006 r1, STATS-007 r2, STATS-008–010 r1, DATA-005 r2; UX-STATS-005–007 r1; PARAM-STAT-002 r1; MASCOT-004 / UX-MASCOT-004 r2 | Preserve the owner-approved exact mockup appearance for homepage Activity and detailed Long-term/Speed statistics. The owning requirements now define production Speed counting/deduplication, fresh history, preservation/import/correction, clock/timezone and loading/error behavior. | Definition-ready; approved mockup saved separately. Flutter implementation and Android verification require a separate explicit request. Separate full export is unscheduled. |
| Optional-content typing focus | F22; UX-COLL-009 r2, UX-COLL-011 r4, VOCAB-EDIT-001/002 | Reproduce Hint/example editing with a real Android keyboard and synthetic data, recording build, initial state, exact actions, expected/actual result and repeatability. If the mechanism is established, make a focused repair with regression tests and repeat the same Android sequence. | Withdrawn at owner request on 2026-10-17: no longer reproducible by the owner; no verified fix claimed. Historical investigation retained below. |

The list rework has three dependent checkpoints. First, replace the combined View entry point with the approved heading menu and shared Filter/Group/Sort controls in `collection_detail.dart` and `collection_view_controls.dart`; retain the existing search field, preference service, staged dialogs and independent resets. Second, adapt the grouped headers, result/bulk row and Compact/Detailed card presentation in `collection_vocabulary.dart` without changing stored identities or learning state. Third, verify control state transitions and preservation with focused widget tests, run analysis and affected regression, then compare the actual Android surface against the approved guide before building the owner candidate. Keep the shared copy/configuration adapters generated from their canonical sources.

Start with F22 evidence and the list control's dependency review, then complete the list surface as a dependency-complete package. Add the learning-help icon/dialog as a separate small checkpoint: generate the shared EN/DE catalog adapter, integrate the icon and dialog using shared components, test open/disclose/dismiss/no-state-change behavior, and inspect the accepted narrow/enlarged Android states. At each checkpoint record the source commit, changed tests, Android states and limitations; the final candidate requires an immutable APK, checksum, final regression and the owner handoff under AGENTS.md. No publication, release, tag or store upload is selected.

Statistics is a planning package, not part of the current app candidate until the owner separately requests Flutter implementation against the now-complete production definitions. Other learning candidates, proficiency/Mastered, manual Speed selection and unrelated findings are excluded. FSRS help is limited to the LEARN-007 / UX-LEARN-007 information affordance and explanation; it does not change scheduling. Round-5 detailed phone-flow acceptance remains unverified; do not recast its update/appearance check as flow acceptance.

The approved statistics source is local commit `9b4a977` on `codex/statistics-mockup`, based on `develop` `1e3f520`. Its `docs/statistics-mockup.md` Approved visual contract, interactive `?preview=statistics` profile, synthetic reference captures and source-hash manifest are the preserved exact-appearance guide. The main checkout has concurrent Collection-list mockup/copy changes, so importing that source and its generated catalog requires a deliberate file-by-file reconciliation; no approved asset or state should be overwritten. Integrate the approved source and references before any PR/publication that claims this visual contract, so the public documentation stands on its own. The canonical functional and UX requirements now reflect the owner-approved revision. The isolated mockup checks passed (six model, eight parser and 22 generator tests; browser review at 390px EN and 320px DE/200%); these do not establish Android behavior. No stats app code, APK or phone check is claimed.

## First checkpoint — F22 evidence and scope documentation

**Subsequent disposition, 2026-10-17:** The owner could no longer reproduce F22 and requested removal. F22 is withdrawn from active/pending work; the checkpoint below preserves historical evidence and its original deferral, not a verified fix. No app/mockup change or new Android check was performed for this withdrawal.

The owner report concerns an optional Hint or example sentence in the Android Collection vocabulary editor: after one letter, the screen jumps, the keyboard closes and focus is lost. The exact field/example index, initial text, Collection list state, installed owner candidate and repeatability are still unknown. This is owner-reported evidence; no storage loss is reported.

Source inspection of the current round-5 integration tree found that `CollectionQueryBinding.refresh()` still enters a loading state, but `SavedVocabularyEditor.busy` no longer derives from query readiness. The older source-based hypothesis that a query refresh disables optional fields therefore does not establish a cause in the current editor. A focused production-composition widget test with synthetic SQLite data opened the Collection editor, typed one character then another into Hint and an Example Pair field across autosave, and retained focus and text. This passed on the current source. It does not exercise the Android IME or reproduce the owner's jump.

The connected emulator is API 36/x86_64. Its normal Piko installation is build 2, older than the round-5 build-4 candidate; the separate installed test identity is an older build-1 fixture. Neither was altered, launched for editing or used as a surrogate for the owner's candidate. No native keyboard reproduction was completed. A cause-established fix is therefore not justified. F22 remains deferred until a matching Android build and exact failing sequence are available; then repeat the same sequence before and after any repair. No application behavior or APK changed in this checkpoint.

Documentation and test evidence: all eight requirements-parser checks pass; all three tests in `collection_inline_runtime_test.dart` pass, including the new focused F22 case; Flutter analysis reports no issues; `git diff --check` passes. Android list verification and a final candidate remain pending. Existing uncommitted mockup/spec/copy drafts were preserved.

Learning-help specification update, 2026-10-17: the owner accepted documentation of LEARN-007 r2 / UX-LEARN-007 r1 (metadata-row info icon, two-section explanation and exact English copy). At that point this accepted the definition only; the subsequent selected-scope entry above adds its app implementation to round 6. Catalog/German integration, app changes and revision-specific Android verification remain pending. The exploratory inline sketch is not an implemented reference; a parallel mockup change is not required for this checkpoint.


## Approved vocabulary-list guide — 2026-10-17

The owner fully approved the final UX-COLL-001 r6 design, requested exact spec alignment and designated the [existing interactive mockup](../mockups/piko-mockup.html?preview=collection-list&lang=de&revision=6) as the visual/interaction guide. The [canonical guide contract](piko-ux.md#approved-vocabulary-list-guide--2026-10-17) owns details. At the time of this design approval, F20/F21 were not assigned to app implementation; the selected-scope decision above now authorizes them. Prior browser checks and the staged iteration history remain in the round-5 ledger. No new app behavior or APK was produced by the earlier spec pass.

Approved reference SHA-256 fingerprints (uncommitted shared-checkout files; these identify content, not a claimed commit):

| Source | SHA-256 |
|---|---|
| mockups/piko-mockup.html | 410fd0ca2d6087518f3b3c1a3a0124d5ee6e4f13617ca3bcab53e88d6fc5bb08 |
| mockups/collection-list-preview.js | 487c59186a8748dcf5c1f7d5c231f997978d48cd41d44b74de23a3e3711fb226 |
| mockups/collection-list-preview.css | ac46ea910d7b5f890d5fc9f8d0bd9c05cc8f57133f84579b8232b368f4c09f19 |
| mockups/collection-list-model.js | a6657ff5fcf78a31201b304d4f7792d0344970091d8042e40c1523f12f1fd5a7 |
| shared/copy.js | e21388c2312f937326099a82b345f4c67aecef2cd60ebdb22b2bbf5f03a3397d |
| shared/design-config.js | c8517205a4eb755d1b4f0ee475cfaf6e753f37ffde0e79f730447fe39e83bb21 |

Specification validation: eight requirements-parser checks pass; diff whitespace checks pass; the linked HTTP preview returns 200. No mockup/app behavior changed in this approval pass.

## Local implementation and verification — 2026-10-17

The Collection list and learning-help packages are locally implemented in `4ddd0d6`, with the approved gold list-tag treatment corrected in `72888fb`. The app reuses the existing Collection query, saved preferences, staged Filter selection and vocabulary editor. No storage migration, scheduler, grade, proficiency or statistics behavior changed. The shared heading accepts a metadata widget and the existing dialog accepts a purpose-specific close name; their other consumers retain their defaults. Two Collection-list opacity roles extend the canonical design configuration without changing existing tokens.

Host evidence: Flutter analysis reports no issues. The full regression run passed 1,176 cases and failed five viewport-dependent cases; all five pass in the nine-case affected rerun after explicitly scrolling to the lazy vocabulary rows. Assertions for autosave focus, invalid raw edits, learning-direction restrictions and Speed completion preservation were retained. The final 27-case Collection list/picker/filter/layout suite passes; the subsequent 14-case category/list check passes after the gold-tag correction. Catalog generation and the approved list model/requirements parser checks pass (35 Node tests). These are full regression plus focused repairs, not a claimed clean full rerun.

The first isolated API-36/x86_64 Android run captured neutral, collapsed, expanded and all-active list states. It exposed two distinct issues: list category tags still used the prior blue treatment (corrected), and an absolute-page geometry assertion included the existing learning-action area above the list. Filtering can add/remove review/Speed actions and therefore reflow that area. The revised fixture separately checks chip/result geometry inside the list and records the observed page displacement. This initially awaited owner clarification. The owner subsequently confirmed that stability applies within the vocabulary-list layout and that learning actions above it may reflow; see the clarification below. The failed run is retained as evidence, not a pass. The normal app identity/data were not opened or replaced; temporary emulator settings were restored and verified.

Final Android acceptance at `16f2a138043118575d369dbee10e5c0c4adfd7af` passes; the normal build-5 candidate is packaged for owner review. Statistics remains planning-only, F22 is withdrawn at owner request, and publication/manual/phone gates remain pending. The approved statistics source stays on its separate local branch; its deliberate reconciliation remains a prerequisite before publishing documentation that claims that source.


### Final Android acceptance

The source frozen for the candidate is `16f2a138043118575d369dbee10e5c0c4adfd7af`. Its Collection/help app code is unchanged after `283daef`; later commits improve test navigation and keyboard assertions. The final `round6-e` run passes on the API-36/x86_64 emulator at 411.4 × 914.3 logical pixels/normal English, then actual emulator display/font settings at 320 × 800/200% German and English. The isolated test application uses the normal production repositories and routes with a unique synthetic SQLite fixture. The installed normal app is never launched for editing, replaced, cleared or uninstalled. Its APK fingerprint remains unchanged. Temporary display, font and storage thresholds are restored and verified after every attempt.

| Owning revisions | Observed evidence | Boundary |
|---|---|---|
| UX-COLL-001 r6; GROUP-001 r2; FILTER-002 r5; F20/F21 | Neutral/all-active/reset controls; staged pickers; collapsed/mixed/expanded groups and contextual bulk action; no results/disabled bulk; Compact/Detailed and reversed language order; saved preferences survive real-route reopen; gold tags omit redundant active group/filter values. Long groups share leading edges and wrap at native 320dp/200% EN/DE. | Internal chip/result geometry is stable. The existing learning area can reflow the whole list by 113dp as actions become available; the owner explicitly accepts that external reflow. F21 is verified against the stable internal list layout. |
| LEARN-007 r2; UX-LEARN-007 r1 | Metadata-row info control, main explanation, collapsed/reopened technical section, disclosure and reachable X at normal and enlarged sizes; native Android Back returns to the same Collection. Exact exported vocabulary/learning state and preferences remain intact. | The German title is the equivalent shorter “Lernen erklärt” to avoid an awkward enlarged-title break. Physical-phone/TalkBack checks remain pending. |

Private capture manifest: `round6-e/manifest.json` (stored outside tracked history). Main inspected states include `01-neutral-list`, `04-all-active`, `05-detailed-reversed`, `06-learning-help`, `07-scheduling-help`, `10b-de-320-200-groups`, `10c-de-320-200-expanded`, `11-de-320-200-help`, `12-de-320-200-scheduling`, `13-en-320-200-groups` and `14-en-320-200-help`. Captures intentionally scroll to their named anchors and show the app surface without system UI. Earlier failed runs are retained: the first identified page reflow; later capture-only failures required scrolling to lazily mounted rows and returning to the offscreen header. None is relabeled as a pass.

Final host additions also pass keyboard Enter/Space disclosure and focus restoration to the info trigger (16-case affected acceptance rerun). Generation/parser/model checks remain passing at 35 cases.


### Candidate and remaining handoff gates

- Private artifact: `piko-round6-16f2a13.apk`, 70,226,424 bytes.
- Frozen source: `16f2a138043118575d369dbee10e5c0c4adfd7af`; subsequent documentation commits do not change its app content.
- SHA-256: `4727ce79066886e2cec0c06a95d0f3efd42d131672131c2773549f911cb4b0ab`.
- Normal package: `io.github.nexa16.piko`, internal build 5, existing versionName `0.1.0`, min SDK 24 / target SDK 36; ARMv7, ARM64 and x86_64. This is a development candidate, not a published release.
- Signing certificate SHA-256: `0e170fc0a27efc6a03525c90597bf66a957b683005238064a90958f60fee7bfb`, matching the previous round-5 owner APK. Build 5 is newer than that build-4 candidate. Physical-phone installation/update is not inferred from signing compatibility.
- Normal packaging initially failed on a stale test-plugin Java registrant. A release build with normal Flutter tooling regeneration (without `--no-pub`) regenerated the release plugin list and succeeded. The private candidate's lib/assets match the frozen production source. No dependency versions or tracked Gradle configuration changed.

Owner review should cover Filter/Group/Sort picker Apply/cancel and independent resets; mixed/all group actions and the local Display/language menu; retained vocabulary editing and learning; info-help open, technical disclosure, X/Back and reopening. Confirm the exact build-5 candidate installs/updates on the phone and check vocabulary learning plus these changed flows before any merge. Existing round-5 detailed-phone-flow gaps are not retroactively closed.

F20 and F21 have revision-specific agent Android evidence. The owner clarified that the vocabulary-list layout must stay stable internally; changes to learning-action availability above it may move the section. F22 is withdrawn at owner request and statistics is planning-only. Native TalkBack, physical-phone behavior and a comprehensive all-language/device matrix are not claimed.

No push, PR, release branch, tag or upload has been performed. Manual review/public-data approval and the phone check remain pending under AGENTS.md. The preexisting approved list guide/spec drafts are preserved. Before a publication that includes statistics planning, reconcile its separately preserved approved mockup source and references without overwriting the list guide.

The normal release entry point was also built for the isolated test identity, installed directly in place and cold-launched to the empty Collections home. The release process remained running and its screenshot was inspected. Temporary storage thresholds were restored; the original normal app APK remained unchanged. This is release-entry-point smoke evidence under the isolated identity, not a claim that the production-identity owner APK was installed on a physical phone.


### Owner clarification of list stability — 2026-10-17

The owner chose: keep the vocabulary-list layout stable and allow learning actions above it to reflow. UX-COLL-001 r6 is clarified in place; its revision and implemented behavior are unchanged. The existing round6-e Android run at source `16f2a13` already checks stable internal chip/result geometry and separately records the 113dp movement caused by learning-action availability. That movement is accepted, not an outstanding defect. F21 is now fixed for the clarified scope using this evidence; owner manual review, public-data approval and exact-candidate phone acceptance remain pending. No app, mockup or APK changed. The build-5 candidate and checksum above remain valid.

## Collection header follow-up — specification and mockup only, 2026-10-17

The owner requested the shrinking/persistent Collection header and an interactive mockup. UX-COLL-008 r6 / UX-SETUP-002 r8; REVIEW-001 r3 / SETUP-008 r3 own accepted behavior. The existing prototype entry point exposes `?preview=collection-header&lang=de`, with one/two/no-learning scenarios and EN/DE/200% controls. Exact visual/transition approval is pending. This scope does not change the round-6 build-5 APK or its original evidence; Flutter implementation and revision-specific Android verification are unassigned and require separate authorization. The local prototype branch preserves the pending round-6 source ancestry; isolate this feature onto current develop before publication rather than publishing unrelated round-6 commits. No push or APK changes.

Header prototype verification: 38 focused Node checks pass (header routing/progress, existing list model, requirements parser and shared generator); JavaScript syntax and generated-catalog freshness pass. Browser checks cover expanded/compact states, direct one-direction Review, two-direction Review and Speed pickers with reverse-direction routing, safe dismissal/focus restoration, no-learning state, EN/DE and German 320px/200% text. Compact actions stack when their labels need space. Synthetic sample: 20 entries with scenario-based directional counts; learning launches/Speed setup are explanatory simulations, not live learning or filter-derived scheduling. Reduced-motion switching is implemented but OS preference, long custom titles, native Android and TalkBack remain unverified. No new APK is claimed.

Header mockup owner adjustment: UX-COLL-008 r6 replaces compact visible action labels with icon-only Review/Speed controls beside the title; localized accessible names and 48px targets remain. Count stays below. Direction routing is unchanged; this remains mockup-only work. Earlier separate-row/stacked-action captures describe the superseded prototype.

Icon-only follow-up verification: 11 header-model/parser checks pass after updating the parser expectation for REVIEW-001 r3 Updated 6 (the prior round-2 filter assertion was stale). Browser inspection confirms icon-only 48px targets beside the title, retained accessible names, direct Review launch and safe dismissal; German 320px/200% wraps the title beside the controls without overflow. Direction routing is unchanged from the earlier picker checks.

## Statistics definition-ready handoff — 2026-10-17

**Statistics readiness, 2026-10-17:** The owner resolved the production data decisions. STATS-005 r2, STATS-006 r1, STATS-007 r2, STATS-008–010 r1, DATA-005 r2 and UX-STATS-005–007 r1 define counting, fresh history, preservation, timezone/correction and loading/error behavior. The approved visual contract is retained. Statistics is ready for a separate implementation request; app/storage migration and Android/phone evidence remain pending. EXPORT-FULL-001 / UX-EXPORT-FULL-001 r1 define a separate, unscheduled full export of all Collections plus statistics; Collection-only export stays unchanged and import ignores statistics. No full import is selected.

Implementation order once authorized: initialize a preserving local migration and coverage metadata; integrate atomic regular/Speed credits and stable deduplication; build consistent day/window/streak queries; connect the approved Activity/Long-term/Speed surfaces with fresh/error/boundary states; then run the functional acceptance matrix, affected regression and revision-specific Android comparison. Add transaction/reopen/deletion/import and 04:00/DST/timezone tests alongside behavior. Preserve normal device data. The separate full-export specification is outside this statistics package. No app source or APK changed in this specification pass.

Specification validation: all nine requirements-parser tests pass in both the shared checkout and isolated statistics branch, including unique IDs, round visibility and complete statistics/full-export text. Both diff whitespace checks pass. This is documentation/parser evidence only; no Flutter, migration or Android verification was performed for these new definitions.

Header count follow-up (mockup/specification only): UX-COLL-008 r7 / UX-SETUP-002 r9; REVIEW-001 r4 / SETUP-008 r4 add per-mode summed directional counts and persistent disabled-zero controls. Synthetic two-direction state is Review 12 + 7 = 19 and Speed 9 + 5 = 14; one direction is 12 / 9; neither is 0 / 0 disabled. Earlier compact hiding/label-free captures are superseded; no APK change or native verification.

Count follow-up verification: 35 focused header-model/parser/shared-generator checks pass. Browser checks confirm 19/14 summed two-direction counts, the corresponding 12/7 Review picker, retained disabled 0/0 buttons, and 320px German/200% title wrapping beside complete numeric targets. Counts are scenario-based; Android implementation/verification remains pending.

## Approved vocabulary selection handoff — 2026-10-17

The owner separately requested selection behavior plus a mockup, with no vocabulary operation. VOCAB-SELECT-001 r1 / UX-COLL-013 r3 and SPEED-004 r4 own the definition; the focused evidence in piko-ux.md owns browser checks. The owner has now approved the exact revision-3 visuals and selected the package for round-6 planning. Flutter execution awaits the explicit request for the clarified batch. Shared EN/DE copy is synchronized into its generated adapter only; no app selection UI was implemented. The round-6 APK and its prior evidence do not verify this new feature. Visual approval is complete; Flutter implementation and revision-specific Android/phone verification remain pending.


### Implementation plan and acceptance boundary

- Use the [approved visual/interaction contract](piko-ux.md#vocabulary-multi-selection--2026-10-17) and [interactive guide](../mockups/piko-mockup.html?preview=collection-selection&lang=en), with DE via lang=de. The selected scope is VOCAB-SELECT-001 r1 / UX-COLL-013 r3, without a new behavior revision for approval/round assignment. Resolve routine app integration through design autonomy; no additional prototype pass is required.
- Implement transient UUID-owned selection with existing list/query/group/editor composition. Preserve duplicate-appearance identity, pending-edit/save guards, vocabulary and learning state. Keep selection independent of stored view preferences and learning eligibility. Reconcile with the separately specified interaction anchoring contract; this feature does not implicitly select the broader anchoring package.
- Add behavior tests for entry/toggle/zero selection, hidden selections through search/filter/group/sort/display changes, collapsed-group Select all, hidden global clear, duplicate UUID appearances, same-page popup retention and page-departure reset. Verify ordinary taps/editing outside selection and that input long-press remains native. Assert no persistence, vocabulary mutation or changed learning launch scope from selecting.
- Verify actual Android three-state appearance, fixed card/text positions and scroll offset through entry/toggle/clear, last-card reachability and no painting behind the floating panel while scrolling. Cover grouped/ungrouped, mixed/zero/no-match selections, panel reflow/hidden counts, Compact/Detailed, EN normal plus targeted DE narrow/200%, focus/keyboard/accessibility, and pending-save/validation preservation. Browser evidence stays scoped to the mockup; do not close Android acceptance from it.
- Integrate with the other explicitly selected round-6 packages; generate shared adapters as needed, run affected tests/analysis/regression and produce an updated source-identified candidate/checksum. Existing build-5 evidence cannot establish selection acceptance. Retain manual/public-data review, exact-candidate phone learning plus changed-flow acceptance and protected PR/merge gates from AGENTS.md. No publication or release is authorized by this handoff.

### Approved reference provenance

The following SHA-256 values preserve the exact local guide sources at owner approval/handoff. The URL is live and is not an immutable snapshot. Prior captures and browser evidence in the owning UX section distinguish r1/r2 from the approved r3. Raw captures remain outside tracked history. Any later visual change requires review of its affected scope.

| Reference source | SHA-256 |
| --- | --- |
| `mockups/collection-selection-model.js` | `ff149fb9e8c5b15a3cbe6c7ee92cf65d95f5a5fa1f9b9d1a83d39cc3ed7df2da` |
| `mockups/collection-selection-preview.js` | `6ed0e4b8e2048dd35f1460113558f53234bc0aa75d67e478d0895ac9b04f1662` |
| `mockups/collection-selection-preview.css` | `d2768033d73e7ca7c46bf279c24464c01d4367a989800d3b92d2a7bec2a0a4c5` |
| `mockups/collection-list-preview.js` | `fbef0fe0bc138538f1b3db974e0fd3d9bd795d9ee698141af7756c7e995084d5` |
| `mockups/collection-list-model.js` | `a6657ff5fcf78a31201b304d4f7792d0344970091d8042e40c1523f12f1fd5a7` |
| `mockups/piko-mockup.html` | `6acad690dcaec37f58030c8ed40639e304126d031a64cc4ec2c0d1aef697e444` |
| `shared/copy.js` | `fe4bb9b55bbb75d4995b1429af31a217d53ad14df44bf83c801669ad6a4dc905` |
| `shared/design-config.js` | `e62a3b6591b5fa327a0797318e2faf2f927e293d8dd459c41081a253cd6fa75d` |

## Interaction anchoring specification follow-up — 2026-10-17

**Current scheduling, superseding the unassigned handoff below:** the owner selected broader all-page anchoring as the first, high-priority package of round 7. The [round-7 ledger](implementation-round-7.md#first-priority--all-page-interaction-anchoring-2026-10-17) owns that scope and verification plan. The expanded round-6 execution authorization above continues to cover affected Collection flows; remaining cross-app coverage is planned for round 7, pending its explicit execution request.

All-page applicability confirmed: UX-ANCHOR-001 r1 now includes a surface map and cross-page acceptance checklist, covering existing and selected pending pages without introducing features. This is a clarification of the shared definition; implementation remains unassigned and unverified. F23 remains the Collection Detail report, not evidence of defects across all pages.

UX-ANCHOR-001 r1 / UX-COLL-001 r7 accept the owner's revised same-screen rule: preserve the interacted item in the viewport and let surrounding content move. F23 records the grouping/filtering/sorting report and bounded investigation; the UX requirement owns acceptance and exceptions. This supersedes the r6 permission for learning-area changes to move the whole list. Existing build-5 / round6-e checks and F21 closure remain historical evidence for r6, not verification of r7. No new app/mockup changes, candidate, Android reproduction or round-scope selection are authorized by this follow-up. Implementation and revision-specific Android/owner verification are pending a separate request; other selected round-6 packages remain as recorded above.

Planning handoff received: retain this as an unassigned package, separate from the selected statistics/header additions. Before executing an affected Collection-list or header batch, reconcile its scope against the new anchor contract rather than carrying forward the superseded r6 displacement exception. Resolve the implementation boundary with the owner if it would expand that batch; do not infer a cross-app retrofit. Once authorized, establish a matching Android baseline and test originating-chip anchoring across popup Apply, disclosure headers, edits/selection and asynchronous updates, including bounded-scroll/removal fallbacks, user-scroll precedence, reduced motion and keyboard/accessibility visibility under the owning acceptance scenarios. The reported installed build, exact settings and repeatability remain unconfirmed; source/video inspection is not runtime reproduction. Keep F23 specified until the required implementation and revision-specific evidence exist.
