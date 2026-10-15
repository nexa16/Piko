import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/retry_obligation.dart';
import 'package:piko/data/retry_answer.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;

class ControlledRetrySource implements RetryReviewSource {
  ControlledRetrySource(this.real);
  final RetryReviewSource real;
  bool failRefresh = false;
  Completer<void>? gate;
  final entered = Completer<void>();
  int refreshCalls = 0;
  @override
  String get collectionId => real.collectionId;
  @override
  LearningDirection get direction => real.direction;
  @override
  Future<RetrySelection> initialSelection({required DateTime cutoff}) =>
      real.initialSelection(cutoff: cutoff);
  @override
  Future<RetryState> retryState({required DateTime at}) async {
    refreshCalls++;
    if (!entered.isCompleted) entered.complete();
    await gate?.future;
    if (failRefresh) throw StateError('retry read');
    return real.retryState(at: at);
  }

  @override
  Future<RetryWaitResult> armBlockedWaits({
    required List<RetryObligation> expectedRounds,
    required List<LearningItemRecord> remainingRegular,
    required DateTime at,
  }) => real.armBlockedWaits(
    expectedRounds: expectedRounds,
    remainingRegular: remainingRegular,
    at: at,
  );

  @override
  Future<List<LearningItemRecord>> dueItems({required DateTime cutoff}) =>
      real.dueItems(cutoff: cutoff);
  @override
  Future<RegularReviewReceipt> review({
    required ReviewKind kind,
    required LearningItemRecord expectedPrior,
    required LearningRating rating,
    required DateTime reviewedAt,
  }) => real.review(
    kind: kind,
    expectedPrior: expectedPrior,
    rating: rating,
    reviewedAt: reviewedAt,
  );
  @override
  Future<RetryAnswerReceipt> answerRetry({
    required LearningItemRecord expectedPrior,
    required RetryObligation expectedRetry,
    required LearningRating rating,
    required DateTime answeredAt,
  }) => real.answerRetry(
    expectedPrior: expectedPrior,
    expectedRetry: expectedRetry,
    rating: rating,
    answeredAt: answeredAt,
  );
}

Future<Fixture> fixture() async {
  final f = Fixture();
  await f.initialize();
  addTearDown(f.db.close);
  await f.vocabulary.create(
    collectionId: f.owner.id,
    targetText: 'Next',
    nativeText: 'Weiter',
  );
  return f;
}

Future<ControlledRetrySource> source(Fixture f) async => ControlledRetrySource(
  await f.learning.forCollection(
    collectionId: f.owner.id,
    direction: LearningDirection.targetToNative,
  ),
);

