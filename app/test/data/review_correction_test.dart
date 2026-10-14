import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/retry_answer.dart';
import 'package:piko/data/retry_obligation.dart';
import 'package:piko/data/review_correction.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture, instant, rows;

const ratings = <LearningRating>[
  LearningRating.again,
  LearningRating.hard,
  LearningRating.good,
];

Future<Fixture> fixture() async {
  final result = Fixture();
  await result.initialize();
  addTearDown(result.db.close);
  return result;
}

Future<CollectionReviewGateway> gateway(
  Fixture value, {
  bool reverse = false,
  bool other = false,
}) => value.learning.forCollection(
  collectionId: (other ? value.kept : value.owner).id,
  direction: reverse
      ? LearningDirection.nativeToTarget
      : LearningDirection.targetToNative,
);

Future<Map<String, List<Map<String, Object?>>>> snapshot(
  PikoDatabase database,
) async => {
  for (final table in [
    'collections',
    'vocabulary_entries',
    'learning_items',
    'regular_reviews',
    'retry_obligations',
    'scope_answer_ordinals',
    'app_settings',
    'learning_identity_sequence',
    'vocabulary_order_sequence',
  ])
    table: await rows(database, table),
};

Map<String, Object?> onlyRow(
  List<Map<String, Object?>> values,
  bool Function(Map<String, Object?>) predicate,
) => values.singleWhere(predicate);

void expectScopeReplacement(ScopeAnswerState before, ScopeAnswerState after) {
  expect(after.collectionId, before.collectionId);
  expect(after.direction, before.direction);
  expect(after.ordinal, before.ordinal);
  expect(after.revision, before.revision + 1);
}

