import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/features/learning/learning_session_progress.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';

void main() {
  for (final language in ['en', 'de']) {
    for (final dismissal in ['close', 'escape', 'barrier', 'back']) {
      testWidgets(
        '$language summary at 320px/200% has honest readable metrics and safe $dismissal',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final focus = FocusNode();
          addTearDown(focus.dispose);
          final copy = PikoCopy(language);
          final members = {
            for (var i = 0; i < 30; i++) (itemId: i, generation: 0),
          };
          final progress = LearningSessionProgress(
            members: members,
            completed: members.take(25).toSet(),
            firstTry: members.take(23).toSet(),
          );
          var dismissed = false;
          await tester.pumpWidget(
            PikoApp(
              locale: Locale(language),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    focusNode: focus,
                    onPressed: () async {
                      await showPikoDialog<void>(
                        context,
                        builder: (_) => ReviewSummaryDialog(progress: progress),
                      );
                      dismissed = true;
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          focus.requestFocus();
          await tester.pump();
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final semantics = tester.ensureSemantics();
          try {
            expect(find.text(copy.text('summary.title')), findsOneWidget);
            expect(
              find.byKey(const ValueKey('piko-celebration')),
              findsOneWidget,
            );
            final art = tester.widget<Image>(
              find.byKey(const ValueKey('piko-celebration')),
            );
            expect(art.excludeFromSemantics, isTrue);
            expect(art.filterQuality, FilterQuality.none);
            expect(
              find.text(copy.text('learn.summaryEncouragement')),
              findsOneWidget,
            );
            expect(find.text('25'), findsOneWidget);
            expect(find.text('23'), findsOneWidget);
            expect(find.text('30'), findsNothing); // Total is not learned.
            expect(
              tester.widget<PikoDialog>(find.byType(PikoDialog)).actions,
              isEmpty,
            ); // The close icon is allowed; no extra return CTA.
            expect(find.text(copy.text('summary.sample')), findsNothing);
            for (final metric in [
              ('completed', '25', 'summary.completed'),
              ('first-try', '23', 'summary.firstTryCorrect'),
            ]) {
              final finder = find.byKey(ValueKey('summary-${metric.$1}'));
              expect(
                tester.getSemantics(finder).label,
                '${metric.$2} ${copy.text(metric.$3)}',
              );
              await tester.ensureVisible(finder);
              final rect = tester.getRect(finder);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(320));
            }
            expect(tester.takeException(), isNull);
            switch (dismissal) {
              case 'close':
                final close = find.byWidgetPredicate(
                  (widget) =>
                      widget is PikoIconButton &&
                      widget.semanticLabel == copy.text('common.close'),
                );
                await tester.ensureVisible(close);
                await tester.tap(close);
              case 'escape':
                await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              case 'barrier':
                await tester.tapAt(const Offset(1, 1));
              case 'back':
                await tester.binding.handlePopRoute();
            }
            await tester.pumpAndSettle();
            expect(find.byType(ReviewSummaryDialog), findsNothing);
            expect(dismissed, isTrue);
            expect(focus.hasFocus, isTrue);
            expect(progress.completed, 25);
            expect(progress.firstTryCorrect, 23);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
