# Decision log

## LEARN-002 — independent directional storage — 2026-10-14

Classify LEARN-002 as First, a dependency of the accepted bidirectional choice and progress-preserving deletion. Schema 5 gives each vocabulary entry two unique direction records with cascading ownership, stable positive integer FSRS identities and complete versioned JSON. A persistent high-water allocator prevents deleted identities being reused while Undo may restore them. Creation and migration backfill are transactional; migration uses one injected UTC instant and preserves existing records. Vocabulary edits do not recreate learning items.

The exact pinned `fsrs` 2.0.1 package source (`lib/fsrs.dart`, MIT license) was inspected: its Card constructor initializes learning/step zero with null memory parameters and last review; explicit IDs and due time avoid its wall-clock-based factory. The adapter retains all seven library serialization fields, validates identity/version/coherent memory state and yields fresh mutable Card objects. This introduces authentic storage and serialization, not scheduling, review history or retry calculations. Mathematical integration remains LEARN-001. Source: https://pub.dev/packages/fsrs/versions/2.0.1

## UX-ENTRY-002 — binding entry header and distinct actions — 2026-10-14

Use the binding three-track entry header with intrinsic Back, a middle-track-centered title and the primary global completion checkmark outside the cards. Canonicalize its gap, title sizes, responsive viewport breakpoint, Back weight and action padding; generate the CSS media rule from the same source as Flutter so a breakpoint change cannot diverge. Reuse shared page-top/title-margin and 48px large-control tokens. Keep localized tooltips/accessibility names distinct between global final completion and card-level Save & Next, preserving the established controller and guarded Back behavior. Large German text can wrap the title without clipping actions. This is header presentation and isolated production-route verification, not Collection route wiring, release completion or an owner decision on the separately pending saved-error policy.

## ENTRY-011 — final confirmation without advancement — 2026-10-14

Global completion uses a dedicated controller operation with one shared pending Future. It drains accepted saved edits, validates and writes the final meaningful draft exactly once, and enters a reusable terminal state without a fresh card. Empty/whitespace input writes nothing. Input and localized feedback survive required, duplicate or storage failures. Pending completion freezes conflicting entry actions. The screen captures route/session identity before awaiting; covered terminal sessions can resume exit without duplicate persistence, while replacements and unrelated routes are never popped. Disposal before draining finishes starts no new final write; an already accepted final write may finish without publishing late session state.

The conservative implementation keeps a prior invalid/failed saved buffer open and activates the first affected saved card, rather than silently losing its edits during global completion. This implements the existing no-silent-discard constraint while the owner's optional policy clarification is pending; it is not labelled an explicit owner acceptance or a new release requirement. Explicit Back retains its distinct ENTRY-007 policy. Header geometry/accessibility audit and production route/Android completion acceptance remain with their owning integration work.

## ENTRY-007 — guarded Back and draft discard — 2026-10-14

Visible Back and PopScope use one guarded production-screen exit request. Only meaningful text on either draft side requires the shared Continue Editing / Discard & Exit warning; whitespace-only drafts leave directly without confirmation. Safe dismissal preserves editing state. Confirmation blocks exit, while accepted saved-edit queues drain before an explicit exit; failures retain last persisted text. An empty draft does not acquire a warning merely because a prior saved buffer is invalid or failed. Session/route identity guards and owned-dialog cleanup prevent late work from exiting replacements or unrelated routes. The caller continues to own the session controller. Shared exit-warning copy now describes retained saved entries truthfully; the mockup dialog repeats its existing sample-session disclaimer. Global completion, route wiring and final header geometry remain separate requirements.

## UX-ENTRY-001 — binding focused stack presentation — 2026-10-13

Promote the effective mockup entry preview, metadata, compact minimum and state-transition measurements into `components.entryStack`, consumed by CSS/runtime and generated Flutter adapters. Reuse canonical card spacing, field geometry and the primary 48px card confirmation target. The compact minimum grows with content rather than fixing card height; measured centering continues to adapt to actual viewport, keyboard and text geometry. Reduced motion suppresses size and state transitions. Android verification exercises the actual EntrySessionScreen with isolated production repositories, real IME opening/resizing, swipe activation, raw draft/selection retention and persisted confirmation. The earlier claim that no production database was cleared or replaced is withdrawn: the runner's default uninstall removed emulator app data after integration runs; see the FOUNDATION-005 verification correction in the ledger. This does not add the header actions, route wiring, exit behavior or deletion reserved for their own specifications.

## ENTRY-001 — production focused stack behavior — 2026-10-13

