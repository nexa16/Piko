# Documentation verification

The [manifest](build-manifest.json) owns the exact APK/source and capture identity. This page summarizes evidence scope; it is not a second build registry or a claim of complete app acceptance.

## Ordinary-product observation

The preserved APK and the installed Android `base.apk` had identical SHA-256. Package/version/SDK fields and the Android debug certificate were inspected. The normal `main.dart` / `MainActivity` entry point ran without an instrumented APK, injected route or package-ID override.

A separate API-36 Android 16/x86_64 emulator used newly created storage and non-identifying synthetic French/German vocabulary. The existing emulator and its app storage were not modified. All published images are unmodified full captures, including Android system UI. Capture-specific locale, time, state and dimensions live in the manifest. Most are English; one illustrates German Settings. These images do not establish every locale/size combination.

| Flow | Directly observed on the selected ordinary APK |
| --- | --- |
| Collections | Empty Home, normal creation/language selection, opening a populated Collection, help, confirmed deletion back to empty Home. |
| Entry/editing | Explicit Save & Next draft confirmation; optional example pair/hint; saved inline editor; actual Android keyboard edits with Saved feedback; restored text and activity after reopening. |
| Categories/list | Imported category definitions, expanded management controls and alphabetical values; applied grouping/sorting; group expansion; filtering to one matching word. |
| Selection | Long-press activation, four-word Select all, filtered hidden-selection count and explicit clear. |
| Long-term | Reveal, same-answer editor, Incorrect, immediate previous-grade correction, Correct, fallback retry countdown, retry answer and four-completed/three-first-try summary. |
| Speed | Setup, reveal, Correct advancing completion from zero to one, exit with the completed result retained. |
| Interchange | Native Android file selection, three-new/zero-error analysis, explicit confirmed apply, native save-file export and saved-file feedback. The private exported synthetic JSON contains schema-4 vocabulary and directional learning. |
| Settings/recovery | English/Deutsch switching and German retention after force-stop/cold launch; Inactive retained after editor reopen; vocabulary deletion and immediate Undo restoration in a bounded sequence. |

The first attempt to use Undo after a separate inspection delay had already expired; a subsequent delete/Undo sequence restored the word. No broader history-restoration claim follows. Capture times describe successive states, not one simultaneous database snapshot.

## Source inspection

Application code, packaged assets and shared catalogs in this documentation checkout match the selected APK's source trees. Later documentation and test-fixture commits do not make the APK a new build. The [technical reference](technical.md) links its claims to immutable files at the manifest commit. In particular, scheduling parameters, retry gaps/expiry, transaction/identity guards, migration behavior, optional-content validation, Speed reset rules and import compatibility are source-backed claims; observing a few screens does not independently prove all of them.

## Host and setup checks

| Check | Result in the existing Windows workspace |
| --- | --- |
| Toolchain/version and doctor | Baseline Flutter/Dart confirmed; Android API-36 toolchain and licenses available with the Android Studio bundled JDK 21. Windows desktop lacks Visual Studio and is not a verified target. |
| Dependency setup | `flutter pub get` succeeds without tracked dependency changes. |
| Analysis | `flutter analyze`: no issues. |
| Full host regression | `flutter test`: all 1,197 tests pass. |
| Normal APK packaging | The documented release build command succeeds with `lib/main.dart` and build-number override. This command-check output was not installed or substituted for the original documented artifact. |
| Shared resources | Generated adapters current; all 22 generator tests pass. |
| Documentation checker | Links/anchors, selected-source references, manifest and all 22 images pass; six focused checker regression tests pass. |
| Historical mockup suite | 81/82 pass. The unchanged Speed warning-color test in `mockups/learning-actions.test.cjs` fails because an undefined color reaches its luminance helper; this is the inherited baseline failure, outside the documentation change. |
| Rendered reading | Seven Markdown pages rendered at 1280px and 390px; no page overflow or broken images. Representative prose, tables and product images inspected. |

A clean-machine dependency installation, physical-phone check and unsupported-platform setup are not claimed. Building another APK for command verification does not replace the manifest-selected artifact or relabel its screenshots. Database code generation and the intrusive Android fixture protocols are documented for their applicable changes; they were not rerun for this prose/capture package.

## Limits

No physical-phone install/update, TalkBack audit, complete keyboard/locale/scale matrix, fresh Android schema-upgrade/termination protocol, DST boundary exercise, Speed minigame or error-reset device scenario was performed for this documentation capture session. Prior instrumented checks remain evidence of their own revisions; none are presented as gallery images or fresh product checks. Capture/host success does not close app findings or establish release readiness.
