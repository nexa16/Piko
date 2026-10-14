import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/retry_answer.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import '../features/retry_learning_session_test.dart'
    show ControlledRetrySource;
import '../support/mutable_clock.dart';
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show card, text;

class HeldReadSource extends ControlledRetrySource {
  HeldReadSource(super.real);
  Completer<void>? heldEntered;
  @override
  Future<RetryState> retryState({required DateTime at}) {
    if (gate != null && !(heldEntered?.isCompleted ?? true)) {
      heldEntered!.complete();
    }
    return super.retryState(at: at);
  }
}

void main() {
  launch.testWidgets(
    'original day expiry before wait removes waiting state, without retry, false no-due or success; Exit stays usable',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final late = DateTime.utc(2026, 10, 15, 1, 59, 55);
      (f.db.clock as MutablePikoClock).set(late);
      final receipt = (await tester.runAsync(
        () => f.review(rating: LearningRating.again, at: late),
      ))!;
      final h = launch.Harness(f);
      await h.mount(tester);
      await h.open(tester);
      final copy = PikoCopy('en');
      await tester.tap(launch.button(copy.text('learn.start')));
      await h.finish(tester);
      final session = h.sessions.single,
          before = (await tester.runAsync(() => snapshot(f)))!;
      expect(
        session.waitMutations.single.next.waitEligibleAt,
        late.add(const Duration(seconds: 10)),
      );
      expect(find.text(copy.text('learn.retryWaiting')), findsOneWidget);
      (f.db.clock as MutablePikoClock).set(receipt.retryNext!.expiresAt);
      await tester.pump(const Duration(seconds: 5));
      await h.finish(tester);
      final after = (await tester.runAsync(() => snapshot(f)))!;
      expect(after[4], isEmpty);
      expect(
        [
          for (var i = 0; i < after.length; i++)
            if (i != 4) after[i],
        ],
        [
          for (var i = 0; i < before.length; i++)
            if (i != 4) before[i],
        ],
      );
      expect(find.text(copy.text('learn.retryWaiting')), findsNothing);
      expect(card, findsNothing);
      expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
      expect(session.lastAnswer, isNull);
      expect(session.acceptedReviews, isEmpty);
      await tester.tap(launch.button(copy.text('learn.exit')));
      await h.finish(tester);
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final cover in [true, false]) {
    launch.testWidgets(
      '${cover ? "covered route" : "paused app"} cancels wake, resume rechecks storage and drains held read safely',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(() => f.review(rating: LearningRating.again));
        final h = launch.Harness(f);
        late HeldReadSource source;
        h.factory = (id, direction) async {
          source = HeldReadSource(
            await f.learning.forCollection(
              collectionId: id,
              direction: direction,
            ),
          );
          final session = await DueLearningSession.start(
            source: source,
            cutoff: launchInstant,
            clock: f.db.clock,
            onPendingWrites: h.drains.add,
            presentationActive: false,
          );
          h.sessions.add(session);
          return session;
        };
        await h.mount(tester);
        await h.open(tester);
        await tester.tap(launch.button(PikoCopy('en').text('learn.start')));
        await h.finish(tester);
        final session = h.sessions.single,
            before = await tester.runAsync(() => snapshot(f));
        final routeContext = tester.element(find.byType(ReviewSessionRoute));
        final navigator = Navigator.of(routeContext);
        Future<void> suspend() async {
          if (cover) {
            unawaited(
              navigator.push<void>(
                MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('Cover')),
                ),
              ),
            );
            await tester.pumpAndSettle();
          } else {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            await tester.pump();
          }
        }

        Future<void> resume() async {
          if (cover) {
            navigator.pop();
            await tester.pumpAndSettle();
          } else {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump();
          }
        }

        try {
          final calls = source.refreshCalls;
          await suspend();
          (f.db.clock as MutablePikoClock).advance(const Duration(seconds: 10));
          await tester.pump(const Duration(seconds: 10));
          expect(source.refreshCalls, calls);
          expect(session.current, isNull);
          expect(await tester.runAsync(() => snapshot(f)), before);
          source.gate = Completer<void>();
          source.heldEntered = Completer<void>();
          await resume();
          await tester.pump();
          expect(source.heldEntered!.isCompleted, isTrue);
          expect(session.isSubmitting, isTrue);
          await suspend();
          source.gate!.complete();
          await h.finish(tester);
          expect(await tester.runAsync(() => snapshot(f)), before);
          expect(session.currentIsRetry, isTrue);
          await resume();
          await h.finish(tester);
          await h.flush(tester);
          expect(find.byType(ReviewSessionRoute), findsOneWidget);
          expect(text(card, tester), ['One']);
          expect(session.waitMutations, hasLength(1));
          expect(tester.takeException(), isNull);
        } finally {
          if (source.gate != null && !source.gate!.isCompleted) {
            source.gate!.complete();
          }
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          if (cover && find.text('Cover').evaluate().isNotEmpty) {
            navigator.pop();
          }
          await tester.pump();
          await h.finish(tester);
        }
      },
    );
  }
}

final launchInstant = DateTime.parse('2026-10-14T09:10:11.123456Z');