The production EntrySessionScreen consumes real Collection metadata and a caller-owned EntrySessionController, preserving widget-owned text/focus/scroll state by stable card identity. No sample cards are seeded. User scrolling selects the nearest measured card center, while continuous expansion anchor correction preserves gesture movement; nested input scrolling and programmatic reflow do not select other cards. Only active fields participate in Tab traversal, and Up/Down applies to stack focus. Confirmation, saved autosave and explicit storage retry consume the established controller behavior; pending, invalid and failed states do not claim edits are saved. Shared Saved/autosave labels become truthful neutral wording; the mockup retains its explicit sample-session disclaimer. Keyboard-resized layouts preserve draft text, selection and focus, and reduced motion bypasses size animation. This establishes tested production screen behavior, not completed Android acceptance, exact UX-ENTRY-001 presentation, or future route/exit/global-completion/deletion actions.

## ENTRY-005 — serialized saved-entry auto-save — 2026-10-13

Confirmed current-session Entries now have separate raw edit buffers, last committed records, saving state and error state. Valid edits start repository updates automatically; required-invalid input stays in the raw buffer and queues no new write. Per-Entry workers serialize writes and coalesce the latest waiting valid revision. A subsequent invalid edit does not cancel a valid revision already accepted for saving. Completion updates only the committed record, preserving identity, owner and session order; it never replaces raw input. Revision checks prevent older success/error results from clearing or replacing newer validation. Separate Entry queues operate independently.

`retrySavedEntry` retries an unchanged valid buffer after failure without creating vocabulary or requiring another confirmation, and cannot duplicate an active save or save invalid input. Errors remain on saved-entry state for later canonical localized feedback. `awaitSavedEdits` resolves when all accepted queues are idle, including edits added while draining; it is coordination for tests and later exit handling, not a save button. Disposal clears exposed session state and rejects further edits, while already accepted valid writes finish without late notifications. Real SQLite tests verify committed values and continued queued-save persistence after disposal. This changes saved-entry editing only; unconfirmed new drafts remain ephemeral. Actual fields, feedback and focused-stack integration remain pending.

## ENTRY-002 — guarded confirmation before advancement — 2026-10-13

The entry-session controller now receives its vocabulary repository and writes only through explicit Confirm & Next. It captures the raw draft, validates required normalized fields and guards one pending write. Repeated confirmation returns the same Future. To avoid losing edits made during a write, field mutations and card navigation are rejected while pending; the later UI must disable those controls using `isConfirming`. This is a temporary pending-write guard, not an automatic draft save.

After a successful repository commit, one state transition appends the actual same-owner record, empties the draft and activates the next draft. Required, duplicate and other persistence errors propagate for later localized UI feedback without changing the draft or active saved-card selection. Disposal during a pending write prevents late notification or state revival; an already initiated write still resolves to its caller. The former public record-registration method is removed, so only confirmation adds session history. Draft/navigation tests now build that history through real SQLite confirmations. This extends the earlier controller boundary; unconfirmed drafts remain ephemeral, and actual entry-screen integration is still pending.

## ENTRY-006 — draft-preserving session navigation — 2026-10-13

The controller now tracks ordered confirmed VocabularyRecord snapshots and the active saved Entry UUID, with a null identity denoting the current draft. Registration is an internal confirmation boundary for records owned by this Collection; it does not query or import Collection history. Saved selection requires a registered identity. Foreign registrations and unknown selections are rejected, while repeated registration/current selection are no-ops. Draft and saved-card navigation preserve the same raw draft snapshot without writing to storage. Confirmed-list views are immutable snapshots; ending the session clears its cards and rejects late navigation. Tests use actual SQLite-created records and verify no saved text changes during navigation. This establishes the session state needed for ENTRY-002 confirmation and the later focused stack; widget text/focus/scroll controllers and screen integration remain separate.

## ENTRY-003 — ephemeral raw entry drafts — 2026-10-13

The entry-session controller owns one Collection identity and immutable snapshots of raw target/native draft values. Field changes preserve the other field and notify consumers only when values change. It has no repository dependency, write method or restoration API, so typing cannot save an Entry. Ending its lifetime clears its current draft and rejects later mutations; another session starts empty, including another session for the same Collection. Widget-owned text, focus and scroll controllers remain separate. Five controller tests cover raw values, notification snapshots, Collection/session isolation and lifetime reset; a real file-backed SQLite fixture confirms draft typing/disposal leaves previously saved vocabulary unchanged. Actual entry-screen integration remains pending, with navigation, confirmation, draft-exit handling and focused scrolling implemented under their own requirements.

## OFFLINE-001 — first-release offline storage evidence — 2026-10-13