void main() {
  group('regular review replacement', () {
    for (final original in ratings) {
      for (final replacement in ratings) {
        test(
          '${original.name} to ${replacement.name} reuses the event and exact prior/original UTC',
          () async {
            final f = await fixture(), source = await gateway(f);
            final seedAt = instant.subtract(const Duration(days: 2));
            final first = await f.review(
              rating: LearningRating.hard,
              at: seedAt,
            );
            final issued = await f.review(rating: original, at: instant);
            final beforeHistory = await f.learning.reviewsForItem(
              issued.prior.id,
            );
            expect(beforeHistory.map((event) => event.id), [
              first.event.id,
              issued.event.id,
            ]);

            final corrected =
                await source.replaceAnswer(
                      expected: issued,
                      expectedWaits: const [],
                      rating: replacement,
                      executionAt: instant.add(const Duration(minutes: 5)),
                    )
                    as RegularReviewReceipt;
            final expectedCard = LearningScheduler()
                .review(issued.prior, rating: replacement, reviewedAt: instant)
                .next
                .cardJson;

            expect(corrected.prior.cardJson, issued.prior.cardJson);
            expect(corrected.next.cardJson, expectedCard);
            expect(
              corrected.next.reviewRevision,
              issued.next.reviewRevision + 1,
            );
            expect((await f.current()).cardJson, expectedCard);
            expect(
              (await f.current()).reviewRevision,
              corrected.next.reviewRevision,
            );
            expect(corrected.event.id, issued.event.id);
            expect(corrected.event.itemId, issued.event.itemId);
            expect(corrected.event.generation, issued.event.generation);
            expect(corrected.event.reviewedAt, instant);
            expect(corrected.event.rating, replacement);
            expectScopeReplacement(issued.scopeNext!, corrected.scopeNext!);
            expect(
              (await source.retryState(
                at: instant.add(const Duration(minutes: 5)),
              )).scope.sameStateAs(corrected.scopeNext!),
              isTrue,
            );

            final history = await f.learning.reviewsForItem(issued.prior.id);
            expect(history, hasLength(2));
            expect(history.first.id, first.event.id);
            expect(history.first.rating, LearningRating.hard);
            expect(history.first.reviewedAt, seedAt);
            expect(history.last.id, issued.event.id);
            expect(history.last.rating, replacement);
            expect(history.last.reviewedAt, instant);

            final pending = await source.pendingRetries(
              at: instant.add(const Duration(minutes: 5)),
            );
            if (replacement == LearningRating.again) {
              expect(pending, hasLength(1));
              final retry = pending.single;
              expect(retry.originReviewId, issued.event.id);
              expect(retry.createdAt, instant);
              expect(retry.expiresAt, corrected.retryNext!.expiresAt);
              expect(retry.sameStateAs(corrected.retryNext!), isTrue);
              if (original == LearningRating.again) {
                expect(retry.id, issued.retryNext!.id);
                expect(retry.expiresAt, issued.retryNext!.expiresAt);
              }
            } else {
              expect(corrected.retryNext, isNull);
              expect(pending, isEmpty);
            }
          },
        );
      }
    }
  });

  group('reinforcement answer replacement', () {
    for (final original in ratings) {
      for (final replacement in ratings) {
        test(
          '${original.name} to ${replacement.name} changes retry state without FSRS or history',
          () async {
            final f = await fixture(), source = await gateway(f);
            final origin = await f.review(rating: LearningRating.again);
            await f.makeRetryEligible(origin.retryNext!);
            final beforeRetryItem = await f.current();
            final beforeRetryHistory = await rows(f.db, 'regular_reviews');
            final issued = await source.answerRetry(
              expectedPrior: beforeRetryItem,
              expectedRetry: origin.retryNext!,
              rating: original,
              answeredAt: instant,
            );
            final afterAnswerItem = await f.current();
            final afterAnswerHistory = await rows(f.db, 'regular_reviews');
            expect(afterAnswerItem.cardJson, beforeRetryItem.cardJson);
            expect(
              afterAnswerItem.reviewRevision,
              beforeRetryItem.reviewRevision,
            );
            expect(afterAnswerHistory, beforeRetryHistory);

            final corrected =
                await source.replaceAnswer(
                      expected: issued,
                      expectedWaits: const [],
                      rating: replacement,
                      executionAt: instant.add(const Duration(minutes: 1)),
                    )
                    as RetryAnswerReceipt;

            expect(corrected.prior.cardJson, issued.prior.cardJson);
            expect(corrected.next.cardJson, issued.prior.cardJson);
            expect(corrected.answeredAt, issued.answeredAt);
            expect(corrected.rating, replacement);
            expectScopeReplacement(issued.scopeNext, corrected.scopeNext);
            expect(
              (await source.retryState(
                at: instant.add(const Duration(minutes: 1)),
              )).scope.sameStateAs(corrected.scopeNext),
              isTrue,
            );
            expect((await f.current()).cardJson, afterAnswerItem.cardJson);
            expect(
              (await f.current()).reviewRevision,
              afterAnswerItem.reviewRevision,
            );
            expect(await rows(f.db, 'regular_reviews'), afterAnswerHistory);

            final pending = await source.pendingRetries(
              at: instant.add(const Duration(minutes: 1)),
            );
            if (replacement == LearningRating.again) {
              expect(pending, hasLength(1));
              final retry = pending.single;
              expect(retry.id, issued.retryPrior.id);
              expect(retry.originReviewId, issued.retryPrior.originReviewId);
              expect(retry.createdAt, issued.retryPrior.createdAt);
              expect(retry.expiresAt, issued.retryPrior.expiresAt);
              expect(retry.errorCount, issued.retryPrior.errorCount + 1);
              expect(retry.sameStateAs(corrected.retryNext!), isTrue);
            } else {
              expect(corrected.retryNext, isNull);
              expect(pending, isEmpty);
            }
          },
        );
      }
    }
  });

  test(
    'accepted post-answer wait mutation is replayed exactly and can then be removed by a later correction',
    () async {
      final f = await fixture(), source = await gateway(f);
      final issued = await f.review(rating: LearningRating.again);
      final armedAt = instant.add(const Duration(seconds: 1));
      final waitResult = await source.armBlockedWaits(
        expectedRounds: [issued.retryNext!],
        remainingRegular: const [],
        at: armedAt,
      );
      expect(waitResult.mutations, hasLength(1));
      final armed = waitResult.mutations.single.next;

      final kept =
          await source.replaceAnswer(
                expected: issued,
                expectedWaits: waitResult.mutations,
                rating: LearningRating.again,
                executionAt: armedAt.add(const Duration(seconds: 1)),
              )
              as RegularReviewReceipt;
      expect(kept.retryNext!.id, armed.id);
      expect(kept.retryNext!.waitEligibleAt, armed.waitEligibleAt);
      expect(kept.retryNext!.revision, armed.revision + 1);
      expect(kept.retryNext!.createdAt, issued.event.reviewedAt);
      expect(kept.retryNext!.expiresAt, issued.retryNext!.expiresAt);
      expectScopeReplacement(issued.scopeNext!, kept.scopeNext!);

      final removed =
          await source.replaceAnswer(
                expected: kept,
                expectedWaits: const [],
                rating: LearningRating.good,
                executionAt: armedAt.add(const Duration(seconds: 2)),
              )
              as RegularReviewReceipt;
      expect(removed.retryNext, isNull);
      expectScopeReplacement(kept.scopeNext!, removed.scopeNext!);
      expect(await source.pendingRetries(at: armedAt), isEmpty);
      final history = await f.learning.reviewsForItem(issued.prior.id);
      expect(history, hasLength(1));
      expect(history.single.id, issued.event.id);
      expect(history.single.rating, LearningRating.good);
    },
  );

  test(
    'all accepted post-answer wait mutations are checked while an unrelated same-scope round is preserved',
    () async {
      final f = await fixture(), source = await gateway(f);
      final sibling = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Sibling',
        nativeText: 'Nachbar',
      );
      final first = await f.review(rating: LearningRating.again);
      final issued = await f.review(
        word: sibling,
        rating: LearningRating.again,
      );
      final waitResult = await source.armBlockedWaits(
        expectedRounds: [first.retryNext!, issued.retryNext!],
        remainingRegular: const [],
        at: instant.add(const Duration(seconds: 1)),
      );
      expect(waitResult.mutations, hasLength(2));
      final unrelatedWait = waitResult.mutations
          .singleWhere((mutation) => mutation.prior.id == first.retryNext!.id)
          .next;

      final corrected =
          await source.replaceAnswer(
                expected: issued,
                expectedWaits: waitResult.mutations,
                rating: LearningRating.good,
                executionAt: instant.add(const Duration(seconds: 2)),
              )
              as RegularReviewReceipt;

      expect(corrected.retryNext, isNull);
      final remaining = await source.pendingRetries(
        at: instant.add(const Duration(seconds: 2)),
      );
      expect(remaining, hasLength(1));
      expect(remaining.single.sameStateAs(unrelatedWait), isTrue);
      expect(await f.learning.reviewsForItem(issued.prior.id), hasLength(1));
      expect(
        (await f.learning.reviewsForItem(issued.prior.id)).single.rating,
        LearningRating.good,
      );
      expectScopeReplacement(issued.scopeNext!, corrected.scopeNext!);
    },
  );

  test(
    'omitting an accepted post-answer wait mutation is stale and changes nothing',
    () async {
      final f = await fixture(), source = await gateway(f);
      final issued = await f.review(rating: LearningRating.again);
      await source.armBlockedWaits(
        expectedRounds: [issued.retryNext!],
        remainingRegular: const [],
        at: instant.add(const Duration(seconds: 1)),
      );
      final before = await snapshot(f.db);

      await expectLater(
        source.replaceAnswer(
          expected: issued,
          expectedWaits: const [],
          rating: LearningRating.good,
          executionAt: instant.add(const Duration(seconds: 2)),
        ),
        throwsA(ReviewCorrectionFailure.staleState),
      );
      expect(await snapshot(f.db), before);
    },
  );

  test(
    'retry correction at the original expiry never resurrects the obligation',
    () async {
      final f = await fixture(), source = await gateway(f);
      final origin = await f.review(rating: LearningRating.again);
      await f.makeRetryEligible(origin.retryNext!);
      final successful = await source.answerRetry(
        expectedPrior: await f.current(),
        expectedRetry: origin.retryNext!,
        rating: LearningRating.good,
        answeredAt: instant,
      );
      final itemBefore = await f.current();
      final historyBefore = await rows(f.db, 'regular_reviews');

      final corrected =
          await source.replaceAnswer(
                expected: successful,
                expectedWaits: const [],
                rating: LearningRating.again,
                executionAt: successful.retryPrior.expiresAt,
              )
              as RetryAnswerReceipt;

      expect(corrected.retryNext, isNull);
      expect(await source.pendingRetries(at: instant), isEmpty);
      expect((await f.current()).cardJson, itemBefore.cardJson);
      expect((await f.current()).reviewRevision, itemBefore.reviewRevision);
      expect(await rows(f.db, 'regular_reviews'), historyBefore);
      expectScopeReplacement(successful.scopeNext, corrected.scopeNext);
    },
  );

  test(
    'storage failure rolls back event card retry and scope before an exact retry succeeds',
    () async {
      final f = await fixture(), source = await gateway(f);
      final issued = await f.review(rating: LearningRating.good);
      final before = await snapshot(f.db);
      await f.db.customStatement(
        "CREATE TRIGGER fail_correction AFTER INSERT ON retry_obligations "
        "BEGIN SELECT RAISE(FAIL, 'blocked correction'); END",
      );

      await expectLater(
        source.replaceAnswer(
          expected: issued,
          expectedWaits: const [],
          rating: LearningRating.again,
          executionAt: instant.add(const Duration(minutes: 1)),
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await snapshot(f.db), before);

      await f.db.customStatement('DROP TRIGGER fail_correction');
      final corrected =
          await source.replaceAnswer(
                expected: issued,
                expectedWaits: const [],
                rating: LearningRating.again,
                executionAt: instant.add(const Duration(minutes: 1)),
              )
              as RegularReviewReceipt;
      expect(corrected.event.id, issued.event.id);
      expect(corrected.retryNext, isNotNull);
      expect(await f.learning.reviewsForItem(issued.prior.id), hasLength(1));
    },
  );

  test(
    'a later same-scope answer makes the previous receipt stale without mutation',
    () async {
      final f = await fixture(), source = await gateway(f);
      final other = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Later',
        nativeText: 'Später',
      );
      final issued = await f.review(rating: LearningRating.good);
      await f.review(word: other, rating: LearningRating.hard);
      final before = await snapshot(f.db);

      await expectLater(
        source.replaceAnswer(
          expected: issued,
          expectedWaits: const [],
          rating: LearningRating.again,
          executionAt: instant.add(const Duration(minutes: 1)),
        ),
        throwsA(ReviewCorrectionFailure.staleState),
      );
      expect(await snapshot(f.db), before);
    },
  );

  test(
    'concurrent replacement of one receipt admits one revision only',
    () async {
      final f = await fixture(), source = await gateway(f);
      final issued = await f.review(rating: LearningRating.good);
      final outcomes = await Future.wait([
        for (final rating in [LearningRating.again, LearningRating.hard])
          source
              .replaceAnswer(
                expected: issued,
                expectedWaits: const [],
                rating: rating,
                executionAt: instant.add(const Duration(minutes: 1)),
              )
              .then<Object>((value) => value, onError: (Object error) => error),
      ]);

      expect(outcomes.whereType<RegularReviewReceipt>(), hasLength(1));
      expect(
        outcomes.where(
          (outcome) => outcome == ReviewCorrectionFailure.staleState,
        ),
        hasLength(1),
      );
      final accepted = outcomes.whereType<RegularReviewReceipt>().single;
      expect(accepted.scopeNext!.ordinal, issued.scopeNext!.ordinal);
      expect(accepted.scopeNext!.revision, issued.scopeNext!.revision + 1);
      expect(
        (await f.current()).reviewRevision,
        issued.next.reviewRevision + 1,
      );
      expect(await f.learning.reviewsForItem(issued.prior.id), hasLength(1));
      expect(
        await rows(f.db, 'retry_obligations'),
        accepted.event.rating == LearningRating.again ? hasLength(1) : isEmpty,
      );
    },
  );

  test(
    'forged receipt and forged wait chain are rejected before stored state changes',
    () async {
      final f = await fixture(), source = await gateway(f);
      final issued = await f.review(rating: LearningRating.again);
      final before = await snapshot(f.db);
      final forgedReceipt = RegularReviewReceipt(
        prior: issued.prior,
        next: issued.next,
        event: RegularReviewRecord(
          id: issued.event.id,
          itemId: issued.event.itemId,
          generation: issued.event.generation,
          rating: LearningRating.good,
          reviewedAt: issued.event.reviewedAt,
        ),
        retryPrior: issued.retryPrior,
        retryNext: issued.retryNext,
        scopePrior: issued.scopePrior,
        scopeNext: issued.scopeNext,
      );
      await expectLater(
        source.replaceAnswer(
          expected: forgedReceipt,
          expectedWaits: const [],
          rating: LearningRating.hard,
          executionAt: instant,
        ),
        throwsA(ReviewCorrectionFailure.invalidReceipt),
      );
      final retry = issued.retryNext!;
      final forgedWait = RetryWaitMutation(
        prior: retry,
        next: RetryObligation(
          id: retry.id,
          itemId: retry.itemId,
          generation: retry.generation,
          revision: retry.revision + 2,
          originReviewId: retry.originReviewId,
          createdAt: retry.createdAt,
          expiresAt: retry.expiresAt,
          errorCount: retry.errorCount,
          dueOrdinal: retry.dueOrdinal,
          waitEligibleAt: instant.add(const Duration(seconds: 10)),
        ),
      );
      await expectLater(
        source.replaceAnswer(
          expected: issued,
          expectedWaits: [forgedWait],
          rating: LearningRating.hard,
          executionAt: instant,
        ),
        throwsA(ReviewCorrectionFailure.invalidReceipt),
      );
      expect(await snapshot(f.db), before);
    },
  );

  test(
    'correction preserves opposite direction and unrelated Collection exactly',
    () async {
      final f = await fixture();
      final primary = await gateway(f);
      final oppositeReceipt = await f.review(
        reverse: true,
        rating: LearningRating.again,
      );
      final otherReceipt = await f.review(
        word: f.other,
        rating: LearningRating.again,
      );
      final issued = await f.review(rating: LearningRating.good);
      final before = await snapshot(f.db);

      await primary.replaceAnswer(
        expected: issued,
        expectedWaits: const [],
        rating: LearningRating.again,
        executionAt: instant.add(const Duration(minutes: 1)),
      );
      final after = await snapshot(f.db);
      final oppositeId = oppositeReceipt.prior.id;
      final otherId = otherReceipt.prior.id;

      for (final itemId in [oppositeId, otherId]) {
        expect(
          onlyRow(before['learning_items']!, (row) => row['id'] == itemId),
          onlyRow(after['learning_items']!, (row) => row['id'] == itemId),
        );
        expect(
          onlyRow(
            before['regular_reviews']!,
            (row) => row['item_id'] == itemId,
          ),
          onlyRow(after['regular_reviews']!, (row) => row['item_id'] == itemId),
        );
        expect(
          onlyRow(
            before['retry_obligations']!,
            (row) => row['item_id'] == itemId,
          ),
          onlyRow(
            after['retry_obligations']!,
            (row) => row['item_id'] == itemId,
          ),
        );
      }
      expect(after['collections'], before['collections']);
      expect(after['vocabulary_entries'], before['vocabulary_entries']);
      expect(after['app_settings'], before['app_settings']);
      expect(
        after['learning_identity_sequence'],
        before['learning_identity_sequence'],
      );
      expect(
        after['vocabulary_order_sequence'],
        before['vocabulary_order_sequence'],
      );

      final unrelatedScopes = before['scope_answer_ordinals']!.where(
        (row) =>
            row['collection_id'] != f.owner.id ||
            row['direction'] != LearningDirection.targetToNative.name,
      );
      for (final row in unrelatedScopes) {
        expect(after['scope_answer_ordinals'], contains(equals(row)));
      }
    },
  );
}
