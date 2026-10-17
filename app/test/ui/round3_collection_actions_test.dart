import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_search_field.dart';
import 'package:piko/features/speed/speed_launch.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_filters_test.dart' show FilterHarness;
import 'collection_query_detail_test.dart' show projection;
import 'collection_speed_launch_test.dart' show DetailSpeedHarness;

void main() {
  testWidgets('confirmed filter count and direct clear preserve search', (
    tester,
  ) async {
    final h = FilterHarness()..scope.setSearch('  Apfel  ');
    h.scope.setFilters({
      'topic': {'food'},
    });
    await h.mount(tester);
    expect(find.text('Filters (1)'), findsOneWidget);
    final clear = find.byTooltip('Clear filters');
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(h.scope.filters, isEmpty);
    expect(h.scope.search, '  Apfel  ');
    expect(find.text('Filters (1)'), findsNothing);
  });

  testWidgets(
    'genuinely empty hides search and filters, nonempty restores them',
    (tester) async {
      final h = FilterHarness();
      h.service.value = projection(all: [], visible: []);
      await h.mount(tester);
      expect(find.byType(CollectionSearchField), findsNothing);
      expect(find.byKey(const ValueKey('collection-filters')), findsNothing);
      h.service.value = projection();
      h.binding.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(CollectionSearchField), findsOneWidget);
      expect(find.byKey(const ValueKey('collection-filters')), findsOneWidget);
    },
  );

  testWidgets('committed Speed notice persists until explicit dismissal', (
    tester,
  ) async {
    final h = DetailSpeedHarness();
    await h.mount(tester);
    tester.widget<SpeedLaunch>(find.byType(SpeedLaunch)).onCompleted!(1);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('speed-completion-notice')),
      findsOneWidget,
    );
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Speed complete · 1 word'), findsOneWidget);
    final close = find.byWidgetPredicate(
      (w) =>
          w is PikoIconButton &&
          w.semanticLabel == 'Dismiss completion message',
    );
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('speed-completion-notice')), findsNothing);
  });
}
