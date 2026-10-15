import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/speed_completion.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'speed_eligibility_test.dart' show completeSnapshot;

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  test(
    'filtered membership is immutable and limits regular, retry, count and Speed discovery',
    () async {
      final f = await fixture();
      final hidden = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Hidden',
        nativeText: 'Versteckt',
      );
      final visibleIds = {f.entry.id};
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
        entryIds: visibleIds,
      );
      visibleIds.add(hidden.id);
      expect(source.entryIds, {f.entry.id});
      expect(() => source.entryIds!.clear(), throwsUnsupportedError);
      expect((await source.items()).single.entryId, f.entry.id);
      expect(
        (await source.newSpeedItems(
          entryIds: {f.entry.id, hidden.id},
        )).single.entryId,
        f.entry.id,
      );
      expect(
        (await source.dueMemberships(at: instant)).single.entryId,
        f.entry.id,
      );
      expect(
        (await source.initialSelection(cutoff: instant)).regular.single.entryId,
        f.entry.id,
      );
      final before = await completeSnapshot(f.db);
      await expectLater(
        source.review(
          kind: ReviewKind.regular,
          expectedPrior: await f.current(hidden),
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(RegularReviewFailure.outOfScope),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'hidden retries never block filtered regular launch or get expired by its selection',
    () async {
      final f = await fixture();
      final visible = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Visible',
        nativeText: 'Sichtbar',
      );
      final hiddenRetry = (await f.review(
        rating: LearningRating.again,
      )).retryNext!;
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
        entryIds: {visible.id},
      );
      final before = await completeSnapshot(f.db);
      expect(
        (await source.dueItems(cutoff: instant)).single.entryId,
        visible.id,
      );
      expect(
        (await source.initialSelection(
          cutoff: hiddenRetry.expiresAt,
        )).regular.single.entryId,
        visible.id,
      );
      expect(await source.pendingRetries(at: hiddenRetry.expiresAt), isEmpty);
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'filtered answers advance the original Collection/direction ordinal and preserve hidden retry gaps and opposite counters',
    () async {
      final f = await fixture();
      final visible = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Visible',
        nativeText: 'Sichtbar',
      );
      final hiddenRetry = (await f.review(
        rating: LearningRating.again,
      )).retryNext!;
      await f.review(reverse: true, rating: LearningRating.good);
      final unfiltered = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final beforeState = await unfiltered.retryState(at: instant);
      final before = await completeSnapshot(f.db);
      final filtered = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
        entryIds: {visible.id},
      );
      final receipt = await filtered.review(
        kind: ReviewKind.regular,
        expectedPrior: await f.current(visible),
        rating: LearningRating.good,
        reviewedAt: instant,
      );
      expect(receipt.scopePrior!.ordinal, beforeState.scope.ordinal);
      expect(receipt.scopeNext!.ordinal, beforeState.scope.ordinal + 1);
      expect(receipt.scopeNext!.collectionId, f.owner.id);
      final afterState = await unfiltered.retryState(at: instant);
      expect(afterState.scope.ordinal, beforeState.scope.ordinal + 1);
      expect(afterState.rounds.single.sameStateAs(hiddenRetry), isTrue);
      final after = await completeSnapshot(f.db);
      expect(after['retry_obligations'], before['retry_obligations']);
      final oldOpposite = (before['scope_answer_ordinals'] as List)
          .cast<Map>()
          .where((row) => row['direction'] == 'nativeToTarget')
          .toList();
      expect(
        (after['scope_answer_ordinals'] as List)
            .cast<Map>()
            .where((row) => row['direction'] == 'nativeToTarget')
            .toList(),
        oldOpposite,
      );
    },
  );

  test(
    'filtered retry answers use original gap counters and cannot address hidden obligations',
    () async {
      final f = await fixture();
      final hidden = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Hidden',
        nativeText: 'Versteckt',
      );
      final visibleRetry = (await f.review(
        rating: LearningRating.again,
      )).retryNext!;
      final hiddenRetry = (await f.review(
        word: hidden,
        rating: LearningRating.again,
      )).retryNext!;
      await f.makeRetryEligible(visibleRetry);
      final filtered = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
        entryIds: {f.entry.id},
      );
      final before = await completeSnapshot(f.db);
      await expectLater(
        filtered.completeSuccessfulRetry(
          expected: hiddenRetry,
          answeredAt: instant,
        ),
        throwsA(RegularReviewFailure.outOfScope),
      );
      expect(await completeSnapshot(f.db), before);
      final state = await filtered.retryState(at: instant);
      expect(state.rounds.single.id, visibleRetry.id);
      final receipt = await filtered.answerRetry(
        expectedPrior: await f.current(),
        expectedRetry: visibleRetry,
        rating: LearningRating.good,
        answeredAt: instant,
      );
      expect(receipt.scopeNext.ordinal, state.scope.ordinal + 1);
      expect(receipt.scopeNext.collectionId, f.owner.id);
      final unfiltered = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      expect(
        (await unfiltered.retryState(
          at: instant,
        )).rounds.single.sameStateAs(hiddenRetry),
        isTrue,
      );
    },
  );

  test(
    'a filtered gateway cannot correct or Speed-complete a hidden item in the same Collection',
    () async {
      final f = await fixture();
      final hidden = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Hidden',
        nativeText: 'Versteckt',
      );
      final receipt = await f.review(
        word: hidden,
        rating: LearningRating.again,
      );
      final filtered = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
        entryIds: {f.entry.id},
      );
      final before = await completeSnapshot(f.db);
      await expectLater(
        filtered.replaceAnswer(
          expected: receipt,
          expectedWaits: [],
          rating: LearningRating.good,
          executionAt: instant,
        ),
        throwsA(RegularReviewFailure.outOfScope),
      );
      await expectLater(
        filtered.completeSpeedItem(
          expectedPrior: await f.current(hidden),
          errors: 0,
          completedAt: instant,
        ),
        throwsA(SpeedCompletionFailure.outOfScope),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'invalid/foreign membership is rejected and an empty subset never becomes an unfiltered gateway',
    () async {
      final f = await fixture();
      for (final ids in [
        {'missing'},
        {f.other.id},
      ]) {
        await expectLater(
          f.learning.forCollection(
            collectionId: f.owner.id,
            direction: LearningDirection.targetToNative,
            entryIds: ids,
          ),
          throwsA(RegularReviewFailure.outOfScope),
        );
      }
      final empty = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
        entryIds: {},
      );
      expect(await empty.items(), isEmpty);
      expect(await empty.newSpeedItems(), isEmpty);
      expect(await empty.dueMemberships(at: instant), isEmpty);
      expect((await empty.initialSelection(cutoff: instant)).regular, isEmpty);
    },
  );
}
