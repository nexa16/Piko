import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/retry_answer.dart';
import 'package:piko/data/retry_obligation.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import '../data/regular_reviews_test.dart' show rows, instant;
import '../ui/review_launch_test.dart' as launch;
import '../support/mutable_clock.dart';
import 'retry_learning_session_test.dart' show ControlledRetrySource;

class WakeTimer implements Timer {
  WakeTimer(this.duration, this.callback);
  final Duration duration;
  final void Function() callback;
  bool active = true;
  void fire({bool evenIfCancelled = false}) {
    if (active || evenIfCancelled) {
      active = false;
      callback();
    }
  }

  @override
  void cancel() => active = false;
  @override
  bool get isActive => active;
  @override
  int get tick => active ? 0 : 1;
}

class WaitSource extends ControlledRetrySource {
  WaitSource(super.real);
  bool failArm = false;
  Completer<void>? armGate;
  Completer<void> armEntered = Completer<void>();
  @override
  Future<RetryWaitResult> armBlockedWaits({
    required List<RetryObligation> expectedRounds,
    required List<LearningItemRecord> remainingRegular,
    required DateTime at,
  }) async {
    if (!armEntered.isCompleted) armEntered.complete();
    await armGate?.future;
    if (failArm) throw StateError('arm failed');
    return super.armBlockedWaits(
      expectedRounds: expectedRounds,
      remainingRegular: remainingRegular,
      at: at,
    );
  }
}

