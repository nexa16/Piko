import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/features/speed/speed_numbers_break.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';
import 'speed_session_route_test.dart' show SpeedHarness;

Finder numberButton(int number) => find.byKey(ValueKey('speed-number-$number'));

Future<void> enterBreak(WidgetTester tester, SpeedHarness h) async {
  for (var index = 0; index < 2; index++) {
    await h.reveal(tester);
    await h.grade(tester, SpeedAnswer.incorrect);
  }
  expect(find.byType(SpeedNumbersBreak), findsOneWidget);
}

Future<void> finishGame(WidgetTester tester) async {
  for (var number = 1; number <= 10; number++) {
    await tester.ensureVisible(numberButton(number));
    await tester.tap(numberButton(number));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      'SPEED-012 $language shuffled numbers fit320px/200%, wrong taps and elapsed time never advance',
      (tester) async {
        final h = SpeedHarness(
          language: language,
          poolSize: 5,
          injectGame: false,
        );
        await h.mount(tester, scale: 2);
        await enterBreak(tester, h);
        final copy = PikoCopy(language);
        final before = h.session.state!;
        final positions = before.numberGame!.positions;
        expect(find.text(copy.text('r2.gameHint')), findsOneWidget);
        expect(
          find.text(copy.text('r2.gameNext', {'number': 1})),
          findsOneWidget,
        );
        final rendered = tester
            .widgetList<PikoButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is PikoButton &&
                    widget.key is ValueKey<String> &&
                    (widget.key! as ValueKey<String>).value.startsWith(
                      'speed-number-',
                    ),
              ),
            )
            .map((button) => int.parse(button.label))
            .toList();
        expect(rendered, positions);
        for (var number = 1; number <= 10; number++) {
          final rect = tester.getRect(numberButton(number));
          expect(
            rect.width,
            greaterThanOrEqualTo(pikoDesign.dimension('controls.largeHeight')),
          );
          expect(
            rect.height,
            greaterThanOrEqualTo(pikoDesign.dimension('controls.largeHeight')),
          );
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }
        await tester.ensureVisible(numberButton(10));
        await tester.tap(numberButton(10));
        await tester.pumpAndSettle();
        expect(h.session.state, same(before));
        await tester.pump(const Duration(hours: 1));
        expect(h.session.state, same(before));
        expect(h.session.state!.numberGame!.positions, positions);
        expect(h.session.current, isNull);
        expect(h.durable, isEmpty);
        await finishGame(tester);
        expect(find.byType(SpeedNumbersBreak), findsNothing);
        expect(h.session.state!.itemProgress, before.itemProgress);
        expect(h.session.state!.completedEntryIds, before.completedEntryIds);
        expect(h.session.state!.pass, ['a', 'b']);
        expect(h.session.current!.entryId, 'a');
        expect(h.session.revealed, isFalse);
        expect(h.commitCalls, 0);
        for (final id in ['a', 'b']) {
          expect(h.session.current!.entryId, id);
          await h.reveal(tester);
          await h.grade(tester, SpeedAnswer.correct);
          if (id == 'a') expect(find.byType(SpeedNumbersBreak), findsNothing);
        }
        expect(find.byType(SpeedNumbersBreak), findsOneWidget);
        await finishGame(tester);
        for (final id in ['a', 'b']) {
          expect(h.session.current!.entryId, id);
          await h.reveal(tester);
          await h.grade(tester, SpeedAnswer.correct);
        }
        expect(h.durable.map((item) => (item.entryId, item.errors)), [
          ('a', 1),
          ('b', 1),
        ]);
        expect(find.byType(SpeedSessionRoute), findsNothing);
        expect(find.byType(SpeedNumbersBreak), findsNothing);
        expect(find.byType(ReviewSummaryDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'keyboard Enter/Space activate the numbers and consumed positions stay disabled',
    (tester) async {
      final h = SpeedHarness(poolSize: 5, injectGame: false);
      await h.mount(tester);
      await enterBreak(tester, h);
      final handle = h.session.currentBreak!;
      final firstCallback = tester
          .widget<PikoButton>(numberButton(1))
          .onPressed!;
      final progress = h.session.state!.itemProgress;
      for (var number = 1; number <= 10; number++) {
        await tester.ensureVisible(numberButton(number));
        final label = find.descendant(
          of: numberButton(number),
          matching: find.text('$number'),
        );
        Focus.of(tester.element(label)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(
          number.isOdd ? LogicalKeyboardKey.enter : LogicalKeyboardKey.space,
        );
        await tester.pumpAndSettle();
        if (number < 10) {
          expect(h.session.currentBreak, same(handle));
          expect(h.session.state!.numberGame!.nextNumber, number + 1);
          expect(
            tester.widget<PikoButton>(numberButton(number)).onPressed,
            isNull,
          );
        }
        expect(h.session.state!.itemProgress, progress);
      }
      expect(h.session.current!.entryId, 'a');
      firstCallback();
      await tester.pumpAndSettle();
      expect(h.session.current!.entryId, 'a');
      expect(h.commitCalls, 0);
      await h.exit(tester);
    },
  );
}
