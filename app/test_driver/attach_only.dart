import 'package:integration_test/integration_test_driver.dart';

// Attach to a manually installed/running test APK only. The coordinator uses
// `flutter drive --use-existing-app` so Flutter cannot retry an install by
// uninstalling the app. Fixtures retain their own metadata/PNG artifacts.
Future<void> main() => integrationDriver(responseDataCallback: null);
