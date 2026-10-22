import 'package:integration_test/integration_test.dart';
import '../test/ui/collection_search_field_test.dart' as search;
import '../test/ui/selected_deletion_test.dart' as deletion;

// Uses isolated in-memory fixture repositories, never the ordinary app database.
// Exercise the real Flutter/native input channel and production Collection UI.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  search.main();
  deletion.main();
}
