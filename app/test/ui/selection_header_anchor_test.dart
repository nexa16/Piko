import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'vocabulary_selection_test.dart' show SelectionHarness, key;

void main() {
  testWidgets(
    'first selection preserves the first card under an expanded two-direction header',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester, width: 411.4285714);
      final detail = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      await detail.directionBinding!.value!.select(PreferredDirection.both);
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      final card = key('vocabulary-${h.fixture.entry.id}');
      expect(card.hitTestable(), findsOneWidget);
      final before = tester.getRect(card);
      await tester.longPress(card);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids, {h.fixture.entry.id});
      expect(tester.getRect(card), before);
      expect(tester.takeException(), isNull);
    },
  );
}
