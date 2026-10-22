import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'vocabulary_selection_test.dart' show SelectionHarness, key;

void main() {
  testWidgets(
    'cancel retains hidden selected UUID; confirmed delete excludes unrelated words',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester);
      await h.start(tester);
      final selected = h.fixture.entry.id;
      final field = key('collection-search');
      await h.reveal(tester, field);
      await tester.enterText(field, 'Word 18');
      await tester.pumpAndSettle();
      final action = key('vocabulary-delete-selection');
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.text('Delete 1 selected vocabulary entries?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids, {selected});
      expect(tester.widget<PikoButton>(action).onPressed, isNotNull);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
        find.text('Delete 1 selected vocabulary entries?'),
        findsOneWidget,
      );
      final confirm = find
          .byWidgetPredicate(
            (w) => w is PikoButton && w.label == 'Delete vocabulary',
          )
          .last;
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(h.selection(tester).active, isFalse);
      final words = await h.fixture.vocabulary
          .watchByCollection(h.fixture.owner.id)
          .first;
      expect(words, hasLength(19));
      expect(words.any((word) => word.id == selected), isFalse);
      expect(words.any((word) => word.targetText == 'Word 18'), isTrue);
      final undo = find.byWidgetPredicate(
        (w) => w is PikoButton && w.label == 'Undo',
      );
      expect(undo, findsOneWidget);
      final rect = tester.getRect(undo);
      expect(rect.bottom, lessThanOrEqualTo(900));
      expect(rect.top, greaterThan(0));
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(
        (await h.fixture.vocabulary.watchByCollection(h.fixture.owner.id).first)
            .any((w) => w.id == selected),
        isTrue,
      );
    },
  );
}
