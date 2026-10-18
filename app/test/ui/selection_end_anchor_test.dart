import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'vocabulary_selection_test.dart' show SelectionHarness, key;

void main() {
  testWidgets(
    'F26 near-end selection and clearing preserve the visible card without a reserved Browse footer',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester);
      final detail = h.fixture.owner.id;
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      final words = tester.widgetList<Widget>(
        find.byKey(ValueKey('collection-vocabulary-$detail')),
      );
      expect(words, isNotEmpty);
      final ids = h.selection(tester);
      final all = tester.widgetList<Widget>(find.byType(Scrollable));
      expect(all, isNotEmpty);
      final binding = tester
          .widget<CollectionDetail>(find.byType(CollectionDetail))
          .queryBinding!;
      final lastRecord = sortVocabulary(
        binding.snapshot!.entries,
        binding.scope.view.sort,
      ).last;
      final last = key('vocabulary-${lastRecord.id}');
      await h.reveal(tester, last);
      final before = tester.getRect(last).top;
      await tester.longPress(last);
      await tester.pumpAndSettle();
      expect(tester.getRect(last).top, closeTo(before, .5));
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      final visible = tester.getRect(last).top;
      final selectedMax = scroll.maxScrollExtent;
      await tester.tap(key('vocabulary-clear-selection'));
      await tester.pumpAndSettle();
      expect(ids.ids, isEmpty);
      expect(key('vocabulary-selection-panel'), findsNothing);
      expect(tester.getRect(last).top, closeTo(visible, .5));
      expect(scroll.maxScrollExtent, lessThan(selectedMax));
      await tester.dragFrom(const Offset(25, 450), const Offset(0, 180));
      await tester.pumpAndSettle();
      expect(scroll.pixels, lessThanOrEqualTo(scroll.maxScrollExtent));
    },
  );
}
