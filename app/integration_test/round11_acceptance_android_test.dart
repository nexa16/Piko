import 'package:integration_test/integration_test.dart';
import 'round11_feedback_android_test.dart' as feedback;
import '../test/data/ai_review_jobs_test.dart' as jobs;
import '../test/features/ai_review_job_controller_test.dart' as controller;
import '../test/ui/ai_feedback_test.dart' as ai;
import '../test/ui/ai_page_test.dart' as ai_forms;
import '../test/ui/round10_learning_routes_test.dart' as learning;

/// One serialized real-Android lane, synthetic SQLite and provider doubles.
/// No ordinary database, credentials or paid provider requests are accessed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  feedback.main();
  jobs.main();
  controller.main();
  ai.main();
  ai_forms.main(nativeViewport: true);
  learning.registerRound10LearningRouteTests();
}
