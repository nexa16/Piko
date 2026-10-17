# Round 6 planning and implementation ledger

**Status, 2026-10-17: the owner selected the approved vocabulary-list rework under UX-COLL-001 r6 / F20–F21 and the accepted FSRS learning-help icon under LEARN-007 r2 / UX-LEARN-007 r1 for round-6 implementation. The approved statistics design is also selected for round-6 planning, with production prerequisites and separate Flutter authorization pending. F22's bounded first checkpoint did not establish the Android cause, so its fix is deferred pending matching runtime evidence. Both app packages are locally implemented and the final isolated Android acceptance passes. One normal build-5 candidate is ready for owner review; owner review/phone acceptance and the F21 page-reflow clarification remain pending.**

## Branch and baseline

- Branch: `codex/round-6-implementation`.
- Base: latest fetched `develop`, `1e3f520061e8ce4cb07da247b8e6c4b145c5ef98`, the owner's squash merge of [PR #6](https://github.com/nexa16/Piko/pull/6).
- The merged tree exactly matches published PR head `ee59a1d480dcdd8286601a0f0df6e1dc33716771`.
- The [round-5 ledger](implementation-round-5.md#owner-merge-and-next-branch-handoff--2026-10-17) owns prior implementation, candidate provenance, verification boundaries, owner merge and preserved-draft evidence. The candidate update/appearance check passed by owner report; detailed phone-flow acceptance remains unverified.

Both Piko chats share the main checkout on this branch. Existing uncommitted Collection-list specification/mockup/copy preparation is preserved; the retired auxiliary mockup draft and old Git history have verified private backups. Preparation and branch creation do not accept those drafts as implementation scope.

## Selected scope and checkpoints — 2026-10-17

| Package | Owning definition | Outcome and boundary | Status |
| --- | --- | --- | --- |
| Vocabulary-list rework | UX-COLL-001 r6; GROUP-001 r2; FILTER-002 r5; F20/F21 | Implement the fully approved guide in the Flutter Collection Detail list: search and independent Filter/Group/Sort chips, local list menu, contextual group action, left-aligned headers, stable result-start geometry and preserved Compact/Detailed cards. Keep stored preferences, vocabulary, editor and learning behavior intact. | Locally implemented and scoped Android-verified; F21 whole-page stability clarification and owner acceptance remain pending. |
| Learning-help info icon | LEARN-007 r2; UX-LEARN-007 r1 | Add the single info trigger to Collection Detail's language/count metadata row and its accepted two-section How learning works dialog. Integrate equivalent EN/DE copy through the shared catalog, with accessible controls and responsive text. Opening help must not change learning, vocabulary or list state. No scheduler, grading, statistics or proficiency changes. | Locally implemented with shared EN/DE copy and scoped Android verification; owner acceptance remains pending. |
| Statistics planning | UX-STATS-001 r2, UX-STATS-002/004 r2, UX-STATS-003; STATS-005 r1, STATS-006/007, PARAM-STAT-002 r1; MASCOT-004 / UX-MASCOT-004 r2 | Preserve the owner-approved exact mockup appearance for homepage Activity and detailed Long-term/Speed statistics. Define production Speed counting/deduplication, history preservation/import/correction, clock/timezone aggregation and loading/error behavior before app work. | Owner-selected for round-6 planning; approved mockup saved separately; Flutter implementation and Android verification require a separate explicit request. |
| Optional-content typing focus | F22; UX-COLL-009 r2, UX-COLL-011 r4, VOCAB-EDIT-001/002 | Reproduce Hint/example editing with a real Android keyboard and synthetic data, recording build, initial state, exact actions, expected/actual result and repeatability. If the mechanism is established, make a focused repair with regression tests and repeat the same Android sequence. | Bounded host investigation complete; Android cause unproven and fix deferred pending matching runtime evidence. |

The list rework has three dependent checkpoints. First, replace the combined View entry point with the approved heading menu and shared Filter/Group/Sort controls in `collection_detail.dart` and `collection_view_controls.dart`; retain the existing search field, preference service, staged dialogs and independent resets. Second, adapt the grouped headers, result/bulk row and Compact/Detailed card presentation in `collection_vocabulary.dart` without changing stored identities or learning state. Third, verify control state transitions and preservation with focused widget tests, run analysis and affected regression, then compare the actual Android surface against the approved guide before building the owner candidate. Keep the shared copy/configuration adapters generated from their canonical sources.

Start with F22 evidence and the list control's dependency review, then complete the list surface as a dependency-complete package. Add the learning-help icon/dialog as a separate small checkpoint: generate the shared EN/DE catalog adapter, integrate the icon and dialog using shared components, test open/disclose/dismiss/no-state-change behavior, and inspect the accepted narrow/enlarged Android states. At each checkpoint record the source commit, changed tests, Android states and limitations; the final candidate requires an immutable APK, checksum, final regression and the owner handoff under AGENTS.md. No publication, release, tag or store upload is selected.

Statistics is a planning package, not part of the current app candidate until its remaining contracts are specified and the owner separately requests Flutter implementation. Other learning candidates, proficiency/Mastered, manual Speed selection and unrelated findings are excluded. FSRS help is limited to the LEARN-007 / UX-LEARN-007 information affordance and explanation; it does not change scheduling. Round-5 detailed phone-flow acceptance remains unverified; do not recast its update/appearance check as flow acceptance.

The approved statistics source is local commit `9b4a977` on `codex/statistics-mockup`, based on `develop` `1e3f520`. Its `docs/statistics-mockup.md` Approved visual contract, interactive `?preview=statistics` profile, synthetic reference captures and source-hash manifest are the preserved exact-appearance guide. The main checkout has concurrent Collection-list mockup/copy changes, so importing that source and its generated catalog requires a deliberate file-by-file reconciliation; no approved asset or state should be overwritten. Integrate the approved source and references before any PR/publication that claims this visual contract, so the public documentation stands on its own. The canonical functional and UX requirements now reflect the owner-approved revision. The isolated mockup checks passed (six model, eight parser and 22 generator tests; browser review at 390px EN and 320px DE/200%); these do not establish Android behavior. No stats app code, APK or phone check is claimed.

## First checkpoint — F22 evidence and scope documentation

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

The first isolated API-36/x86_64 Android run captured neutral, collapsed, expanded and all-active list states. It exposed two distinct issues: list category tags still used the prior blue treatment (corrected), and an absolute-page geometry assertion included the existing learning-action area above the list. Filtering can add/remove review/Speed actions and therefore reflow that area. The revised fixture separately checks chip/result geometry inside the list and records the observed page displacement. Whether stability must also cover movement caused by learning-action availability is awaiting owner clarification; do not close F21 or claim whole-page stability meanwhile. The failed run is retained as evidence, not a pass. The normal app identity/data were not opened or replaced; temporary emulator settings were restored and verified.

Final Android acceptance at `16f2a138043118575d369dbee10e5c0c4adfd7af` passes; the normal build-5 candidate is packaged for owner review. Statistics remains planning-only, F22 remains deferred, and publication/manual/phone gates remain pending. The approved statistics source stays on its separate local branch; its deliberate reconciliation remains a prerequisite before publishing documentation that claims that source.


### Final Android acceptance

The source frozen for the candidate is `16f2a138043118575d369dbee10e5c0c4adfd7af`. Its Collection/help app code is unchanged after `283daef`; later commits improve test navigation and keyboard assertions. The final `round6-e` run passes on the API-36/x86_64 emulator at 411.4 × 914.3 logical pixels/normal English, then actual emulator display/font settings at 320 × 800/200% German and English. The isolated test application uses the normal production repositories and routes with a unique synthetic SQLite fixture. The installed normal app is never launched for editing, replaced, cleared or uninstalled. Its APK fingerprint remains unchanged. Temporary display, font and storage thresholds are restored and verified after every attempt.

| Owning revisions | Observed evidence | Boundary |
|---|---|---|
| UX-COLL-001 r6; GROUP-001 r2; FILTER-002 r5; F20/F21 | Neutral/all-active/reset controls; staged pickers; collapsed/mixed/expanded groups and contextual bulk action; no results/disabled bulk; Compact/Detailed and reversed language order; saved preferences survive real-route reopen; gold tags omit redundant active group/filter values. Long groups share leading edges and wrap at native 320dp/200% EN/DE. | Internal chip/result geometry is stable. The existing learning area can reflow the whole list by 113dp as actions become available; the owner clarification remains open and F21 stays needs_verification. |
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

F20 has revision-specific agent Android evidence. F21 remains needs_verification while its whole-page stability interpretation is unresolved; the controls inside the list are stable, but changes to learning-action availability above them can move the section. F22 is deferred and statistics is planning-only. Native TalkBack, physical-phone behavior and a comprehensive all-language/device matrix are not claimed.

No push, PR, release branch, tag or upload has been performed. Manual review/public-data approval and the phone check remain pending under AGENTS.md. The preexisting approved list guide/spec drafts are preserved. Before a publication that includes statistics planning, reconcile its separately preserved approved mockup source and references without overwriting the list guide.

The normal release entry point was also built for the isolated test identity, installed directly in place and cold-launched to the empty Collections home. The release process remained running and its screenshot was inspected. Temporary storage thresholds were restored; the original normal app APK remained unchanged. This is release-entry-point smoke evidence under the isolated identity, not a claim that the production-identity owner APK was installed on a physical phone.
