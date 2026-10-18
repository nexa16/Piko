import 'package:piko/data/learning_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../data/speed_eligibility_test.dart' show completeSnapshot;
import 'vocabulary_selection_test.dart' show SelectionHarness, key;

void main() {
  testWidgets(
    'F26 selected Header keeps hidden UUID, true directional counts, disabled zero and selected Long-term start',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester);
      await h.start(tester);
      final detail = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      await detail.directionBinding!.value!.select(PreferredDirection.both);
      final item = await h.fixture.current();
      final card = item.card
        ..due = h.db.clock.now().toUtc().add(const Duration(days: 3));
      await h.db.customStatement(
        'UPDATE learning_items SET card_json = ? WHERE id = ?',
        [LearningCardCodec.encode(card), item.id],
      );
      detail.queryBinding!.scope.setSearch('nothing matches');
      await tester.pumpAndSettle();
      final selection = h.selection(tester);
      final before = await completeSnapshot(h.db);
      final forward = key('collection-review-targetToNative');
      final reverse = key('collection-review-nativeToTarget');
      expect(tester.widget<PikoButton>(forward).onPressed, isNull);
      expect(tester.widget<PikoButton>(reverse).onPressed, isNotNull);
      expect(tester.widget<PikoButton>(forward).label, contains('0'));
      expect(tester.widget<PikoButton>(reverse).label, contains('1'));
      for (final name in ['targetToNative', 'nativeToTarget']) {
        expect(
          tester.widget<PikoButton>(key('collection-speed-$name')).label,
          contains('1'),
        );
      }
      expect(find.byKey(const ValueKey('selected-speed-launch')), findsNothing);
      expect(await completeSnapshot(h.db), before);
      await tester.ensureVisible(reverse);
      await tester.tap(reverse);
      await tester.pumpAndSettle();
      final route = tester.widget<ReviewSessionRoute>(
        find.byType(ReviewSessionRoute),
      );
      expect(route.session.members.map((m) => m.entryId).toSet(), {
        h.fixture.entry.id,
      });
      expect(selection.ids, isEmpty);
      expect(await completeSnapshot(h.db), before);
      expect(tester.takeException(), isNull);
    },
  );
}
