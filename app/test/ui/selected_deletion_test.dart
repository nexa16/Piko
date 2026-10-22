import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:flutter/material.dart';
import 'vocabulary_selection_test.dart' show SelectionHarness, key;

void main({bool nativeViewport = false}) {
  testWidgets('Compact language text keeps row selection and editor gestures', (
    tester,
  ) async {
    final h = SelectionHarness();
    await h.mount(tester, nativeViewport: nativeViewport);
    final entry = h.fixture.entry;
    final card = key('vocabulary-${entry.id}');
    for (final language in [entry.targetText, entry.nativeText]) {
      await h.reveal(tester, card);
      final text = find.descendant(of: card, matching: find.text(language));
      await tester.longPress(text);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids, {entry.id});
      h.selection(tester).clear();
      await tester.pumpAndSettle();
    }
    await h.reveal(tester, card);
    await tester.tap(
      find.descendant(of: card, matching: find.text(entry.targetText)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('inline-${entry.id}-target')), findsOneWidget);
  });
  testWidgets(
    'cancel retains hidden selected UUID; confirmed delete excludes unrelated words',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester, nativeViewport: nativeViewport);
      await h.start(tester);
      final selected = h.fixture.entry.id;
      final field = key('collection-search');
      await h.reveal(tester, field);
      await tester.enterText(field, 'Word 18');
      await tester.testTextInput.receiveAction(TextInputAction.search);
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
      expect(
        rect.bottom,
        lessThanOrEqualTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
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
