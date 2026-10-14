import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import '../data/regular_reviews_test.dart' show instant;
import '../data/retry_gap_migration_test.dart' show gateway;
import '../support/mutable_clock.dart';
import '../ui/review_launch_test.dart' as launch;

void main() {
  test(
    'accepted Incorrect remains one pending item through repeated retry; only correct or original-day expiry ends pending',
    () async {
      final f = launch.fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final source = await gateway(f.db, f.owner.id);
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        presentationActive: false,
      );
      try {
        expect(session.pendingItemCount, 1);
        await session.submitAnswer(
          session.current!,
          AnswerGrade.incorrect,
          reviewedAt: instant,
        );
        final round = (await source.retryState(at: instant)).rounds.single;
        expect(session.pendingItemCount, 1);
        expect(session.regularItemsExhausted, isTrue);
        final clock = f.db.clock as MutablePikoClock;
        clock.advance(const Duration(seconds: 10));
        await session.refreshRetries();
        await session.submitAnswer(
          session.current!,
          AnswerGrade.incorrect,
          reviewedAt: clock.now(),
        );
        expect(session.pendingItemCount, 1);
        clock.advance(const Duration(seconds: 10));
        await session.refreshRetries();
        await session.submitAnswer(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: clock.now(),
        );
        expect(session.pendingItemCount, 0);
        expect((await source.retryState(at: clock.now())).rounds, isEmpty);
        expect(session.acceptedReviews, hasLength(1));
        expect(round.expiresAt.isAfter(clock.now()), isTrue);
      } finally {
        await session.stop();
        session.dispose();
      }
      // A separate admitted round expires without a successful answer.
      final reverse = await gateway(f.db, f.owner.id, reverse: true);
      final created = (await f.review(
        reverse: true,
        rating: LearningRating.again,
        at: (f.db.clock as MutablePikoClock).now(),
      )).retryNext!;
      final expires = await DueLearningSession.start(
        source: reverse,
        cutoff: (f.db.clock as MutablePikoClock).now(),
        clock: f.db.clock,
        presentationActive: false,
      );
      try {
        expect(expires.pendingItemCount, 1);
        (f.db.clock as MutablePikoClock).set(created.expiresAt);
        await expires.refreshRetries();
        expect(expires.pendingItemCount, 0);
        expect(expires.lastAnswer, isNull);
        expect(
          (await reverse.retryState(at: created.expiresAt)).rounds,
          isEmpty,
        );
      } finally {
        await expires.stop();
        expires.dispose();
      }
    },
  );
}
