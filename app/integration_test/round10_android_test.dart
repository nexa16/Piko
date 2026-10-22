import 'package:integration_test/integration_test.dart';
import 'search_selection_handover_android_test.dart' as retained;
import 'support/round10_search_render.dart' as rendering;
import '../test/ui/round10_learning_routes_test.dart' as learning;
import '../test/ui/round10_learning_reset_test.dart' as reset;
import '../test/ui/round10_recovery_controls_test.dart' as recovery_controls;
import '../test/ui/collection_views_test.dart' as groups;
import '../test/ui/category_value_order_test.dart' as order;
import '../test/ui/collection_deletion_test.dart' as editors;
import '../test/ui/ai_page_test.dart' as ai_page;
import '../test/data/ai_round10_test.dart' as ai_contract;
import '../test/data/round10_recovery_test.dart' as recovery_data;
import '../test/data/collection_search_scale_test.dart' as query_timing;

/// One serialized lane. All repositories/DB files belong to synthetic fixtures;
/// no ordinary application database, provider, account or external service is used.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  retained.main();
  learning.registerRound10LearningRouteTests();
  reset.main();
  recovery_controls.main(nativeViewport: true);
  for (final variant in [
    (locale: 'en', scale: 1.0),
    (locale: 'de', scale: 2.0),
  ]) {
    groups.registerRound10GroupTests(
      locale: variant.locale,
      scale: variant.scale,
    );
    order.registerRound10OrderTests(
      locale: variant.locale,
      scale: variant.scale,
    );
    editors.registerRound10EditorTests(
      nativeViewport: true,
      locale: variant.locale,
      scale: variant.scale,
    );
  }
  ai_page.main(nativeViewport: true);
  // Pure wire-format tests include the 700-vocabulary lossless payload fixture.
  ai_contract.main();
  // Real native SQLite: memory DBs and uniquely created system-temp DB files.
  // Covers reset guards, durable recovery, TTL, transaction rollback and reopen.
  recovery_data.main();
  // Keep SQL projection and actual Collection rendering timings distinguishable.
  query_timing.main();
  final renderMeasurements = <Map<String, Object>>[];
  rendering.registerRound10SearchRenderTests(
    onMeasurement: (measurement) {
      renderMeasurements.add(measurement);
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['round10SearchRenderMeasurements'] =
          renderMeasurements;
    },
  );
}
