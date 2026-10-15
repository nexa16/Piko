import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/retry_obligation.dart';
import 'package:piko/data/retry_answer.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture, instant, rows;

Future<Fixture> fixture() async {
  final f = Fixture();
  await f.initialize();
  addTearDown(f.db.close);
  return f;
}

Future<CollectionReviewGateway> source(
  Fixture f, {
  bool reverse = false,
  bool foreign = false,
}) => f.learning.forCollection(
  collectionId: foreign ? f.kept.id : f.owner.id,
  direction: reverse
      ? LearningDirection.nativeToTarget
      : LearningDirection.targetToNative,
);
Future<void> otherAnswer(
  Fixture f,
  int index, {
  bool reverse = false,
  bool foreign = false,
}) async {
  final word = await f.vocabulary.create(
    collectionId: foreign ? f.kept.id : f.owner.id,
    targetText: 'Other $index',
    nativeText: 'Anders $index',
  );
  final item = (await f.learning.forEntry(word.id)).singleWhere(
    (item) =>
        item.direction ==
        (reverse
            ? LearningDirection.nativeToTarget
            : LearningDirection.targetToNative),
  );
  await f.learning.review(
    kind: ReviewKind.regular,
    expectedPrior: item,
    rating: LearningRating.good,
    reviewedAt: instant,
  );
}

Future<List<Object?>> snapshot(Fixture f) => Future.wait([
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
    rows(f.db, table),
]);

