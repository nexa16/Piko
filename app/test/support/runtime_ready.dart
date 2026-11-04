import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/features/collections/collections_home.dart';

/// Installation reconciliation is real SQLite work, not an animation. Wait on
/// its observable outcome with a bound instead of assuming one settled frame.
Future<void> waitForRuntimeHome(WidgetTester tester, PikoDatabase db) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();
    if (find.byType(CollectionsHome).evaluate().isNotEmpty) return;
  }
  expect(
    find.byType(CollectionsHome),
    findsOneWidget,
    reason: 'Runtime did not finish installation and language hydration',
  );
}
