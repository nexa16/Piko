import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show card, text;
import '../support/mutable_clock.dart';

void main() {
  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language insufficient pool arms one wait, wakes automatically without grading, and preserves opposite direction',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(() => f.review(rating: LearningRating.again));
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester);
        final before = await tester.runAsync(() => snapshot(f)),
            copy = PikoCopy(language);
        await h.open(tester);
        await tester.tap(launch.button(copy.text('learn.start')));
        await h.finish(tester);
        expect(
          find.text(copy.text('learn.retryCountdown', {'seconds': 10})),
          findsOneWidget,
        );
        expect(launch.button(copy.text('action.retry')), findsNothing);
        expect(find.text(copy.text('learn.prepareFailed')), findsNothing);
        expect(find.byType(ReviewSessionRoute), findsOneWidget);
        expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
        expect(card, findsNothing);
        expect(h.sessions.single.hasInitialWork, isTrue);
        expect(h.sessions.single.members, isEmpty);
        final armed = await tester.runAsync(() => snapshot(f));
        expect(
          [
            for (var i = 0; i < armed!.length; i++)
              if (i != 4) armed[i],
          ],
          [
            for (var i = 0; i < before!.length; i++)
              if (i != 4) before[i],
          ],
        );
        final wait = h.sessions.single.waitMutations.single;
        expect(
          wait.next.waitEligibleAt,
          wait.prior.createdAt.add(const Duration(seconds: 10)),
        );
        expect(wait.next.revision, wait.prior.revision + 1);
        final clock = f.db.clock as MutablePikoClock;
        clock.advance(const Duration(seconds: 9));
        await tester.pump(const Duration(seconds: 9));
        await h.finish(tester);
        expect(card, findsNothing);
        expect(
          find.text(copy.text('learn.retryCountdown', {'seconds': 1})),
          findsOneWidget,
        );
        expect(launch.button(copy.text('action.retry')), findsNothing);
        await tester.tap(launch.button(copy.text('learn.exit')));
        await h.finish(tester);
        await h.open(tester);
        await tester.tap(launch.button(copy.text('learn.start')));
        await h.finish(tester);
        expect(h.sessions.last.waitMutations, isEmpty);
        expect(card, findsNothing);
        expect(
          find.text(copy.text('learn.retryCountdown', {'seconds': 1})),
          findsOneWidget,
        );
        expect(await tester.runAsync(() => snapshot(f)), armed);
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await h.finish(tester);
        await h.flush(tester);
        expect(text(card, tester), ['One']);
        expect(h.sessions.last.currentIsRetry, isTrue);
        expect(await tester.runAsync(() => snapshot(f)), armed);
        await tester.tap(launch.button(copy.text('learn.exit')));
        await h.finish(tester);
        await h.open(tester);
        await h.reverse(tester);
        await tester.tap(launch.button(copy.text('learn.start')));
        await h.finish(tester);
        await h.flush(tester);
        expect(find.byType(ReviewSessionRoute), findsOneWidget);
        expect(h.sessions.last.direction, LearningDirection.nativeToTarget);
        expect(text(card, tester), ['Eins']);
        expect(await tester.runAsync(() => snapshot(f)), armed);
        await tester.tap(launch.button(copy.text('learn.exit')));
        await h.finish(tester);
        expect(await tester.runAsync(() => snapshot(f)), armed);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
