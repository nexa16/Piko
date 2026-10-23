import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:piko/data/retry_answer.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/learning_session_progress.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant;
import '../data/retry_gap_migration_test.dart' show gateway, storedSnapshot;
import '../support/mutable_clock.dart';
import 'due_learning_session_test.dart' show GatedSource;
import 'retry_learning_session_test.dart' show ControlledRetrySource;

Future<Fixture> fixture({int extra = 0}) async {
  final f = Fixture();
  await f.initialize();
  addTearDown(f.db.close);
  for (var index = 0; index < extra; index++) {
    await f.vocabulary.create(
      collectionId: f.owner.id,
      targetText: 'Word $index',
      nativeText: 'Wort $index',
    );
  }
  return f;
}

void expectCounts(
  DueLearningSession session, {
  required int total,
  required int completed,
  required int firstTry,
  required int pending,
}) {
  expect(session.progress.total, total);
  expect(session.progress.completed, completed);
  expect(session.progress.firstTryCorrect, firstTry);
  expect(session.progress.fraction, total == 0 ? 0 : completed / total);
  expect(session.pendingItemCount, pending);
}

void main() {
  test(
    'Good and Hard complete unique regular items; Again stays pending through repeated retries and retry success is not first-try',
    () async {
      final f = await fixture(extra: 2),
          source = await gateway(f.db, f.owner.id);
      final clock = f.db.clock as MutablePikoClock;
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: clock,
        presentationActive: false,
      );
      addTearDown(session.dispose);
      final initial = session.progress;
      expectCounts(session, total: 3, completed: 0, firstTry: 0, pending: 3);
      expect(initial.members, hasLength(3));
      final goodHandle = session.current!;
      final good = (await session.submitAnswerNow(
        goodHandle,
        AnswerGrade.correct,
      ))!;
      expect(good, isA<RegularReviewReceipt>());
      expectCounts(session, total: 3, completed: 1, firstTry: 1, pending: 2);
      expect(initial.completedItems, isEmpty);
      expect(initial.firstTryItems, isEmpty);
      expect(() => initial.members.clear(), throwsUnsupportedError);
      expect(
        () => session.progress.completedItems.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => session.progress.firstTryItems.clear(),
        throwsUnsupportedError,
      );
      final hardHandle = session.current!, beforeToggle = session.progress;
      final storage = await storedSnapshot(f.db);
      expect(session.setHard(hardHandle, true), isFalse);
      expect(session.progress, same(beforeToggle));
      expect(await storedSnapshot(f.db), storage);
      final hard =
          (await session.submitAnswerNow(hardHandle, AnswerGrade.correct))!
              as RegularReviewReceipt;
      expect(hard.event.rating, LearningRating.good);
      expectCounts(session, total: 3, completed: 2, firstTry: 2, pending: 1);
      final incorrectHandle = session.current!,
          priorIncorrect = session.progress;
      final incorrect = (await session.submitAnswerNow(
        incorrectHandle,
        AnswerGrade.incorrect,
      ))!;
      expectCounts(session, total: 3, completed: 2, firstTry: 2, pending: 1);
      expect(session.progress.completedItems, priorIncorrect.completedItems);
      expect(session.progress.totalRetries, 0);
      expect(session.lastProgressChange!.receipt, same(incorrect));
      expect(session.lastProgressChange!.prior, same(priorIncorrect));
      expect(session.lastProgressChange!.next, same(session.progress));
      expect(session.hasPendingRetryWork, isTrue);
      expect(session.regularItemsExhausted, isTrue);
      for (var retry = 0; retry < 2; retry++) {
        final round = (await source.pendingRetries(at: clock.now())).single;
        expect(round.waitEligibleAt, isNotNull);
        clock.set(round.waitEligibleAt!);
        await session.refreshRetries();
        expect(session.currentIsRetry, isTrue);
        await session.submitAnswerNow(session.current!, AnswerGrade.incorrect);
        expectCounts(session, total: 3, completed: 2, firstTry: 2, pending: 1);
      }
      final round = (await source.pendingRetries(at: clock.now())).single;
      clock.set(round.waitEligibleAt!);
      await session.refreshRetries();
      final successfulHandle = session.current!,
          beforeSuccess = session.progress;
      final success =
          (await session.submitAnswerNow(
                successfulHandle,
                AnswerGrade.correct,
              ))!
              as RetryAnswerReceipt;
      expect(success.retryNext, isNull);
      expectCounts(session, total: 3, completed: 3, firstTry: 2, pending: 0);
      expect(session.lastProgressChange!.prior, same(beforeSuccess));
      expect(session.lastProgressChange!.next, same(session.progress));
      expect(session.lastProgressChange!.receipt, same(success));
      final finished = session.progress;
      expect(
        finished.accepting(success).completedItems,
        finished.completedItems,
      );
      expect(finished.accepting(success).firstTryItems, finished.firstTryItems);
      expect(
        await session.submitAnswerNow(successfulHandle, AnswerGrade.correct),
        isNull,
      );
      expect(
        await session.submitAnswerNow(goodHandle, AnswerGrade.correct),
        isNull,
      );
      expect(session.progress, same(finished));
      expect(LearningSessionProgress(members: {}).fraction, 0);
    },
  );

  test(
    'resumed pending item belongs to the unique launch union and its Hard success never carries prior-session first-try counts',
    () async {
      final f = await fixture(extra: 2),
          source = await gateway(f.db, f.owner.id);
      final words = await f.vocabulary.watchByCollection(f.owner.id).first;
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      final oldGood = await f.review(word: words[1]);
      // Explicit seeded admission tests resumed accounting, not earned retry gaps.
      await f.makeRetryEligible(round);
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        presentationActive: false,
      );
      addTearDown(session.dispose);
      expect(session.members, hasLength(1));
      expect(session.currentIsRetry, isTrue);
      expectCounts(session, total: 2, completed: 0, firstTry: 0, pending: 2);
      expect(
        session.progress.members.contains((
          itemId: round.itemId,
          generation: round.generation,
        )),
        isTrue,
      );
      expect(
        session.progress.members.contains((
          itemId: oldGood.prior.id,
          generation: oldGood.prior.generation,
        )),
        isFalse,
      );
      final retry = session.current!;
      session.setHard(retry, true);
      final accepted =
          (await session.submitAnswerNow(retry, AnswerGrade.correct))!
              as RetryAnswerReceipt;
      expect(accepted.rating, LearningRating.good);
      expectCounts(session, total: 2, completed: 1, firstTry: 0, pending: 1);
      final regular = session.current!;
      await session.submitAnswerNow(regular, AnswerGrade.correct);
      expectCounts(session, total: 2, completed: 2, firstTry: 1, pending: 0);
      expect(session.progress.firstTryItems, {
        (itemId: regular.item.id, generation: regular.item.generation),
      });
    },
  );

  test(
    'failed write leaves counters exact; accepted grade survives failed next-read and recovery/stale replay never counts it twice',
    () async {
      final f = await fixture(extra: 1);
      final source = ControlledRetrySource(await gateway(f.db, f.owner.id));
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        presentationActive: false,
      );
      addTearDown(session.dispose);
      final handle = session.current!, initial = session.progress;
      final before = await storedSnapshot(f.db);
      await f.db.customStatement(
        "CREATE TRIGGER fail_progress_grade AFTER INSERT ON regular_reviews BEGIN SELECT RAISE(FAIL, 'blocked'); END",
      );
      await expectLater(
        session.submitAnswerNow(handle, AnswerGrade.correct),
        throwsA(isA<SqliteException>()),
      );
      expectCounts(session, total: 2, completed: 0, firstTry: 0, pending: 2);
      expect(session.progress.completedItems, initial.completedItems);
      expect(session.lastProgressChange, isNull);
      expect(await storedSnapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER fail_progress_grade');
      source.failRefresh = true;
      final accepted = (await session.submitAnswerNow(
        handle,
        AnswerGrade.correct,
      ))!;
      expect(session.selectionFailed, isTrue);
      expectCounts(session, total: 2, completed: 1, firstTry: 1, pending: 1);
      final counted = session.progress, change = session.lastProgressChange!;
      expect(change.prior, same(initial));
      expect(change.next, same(counted));
      expect(change.receipt, same(accepted));
      final committed = await storedSnapshot(f.db);
      source.failRefresh = false;
      await session.refreshRetries();
      expect(session.selectionFailed, isFalse);
      expect(session.current!.item.id, isNot(handle.item.id));
      expect(session.progress, same(counted));
      expect(session.lastProgressChange, same(change));
      expect(
        await session.submitAnswerNow(handle, AnswerGrade.correct),
        isNull,
      );
      expect(await storedSnapshot(f.db), committed);
      expectCounts(session, total: 2, completed: 1, firstTry: 1, pending: 1);
    },
  );

  test(
    'accepted post-stop grade drains exact progress context without changing unanswered membership or notifying late',
    () async {
      final f = await fixture(extra: 1),
          source = GatedSource(await gateway(f.db, f.owner.id));
      final drains = <Future<void>>[];
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        onPendingWrites: drains.add,
        presentationActive: false,
      );
      final initial = session.progress, handle = session.current!;
      var notifications = 0;
      session.addListener(() => notifications++);
      final submit = session.submitAnswerNow(handle, AnswerGrade.correct);
      try {
        await source.entered.future;
        final stopped = session.stop();
        final frozen = notifications;
        expectCounts(session, total: 2, completed: 0, firstTry: 0, pending: 2);
        source.gate.complete();
        final accepted = (await submit)!;
        await stopped;
        await Future.wait(drains);
        expect(session.isStopped, isTrue);
        expect(session.current, isNull);
        expect(notifications, frozen);
        expectCounts(session, total: 2, completed: 1, firstTry: 1, pending: 1);
        expect(session.lastProgressChange!.prior, same(initial));
        expect(session.lastProgressChange!.next, same(session.progress));
        expect(session.lastProgressChange!.receipt, same(accepted));
        expect(session.unreviewedMembers, hasLength(1));
        expect(
          await session.submitAnswerNow(handle, AnswerGrade.correct),
          isNull,
        );
        expectCounts(session, total: 2, completed: 1, firstTry: 1, pending: 1);
      } finally {
        if (!source.gate.isCompleted) source.gate.complete();
        await submit;
        await session.awaitPending();
        session.dispose();
      }
    },
  );

  test(
    'expired pending retry ends pending without completion or first-try success and retains the captured total',
    () async {
      final f = await fixture(), source = await gateway(f.db, f.owner.id);
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      await f.makeRetryEligible(round);
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        presentationActive: false,
      );
      addTearDown(session.dispose);
      final initial = session.progress, handle = session.current!;
      expectCounts(session, total: 1, completed: 0, firstTry: 0, pending: 1);
      final before = await storedSnapshot(f.db);
      (f.db.clock as MutablePikoClock).set(round.expiresAt);
      expect(
        await session.submitAnswerNow(handle, AnswerGrade.correct),
        isNull,
      );
      expectCounts(session, total: 1, completed: 0, firstTry: 0, pending: 0);
      expect(session.progress.completedItems, initial.completedItems);
      expect(session.lastProgressChange, isNull);
      expect(session.lastAnswer, isNull);
      final after = await storedSnapshot(f.db);
      for (final table in before.keys) {
        if (table != 'retry_obligations') expect(after[table], before[table]);
      }
      expect(after['retry_obligations'], isEmpty);
    },
  );

  test(
    'latest regular correction replaces receipt and queue while reversing then applying exact progress',
    () async {
      final f = await fixture(extra: 1),
          source = await gateway(f.db, f.owner.id);
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        presentationActive: false,
      );
      addTearDown(session.dispose);
      final initial = session.progress, first = session.current!;
      final accepted =
          (await session.submitAnswerNow(first, AnswerGrade.correct))!
              as RegularReviewReceipt;
      final unanswered = session.current!;
      expectCounts(session, total: 2, completed: 1, firstTry: 1, pending: 1);
      expect(session.canCorrectPrevious(first), isFalse);
      expect(session.canCorrectPrevious(unanswered), isTrue);
      expect(session.beginCorrection(unanswered), isTrue);
      final correction = session.current!;
      expect(correction.item.id, accepted.prior.id);
      expect(session.previousRating, LearningRating.good);
      expect(session.beginCorrection(correction), isFalse);
      final replaced =
          (await session.submitAnswerNow(correction, AnswerGrade.incorrect))!
              as RegularReviewReceipt;
      expect(replaced.event.id, accepted.event.id);
      expect(replaced.event.reviewedAt, accepted.event.reviewedAt);
      expect(replaced.event.rating, LearningRating.again);
      expect(replaced.scopeNext!.ordinal, accepted.scopeNext!.ordinal);
      expect(replaced.scopeNext!.revision, accepted.scopeNext!.revision + 1);
      expect(replaced.next.reviewRevision, accepted.next.reviewRevision + 1);
      expect(
        replaced.next.cardJson,
        LearningScheduler()
            .review(
              accepted.prior,
              rating: LearningRating.again,
              reviewedAt: accepted.event.reviewedAt,
            )
            .next
            .cardJson,
      );
      expect(session.current, same(unanswered));
      expect(session.currentIsRetry, isFalse);
      expect(session.acceptedReviews, [same(replaced)]);
      expect(session.lastProgressChange!.prior, same(initial));
      expect(session.lastProgressChange!.receipt, same(replaced));
      expectCounts(session, total: 2, completed: 0, firstTry: 0, pending: 2);
      expect(
        (await source.pendingRetries(at: f.db.clock.now())).single.id,
        replaced.retryNext!.id,
      );
    },
  );

  test(
    'correcting latest regular Again to Good removes its retry and counts one first-try success without advancing ordinal',
    () async {
      final f = await fixture(extra: 1),
          source = await gateway(f.db, f.owner.id);
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        presentationActive: false,
      );
      addTearDown(session.dispose);
      final initial = session.progress, first = session.current!;
      final accepted =
          (await session.submitAnswerNow(first, AnswerGrade.incorrect))!
              as RegularReviewReceipt;
      final unanswered = session.current!;
      expect(session.progress.completedItems, initial.completedItems);
      expect(session.beginCorrection(unanswered), isTrue);
      final correction = session.current!;
      expect(session.previousRating, LearningRating.again);
      final replaced =
          (await session.submitAnswerNow(correction, AnswerGrade.correct))!
              as RegularReviewReceipt;
      expect(replaced.event.id, accepted.event.id);
      expect(replaced.event.rating, LearningRating.good);
      expect(replaced.retryNext, isNull);
      expect(replaced.scopeNext!.ordinal, accepted.scopeNext!.ordinal);
      expect(replaced.scopeNext!.revision, accepted.scopeNext!.revision + 1);
      expect(session.current, same(unanswered));
      expect(session.acceptedReviews, [same(replaced)]);
      expect(session.lastProgressChange!.prior, same(initial));
      expectCounts(session, total: 2, completed: 1, firstTry: 1, pending: 1);
      expect(await source.pendingRetries(at: f.db.clock.now()), isEmpty);
    },
  );

  test(
    'correcting the previous retry retires its now-stale displayed retry and preserves the unrelated armed round',
    () async {
      final f = await fixture(extra: 1),
          source = await gateway(f.db, f.owner.id);
      final words = await f.vocabulary.watchByCollection(f.owner.id).first;
      final first = await f.review(rating: LearningRating.again);
      final second = await f.review(
        word: words[1],
        rating: LearningRating.again,
      );
      await f.db.customStatement(
        'UPDATE retry_obligations SET due_ordinal=100, revision=revision+1 WHERE id=?',
        [second.retryNext!.id],
      );
      await f.makeRetryEligible(first.retryNext!);
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        presentationActive: false,
      );
      addTearDown(session.dispose);
      expect(session.current!.item.id, first.prior.id);
      final answer =
          (await session.submitAnswerNow(
                session.current!,
                AnswerGrade.incorrect,
              ))!
              as RetryAnswerReceipt;
      expect(session.current, isNull);
      final armed = await source.pendingRetries(at: f.db.clock.now());
      expect(armed, hasLength(2));
      expect(armed.every((round) => round.waitEligibleAt != null), isTrue);
      (f.db.clock as MutablePikoClock).set(
        armed
            .map((round) => round.waitEligibleAt!)
            .reduce((a, b) => a.isAfter(b) ? a : b),
      );
      await session.refreshRetries();
      final staleDisplayed = session.current!;
      expect(staleDisplayed.item.id, answer.prior.id);
      expect(session.beginCorrection(staleDisplayed), isTrue);
      final replacement =
          (await session.submitAnswerNow(
                session.current!,
                AnswerGrade.correct,
              ))!
              as RetryAnswerReceipt;
      expect(replacement.retryNext, isNull);
      expect(session.current, isNot(same(staleDisplayed)));
      expect(session.current!.item.id, second.prior.id);
      expect(session.currentIsRetry, isTrue);
      final remaining = await source.pendingRetries(at: f.db.clock.now());
      expect(remaining, hasLength(1));
      expect(remaining.single.id, second.retryNext!.id);
      expectCounts(session, total: 2, completed: 1, firstTry: 0, pending: 1);
    },
  );
}
