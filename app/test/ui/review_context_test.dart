import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/shared/catalogs.dart';
import '../support/mutable_clock.dart';
import 'review_launch_test.dart' as launch;
import 'review_grading_test.dart' as grading;
import 'review_prompt_test.dart' show card, text;

void main() {
  for (final reverse in [false, true]) {
    launch.testWidgets(
      '${reverse ? "de native→target" : "en target→native"} actual hidden/revealed/retry-wait card keeps fixed direction and honest unique progress',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        final h = launch.Harness(f)
          ..locale.value = Locale(reverse ? 'de' : 'en');
        await h.mount(tester);
        await h.open(tester);
        if (reverse) await h.reverse(tester);
        final copy = PikoCopy(reverse ? 'de' : 'en');
        await tester.tap(launch.button(copy.text('learn.start')));
        await h.finish(tester);
        await h.flush(tester);
        final session = h.sessions.single;
        final direction = find.byKey(const ValueKey('review-fixed-direction')),
            counter = find.byKey(const ValueKey('review-counters'));
        final fixed = tester.widget<Text>(direction).data;
        expect(fixed, reverse ? 'DE → FR' : 'FR → DE');
        expect(
          session.direction,
          reverse
              ? LearningDirection.nativeToTarget
              : LearningDirection.targetToNative,
        );
        expect(text(card, tester), reverse ? ['Eins'] : ['One']);
        expect(
          tester.widget<Text>(counter).data,
          copy.text('learn.progress', {
            'completed': 0,
            'total': 1,
            'correct': 0,
          }),
        );
        await grading.reveal(tester);
        expect(text(card, tester), reverse ? ['Eins', 'One'] : ['One', 'Eins']);
        expect(tester.widget<Text>(direction).data, fixed);
        await tester.tap(grading.gradeButton(AnswerGrade.incorrect));
        await h.finish(tester);
        expect(card, findsNothing);
        expect(session.progress.completed, 0);
        expect(find.text(copy.text('learn.retryWaiting')), findsOneWidget);
        expect(tester.widget<Text>(direction).data, fixed);
        expect(
          tester.widget<Text>(counter).data,
          copy.text('learn.progress', {
            'completed': 0,
            'total': 1,
            'correct': 0,
          }),
        );
        (f.db.clock as MutablePikoClock).advance(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 10));
        await h.finish(tester);
        await h.flush(tester);
        expect(session.currentIsRetry, isTrue);
        expect(session.progress.total, 1);
        await grading.reveal(tester);
        await tester.tap(grading.gradeButton(AnswerGrade.correct));
        await h.finish(tester);
        expect(session.progress.completed, 1);
        expect(session.progress.firstTryCorrect, 0);
        expect(
          tester.widget<Text>(counter).data,
          copy.text('learn.progress', {
            'completed': 1,
            'total': 1,
            'correct': 0,
          }),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
