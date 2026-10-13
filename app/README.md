# Piko application

Flutter application for the local-first first release. Android is the release verification target. The scaffold is intentionally empty; product features follow in individually traceable requirement commits.

Toolchain baseline: Flutter 3.44.7 stable, Dart 3.12.2. Android application ID: `io.github.nexa16.piko`.

From this directory, run `flutter pub get`, `flutter analyze`, `flutter test`, then `flutter run` with an Android emulator or development device available.

SDK paths, caches and build output remain untracked. Generated release builds currently use development signing and are not store publication artifacts. Interface copy and design configuration will use adapters from the canonical `shared/copy.js` and `shared/design-config.js`; this scaffold introduces no separate UI wording or design values.
