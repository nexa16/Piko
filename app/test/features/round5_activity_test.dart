import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/speed_completion.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;

Future<void> activity(Fixture f, VocabularyRecord entry, bool active) =>
    f.vocabulary.updateWithContent(
      id: entry.id,
      targetText: entry.targetText,
      nativeText: entry.nativeText,
      assignments: {},
      content: entry.content,
      active: active,
    );

void main() {
  test(
    'deleting uncaptured future work does not invalidate the current answer',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final later = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'later',
        nativeText: 'later',
      );
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      await source.review(
        kind: ReviewKind.regular,
        expectedPrior: (await source.items()).singleWhere(
          (item) => item.entryId == later.id,
        ),
        rating: LearningRating.good,
        reviewedAt: instant,
      );
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
      );
      addTearDown(session.dispose);
      expect(session.members.map((item) => item.entryId), [f.entry.id]);
      await SqliteVocabularyDeletionService(f.db).delete(later.id);
      expect(
        await session.submitAnswer(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        ),
        isNotNull,
      );
      expect(session.progress.completed, 1);
    },
  );

  for (final direction in LearningDirection.values) {
    test(
      'inactive gates discovery and stale writes without learning mutations: $direction',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final source = await f.learning.forCollection(
          collectionId: f.owner.id,
          direction: direction,
          entryIds: {f.entry.id},
        );
        final prior = (await source.items()).single;
        await activity(f, f.entry, false);
        final learning = await rows(f.db, 'learning_items');
        expect(await source.dueItems(cutoff: instant), isEmpty);
        expect(await source.dueMemberships(at: instant), isEmpty);
        expect(await source.newSpeedItems(), isEmpty);
        expect(await source.items(), hasLength(1));
        await expectLater(
          source.review(
            kind: ReviewKind.regular,
            expectedPrior: prior,
            rating: LearningRating.good,
            reviewedAt: instant,
          ),
          throwsA(RegularReviewFailure.inactive),
        );
        await expectLater(
          source.completeSpeedItem(
            expectedPrior: prior,
            errors: 2,
            completedAt: instant,
          ),
          throwsA(SpeedCompletionFailure.inactive),
        );
        expect(await rows(f.db, 'learning_items'), learning);
        expect(await rows(f.db, 'regular_reviews'), isEmpty);
        expect(await rows(f.db, 'scope_answer_ordinals'), isEmpty);
        await activity(f, f.entry, true);
        expect(await source.newSpeedItems(), hasLength(1));
      },
    );

    test(
      'normal skips current and future inactive captured work, excludes unfinished totals, never reinserts: $direction',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final b = await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'B',
          nativeText: 'B',
        );
        final c = await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'C',
          nativeText: 'C',
        );
        final source = await f.learning.forCollection(
          collectionId: f.owner.id,
          direction: direction,
        );
        final session = await DueLearningSession.start(
          source: source,
          cutoff: instant,
          clock: f.db.clock,
        );
        addTearDown(session.dispose);
        final first = session.current!;
        session.setHard(first, true);
        await activity(f, f.entry, false);
        await activity(f, c, false);
        expect(
          await session.submitAnswer(
            first,
            AnswerGrade.correct,
            reviewedAt: instant,
          ),
          isNull,
        );
        expect(session.current!.item.entryId, b.id);
        expect(session.progress.total, 1);
        expect(session.progress.completed, 0);
        expect(await rows(f.db, 'scope_answer_ordinals'), isEmpty);
        await activity(f, f.entry, true);
        await activity(f, c, true);
        await session.revalidateActivity();
        expect(session.progress.total, 1);
        expect(session.current!.item.entryId, b.id);
        await session.submitAnswer(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        );
        expect(session.current, isNull);
        expect(session.progress.completed, 1);
        expect(session.endedByExclusion, isFalse);
        expect(await rows(f.db, 'regular_reviews'), hasLength(1));
      },
    );

    test(
      'inactive retry retains gap/wait/expiry; no wait is armed and no answer ordinal changes: $direction',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        await f.review(
          reverse: direction == LearningDirection.nativeToTarget,
          rating: LearningRating.again,
        );
        final source = await f.learning.forCollection(
          collectionId: f.owner.id,
          direction: direction,
        );
        final before = await rows(f.db, 'retry_obligations');
        final ordinal = await rows(f.db, 'scope_answer_ordinals');
        await activity(f, f.entry, false);
        final session = await DueLearningSession.start(
          source: source,
          cutoff: instant,
          clock: f.db.clock,
        );
        addTearDown(session.dispose);
        expect(session.hasInitialWork, isFalse);
        expect(session.hasPendingRetryWork, isFalse);
        expect(await rows(f.db, 'retry_obligations'), before);
        expect(await rows(f.db, 'scope_answer_ordinals'), ordinal);
        await activity(f, f.entry, true);
        expect(await source.pendingRetries(at: instant), hasLength(1));
        expect(await rows(f.db, 'retry_obligations'), before);
      },
    );
  }

  test(
    'Speed excludes current/waiting without attempt, game, or completion; retains committed progress',
    () async {
      var active = {'a', 'b', 'c', 'd'};
      final completed = <String>[];
      final session = SpeedLearningSession(
        initial: SpeedSession.start(
          collectionId: 'c',
          direction: LearningDirection.targetToNative,
          eligibleEntryIds: active,
          poolSize: 2,
        ),
        activeEntryIds: () async => active,
        commitCompletion: (result) async => completed.add(result.entryId),
      );
      addTearDown(session.dispose);
      var handle = session.current!;
      session.reveal(handle);
      await session.submitAnswer(handle, SpeedAnswer.correct);
      expect(completed, ['a']);
      handle = session.current!;
      session.reveal(handle);
      active = {'a', 'c'};
      expect(
        await session.submitAnswer(handle, SpeedAnswer.incorrect),
        isFalse,
      );
      expect(session.current!.entryId, 'c');
      expect(session.state!.entryIds, ['a', 'c']);
      expect(session.state!.completedEntryIds, {'a'});
      expect(session.state!.itemProgress['c']!.errors, 0);
      expect(session.needsBreak, isFalse);
      active = {'a', 'b', 'c', 'd'};
      await session.revalidateActivity();
      expect(session.state!.entryIds, ['a', 'c']);
      active = {'a'};
      await session.revalidateActivity();
      expect(session.current, isNull);
      expect(session.endedByExclusion, isTrue);
      expect(session.state!.completedEntryIds, {'a'});
      expect(completed, ['a']);
      expect(session.needsBreak, isFalse);
    },
  );
}