void main() {
  test(
    'accepted Incorrect retry resets ten-gap and relinquishes priority to captured regular',
    () async {
      final f = await fixture();
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      await f.makeRetryEligible(round);
      final real = await source(f),
          session = await DueLearningSession.start(
            source: real,
            cutoff: instant,
            clock: f.db.clock,
          );
      try {
        final retry = session.current!;
        expect(session.currentIsRetry, isTrue);
        final receipt =
            (await session.submitAnswer(
                  retry,
                  AnswerGrade.incorrect,
                  reviewedAt: instant,
                ))!
                as RetryAnswerReceipt;
        expect(receipt.retryNext!.dueOrdinal - receipt.scopeNext.ordinal, 10);
        expect(receipt.retryNext!.errorCount, 2);
        expect(session.currentIsRetry, isFalse);
        expect(session.current!.item.id, isNot(retry.item.id));
        await session.submitAnswer(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        );
        expect(session.current, isNull);
        expect(session.hasPendingRetryWork, isTrue);
        expect(session.regularItemsExhausted, isTrue);
        final state = await real.retryState(at: instant);
        expect(state.rounds.single.dueOrdinal - state.scope.ordinal, 9);
      } finally {
        session.dispose();
      }
    },
  );
  test(
    'committed Good retains receipt when selection read fails; recovery resumes next member without regrading/count',
    () async {
      final f = await fixture(), real = await source(f);
      final session = await DueLearningSession.start(
        source: real,
        cutoff: instant,
        clock: f.db.clock,
      );
      try {
        final first = session.current!;
        real.failRefresh = true;
        final accepted = await session.submitAnswer(
          first,
          AnswerGrade.correct,
          reviewedAt: instant,
        );
        expect(accepted, isA<RegularReviewReceipt>());
        expect(session.acceptedReviews, hasLength(1));
        expect(session.current, isNull);
        expect(session.hasPendingRetryWork, isFalse);
        expect(session.selectionFailed, isTrue);
        expect(session.error, isA<StateError>());
        final ordinal = await rows(f.db, 'scope_answer_ordinals'),
            history = await rows(f.db, 'regular_reviews');
        real.failRefresh = false;
        await session.refreshRetries();
        expect(session.current!.item.id, isNot(first.item.id));
        expect(session.selectionFailed, isFalse);
        expect(await rows(f.db, 'scope_answer_ordinals'), ordinal);
        expect(await rows(f.db, 'regular_reviews'), history);
        expect(
          await session.submitAnswer(
            first,
            AnswerGrade.correct,
            reviewedAt: instant,
          ),
          isNull,
        );
      } finally {
        session.dispose();
      }
    },
  );
  test(
    'stop drains admitted grade plus gated next-read and receipt, without late presentation/notification',
    () async {
      final f = await fixture(),
          real = await source(f),
          drains = <Future<void>>[];
      final session = await DueLearningSession.start(
        source: real,
        cutoff: instant,
        clock: f.db.clock,
        onPendingWrites: drains.add,
      );
      real.gate = Completer<void>();
      var notifications = 0;
      session.addListener(() => notifications++);
      final submit = session.submitAnswer(
        session.current!,
        AnswerGrade.correct,
        reviewedAt: instant,
      );
      try {
        await real.entered.future;
        expect(session.acceptedReviews, hasLength(1));
        expect(session.isSubmitting, isTrue);
        var stopped = false;
        final stop = session.stop().then((_) => stopped = true);
        await Future<void>.value();
        expect(stopped, isFalse);
        final before = notifications;
        real.gate!.complete();
        final receipt = await submit;
        await stop;
        await Future.wait(drains);
        expect(receipt, same(session.acceptedReviews.single));
        expect(session.current, isNull);
        expect(notifications, before);
        expect(session.unreviewedMembers, hasLength(1));
        expect(await rows(f.db, 'regular_reviews'), hasLength(1));
      } finally {
        if (!real.gate!.isCompleted) real.gate!.complete();
        await submit;
        session.dispose();
      }
    },
  );
  test(
    'displayed retry exact expiry retires unanswered handle and selects captured regular without success/count',
    () async {
      final f = await fixture();
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      await f.makeRetryEligible(round);
      final real = await source(f),
          session = await DueLearningSession.start(
            source: await source(f),
            cutoff: instant,
            clock: f.db.clock,
          );
      try {
        final expired = session.current!;
        expect(session.currentIsRetry, isTrue);
        final before = await rows(f.db, 'scope_answer_ordinals'),
            history = await rows(f.db, 'regular_reviews');
        expect(
          await session.submitAnswer(
            expired,
            AnswerGrade.correct,
            reviewedAt: round.expiresAt,
          ),
          isNull,
        );
        expect(session.currentIsRetry, isFalse);
        expect(session.current!.item.id, isNot(expired.item.id));
        expect(session.acceptedReviews, isEmpty);
        expect(session.lastAnswer, isNull);
        expect(await rows(f.db, 'scope_answer_ordinals'), before);
        expect(await rows(f.db, 'regular_reviews'), history);
        expect((await real.retryState(at: instant)).rounds, isEmpty);
      } finally {
        session.dispose();
      }
    },
  );
  test(
    'retry refresh registration failure is fail-closed and can recover without answer writes',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review(rating: LearningRating.again);
      final real = await source(f);
      bool reject = true;
      final session = await DueLearningSession.start(
        source: real,
        cutoff: instant,
        clock: f.db.clock,
        onPendingWrites: (_) {
          if (reject) throw StateError('register');
        },
      );
      try {
        final before = await rows(f.db, 'scope_answer_ordinals');
        await session.refreshRetries();
        expect(real.refreshCalls, 0);
        expect(session.selectionFailed, isTrue);
        reject = false;
        await session.refreshRetries();
        expect(real.refreshCalls, 1);
        expect(session.selectionFailed, isFalse);
        expect(session.current, isNull);
        expect(session.hasPendingRetryWork, isTrue);
        expect(await rows(f.db, 'scope_answer_ordinals'), before);
      } finally {
        session.dispose();
      }
    },
  );
}
