import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'vocabulary_selection_test.dart' show SelectionHarness, key;

void main() {
  testWidgets(
    'real runtime includes hidden reviewed selection; cancellation keeps scroll; departure clears selection',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester);
      await h.start(tester);
      final detail = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      final scope = detail.queryBinding!.scope;
      await detail.directionBinding!.value!.select(PreferredDirection.both);
      await tester.pumpAndSettle();
      final selection = h.selection(tester);
      final another = detail.queryBinding!.snapshot!.allEntries.last;
      selection.toggle(another.id);
      await scope.saveView(
        const CollectionViewPreferences(sort: VocabularySort.targetDescending),
      );
      scope.setSearch(another.targetText);
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = scroll.pixels;
      final savedSelection = selection.ids;
      await tester.tap(key('selected-speed-launch'));
      await tester.pumpAndSettle();
      await tester.tap(key('selected-speed-direction-targetToNative'));
      await tester.pumpAndSettle();
      expect(find.text('Selected active words: 2'), findsOneWidget);
      expect(find.text('Included but hidden in the list: 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(selection.ids, savedSelection);
      expect(scroll.pixels, closeTo(offset, .1));
      await tester.tap(key('selected-speed-launch'));
      await tester.pumpAndSettle();
      await tester.tap(key('selected-speed-direction-targetToNative'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Speed'));
      await tester.tap(find.text('Start Speed'));
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsNothing);
      final route = tester.widget<SpeedSessionRoute>(
        find.byType(SpeedSessionRoute),
      );
      expect(route.session.state!.entryIds, [another.id, h.fixture.entry.id]);
      expect(selection.ids, isEmpty);
      expect(selection.active, isFalse);
    },
  );
}
