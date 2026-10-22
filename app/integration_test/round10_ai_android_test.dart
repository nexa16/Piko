import 'package:integration_test/integration_test.dart';
import '../test/ui/ai_page_test.dart' as ai;
import '../test/ui/ai_stage_admission_test.dart' as stage;
import '../test/ui/collection_level_test.dart' as level;

// Final affected-scope rerun after AI admission/form repairs. Every fixture is
// synthetic; no production database, external provider or account is touched.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ai.main(nativeViewport: true);
  stage.main();
  level.main();
}