void main() {
  test(
    'automatic displayed expiry retires handle even if next-read fails; explicit recovery never regrades/counts',
    () async {
      final f = launch.fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      await f.makeRetryEligible(round);
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
        timerFactory: (d, callback) {
          final t = WakeTimer(d, callback);
          wakes.add(t);
          return t;
        },
      );
      addTearDown(session.dispose);
      final handle = session.current!;
      final history = await rows(f.db, 'regular_reviews'),
          items = await rows(f.db, 'learning_items'),
          ordinal = await rows(f.db, 'scope_answer_ordinals');
      source.failRefresh = true;
      (f.db.clock as MutablePikoClock).set(round.expiresAt);
      wakes.last.fire();
      await session.awaitPending();
      expect(session.current, isNull);
      expect(session.selectionFailed, isTrue);
      expect(
        await session.submitAnswerNow(handle, AnswerGrade.correct),
        isNull,
      );
      source.failRefresh = false;
      await session.refreshRetries();
      expect(session.selectionFailed, isFalse);
      expect(session.hasPendingRetryWork, isFalse);
      expect(await rows(f.db, 'retry_obligations'), isEmpty);
      expect(await rows(f.db, 'regular_reviews'), history);
      expect(await rows(f.db, 'learning_items'), items);
      expect(await rows(f.db, 'scope_answer_ordinals'), ordinal);
      expect(session.lastAnswer, isNull);
    },
  );
  test(
    'persisted wait wakes from fresh time; rollback and cancelled callbacks cannot grant eligibility; resume retains deadline',
    () async {
      final f = launch.fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review(rating: LearningRating.again);
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final wakes = <WakeTimer>[];
      Timer timer(Duration duration, void Function() callback) {
        final wake = WakeTimer(duration, callback);
        wakes.add(wake);
        return wake;
      }

      var session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        timerFactory: timer,
      );
      addTearDown(() => session.dispose());
      final clock = f.db.clock as MutablePikoClock;
      final wait = session.waitMutations.single.next;
      final before = await rows(f.db, 'learning_items'),
          history = await rows(f.db, 'regular_reviews'),
          ordinals = await rows(f.db, 'scope_answer_ordinals');
      expect(wakes.last.duration, const Duration(seconds: 1));
      expect(session.retryWaitSeconds, 10);
      clock.advance(const Duration(seconds: 4));
      wakes.last.fire();
      await session.awaitPending();
      expect(session.current, isNull);
      expect(wakes.last.duration, const Duration(seconds: 1));
      expect(session.retryWaitSeconds, 6);
      final cancelled = wakes.last;
      session.setPresentationActive(false);
      clock.advance(const Duration(seconds: 6));
      cancelled.fire(evenIfCancelled: true);
      await session.awaitPending();
      expect(session.current, isNull);
      session.setPresentationActive(true);
      await session.awaitPending();
      expect(session.currentIsRetry, isTrue);
      await session.stop();
      session.dispose();
      clock.set(instant.add(const Duration(seconds: 5)));
      session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: clock,
        timerFactory: timer,
      );
      expect(session.current, isNull);
      expect(session.waitMutations, isEmpty);
      expect(
        (await source.retryState(
          at: clock.now(),
        )).rounds.single.sameStateAs(wait),
        isTrue,
      );
      expect(wakes.last.duration, const Duration(seconds: 1));
      expect(session.retryWaitSeconds, 5);
      clock.set(wait.waitEligibleAt!);
      wakes.last.fire();
      await session.awaitPending();
      expect(session.currentIsRetry, isTrue);
      expect(await rows(f.db, 'learning_items'), before);
      expect(await rows(f.db, 'regular_reviews'), history);
      expect(await rows(f.db, 'scope_answer_ordinals'), ordinals);
    },
  );

  test(
    'remaining regular work prevents wait; Incorrect retry resets wait and next blocked selection arms a new ten seconds',
    () async {
      final f = launch.fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review(rating: LearningRating.again);
      await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Next',
        nativeText: 'Weiter',
      );
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final wakes = <WakeTimer>[];
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        timerFactory: (d, callback) {
          final t = WakeTimer(d, callback);
          wakes.add(t);
          return t;
        },
      );
      addTearDown(session.dispose);
      expect(session.currentIsRetry, isFalse);
      expect(wakes, isEmpty);
      expect(
        (await source.retryState(at: instant)).rounds.single.waitEligibleAt,
        isNull,
      );
      await session.submitAnswer(
        session.current!,
        AnswerGrade.correct,
        reviewedAt: instant,
      );
      expect(session.waitMutations, hasLength(1));
      final clock = f.db.clock as MutablePikoClock;
      clock.advance(const Duration(seconds: 10));
      wakes.last.fire();
      await session.awaitPending();
      final answer =
          (await session.submitAnswer(
                session.current!,
                AnswerGrade.incorrect,
                reviewedAt: clock.now(),
              ))!
              as RetryAnswerReceipt;
      expect(
        answer.retryPrior.waitEligibleAt,
        instant.add(const Duration(seconds: 10)),
      );
      expect(answer.retryNext!.waitEligibleAt, isNull);
      expect(answer.retryNext!.dueOrdinal - answer.scopeNext.ordinal, 10);
      expect(session.waitMutations, hasLength(2));
      expect(
        session.waitMutations.last.next.waitEligibleAt,
        instant.add(const Duration(seconds: 20)),
      );
      expect(
        session.waitMutations.last.next.expiresAt,
        answer.retryPrior.expiresAt,
      );
      expect(await rows(f.db, 'regular_reviews'), hasLength(2));
    },
  );

  test(
    'failed arming keeps recovery; stop drains admitted arming and exact mutation without late notification',
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
      )..failArm = true;
      final drains = <Future<void>>[];
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        onPendingWrites: drains.add,
      );
      addTearDown(session.dispose);
      expect(session.selectionFailed, isTrue);
      expect(session.current, isNull);
      expect(
        (await source.real.retryState(
          at: instant,
        )).rounds.single.waitEligibleAt,
        isNull,
      );
      source.failArm = false;
      source.armGate = Completer<void>();
      source.armEntered = Completer<void>();
      var notifications = 0;
      session.addListener(() => notifications++);
      final refresh = session.refreshRetries();
      try {
        await source.armEntered.future;
        final stop = session.stop(), frozen = notifications;
        source.armGate!.complete();
        await refresh;
        await stop;
        await Future.wait(drains);
        expect(session.waitMutations, hasLength(1));
        expect(notifications, frozen);
        expect(session.current, isNull);
        expect(
          (await source.real.retryState(
            at: instant,
          )).rounds.single.waitEligibleAt,
          isNotNull,
        );
      } finally {
        if (!source.armGate!.isCompleted) source.armGate!.complete();
        await refresh;
        await session.awaitPending();
      }
    },
  );
}
