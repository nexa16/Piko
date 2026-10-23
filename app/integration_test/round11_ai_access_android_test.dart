import 'package:integration_test/integration_test.dart';
import '../test/ui/ai_access_status_test.dart' as access;

/// Exact managed-access UI, isolated SQLite and in-memory HTTP transport.
/// No ordinary database, native vault, network or provider charges are used.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  access.main();
}
