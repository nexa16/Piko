# Verification coverage

This page records source-bound checks for development build **16**, ordinary `main.dart` application source **`e1e6230fff4694bc64e25ccfec2261cc2e0a9d12`**. Its release-mode APK SHA-256 is **`35b38f6403450171528e08a06075c159b86d7920f3e09ea72e3b82375fcf7318`**. Later documentation-only commits do not change that application source. The [manifest](build-manifest.json) owns artifact and capture metadata; [developer setup](development.md#android-verification) owns the safe execution procedure. This is a development artifact, not a store release.

## Host and source checks

The integrated full Flutter run recorded **1,427 passes and 22 failures**. Repairs were followed by **40 passing failed/affected checks**, then **nine passing final AI admission/filter checks**. The Value-append follow-up passed **17 focused data checks**. These are a full run plus focused repairs and follow-ups, not a completely passing full rerun at the frozen source.

Backend protocol checks passed **51 tests** and shared generation checks passed **22 tests**. The last recorded application analysis before packaging reported no issues. These results do not establish native behavior or fresh-machine setup.

## Synthetic Android checks

| Entry and source | Observed result and scope |
| --- | --- |
| Combined `round10_android_test.dart`, `e01d70e` | **54 scenarios plus teardown pass (55 total)**. Search/selection, learning/correction/reset, editor controls, category order/grouping, Trash/recovery and AI form contracts share one serialized lane. |
| Affected `round10_ai_android_test.dart`, frozen `e1e6230` | **11 scenarios plus teardown pass (12 total)**. Final AI admission/form/filter and Collection-level scope. |

The fixtures use actual Android viewport dimensions in English at normal text scale and German at 200%. Real SQLite checks cover recovery, reset, reopen, migration, expiry, Undo and stale-state guards. Protected ordinary database and sentinel files remain unchanged across the synthetic runs. This is focused changed-surface coverage, not a whole-app device or accessibility matrix.

AI fixtures use fake providers. The lossless 700-vocabulary transport fixture reduces **284,803 bytes to 127,701 bytes** through reversible identifier compaction, with no lexical truncation. No fresh paid 700-vocabulary provider request or general linguistic-quality result is claimed.

### Search latency

Measured input-to-matching-render times, including query and actual Collection rendering, were:

| Vocabulary count | Three observed times |
| --- | --- |
| 600 | 377 / 738 / 826 ms |
| 5,000 | 1,869 / 1,724 / 1,822 ms |

The provisional **200 ms** target is unmet. Separate SQL query measurements do not represent these end-to-end times and do not establish full list responsiveness.

## Ordinary build 16

The exact ordinary release-mode APK installs in place and cold-opens. The existing database migrates to schema **23** with all content and learning history preserved: **16 existing tables remain exactly equal**. The previously absent `statistics_origins` singleton is initialized once by the existing Home bootstrap; this expected initialization does not rewrite review history. Existing Collections receive the A1 default, and the retained sentinel is unchanged.

Observed ordinary-app interactions include Compact-row long-press selection, saved-editor Delete cancellation, learning-reset cancellation, heading save status, Collection Settings → Trash and group recovery. Long-term and selected Speed rounds complete with retry totals; completed rounds expose no Previous Review. Trash recovery survives cold restart. Settings group reordering and new-Value append order persist.

After these ordinary interactions, read-only SQLite inspection confirms all three vocabulary entries and their assignments remain identical. Five of six learning directions are unchanged; the exercised direction has exactly the expected Long-term review and Speed-completion marker, with one regular review, one Speed receipt and two statistics events. Trash is empty after recovery, the sentinel is unchanged, and integrity and foreign-key checks pass. The exact ordinary release APK is restored and cold-opens; its installed SHA-256 matches the manifest. Refreshed full captures come from this ordinary APK. These observations are separate from synthetic fixture results.

## Managed backend boundary

The approved version-5 backend is live with the exact reviewed function files and JWT verification enabled. An unauthenticated request returns **401**; existing service limits remain unchanged. This verifies the deployment/authentication boundary, not a new paid provider result or independent deletion of every provider-managed internal copy or backup. Ordinary builds keep AI disabled.

## Limits

Physical-phone and TalkBack coverage remain unverified. There is no complete OS, keyboard, locale or fresh-machine matrix. The configured private-AI APK is built and checksum-verified; the native AI tests use fake providers, and no fresh paid provider attempt is inferred. Earlier published-gallery observations, line coverage and duplication percentages are historical and are not carried forward as measurements of this source. No release/store readiness is implied.
