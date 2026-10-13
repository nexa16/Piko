# Piko application

Flutter application for the local-first first release. Android is the release verification target. Collection creation persists locally; the overview lists stored Collections and opens their detail by stable identity. The New action opens a validated creation popup. Remaining product features follow in individually traceable requirement commits.

Toolchain baseline: Flutter 3.44.7 stable, Dart 3.12.2. Android application ID: `io.github.nexa16.piko`.

From this directory, run `flutter pub get`, `flutter analyze`, `flutter test`, then `flutter run` with an Android emulator or development device available.

SDK paths, caches and build output remain untracked. Generated release builds currently use development signing and are not store publication artifacts. Interface copy and design configuration will use adapters from the canonical `shared/copy.js` and `shared/design-config.js`; this scaffold introduces no separate UI wording or design values.

Lucide SVGs and their full ISC/Feather MIT notice are edited only in `mockups/assets/icons/lucide`. Android does not package the parent-relative asset paths, so `node tool/generate_shared.mjs` produces byte-identical adapters in `assets/generated/lucide`. Never edit these copies; `--check` rejects changed, missing or extra output. Run `flutter test integration_test/piko_icon_android_test.dart -d <android-device>` to verify real bundled loading and raster rendering. The test fixture does not ship as a product screen.