Classify OFFLINE-001 from Undecided to First as a constraint on the accepted local-first release. An isolated Android fixture writes through the production Collection/vocabulary repositories with a self-checked HTTP guard and verifies normalized text, IDs, ownership and comparison keys after SQLite file reopen. The verification run had no active default network; original airplane/Wi-Fi/mobile settings were restored afterward. Fixture storage uses only a newly owned application-support subdirectory, not the production piko database. The main manifest requests no Internet permission; debug/profile tooling permissions remain intact. The ledger stays Implemented, not fully verified, until actual manual-entry UI and termination durability gates pass. No fake entry form, synchronization or AI capability is added.

## VOCAB-003 — cross-Collection vocabulary independence — 2026-10-13

Dedicated acceptance tests confirm that the existing schema 4 collection-scoped uniqueness permits identical normalized vocabulary pairs in different Collections, even when their names and language pairs match. Entries retain distinct UUIDs and owner-scoped reads. Updating one Entry leaves the other intact and may match a pair in another Collection; attempts to create a second matching pair within either owner remain blocked. File reopen retains both Collection and Entry identities, texts and language metadata. This requirement needs no production change, schema migration or move API; it adds explicit evidence for the accepted ownership boundary. Manual-entry screens remain separately scoped.

## VOCAB-002 — durable normalized uniqueness and safe migration — 2026-10-13

Schema 4 requires target/native comparison keys and enforces `UNIQUE(collection_id, target_key, native_key)`. Repository create and exact-ID update apply VOCAB-012 display normalization and key calculation; self-matching edits retain identity and ownership. Invalid or duplicate writes leave the saved Entry intact. SQLite extended error 2067 maps to typed duplicate-pair validation because this table currently has exactly one UNIQUE constraint, the comparison pair; primary-key, foreign-key, trigger and other errors propagate. The existing sqlite3 dependency is now direct rather than development-only for that typed error mapping. Future additional unique constraints must revisit this assumption.

Version 3 upgrades in an explicit transaction, reading its old columns without the version 4 mapper. Preflight compares owner/key tuples and rejects collisions rather than merging or deleting records. A rebuilt table copies bound values while retaining exact IDs, owners, original rowids and raw display text; only comparison keys are derived. New or edited records receive canonical display text. Foreign-key validation follows the rebuild and rolls back on failure. Versions 1/2 create the current vocabulary table directly. Tests verify both preflight retry safety and rollback after actual table replacement, with version/schema/raw data intact. Collection-specific duplicate policy is implemented here; cross-Collection acceptance remains separately tested under VOCAB-003, and editor UI remains pending.

## VOCAB-012 — exact normalized pair comparison — 2026-10-13

