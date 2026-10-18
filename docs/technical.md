# Technical reference

This reference describes the application source selected by the [build manifest](build-manifest.json). Source links below are immutable links to that commit; documentation commits do not change APK provenance. [Verification coverage](verification.md) states what was actually exercised. End-user instructions belong to the [feature guide](features.md).

## Contents

- [Runtime and preferences](#runtime)
- [Storage and migrations](#storage)
- [Vocabulary identity and content](#vocabulary)
- [Queries, categories and selection](#queries)
- [Learning, retry and correction](#learning)
- [Speed state](#speed)
- [JSON interchange](#interchange)
- [Shared resources](#resources)

<a id="runtime"></a>
## Runtime and preferences

`main()` registers icon licenses and starts `PikoApp`. The application owns its internal locale controller; an injected controller remains caller-owned. `PikoRuntime` owns one lazy private database and composes Collection, vocabulary, category, query, settings, learning and JSON services over it. The Speed runtime shares that database's learning repository and clock. Routes receive those services rather than opening competing stores.

The runtime hydrates retained language and learning-direction settings and tracks pending writes. A retained supported locale overrides initial composition; missing/unsupported locale falls back to English. Per-Collection query/view state is held through `CollectionViewScopes`; persisted preferences are separate from route-local selection. Settings save failures restore the prior selection and expose retry.

UI composition seams permit injected repositories/controllers/clocks in tests. An injected route or synthetic test entry point is not the ordinary product entry point used by the gallery.

Sources: [`main.dart`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/main.dart), [`PikoRuntime`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/piko_runtime.dart), [`CollectionViewScopes`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/collections/collection_view_scope.dart).

<a id="storage"></a>
## Storage and migrations

Drift opens the `piko` SQLite database in the platform application-support directory. The schema version is **16**, distinct from the JSON interchange version and APK version. Domain repositories own transactional writes and invariant checks. Foreign-key validation and explicit ownership guards prevent cross-Collection references.

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

`SpeedLearningSession` coordinates memory transitions with durable per-word completion. The persistence operation is guarded/idempotent. Error-free completion retains the existing directional card; completion after error starts a fresh generation for that direction and clears incompatible retry state. The other direction is preserved. The session's unfinished pool, streaks and number-game state are not a durable resume record. This build does not implement selection-driven Speed launch or persistent Speed statistics.

Sources: [`SpeedSession`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/speed/speed_session.dart), [`SpeedLearningSession`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/features/speed/speed_learning_session.dart), [`Speed completion`](https://github.com/nexa16/Piko/blob/0afecdbc083c00bd34ce8f70c31473725af58377/app/lib/data/local/sqlite_speed_completion.dart).

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
