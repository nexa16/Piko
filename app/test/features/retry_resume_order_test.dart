import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import '../data/regular_reviews_test.dart' show instant;
import '../data/retry_gap_migration_test.dart' show gateway, storedSnapshot;
import '../ui/review_launch_test.dart' as launch;

void main() {
  test(
    'pending retry launch regenerates full captured regular order; fresh seed, not prior sequence, governs each launch',
    () async {
      final f = launch.fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review(rating: LearningRating.again);
      for (var index = 0; index < 6; index++) {
        await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Other $index',
          nativeText: 'Anders $index',
        );
      }
      final source = await gateway(f.db, f.owner.id),
          before = await storedSnapshot(f.db);
      final initial = await source.initialSelection(cutoff: instant);
      final generated = <List<int>>[];
      for (final seed in [1, 2]) {
        final expected = initial.regular.map((item) => item.id).toList()
          ..shuffle(Random(seed));
        final session = await DueLearningSession.start(
          source: source,
          cutoff: instant,
          clock: f.db.clock,
          presentationActive: false,
          orderRandom: Random(seed),
        );
        try {
          final actual = session.members.map((item) => item.id).toList();
          expect(actual, expected);
          expect(
            actual.toSet(),
            initial.regular.map((item) => item.id).toSet(),
          );
          expect(session.current!.item.id, expected.first);
          expect(session.currentIsRetry, isFalse);
          expect(session.waitMutations, isEmpty);
          generated.add(actual);
          expect(await storedSnapshot(f.db), before);
        } finally {
          await session.stop();
          session.dispose();
        }
      }
      expect(
        generated[0],
        isNot(generated[1]),
      ); // These deterministic seeds; not every random launch must differ.
    },
  );

  test(
    'eligible resumed retry precedes regenerated regular order; refresh never expands captured membership',
    () async {
      final f = launch.fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      await f.makeRetryEligible(
        round,
      ); // Explicit priority fixture; earned gaps have separate acceptance.
      for (var index = 0; index < 5; index++) {
        await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Other $index',
          nativeText: 'Anders $index',
        );
      }
      final source = await gateway(f.db, f.owner.id);
      final initial = await source.initialSelection(cutoff: instant);
      final expected = initial.regular.map((item) => item.id).toList()
        ..shuffle(Random(7));
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        presentationActive: false,
        orderRandom: Random(7),
      );
      try {
        expect(session.currentIsRetry, isTrue);
        expect(session.current!.item.id, round.itemId);
        expect(session.members.map((item) => item.id), expected);
        final late = await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Late',
          nativeText: 'Später',
        );
        await session.submitAnswer(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        );
        expect(session.currentIsRetry, isFalse);
        expect(session.current!.item.id, expected.first);
        expect(session.members.any((item) => item.entryId == late.id), isFalse);
        expect(session.members.map((item) => item.id), expected);
      } finally {
        await session.stop();
        session.dispose();
      }
    },
  );
}