The owner explicitly keeps German ß and ss distinct. Display text uses `NFC(trim(text))`; comparison keys use `NFC(NFC(trim(text)).toLowerCase())` with Dart's locale-independent Unicode lowercase mapping. Case differences such as ẞ/ß and É/é compare equally. Internal whitespace, punctuation, accents and compatibility forms remain significant; the policy adds no spelling substitutions or full case folding. Pure shared functions implement this policy without changing stored vocabulary or adding uniqueness in this commit; VOCAB-002 applies it at the repository/storage boundary. Empty results remain available to required-field validation rather than becoming valid entries. NFC uses pinned `unorm_dart` 0.3.3, verified against its downloaded primary implementation and [upstream source](https://github.com/yshrsmz/unorm-dart/blob/master/lib/src/unorm_dart_base.dart), under its MIT license. The package remains a normal locked Flutter dependency whose upstream license is retained; no normalization tables are copied into Piko. Dart's [lowercase documentation](https://api.dart.dev/dart-core/String/toLowerCase.html) describes the language-independent mapping.

## VOCAB-001 — distinct local vocabulary identities — 2026-10-13

Schema 3 stores Vocabulary Entries as UUID identities owned by a Collection, with two required texts. Separate meanings sharing the target text or the native text remain separate records. Repository validation rejects whitespace-only text and missing Collection identities before committing, while SQLite foreign keys and nonempty-text checks protect direct writes. The ownership foreign key cascades vocabulary removal if its Collection is deleted; this establishes data integrity without claiming the later confirmed-deletion UI or learning-progress cascade. Reactive reads use stable insertion order and exact UUID lookup. Migration from the exported schema 2 preserves settings and Collections, and the existing schema 1 migration still passes through schema 3. Display text is preserved at this stage; normalization and comparison uniqueness are introduced under VOCAB-012 and VOCAB-002. No vocabulary, manual-entry or learning UI is introduced by this storage requirement.

## UX-COLL-005 — real target-language badges — 2026-10-13

Classify UX-COLL-005 as First. Collection cards display uppercase Latin codes from the stored target language (KO/FR/EN/DE), independent of interface locale. Extract the binding cover's effective 42px size, 12px radius, 15px font, weight 800 and .03em tracking into `components.languageBadge`; replace the obsolete earlier 48px cover default rather than maintaining conflicting geometry. Flutter uses that baseline as a minimum with centered intrinsic text so enlarged glyphs can grow without clipping. Decorative code does not add another announcement to the existing whole-card name/full-pair action. No due counts or review actions are introduced by this badge requirement.

## UX-HOME-002 — binding empty invitation presentation — 2026-10-13

The successful-empty invitation uses the binding card with readable muted body text and the primary Create first collection action, while New remains available. Existing canonical body size, card properties and 20px spacing are reused; the mockup's description-only 1.6 line-height is extracted into `components.emptyState.descriptionLineHeight`, consumed by browser and Flutter adapters. English/German semantic and keyboard actions, 392px doubled-text scroll reachability and live locale updates have focused widget coverage. Functional empty-result gating remains COLL-015; this does not claim future review counts or a completed Settings header.

## FOUNDATION-005 — execution order follows real data dependencies — 2026-10-13

The coordinator refined the implementation sequence without changing the 95-requirement release scope. Review entry points wait for real due counts and working session launch; vocabulary order waits for persisted entries rendered in detail. Rename and deletion preservation/cascade tests follow vocabulary and directional learning storage, and combined collection controls follow their functional actions. Data minimization is audited after the complete release storage exists. Requirements remain individually committed and pending until their full acceptance evidence exists; mock data or a disabled placeholder cannot satisfy a missing dependency.

## COLL-015 — truthful empty collection state — 2026-10-13

An empty-state invitation represents a successful repository result containing no Collections, not a loading or read-failure assumption. The canonical explanation and Create first collection action appear alongside ordinary New; both launch the same validated creation dialog. Dismissal preserves the empty database, and a successful first creation removes the invitation through the existing live stream. No sample Collections or invented review counts appear. This establishes the functional state and action; UX-HOME-002 separately verifies its binding presentation.

## COLL-013 — reactive local collection navigation — 2026-10-13

The overview now watches stored Collections and opens detail by UUID, so matching names remain distinct. SQLite rowid provides stable insertion order as a technical default; this adds neither a sorting preference nor stored timestamps. Detail watches its identity and shows the persisted name and localized language pair with Back navigation. Cached subscriptions survive interface-language rebuilds; explicit read retry starts a fresh subscription. Loading, read errors and a missing identity have separate canonical English/German copy. Whole-card touch, keyboard and semantic activation include the language pair, with a visible canonical focus border. Empty-state invitation, badges, vocabulary and review content retain their owning requirements. Host widget fixtures use Drift's documented synchronous stream cleanup option only in tests. Android verification uses an isolated temporary database and proves reopen/list/open/Back; final application force-stop durability remains an acceptance gate.

## UX-COLL-010 — binding creation-form presentation — 2026-10-13

The Flutter creation form follows the binding mockup's target/native/required-name order, including target options Korean/French/English/German and native options German/English/French/Korean. Canonical localized labels name the actual controls for accessibility; Tab follows their reading order. Shared popup scrolling keeps the name and Create reachable at 392px width, doubled German text and simulated 300px keyboard inset. No new geometry defaults were needed. Default-name customization remains COLL-017; this commit verifies its preservation during form interaction rather than redefining it. These widget checks do not replace the final real-device entry/keyboard acceptance gate.

## COLL-017 — localized defaults preserve explicit draft edits — 2026-10-13

The creation form starts with the target-language name from the current canonical interface catalog. Target changes replace it only before an explicit user name edit or clear; returning the text to the original default remains customization. Native-language changes never rename it. Locale-only changes preserve name text, selection and focus consistently with I18N-002 rather than introducing an additional automatic rewrite; a later target change uses the current locale while the draft is still automatic. Required-name validation and existing support for duplicate names/language pairs remain in place. Field-order presentation is separately verified under UX-COLL-010.

## COLL-001 — local collection creation — 2026-10-13

Collection creation now uses local SQLite storage with UUID identities, a required trimmed name and two distinct language codes. Matching names and language pairs remain allowed. The initial language choices follow the binding mockup (Korean, French, English and German). Schema 2 adds collections while preserving existing settings. Explicit Create starts one guarded write; dismissing an unsubmitted form does not write, and dismissing during a previously initiated write cannot close another route when that write completes. Failures preserve inputs for retry. Listing, default names and detail navigation retain their separate requirement commits.

## UX-HEADER-002 — first-release compact header geometry — 2026-10-13

Classify UX-HEADER-002 as First. Extract the binding mockup's existing 7px title block margin into `components.headings.titleMargin`; browser CSS and generated Flutter data consume this canonical value. Flutter headings use existing 4px spacing below navigation and 8px subtitle inset, retaining one Back control at wider widths. Tests compare layout boxes at normal and doubled text sizes; font baselines do not imply identical visible glyph gaps between platforms. Broader tablet/desktop layout and actual screen integration remain separately scoped.

## UX-HEADER-001 — first-release page-heading hierarchy — 2026-10-13

Classify UX-HEADER-001 as First, as the shared heading dependency for the accepted screens. PikoHeading presents one level-one semantic title and supports a meaningful Collection subtitle using canonical small/muted typography with natural wrapping. There is no decorative eyebrow or generic explanatory subtitle slot. Learning direction/progress, section headings and field instructions remain separate useful context. This establishes the shared primitive; full page integration belongs to each screen requirement and spacing belongs to UX-HEADER-002.

## UX-DIALOG-001 — reusable application popup — 2026-10-13

Flutter now uses one shared popup component with the accepted title/close-X pattern. Safe X, Escape, backdrop and Android Back return no action result, preserve caller-owned drafts and restore opener focus. Only explicit positive or meaningful draft-choice actions return a result. Canonical dialog tokens preserve the binding mockup's 430px maximum width, 20px bold title and existing backdrop; Flutter maps the same values with keyboard-safe scrolling, closed-loop focus and reduced-motion transitions. Product-specific creation, deletion and review dialogs consume this component in their own requirements.

## UX-ICON-002 — shared Lucide asset adapter — 2026-10-13

Flutter uses the mockup's 17 pinned Lucide originals and complete ISC/Feather MIT notices. Direct parent-relative asset paths passed host tests but produced an Android APK without the icons; the installed emulator could not load them. The shared generator therefore creates byte-identical copies in `app/assets/generated/lucide`, checked for missing, changed and extra files. These are generated adapters, not another editable source. PikoIcon uses canonical size and inherited control color; standalone imagery can opt into semantics, and PikoIconButton supplies action names. Android integration verifies every icon renders and the full notice loads. Product-screen use remains scoped to each screen's requirement.

## I18N-002 — independent interface language — 2026-10-13

Classify I18N-002 from Undecided to First as a constraint on the accepted bilingual implementation. A dedicated interface locale controller updates copy and native control language without transforming user-entered vocabulary or replacing editing state. Storage and Settings selection remain separate. Product-wide localized text coverage must be audited as screens are implemented; the initial integration test proves live switching preserves input, selection and focus.

## I18N-001 — first-release interface locales — 2026-10-13

Classify I18N-001 from Undecided to First as a dependency of the accepted bilingual release. English remains the initial interface language regardless of device language. Explicit German selection also localizes Flutter's native control labels. Unsupported interface locales fall back consistently to English. The application accepts locale injection now; persisted selection and its Settings control remain SETTINGS-001.

## UX-I18N-002 — shared app catalog consumption — 2026-10-13

Classify the previously unassigned shared-catalog requirement as First, as an explicit dependency of the accepted English/German app. Flutter widget consumers use one inherited catalog context; the application title comes from `app.name`. Shared JS remains the editable source, and generated Dart data remains an adapter. Material localization and persisted language selection are separate requirements.

## FOUNDATION-005 — implementation coordination — 2026-10-13

The accepted implementation plan is tracked in `release-1-implementation.md`, with one spec per commit, explicit exclusions and evidence required for completion. The roadmap and product phase now reflect authorized implementation. Older discovery questions are retained as historical research context, not treated as fresh blockers or permission to add later capabilities. Android is the verification target; the owner controls merge and publication. Requirement details and release tags are reconciled individually as their implementations land.

## FOUNDATION-001 — implementation start — 2026-10-13

The owner authorizes first-release implementation in Flutter, using a local-first approach. Android is the first-release verification target. The application lives under `app/`, with Android application ID `io.github.nexa16.piko` and the installed Flutter 3.44.7 / Dart 3.12.2 baseline. This supersedes earlier statements that Flutter was only preferred and no stack had been selected. FOUNDATION-001 establishes an empty application host; it does not claim persistence or product features are complete. The HTML/CSS mockup and canonical shared design/copy sources remain authoritative. Implementation uses one branch, with one requirement ID per commit and owner-controlled merge/release.

## Button default — 2026-10-13

Accepted: Soft filled buttons with 24px corner radius. Canonical tokens define this default for standalone mockup and studio reset. Red Incorrect and green Correct grading remain semantic and equal-width. Other height, padding and font-weight experiments are not approved by this decision.

Planning documents are the initial source of truth. Record accepted changes here and update the affected documents.

## All-popup default — 2026-10-13

The owner extends the close-X pattern to all dialogs, including Collection deletion and creation. X/Escape/backdrop dismiss safely and restore focus; redundant Cancel/Close bottom buttons are removed. Positive destructive Delete remains explicit and closing never deletes. Draft-exit Continue Editing / Discard & Exit remain meaningful separate choices; X means stay and preserve the draft. This supersedes the earlier exception preserving destructive-confirmation Cancel buttons, not the requirement for explicit deletion confirmation. UX-DIALOG-001 now covers all flow areas.

## Review popup dismissal consistency — 2026-10-13

The owner aligns review setup with summary: shared title/close-X header, Escape and backdrop dismissal, with Start remaining the setup's bottom action and no redundant Cancel. Closing setup never launches a session. UX-DIALOG-001 is First. Destructive confirmation cancellation is not removed or implicitly redesigned.

## First-release session summary popup — 2026-10-13

The owner accepts a session summary popup containing learned/completed vocabulary count and first-try-correct count. REVIEW-003 and UX-REVIEW-004 are First. Normal close X, Escape or backdrop dismiss it over the Collection; no Back to Collection button or separate summary page. Studio shortcut previews illustrative 30/23 counts without changing a review session's grades. This supersedes the earlier proposed summary page and content disclaimer; prototype data remain explicitly labelled as samples.

## Collection defaults and vocabulary deletion — 2026-10-13

Accepted: required Collection names default to the selected target language in the interface language; owner customization is preserved and multiple same-language Collections remain allowed (COLL-017, First). Saved vocabulary deletion with mobile swipe discovery, explicit Delete and time-limited Undo is First (ENTRY-009, UX-VOCAB-DELETE-001). Exact production Undo timing remains open. A future trash/recovery area is Later with retention undecided (VOCAB-TRASH-001); prototype Undo timing does not specify retention.

## First-release retry gaps and review correction visibility — 2026-10-13

The owner confirms retry gaps 20, 10, 5, 3, then 1 for the fifth and subsequent errors in the current round. RETRY-001–002 move from Undecided to First. Exact counting/off-by-one conventions, short-wait duration and FSRS interaction remain open; these decisions are not inferred from the sequence. Previous-grade correction is available only before revealing the current card's answer, not after reveal. The studio adds a direct sample-summary preview for design discussion; it is a planning-tool shortcut and does not approve summary content or add a production application shortcut.

## Review reveal and direction controls — 2026-10-13

The owner removes the separate Show Answer button: self-assessment reveals through the card itself, retaining keyboard activation and a small Lucide icon beside the lower-right Tap to reveal cue. Choose one direction before starting; learning displays it once as noninteractive context, with no session direction dropdown. Revealed cards omit Answer revealed status, retain the prompt smaller/muted and emphasize the translation. Hard has a full-column clickable label and comfortable mobile target, remaining a checkbox rather than a third grading button. Previous-grade correction gets a back/undo arrow; red-outline styling remains an experiment. This refines REVIEW-001, CARD-UI-007 and UX-REVIEW-002, superseding the optional separate reveal action. The mockup uses a minimal pre-start direction dialog, not a first-release Settings preference.

## Icon family — 2026-10-13

The owner explicitly confirms Lucide as Piko's icon family. Use consistent outline icons for interface controls, with semantic accessible names and shared size/stroke tokens. Preserve upstream ISC and Feather-derived MIT notices. This replaces the earlier pending family choice; it does not select an application framework or a repository license.

## Design source of truth — 2026-10-13

The owner accepts the HTML/CSS mockup as the authoritative design and interaction reference; no parallel Figma document is required. Centralize semantic colors, spacing, typography, radii, control dimensions and reusable UI components; keep bilingual interface copy in shared/copy.js. Document empty, active, draft, error and disabled states. Future implementation must reproduce accepted behavior and design, adapting to platform accessibility, keyboard and responsive constraints. Flutter is the owner's preferred future direction, not a final stack selection or authorization to implement an application. HTML/CSS is not directly reusable Flutter widget code.

## First-release Settings — 2026-10-13

The owner accepts App Language as the only first-release Settings control, with English/German and retained selection. SETTINGS-001 and UX-SETTINGS-001 are First. Learning direction belongs to the review flow; additional settings remain outside the first-release Settings screen. Prototype language switching remains distinct from production persistence.

## Entry completion versus Back — 2026-10-13

The owner confirms separate top-left Back and top-right global completion checkmark. Global completion saves the final valid draft and exits, without another card; Back requires warning before discarding a nonempty draft. The card checkmark still saves and advances. ENTRY-007 and UX-ENTRY-002 are refined; ENTRY-011 is First. Empty drafts create no entry; incomplete nonempty drafts remain open for validation rather than becoming invalid saved vocabulary. This supersedes the earlier assumption that both top actions share discard behavior.

## First-release review refinements — 2026-10-13

Accepted: one selected direction per session (either direction, not both together); self-assessment red/green grading with fixed 50/50 widths; Hard checkbox and its rating semantics; correction of the immediately previous grade with consistent history/queue updates; no-due empty state; both languages on the revealed answer; one direction display plus progress bar/counter. UNDO-001, CARD-UI-015–016, CARD-UI-019–020, OPEN-CARD-004 and core card/progress rules move to First. Implementation details of rollback remain Open even though required for First. Skip (CARD-UI-021–022) is Later. Mixed expanded direction requirements CARD-005/PREF-005 and dynamic-width CARD-UI-014 are Later as whole requirements, with their first-release portions explicitly captured by REVIEW-001/CARD-UI-025. New answer/empty-state rules are CARD-UI-026/REVIEW-002. No FSRS algorithm parameters or release date are inferred.

## First-release focused entry — 2026-10-13

The owner explicitly includes the complete scroll-focused entry stack in the first release, rather than deferring it as visual polish. ENTRY-001–008 move from Undecided to First; ENTRY-001 moves from Additional to Minimum. UX-ENTRY-001–002 are First. New entries use a checkmark for Save & Next; End entry session is top-right outside the cards. Drafts survive scrolling; saved entry edits auto-save; leaving with a nonempty draft requires Continue Editing / Discard & Exit. ENTRY-009 deletion/Undo and the unresolved mixed ENTRY-010 details are not silently approved by this change. Prototype values for animation thresholds are experiments, not accepted production constants.

## First-release Collections — 2026-10-13

The owner accepted create/name/language pair, multiple Collections including matching pairs, list/open, rename without loss of progress, and confirmed deletion of Collection vocabulary/progress. An empty initial state explains Collections and offers creation. COLL-001 and COLL-012 move from Undecided to First; COLL-012 moves from Proposed to Confirmed. New stable IDs COLL-013–015 and UX-HOME-002 are First. Changing an existing language pair is excluded from the first release (COLL-016, Later). This confirms the Collections block only, not the entire release. The mockup remains a visual prototype; rename/deletion persistence is not implemented.

## Homepage review summary — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Remove the global Ready to review information block; keep review counts and actions per Collection. | Accepted | Owner finds the global block redundant with collection-level information. | Keep the global due-review summary. | Let users start directly from their Collection. | Supersedes the earlier Minimum homepage summary decision; Expanded activity exploration remains separate. |

## Page heading simplification — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Use one page title without decorative eyebrows or redundant subtitles; keep meaningful Collection subtitles. | Accepted | Owner found the three repeated Settings headings unnecessary, but finds the Collection subtitle useful. | Retain the repeated heading block. | Reduce repetition without removing useful context. | Simplify headers throughout the mockup; preserve collection language/count and learning session context. |

## Initial decisions — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | GitHub is used for version history and future collaboration. | Accepted | Piko needs a durable planning home. | Local-only documents or another host. | Owner selected GitHub. | Changes have version history and a collaboration path. |
| 2026-10-13 | The repository begins public. | Accepted | Repository bootstrap. | Private repository. | Owner selected public visibility. | Commit only material suitable for public access. |
| 2026-10-13 | Planning documents are the initial source of truth. | Accepted | Product discovery precedes implementation. | Code-first or external planning tools. | Keep planning lightweight and versioned. | PRODUCT.md defines the product; this log records choices. |
| 2026-10-13 | No GitHub Project or Luufi integration is required for the discovery phase. | Accepted | Low initial delivery volume. | Add integrations immediately. | Owner requested a lightweight bootstrap. | Revisit only when delivery volume justifies more tooling. |
| 2026-10-13 | No application stack is selected during repository bootstrap. | Accepted | Product needs and platform are unresolved. | Select a framework now. | Discovery must inform the technical foundation. | No framework or package manifests are introduced. |
| 2026-10-13 | No open-source license is selected yet. | Accepted | Licensing has not been decided. | Select a license now. | Owner deferred the choice. | Public visibility grants no additional reuse rights through a license. |

## Bootstrap additions — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Integrate the supplied Piko specifications, handoff, and navigation mockup in the initial repository setup. | Accepted | Existing planning is available. | Keep a blank brief only. | Owner requested preserving the existing work. | PRODUCT.md links detailed requirements; remaining unknowns stay explicit. |
| 2026-10-13 | Commit and push the initial bootstrap to main; create develop from it. Main serves releases and develop serves development. | Accepted | Establish branch roles before future implementation. | One branch only. | Owner selected the branch model. | Feature branches target develop; release-ready promotion targets main through a PR. No release is declared. |
| 2026-10-13 | Start GitHub CLI web authentication, show the device code, and open a visible Codex browser tab; the user completes sign-in and authorization. | Accepted | The assisted device-login flow succeeded. | Ask the user to run the command, or use the default browser. | Owner selected this as the project's default authentication flow. | Use the default browser only as a fallback; verify nexa16 before resuming and keep authentication data out of commits. |
| 2026-10-13 | Review the complete proposed publication with the owner before the first push; review new content before later pushes. | Accepted | Repository will be public. | Publish without a shared review. | Owner requested a project-wide public-data review rule. | Inspect contents, history, identities, and metadata; obtain first-push approval and escalate questionable data. |

## Documentation cleanup — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Consolidate the specification index into PRODUCT.md and integrate unique handoff decisions into the specifications. Retain original handoff materials locally, excluded from Git and published history. | Accepted | Overlapping documents complicated navigation. | Publish all overlapping transfer documents. | Owner approved cleanup and local-only handoff retention. | Public documentation stands alone; unpublished bootstrap history must exclude the originals. |
| 2026-10-13 | Record five Collection Overview annotations without applying mockup changes yet. | Accepted | Owner supplied browser feedback and requested deferral. | Change the mockup immediately. | Owner wants the annotations remembered for a later UX pass. | UX specification holds the pending feedback; final wording and layout remain open. |

## Shared naming — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Maintain one editable English/German naming catalog shared by the mockup and future app. | Accepted | Owner wants to try wording live and avoid diverging labels. | Duplicate strings in each consumer. | A single source keeps naming consistent. | Current prototype loads shared/copy.js; live studio edits are drafts until exported into that source. The future app needs a platform adapter. |
| 2026-10-13 | Keep palette, icon family, typography, and visual principles as proposals pending agreement. | Proposed | Owner requested research and choices before polishing the mockup. | Select a design unilaterally. | Visual direction is an owner decision. | Design studio and DESIGN.md show options; no final design or stack chosen. |

## Proposed requirement scope — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Label each functional requirement Base, Minimum, or Additional without changing its existing acceptance status. | Accepted | Owner requested a parallel scope overview. | Leave all requirements undifferentiated. | Make first-version tradeoffs reviewable. | All 214 IDs are labeled; the particular category assignments are proposals, not an accepted release scope. |

## Visual direction and Minimum flow — 2026-10-13

| Date | Decision | Status | Context | Alternatives | Reason | Consequences |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-13 | Use Cobalt as the current color baseline with directly editable semantic color roles. | Accepted | Owner dislikes green and prefers Cobalt and Plum. | Keep green or choose a fixed palette. | Owner selected a cooler direction and wants live tuning. | shared/theme.js is canonical; studio offers color/hex editing, reset, and export. Final values may evolve. |
| 2026-10-13 | Design the homepage for create/open collection → manual entry → Long-term self-assessment review. | Accepted | Owner agrees to begin with a visible Minimum flow. | Design every Additional feature first. | Establish a polished, extensible foundation. | Minimum is the default preview; Expanded permits comparison. Scope labels remain proposals except this explicit flow. |

## Shared Flutter primitives — 2026-10-13

- **Decision:** Include UX-SYSTEM-001 in First release as the reusable component dependency of the accepted Flutter implementation.
- **Status:** Accepted implementation dependency.
- **Context:** The owner requests one canonical configuration for recurring UI properties and implementation matching the binding mockup.
- **Reason:** Shared buttons, fields, cards, headings and page layout keep accepted appearance and accessible states consistent across product screens.
- **Consequences:** Existing recurring CSS measurements are promoted into `shared/design-config.js`; CSS and generated Flutter adapters consume them. Large text can grow controls and wrap validation messages. Product screens, Lucide integration and dialogs retain their own specification commits.

## Template for the next decision

- **Date:** To be decided — when was this choice accepted?
- **Decision:** To be decided — what exactly was chosen?
- **Status:** Proposed / Accepted / Superseded
- **Context:** To be decided — what prompted the decision?
- **Alternatives:** To be decided — what other options were considered?
- **Reason:** To be decided — why was this option selected?
- **Consequences:** To be decided — what changes, constraints, or follow-up work result?
