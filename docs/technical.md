# Technical reference

This reference describes application behavior and its source boundaries. Immutable source links and the [build manifest](build-manifest.json) identify the documented gallery build; the interaction-layout and statistics sections, schema 17 and Speed preservation describe subsequent source changes. Their current source links are relative to this checkout. [Verification coverage](verification.md) states what was actually exercised. End-user instructions belong to the [feature guide](features.md).

## Contents

- [Runtime and preferences](#runtime)
- [Interaction layout](#interaction-layout)
- [Storage and migrations](#storage)
- [Vocabulary identity and content](#vocabulary)
- [Queries, categories and selection](#queries)
- [Learning, retry and correction](#learning)
- [Speed state](#speed)
- [Statistics](#statistics)
- [JSON interchange](#interchange)
- [Shared resources](#resources)

<a id="runtime"></a>
## Runtime and preferences

`main()` registers icon licenses and starts `PikoApp`. The application owns its internal locale controller; an injected controller remains caller-owned. `PikoRuntime` owns one lazy private database and composes Collection, vocabulary, category, query, settings, learning and JSON services over it. The Speed runtime shares that database's learning repository and clock. Routes receive those services rather than opening competing stores.

The runtime hydrates retained language and learning-direction settings and tracks pending writes. A retained supported locale overrides initial composition; missing/unsupported locale falls back to English. Per-Collection query/view state is held through `CollectionViewScopes`; persisted preferences are separate from route-local selection. Settings save failures restore the prior selection and expose retry.

UI composition seams permit injected repositories/controllers/clocks in tests. An injected route or synthetic test entry point is not the ordinary product entry point used by the gallery.

Sources: [`main.dart`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/main.dart), [`PikoRuntime`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/piko_runtime.dart), [`CollectionViewScopes`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/collections/collection_view_scope.dart).

<a id="interaction-layout"></a>
## Interaction layout

Shared pages, dialog bodies and the entry stack preserve the interacted control's top edge during same-surface layout changes. Disclosures retain their header; learning hint/reveal/editor changes retain the learning card. Compensation happens during layout before paint, with no extra blank area added for anchoring. Dialog bodies remain content-sized. Shared controls also capture semantic and keyboard activation without introducing an accessibility node.

Only one interaction owns a scroll container at a time. A new interaction, deliberate scrolling or an explicit reveal takes precedence. Removed controls fall back to their surviving contextual header or neighbor. Scroll bounds, viewport/text-scale changes and keyboard/caret visibility limit exact coordinate retention. Entry-stack navigation keeps its existing centered transition; optional content grows from its header.

These changes are newer than the gallery APK. Source: [shared anchoring](../app/lib/ui/components/piko_interaction_anchor.dart), [entry coordination](../app/lib/features/entry/entry_session_screen.dart). Host behavior and regression checks cover transitions, bounds, raw input, selection, keyboard navigation and enlarged text; device evidence remains tied to the exact tested source.

<a id="storage"></a>
## Storage and migrations

Drift opens the `piko` SQLite database in the platform application-support directory. The schema version is **17**, distinct from the JSON interchange version and APK version. Domain repositories own transactional writes and invariant checks. Foreign-key validation and explicit ownership guards prevent cross-Collection references.

| Stored area | Responsibility |
| --- | --- |
| Collections | UUID, name and target/native language codes. |
| Vocabulary | UUID, Collection ownership, canonical text/comparison keys, stable order, optional added time, activity and hint content/visibility. |
| Examples/categories | Ordered example pairs; Collection-owned dimensions/values and word assignments. |
| Learning | Two directional items per word, serialized FSRS cards, generation/revision guards and Speed completion. |
| Regular reviews/retries | Original events, retry obligations and per-Collection/direction answer ordinals. |
| Settings/allocators | Retained preferences and monotonic identity/order allocation. |

Upgrades run additive/backfill steps appropriate to the starting schema, inside a transaction. Earlier migrations read columns that existed at their stage rather than decoding the newest full row shape prematurely. Existing vocabulary receives directional learning items when the learning schema is introduced. Later upgrades add retry accounting, categories, Speed completion, examples, activity and Collection defaults while preserving prior identities/state.

Saved editors serialize admitted writes, retain invalid raw drafts for correction, and distinguish validation from persistence errors. Pending writes are drained at relevant navigation/learning boundaries. Deletion and Undo use ownership/conflict checks; restoration cannot overwrite unrelated edits. Do not manipulate allocator high-water marks or infer preservation from a newly created empty database. Android preservation and termination protocols are in [developer setup](development.md#android-verification).

Sources: [`PikoDatabase` and migrations](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/local/piko_database.dart), [`openPikoDatabase`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/local/database_connection.dart), [`SqliteVocabularyRepository`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/local/sqlite_vocabulary_repository.dart).

<a id="vocabulary"></a>
## Vocabulary identity and content

Vocabulary display text is NFC-normalized and trimmed at its ends. Comparison keys additionally use locale-independent lowercase, without full Unicode case folding: `ß` remains different from `ss`. Internal spacing, punctuation and accents are not folded away. The final target/native pair must be unique within a Collection, including batch-update results. Stable UUIDs identify records independently of editable text.

A vocabulary entry has two learning directions. Editing words, examples, hints or categories retains that identity and its learning state. Independent `active` state gates both directions and Speed eligibility; it is not a derived readiness/mastery level.

Example pairs preserve order and require both sides when nonempty; each side is capped at 1,000 characters. A hint is capped at 2,000 and has `always`/`hidden` visibility. Collection Hint defaults apply to new content rather than rewriting existing entries. Added timestamps for legacy entries may be unknown; the app does not synthesize historical creation dates.

Sources: [`normalization`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/vocabulary_normalization.dart), [`content model`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/vocabulary_content.dart), [`saved editor controller`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/vocabulary/inline_vocabulary_edit_controller.dart).

<a id="queries"></a>
## Queries, categories and selection

`SqliteCollectionQueryService` produces a consistent snapshot of matching vocabulary, category metadata/assignments and directional readiness. Search uses normalized comparison keys for target/native text. Filters OR values within a dimension and AND across dimensions. Invalid ownership or filter IDs fail rather than being silently interpreted as a different query.

Single dimensions allow one value per word; Multiple dimensions allow several. Display sorting uses normalized Unicode scalar lexical order, without locale collation, accent folding or natural-number sorting. Ties preserve original order. Date sorting puts unknown dates after known ones. Grouping can render one word in several value groups; counts and selection use its identity rather than rendered occurrences.

`CollectionViewPreferences` holds layout, language order, grouping and sorting. Query bindings combine search/filters with those preferences and refresh on database invalidation. Staged dialog choices are committed with Apply. `VocabularySelection` owns only transient UUIDs: Select all unions matching IDs, hidden selections remain selected, and explicit clear/page departure ends selection. It performs no persistent mutation or learning launch.

Sources: [`query service`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/local/sqlite_collection_query.dart), [`view model`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/collections/collection_view_preferences.dart), [`selection`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/vocabulary/vocabulary_selection.dart).

<a id="learning"></a>
## Learning, retry and correction

`LearningScheduler` wraps pinned `fsrs` **2.0.1**. It uses desired retention **0.9**, empty learning/relearning steps, disabled fuzzing and the library's default weights/maximum interval. It requires explicit UTC review instants and calculates immutable transitions; persistence belongs to the repository.

The interface's Incorrect maps to Again. Correct maps to Good unless Hard is selected, in which case it maps to Hard. Two directions retain independent cards. Optimistic item/scope revisions guard duplicate or stale submissions. A normal grade atomically records its regular review and updates scheduling, answer ordinal and any retry obligation.

After successive errors the retry gaps are **20, 10, 5, 3, 1** other answered questions in the same Collection/direction; the triggering answer is excluded. If the available pool cannot fill the gap, the retained fallback makes another attempt eligible after ten seconds. Retry answers update retry/ordinal state, not another FSRS regular-review event. Expiry is stored at the next device-local **04:00**, converted to UTC through calendar construction rather than adding 24 hours. Expiry removes the retry obligation without manufacturing success or changing the original FSRS review.

Immediate previous-grade correction is an atomic replacement guarded by the latest receipt and authoritative state. It retains the regular event UUID/time, recalculates from the exact prior card and adjusts that round's retry without extending expiry. Retry-answer correction does not write normal FSRS history. This is bounded correction, not arbitrary history editing.

Due-session membership and progress separate distinct words, directional work, completion and first-try correctness. Exiting does not invent completion. Readiness presentation derives from current state, not a knowledge-level model. Device timezone/DST and injected-clock host coverage remain distinct verification claims.

Sources: [`LearningScheduler`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/learning/learning_scheduler.dart), [`learning repository`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/local/sqlite_learning_repository.dart), [`retry gap`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/learning/retry_gap.dart), [`learning day`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/core/learning_day.dart).

<a id="speed"></a>
## Speed state

`SpeedSession` is an immutable in-memory fixed-direction pool/pass model. Eligible IDs arrive from the authoritative Collection query. Errors determine required consecutive correct answers, capped at four; Incorrect clears the streak. Completion admits waiting words, and pass boundaries can invoke the numbers minigame while unfinished work remains. There is no final unnecessary minigame.

`SpeedLearningSession` coordinates memory transitions with durable per-word completion. The persistence operation is guarded/idempotent. Every completion retains both directional cards, generations, review revisions, review history, retry obligations and answer ordinals exactly. Only the Speed completion marker and independent statistics records may change. The session's unfinished pool, streaks and number-game state are not a durable resume record. Selection-driven Speed launch is not yet implemented.

Sources: [`SpeedSession`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/speed/speed_session.dart), [`SpeedLearningSession`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/speed/speed_learning_session.dart), [`current Speed completion`](../app/lib/data/local/sqlite_speed_completion.dart).

<a id="statistics"></a>
## Statistics

Schema 17 additively creates independent statistics origin, activity-credit and Speed-receipt tables without foreign keys to vocabulary or Collections. The first successful statistics read or learning write initializes one immutable UTC start and assigned learning date. Migration does not reconstruct prior activity. Regular answers insert their event credit inside the existing learning transaction; grade correction retains that credit. Failed writes roll back learning, initialization and statistics together.

A Speed request freezes the vocabulary UUID, direction and completion UTC instant across retries. Its receipt retains the originally assigned date across timezone changes. Daily credit is separately unique by UUID, direction and learning date, independent of generation or an already-true completion marker. A new completion on another date can earn credit. Storage contains no vocabulary text, Collection names or error-attempt history. Deletion/Undo/import cannot fabricate or remove credit.

The read transaction supplies coverage, totals and history in one committed snapshot. Civil learning dates use device-local 04:00 calendar boundaries, including DST. Dates before coverage are unavailable except for actual later-committed activity assigned to an earlier date, which creates partial coverage there. Future buckets survive clock rollback but remain hidden. The current date, active-day average and uncapped streak are derived without rewriting stored dates.

One runtime-owned binding refreshes after activity, on page open/resume, at the next local boundary and through Android TIME_SET/TIMEZONE_CHANGED/DATE_CHANGED broadcasts. Generation checks discard superseded reads. Loading and failed-refresh state remains explicit; view mode, calendar month and focus belong to the persistent page state. Other platforms use open/resume and boundary refresh. The approved statistics artwork and composition use the shared copy/design catalogs.

Sources: [statistics repository](../app/lib/data/local/sqlite_statistics_repository.dart), [projection](../app/lib/data/statistics_repository.dart), [refresh binding](../app/lib/features/statistics/statistics_binding.dart), [Android bridge](../app/android/app/src/main/kotlin/io/github/nexa16/piko/MainActivity.kt).

<a id="interchange"></a>
## JSON interchange

`VocabularyJsonService` separates consistent export, read-only analysis and confirmed apply. `VocabularyJsonPlatform` isolates Android file-picker/clipboard operations and their cancellation/failure outcomes. No broad storage permission or user-visible private database path is required.

| Contract | Implemented behavior |
| --- | --- |
| Envelope | `format: "piko-vocabulary"`; export `schemaVersion: 4`; import versions 1–4; exactly one Collection with a matching language pair. |
| Limits | 1,000,000 UTF-8 bytes; bounded entries/content and type/identity validation. |
| Export | Collection, category definitions/assignments, entries, examples, hint, activity, added date and associated directional learning/review/retry data. Scheduler metadata identifies card compatibility. |
| Import | Selected target/native/category/example/hint/activity groups; omitted or unselected existing content is retained. Imported learning is ignored. New words receive fresh learning state and default activity/Hint behavior where omitted. |
| Identity | Existing owned UUIDs select updates; foreign/duplicate IDs and final duplicate word pairs fail validation. Collection metadata does not replace the destination. |
| Apply | Confirmation follows analysis. Authoritative stale-preview and one-shot guards precede an atomic transaction; no partial batch on failure. |

The in-app example generator produces synthetic structure for the destination language pair. Use it as the shape reference rather than inventing a second independently maintained JSON example. Collection export is not whole-app backup and import is not progress restoration. Schema-4 Activity is independent of learning. Unknown source versions and malformed data must be corrected before apply; the UI's row/path feedback identifies the affected location.

Sources: [`format and interfaces`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/vocabulary_json.dart), [`JSON service`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/local/sqlite_vocabulary_json_service.dart), [`platform adapter`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/platform/vocabulary_json_platform.dart).

<a id="resources"></a>
## Shared resources

`shared/copy.js` owns EN/DE labels and matching placeholders; `shared/design-config.js` owns semantic colors, typography, spacing and reusable component configuration. The generator validates and emits the Flutter catalog and byte-identical icon adapters. Generated files are tracked outputs, not independent editable defaults.

Lucide SVG source and notices live in `mockups/assets/icons/lucide`; the app packages generated copies under its own assets directory. Nunito Sans and Korean fallback font assets and their notices are bundled offline. Original artwork and Android system UI have their own appearance; historical mockups are not product screenshot evidence. The Android release configuration currently uses debug signing and is not a store-ready signing setup.

Sources: [`generator`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/tool/generate_shared.mjs), [`dependencies and assets`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/pubspec.yaml), [`Android build configuration`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/android/app/build.gradle.kts).
