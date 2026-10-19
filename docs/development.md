# Developer setup

Use this page for commands; the [technical reference](technical.md) owns architecture and the [feature guide](features.md) owns app tasks. The [manifest](build-manifest.json) identifies the documented APK and its original source. [Verification coverage](verification.md) records which commands/environments were exercised; an existing workspace check is not a clean-machine installation test.

## Prerequisites

- Git and Node.js for the shared catalogs and host checks.
- Flutter **3.44.7 stable** with Dart **3.12.2**, the baseline used for the documented application.
- Android SDK platform/build tools for API 36, platform-tools/ADB and a compatible JDK. Android compilation targets Java 17; Flutter doctor reports the configured JDK.
- An Android emulator or explicitly authorized development device. The selected APK supports Android API 24 and later and targets API 36.

Keep machine-specific SDK paths in untracked Android `local.properties` and environment configuration. Do not commit SDKs, caches, keys, APKs or personal data. Other platforms are not claimed verified by this Android baseline.

## Prepare dependencies and generated resources

From the repository root:

```powershell
flutter --version
flutter doctor -v
node --version
node app/tool/generate_shared.mjs --check
```

From `app/`:

```powershell
flutter pub get
```

The lockfile pins the resolved dependencies. If editing interface copy/design, edit `shared/copy.js` / `shared/design-config.js`, then run `node app/tool/generate_shared.mjs` from the root and inspect the generated diff. Never repair generated catalogs directly. Icon source and full notices live in `mockups/assets/icons/lucide`; the same generator copies them into app assets.

The documentation checker resolves immutable source references against the manifest's `sourceCommit`. If that original candidate commit is absent from a shallow or squash-only clone, fetch it before running the checker:

```powershell
git fetch origin <source-commit-from-manifest>
```

For database source changes, generate Drift output from `app/`:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Generation is needed when its inputs change; it is not a routine step for editing documentation. Check migrations against populated supported older schemas before adopting a database change.

## Host checks

From `app/`:

```powershell
flutter analyze
flutter test
```

From the repository root:

```powershell
node --test app/tool/*.test.mjs
node --test mockups/*.test.cjs
node --test tools/check-documentation.test.mjs
node tools/check-documentation.mjs
git diff --check
```

The mockup suite includes historical exploration checks and is not Android acceptance. Review failures against their actual baseline and affected scope. Test names describe intent; report observed results instead of inferring a pass from their presence.

## Run and package

On a disposable development emulator, from `app/`:

```powershell
flutter devices
flutter run -d <android-device-id> --target lib/main.dart
```

For a normal application APK:

```powershell
flutter build apk --release --target lib/main.dart --build-number=<candidate-number>
```

The artifact is produced under `app/build/app/outputs/flutter-apk/`. Preserve a candidate outside build output with its full source identity, configuration and SHA-256 before another build. A rebuild with the same version fields is a different artifact if its bytes differ. The checked-in version is not a substitute for the actual APK's identity.

After integration testing, run the normal build command without `--no-pub` so release-mode plugin registration is refreshed. A separate `pub get` does not repair all stale mode-specific registrants. Release-mode APKs currently use debug signing and are development artifacts; this command does not prepare store signing or publish a release.

<a id="android-verification"></a>
## Android verification and data preservation

Prefer a separate emulator with synthetic data. Build the required test target first; inspect package/version/signature and free space before installation. On any device with data to preserve, use explicit direct installation and stop on failure:

```powershell
adb -s <device-id> install -r -t <test-apk>
```

Do not continue if installation fails. Do not clear storage, uninstall, force a downgrade or retry through automatic Flutter installation. In the baseline toolchain, automatic installation can fall back to uninstall after an error despite `--no-uninstall`.

Start the installed test activity, obtain and forward its VM service, then attach from `app/`:

```powershell
flutter drive --use-existing-app=<forwarded-vm-service-url> --driver=test_driver/attach_only.dart -d <device-id>
```

Use the fixture's isolated storage and preservation protocol. Keep a private before/after inventory and a pre-existing sentinel. Restore a compatible normal APK through direct in-place installation and verify its cold launch and retained sentinel. A new empty database is not preservation evidence. Never run integration fixtures on a personal device without explicit approval.

Relevant fixtures include `count_refresh_android_test.dart` for production header/launch widgets under delayed, failed and obsolete reads using actual native dimensions and isolated in-memory fixtures; `round5_android_test.dart` for editor/content/activity learning integration, `retry_expiry_android_test.dart` for isolated retry expiry, `offline_vocabulary_android_test.dart` for repository persistence and `piko_icon_android_test.dart` for packaged SVG rendering. Older inline-edit fixtures retain earlier interaction assumptions; inspect the selected contract before using them as acceptance. Fixture captures must not be published as ordinary-product screenshots.

### Termination durability exception

The paired `entry_termination_prepare_android_test.dart` / `entry_termination_verify_android_test.dart` deliberately exercise the production database on an emulator. Both phases require the same unique `--dart-define=PIKO_TERMINATION_RUN=<run-id>`. Preparation confirms through the UI, leaves a raw draft and waits at `ENTRY008_READY:<run-id>`. The coordinator checks readiness/live PID, force-stops and confirms process absence; preparation is interrupted, not passed. Restore the compatible normal APK in place and cold-launch before verification.

Verification compares the exact logical baseline, saved checkpoint and fresh draft behavior. Cleanup deletes only unchanged owned synthetic rows, checks learning/retry/ordinal descendants and retains allocator high-water marks. Any mismatch stops cleanup. Restore the normal APK and compare the retained sentinel afterward. Keep detailed inventory/evidence private. The focused host preservation checks are `test/data/entry_termination_guards_test.dart`; they do not replace this Android protocol.

## Working tree and contribution workflow

Use focused branches from accepted `develop`, preserve unrelated edits and inspect generated diffs. Follow [CONTRIBUTING](../CONTRIBUTING.md) for review/integration and [AGENTS](../AGENTS.md) for automation rules. The [maintenance procedure](maintenance.md) keeps the current documentation aligned with a verified candidate. No release, store upload or publication is implicit in setup/build commands.
