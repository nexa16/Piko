# Implementation foundation requirements

## FOUNDATION-001 — Flutter Android application scaffold

**Status:** Accepted for First release implementation.

The owner authorizes Flutter implementation under `app/`, with a local-first approach and Android-only release verification. The application identifier is `io.github.nexa16.piko`. The installed baseline is Flutter 3.44.7 stable with Dart 3.12.2.

Acceptance:

- A Flutter application and Android host exist under `app/`.
- Android namespace and application ID both equal `io.github.nexa16.piko`.
- Startup renders an empty shell without example counter, sample vocabulary, or fabricated collections.
- Dependencies are locked through the checked-in application lockfile.
- A widget startup test passes and static analysis reports no issues.
- SDK paths, build output, editor configuration and caches are excluded from version control.
- The debug Android application builds, installs and launches on the verification emulator.

This requirement establishes the application host only. Storage, shared design/copy adapters, product screens and scheduling retain their own requirements and commits. Generated launcher assets are temporary Flutter scaffold assets, not an accepted Piko brand design. Development signing does not establish a store-ready release.

Verification from `app/`: `flutter analyze`, `flutter test`, and a debug APK build/install/launch. Full product behavior is verified as implementation proceeds.
