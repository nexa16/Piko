# Piko application

Flutter application for the local-first first release. Android is the release verification target. Collection creation persists locally; the overview lists stored Collections and opens their detail by stable identity. The New action opens a validated creation popup. Remaining product features follow in individually traceable requirement commits.

Toolchain baseline: Flutter 3.44.7 stable, Dart 3.12.2. Android application ID: `io.github.nexa16.piko`.

From this directory, run `flutter pub get`, `flutter analyze`, `flutter test`, then `flutter run` with an Android emulator or development device available.

Android integration runs must use `flutter test --no-uninstall integration_test/<fixture>.dart -d <android-device>`. Flutter 3.44.7 otherwise uninstalls the application after the test and deletes its app data. Use isolated fixture storage, verify a pre-existing sentinel survives runner cleanup, then restore the normal debug APK with an in-place install. Never infer data preservation merely from seeing a newly created database after relaunch. Do not use these integration commands on a personal device without a verified backup and explicit approval.

SDK paths, caches and build output remain untracked. Generated release builds currently use development signing and are not store publication artifacts. Interface copy and design configuration will use adapters from the canonical `shared/copy.js` and `shared/design-config.js`; this scaffold introduces no separate UI wording or design values.

Lucide SVGs and their full ISC/Feather MIT notice are edited only in `mockups/assets/icons/lucide`. Android does not package the parent-relative asset paths, so `node tool/generate_shared.mjs` produces byte-identical adapters in `assets/generated/lucide`. Never edit these copies; `--check` rejects changed, missing or extra output. Run `flutter test --no-uninstall integration_test/piko_icon_android_test.dart -d <android-device>` to verify real bundled loading and raster rendering. The test fixture does not ship as a product screen.

`integration_test/offline_vocabulary_android_test.dart` verifies the production repositories save with HTTP blocked and retain vocabulary identity, canonical text, ownership and comparison keys after file reopen. It owns and cleans a unique application-support subdirectory and never opens the runtime piko database. The recorded Android offline run also disabled external connectivity and restored the original network settings afterward. This storage check does not verify future manual-entry UI or application termination durability. Development Internet permissions remain available for Flutter tooling.