void main() {
  test(
    'exact 20 subsequent graded same-scope answers; trigger, other scope and direction excluded',
    () async {
      final f = await fixture(), gateway = await source(f);
      final regular = await f.review(rating: LearningRating.again),
          round = regular.retryNext!;
      expect(regular.scopePrior!.ordinal, 0);
      expect(regular.scopeNext!.ordinal, 1);
      expect(round.dueOrdinal, 21);
      expect(round.errorCount, 1);
      await otherAnswer(f, 100, foreign: true);
      await otherAnswer(f, 101, reverse: true);
      expect((await gateway.retryState(at: instant)).scope.ordinal, 1);
      for (var index = 0; index < 19; index++) {
        await otherAnswer(f, index);
      }
      final before = await snapshot(f);
      await expectLater(
        gateway.answerRetry(
          expectedPrior: await f.current(),
          expectedRetry: round,
          rating: LearningRating.again,
          answeredAt: instant,
        ),
        throwsA(RetryFailure.notEligible),
      );
      expect(await snapshot(f), before);
      await otherAnswer(f, 19);
      final item = await f.current();
      final receipt = await gateway.answerRetry(
        expectedPrior: item,
        expectedRetry: round,
        rating: LearningRating.again,
        answeredAt: instant,
      );
      expect(receipt.scopePrior.ordinal, 21);
      expect(receipt.scopeNext.ordinal, 22);
      expect(receipt.retryNext!.errorCount, 2);
      expect(receipt.retryNext!.dueOrdinal, 32);
      expect(receipt.prior.cardJson, item.cardJson);
      expect(receipt.next.cardJson, item.cardJson);
      expect(await f.learning.reviewsForItem(item.id), hasLength(1));
      expect(
        (await source(f, reverse: true)).direction,
        LearningDirection.nativeToTarget,
      );
    },
  );
  test(
    'earned current-round errors use 20/10/5/3/1 then1, immutable origin/deadline and exact receipt',
    () async {
      final f = await fixture(), gateway = await source(f);
      var round = (await f.review(rating: LearningRating.again)).retryNext!;
      final first = round, card = await f.current();
      var other = 0;
      for (final gap in [20, 10, 5, 3, 1, 1]) {
        final initial = (await gateway.retryState(at: instant)).scope.ordinal;
        expect(round.dueOrdinal - initial, gap);
        for (var index = 0; index < gap; index++) {
          if (index == gap - 1) {
            await expectLater(
              gateway.answerRetry(
                expectedPrior: card,
                expectedRetry: round,
                rating: LearningRating.again,
                answeredAt: instant,
              ),
              throwsA(RetryFailure.notEligible),
            );
          }
          await otherAnswer(f, other++);
        }
        final receipt = await gateway.answerRetry(
          expectedPrior: card,
          expectedRetry: round,
          rating: LearningRating.again,
          answeredAt: instant,
        );
        expect(receipt.retryPrior.sameStateAs(round), isTrue);
        expect(receipt.scopeNext.ordinal, receipt.scopePrior.ordinal + 1);
        expect(receipt.scopeNext.revision, receipt.scopePrior.revision + 1);
        round = receipt.retryNext!;
        expect(round.id, first.id);
        expect(round.originReviewId, first.originReviewId);
        expect(round.createdAt, first.createdAt);
        expect(round.expiresAt, first.expiresAt);
      }
      expect(round.errorCount, 7);
      expect(round.revision, 6);
      expect(
        round.dueOrdinal -
            (await gateway.retryState(at: instant)).scope.ordinal,
        1,
      );
      expect((await f.current()).cardJson, card.cardJson);
      expect(await f.learning.reviewsForItem(card.id), hasLength(1));
    },
  );
  test(
    'another eligible retry grade consumes gap; success receipt removes only round, not FSRS/history',
    () async {
      final f = await fixture(), gateway = await source(f);
      final second = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Second',
        nativeText: 'Zweite',
      );
      final a = (await f.review(rating: LearningRating.again)).retryNext!;
      final b = (await f.review(
        word: second,
        rating: LearningRating.again,
      )).retryNext!;
      for (var index = 0; index < 19; index++) {
        await otherAnswer(f, index);
      }
      final cards = await rows(f.db, 'learning_items'),
          events = await rows(f.db, 'regular_reviews');
      final accepted = await gateway.answerRetry(
        expectedPrior: await f.current(),
        expectedRetry: a,
        rating: LearningRating.hard,
        answeredAt: instant,
      );
      expect(accepted.retryNext, isNull);
      expect(accepted.retryPrior.sameStateAs(a), isTrue);
      expect(accepted.scopePrior.ordinal, 21);
      expect(accepted.scopeNext.ordinal, 22);
      final next = await gateway.answerRetry(
        expectedPrior: await f.current(second),
        expectedRetry: b,
        rating: LearningRating.again,
        answeredAt: instant,
      );
      expect(next.retryNext!.dueOrdinal, 33);
      expect(next.retryNext!.errorCount, 2);
      expect(await rows(f.db, 'learning_items'), cards);
      expect(await rows(f.db, 'regular_reviews'), events);
      await expectLater(
        gateway.answerRetry(
          expectedPrior: await f.current(),
          expectedRetry: a,
          rating: LearningRating.good,
          answeredAt: instant,
        ),
        throwsA(RetryFailure.notFound),
      );
    },
  );
  test(
    'round update failure rolls scope back; concurrent same prior error admits one ordinal only',
    () async {
      final f = await fixture(), gateway = await source(f);
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      for (var index = 0; index < 20; index++) {
        await otherAnswer(f, index);
      }
      final item = await f.current(), before = await snapshot(f);
      await f.db.customStatement(
        "CREATE TRIGGER gap_fail AFTER UPDATE ON retry_obligations BEGIN SELECT RAISE(FAIL,'gap mutation'); END",
      );
      await expectLater(
        gateway.answerRetry(
          expectedPrior: item,
          expectedRetry: round,
          rating: LearningRating.again,
          answeredAt: instant,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(await snapshot(f), before);
      await f.db.customStatement('DROP TRIGGER gap_fail');
      final results = await Future.wait([
        for (var index = 0; index < 2; index++)
          gateway
              .answerRetry(
                expectedPrior: item,
                expectedRetry: round,
                rating: LearningRating.again,
                answeredAt: instant,
              )
              .then<Object>((value) => value, onError: (Object error) => error),
      ]);
      expect(results.whereType<RetryAnswerReceipt>(), hasLength(1));
      expect(
        results.where((value) => value == RetryFailure.staleState),
        hasLength(1),
      );
      expect((await gateway.retryState(at: instant)).scope.ordinal, 22);
      expect((await gateway.pendingRetries(at: instant)).single.revision, 1);
    },
  );
  test(
    'regular event failure after ordinal update rolls count and round/card/history back',
    () async {
      final f = await fixture();
      final before = await snapshot(f);
      await f.db.customStatement(
        "CREATE TRIGGER ordinal_fail AFTER INSERT ON regular_reviews BEGIN SELECT RAISE(FAIL,'regular failure'); END",
      );
      await expectLater(
        f.review(rating: LearningRating.again),
        throwsA(isA<SqliteException>()),
      );
      expect(await snapshot(f), before);
      await f.db.customStatement('DROP TRIGGER ordinal_fail');
      final receipt = await f.review(rating: LearningRating.again);
      expect(receipt.scopeNext!.ordinal, 1);
      expect(receipt.retryNext!.dueOrdinal, 21);
    },
  );
  test(
    'expired answer commits removal without answer ordinal or FSRS/history and never revives',
    () async {
      final f = await fixture(), gateway = await source(f);
      final round = (await f.review(rating: LearningRating.again)).retryNext!,
          item = await f.current();
      final ordinal = (await gateway.retryState(at: instant)).scope;
      await expectLater(
        gateway.answerRetry(
          expectedPrior: item,
          expectedRetry: round,
          rating: LearningRating.good,
          answeredAt: round.expiresAt,
        ),
        throwsA(RetryFailure.expired),
      );
      final state = await gateway.retryState(at: instant);
      expect(state.rounds, isEmpty);
      expect(state.scope.sameStateAs(ordinal), isTrue);
      expect((await f.current()).cardJson, item.cardJson);
      expect(await f.learning.reviewsForItem(item.id), hasLength(1));
    },
  );
  test(
    'Undo retains threshold/errors/revision while another answer advances surviving same-scope counter',
    () async {
      final f = await fixture(), gateway = await source(f);
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      expect((await gateway.retryState(at: instant)).scope.ordinal, 1);
      await otherAnswer(f, 1);
      await deletion.restore(receipt);
      final state = await gateway.retryState(at: instant);
      expect(state.scope.ordinal, 2);
      expect(state.rounds.single.sameStateAs(round), isTrue);
      expect(round.dueOrdinal - state.scope.ordinal, 19);
    },
  );
}
