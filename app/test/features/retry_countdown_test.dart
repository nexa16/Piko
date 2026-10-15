import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../data/regular_reviews_test.dart' show instant, rows;
import '../support/mutable_clock.dart';
import '../ui/review_launch_test.dart' as launch;
import 'retry_wait_session_test.dart' show WaitSource, WakeTimer;

void main() {
  test(
    'RETRY-005 countdown ticks read the same deadline without storage or answers',
    () async {
      final f = launch.fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review(rating: LearningRating.again);
      final source = WaitSource(
        await f.learning.forCollection(
          collectionId: f.owner.id,
          direction: LearningDirection.targetToNative,
        ),
      );
      final wakes = <WakeTimer>[];
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        timerFactory: (duration, callback) {
          final timer = WakeTimer(duration, callback);
          wakes.add(timer);
          return timer;
        },
      );
      addTearDown(session.dispose);
      final clock = f.db.clock as MutablePikoClock;
      final deadline = session.waitMutations.single.next.waitEligibleAt!;
      final before = [
        for (final table in [
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
        ])
          await rows(f.db, table),
      ];
      final reads = source.refreshCalls;
      var notifications = 0;
      session.addListener(() => notifications++);
      expect(session.retryWaitDeadline, deadline);
      expect(session.retryWaitSeconds, 10);
      clock.advance(const Duration(microseconds: 1));
      expect(session.retryWaitSeconds, 10);
      for (var elapsed = 1; elapsed <= 9; elapsed++) {
        clock.set(deadline.subtract(Duration(seconds: 10 - elapsed)));
        wakes.last.fire();
        await session.awaitPending();
        expect(session.retryWaitSeconds, 10 - elapsed);
        expect(session.retryWaitDeadline, deadline);
        expect(session.current, isNull);
        expect(source.refreshCalls, reads);
        expect(session.lastAnswer, isNull);
        expect(session.progress.completed, 0);
        expect(session.waitMutations, hasLength(1));
      }
      expect(notifications, 9);
      clock.set(deadline);
      expect(session.retryWaitSeconds, 0);
      wakes.last.fire();
      await session.awaitPending();
      expect(session.currentIsRetry, isTrue);
      expect(session.retryWaitDeadline, isNull);
      expect(session.retryWaitSeconds, isNull);
      expect(source.refreshCalls, reads + 1);
      final after = [
        for (final table in [
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
        ])
          await rows(f.db, table),
      ];
      expect(after, before);
      expect(session.acceptedReviews, isEmpty);
      expect(session.progress.completed, 0);
      await session.stop();
      final frozen = notifications;
      wakes.last.fire(evenIfCancelled: true);
      await session.awaitPending();
      expect(notifications, frozen);
      expect(session.retryWaitSeconds, isNull);
    },
  );
}
