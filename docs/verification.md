# Verification coverage

This page records source-bound checks for development build **17**, ordinary `main.dart` application source **`951018dcdf494754526f2fc7d8e9540e6bc31900`**. Its release-mode APK SHA-256 is **`36f6b20e9d965c69c9b769049ab6aa49b20da71fd5e0d4f7e54731f7e6cb32f3`**. Later documentation/test-only commits do not change that application source. The [manifest](build-manifest.json) owns artifact and capture metadata; [developer setup](development.md#android-verification) owns the safe execution procedure. This is a development artifact, not a store release.

## Host and source checks

The integrated full Flutter run recorded **1,493 passing tests and one failure**. The remaining failure was a Windows host test incorrectly expecting an Android platform-channel subscription. After making its Android condition explicit, **10 focused clock/settings tests passed**. These results are a full run plus focused repair, not a completely passing full rerun at the frozen source. Earlier migration-fixture and layout repairs were included in the integrated run.

Backend protocol, worker and database checks passed **77 tests**, using provider doubles and a local PostgreSQL-compatible fixture with a minimal queue implementation. Shared-generation checks passed **22 tests**, and generated catalogs matched their sources. The last recorded application analysis reported no issues. The Dart-produced review-manifest digest also matched the backend implementation. These results do not establish hosted queue/scheduler operation, native behavior or fresh-machine setup.

## Synthetic Android checks

| Entry and source | Observed result and scope |
| --- | --- |
| Combined `round11_acceptance_android_test.dart`, application source `18dced1` | **22 scenarios plus teardown passed** for job persistence/control, AI forms and learning routes. The separate feedback scenario initially failed a fixture tap; it is not counted as passing in this run. |
| `round11_feedback_android_test.dart`, same Dart application source | After correcting fixture gestures, **one complete scenario plus teardown passed** in English at normal scale: cards, selection, actual keyboard interaction, Undo and language-pair preservation. |
| `round11_feedback_android_test.dart`, frozen `951018d` | **One complete scenario plus teardown passed** in German at a 320-logical-pixel width and 200% system font scale. Original emulator display settings were restored afterward. |
| `round11_ai_access_android_test.dart`, same frozen application source | **Two scenarios plus teardown passed**, EN/DE: actual managed client/connection controller with in-memory HTTP, retained identity, explicit consent updates the stale access label, return to form and one explicit generation. No socket or paid provider request. |

The emulator runs on Android API 36. Synthetic fixtures use isolated databases and provider doubles. Protected ordinary database and sentinel files remain unchanged across the fixture runs. The feedback scenario checks exact restoration of seven content/learning tables after Undo under filtering, sorting and grouping; language-pair metadata changes preserve learning data. Real keyboard checks cover raw invalid drafts, close/correction behavior and outside-tap focus handling. Inspected captures supplement the interaction assertions.

These are focused changed-surface checks. The historical keyboard/dialog transient was not reproduced; passing the named current flows does not establish its historical cause. Selection/layout evidence covers the tested English and German states, not a whole-app visual or accessibility matrix.

Host/backend fixtures exercise a 700-entry review scope, batch-boundary planning, restart/retry, stale generations, cancellation, reservations and idempotent adoption. An additional five-test controller run passes the combined filtered-700 fixture: 600 exact matches including 200 inactive entries, 24 upload chunks, excluded vocabulary absent, frozen options and GET-only restart. Distant related entries remain in the payload; backend fixtures separately check cross-shard planning. This is controlled local protocol evidence, not a paid end-to-end linguistic review. No fresh paid 700-entry provider request or general linguistic-quality result is claimed.

### Search latency

Historical input-to-matching-render measurements, including query and actual Collection rendering, were:

| Vocabulary count | Three observed times |
| --- | --- |
| 600 | 377 / 738 / 826 ms |
| 5,000 | 1,869 / 1,724 / 1,822 ms |

These are retained measurements from the preceding application source, not new build-17 benchmarks. The provisional **200 ms** target was unmet; the existing speed was accepted without a new optimization task. Separate SQL query measurements do not represent these end-to-end times.

## Ordinary build 17

The exact ordinary release-mode APK installs in place and cold-opens. Its schema **23 → 24** migration preserves all **18 existing tables exactly**, including content and learning state. The two new operational tables start empty. Database integrity passes, there are no foreign-key violations, and the retained sentinel remains unchanged. This observation uses the retained populated database; a fresh empty fixture is not substituted for upgrade evidence.

The final ordinary candidate also exercises launcher entry, direct component entry, background return and repeated launcher entry. Each path retains exactly one Piko task with the same identity. An obsolete empty task left by the earlier launcher behavior was removed by the final candidate's narrowly guarded cleanup. That cleanup runs on API 29 and later; API 24–28 retain the preventive task configuration, but cleanup on those versions is not claimed verified. The checked-in task-reuse probe observes navigation and task identity without deleting tasks or data.

Ordinary-product captures and their source/configuration are identified separately in the manifest. Synthetic fixture captures are not product screenshots.

## Managed backend boundary

The previously approved version-5 backend remains the live service. The new persistent full-review jobs, queue and scheduled worker are implemented and tested locally but **have not been deployed or activated**. The client checks the server's supported capability before creating a local job or content lock; an unavailable legacy service cannot silently fall back to paid generation.

The private-AI development APK is built separately; its SHA-256 is **`9c30c2fb0ee5be099ece89b1c2f8b7668cdb68b6d89d20ce256bb946551257c3`**. Ordinary builds keep AI disabled. Neither APK packaging nor local doubles prove production model access, actual pricing/limits, hosted queue concurrency, scheduler availability or provider-managed deletion. Those remain activation-checkpoint conditions.

## Limits

Physical-phone and TalkBack coverage remain unverified. There is no complete OS, keyboard, locale or fresh-machine matrix. No fresh paid provider attempt, productive full-review activation or release/store readiness is inferred. Earlier published-gallery observations, line coverage and duplication percentages are historical and are not carried forward as measurements of this source.
