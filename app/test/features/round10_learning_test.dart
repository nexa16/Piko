import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_parameters.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/speed_runtime.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;
import '../support/mutable_clock.dart';
import 'due_learning_session_test.dart' show addWords, source;

void main() {
  test(
    'Skip on eligible retry preserves obligation, expiry and answer ordinal',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final gateway = await source(f);
      final clock = f.db.clock as MutablePikoClock;
      final session = await DueLearningSession.start(
        source: gateway,
        cutoff: instant,
        clock: clock,
        presentationActive: false,
      );
      addTearDown(session.dispose);
      await session.submitAnswerNow(session.current!, AnswerGrade.incorrect);
      final pending = (await gateway.pendingRetries(at: clock.now())).single;
      clock.set(pending.waitEligibleAt!);
      await session.refreshRetries();
      session.setPresentationActive(true);
      final before = <String, Object>{};
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        before[table] = await rows(f.db, table);
      }
      expect(session.currentIsRetry, isTrue);
      final first = session.current!;
      expect(session.skip(first), isTrue);
      expect(session.currentIsRetry, isTrue);
      expect(session.current!.item.id, first.item.id);
      expect(session.progress.totalRetries, 0);
      for (final table in before.keys) {
        expect(await rows(f.db, table), before[table], reason: table);
      }
      await session.submitAnswerNow(session.current!, AnswerGrade.incorrect);
      expect(session.progress.totalRetries, 1);
      final retry = (await gateway.pendingRetries(at: clock.now())).single;
      clock.set(retry.waitEligibleAt!);
      await session.refreshRetries();
      await session.submitAnswerNow(session.current!, AnswerGrade.correct);
      expect(session.progress.totalRetries, 2);
    },
  );

  test(
    'Speed previous remains available during game; correction recalculates break and attempts',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await addWords(f, 1);
      final ids = (await (await source(
        f,
      )).items()).map((item) => item.entryId).toList();
      final session =
          await PikoSpeedRuntime(
            learning: f.learning,
            clock: f.db.clock,
          ).prepareSelected(
            collectionId: f.owner.id,
            direction: LearningDirection.targetToNative,
            orderedEntryIds: ids,
            poolSize: 2,
          );
      addTearDown(session.dispose);
      session.setPresentationActive(true);
      Future<void> answer(SpeedAnswer grade) async {
        final handle = session.current!;
        session.reveal(handle);
        expect(await session.submitAnswer(handle, grade), isTrue);
      }

      await answer(SpeedAnswer.incorrect);
      await answer(SpeedAnswer.correct);
      expect(session.needsBreak, isTrue);
      expect(session.beginBreak(), isTrue);
      session.tapNumber(session.currentBreak!, 1);
      expect(session.canCorrectPrevious, isTrue);
      expect(session.beginCorrection(), isTrue);
      expect(
        await session.submitAnswer(session.current!, SpeedAnswer.incorrect),
        isTrue,
      );
      expect(session.state!.pool, ids);
      expect(session.needsBreak, isFalse);
      expect(session.state!.numberGame, isNull);
      expect(session.state!.totalRetries, 0);
      expect(await rows(f.db, 'statistics_activity'), isEmpty);
      expect(session.beginCorrection(), isTrue);
      expect(
        await session.submitAnswer(session.current!, SpeedAnswer.correct),
        isTrue,
      );
      expect(session.needsBreak, isTrue);
      session.beginBreak();
      final game = session.currentBreak!;
      for (var i = 1; i <= 10; i++) {
        session.tapNumber(game, i);
      }
      expect(session.state!.completedBreaks, 1);
      expect(session.beginCorrection(), isTrue);
      expect(
        await session.submitAnswer(session.current!, SpeedAnswer.correct),
        isTrue,
      );
      expect(session.state!.completedBreaks, 1);
      expect(session.current!.entryId, ids.first);
      await answer(SpeedAnswer.correct);
      expect(session.state!.totalRetries, 1);
      expect(session.beginCorrection(), isTrue);
      expect(
        await session.submitAnswer(session.current!, SpeedAnswer.incorrect),
        isTrue,
      );
      expect(session.state!.totalRetries, 1);
      expect(session.state!.itemProgress[ids.first]!.errors, 2);
      await session.stop();
      expect(session.canCorrectPrevious, isFalse);
      expect(session.state, isNull);
    },
  );
  test(
    'unlimited Skip defers behind five presentations with no durable effects',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await addWords(f, 6);
      final session = await DueLearningSession.start(
        source: await source(f),
        cutoff: instant,
      );
      addTearDown(session.dispose);
      final before = <String, Object>{};
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
        'statistics_activity',
      ]) {
        before[table] = await rows(f.db, table);
      }
      final first = session.current!.item.id;
      final order = <int>[];
      expect(session.skip(session.current!), isTrue);
      for (var i = 0; i < 5; i++) {
        order.add(session.current!.item.id);
        expect(session.skip(session.current!), isTrue);
      }
      expect(order.toSet(), hasLength(5));
      expect(order, isNot(contains(first)));
      expect(session.current!.item.id, first);
      for (var i = 0; i < 20; i++) {
        expect(session.skip(session.current!), isTrue);
      }
      expect(session.pendingItemCount, 7);
      expect(session.progress.totalRetries, 0);
      expect(session.progress.completed, 0);
      for (final table in before.keys) {
        expect(await rows(f.db, table), before[table], reason: table);
      }
    },
  );

  test(
    'single Skip remains pending; correct always Good with historical Hard retained',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final session = await DueLearningSession.start(
        source: await source(f),
        cutoff: instant,
      );
      addTearDown(session.dispose);
      final old = session.current!;
      for (var i = 0; i < 8; i++) {
        expect(session.skip(session.current!), isTrue);
        expect(session.current!.item.id, old.item.id);
      }
      expect(session.setHard(session.current!, true), isFalse);
      final result = await session.submitAnswer(
        session.current!,
        AnswerGrade.correct,
        reviewedAt: instant,
      );
      expect(result!.next.card.lastReview, instant);
      expect(session.acceptedReviews.single.event.rating, LearningRating.good);
      expect(session.progress.totalRetries, 0);
    },
  );

  test(
    'Speed previous correction restores pool and removes only new completion credit',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await addWords(f, 1);
      final gateway = await source(f);
      final ids = (await gateway.items()).map((item) => item.entryId).toList();
      final beforeItems = await rows(f.db, 'learning_items');
      final session =
          await PikoSpeedRuntime(
            learning: f.learning,
            clock: f.db.clock,
          ).prepareSelected(
            collectionId: f.owner.id,
            direction: LearningDirection.targetToNative,
            orderedEntryIds: ids,
            poolSize: 2,
          );
      addTearDown(session.dispose);
      session.setPresentationActive(true);
      var turn = session.current!;
      session.reveal(turn);
      expect(await session.submitAnswer(turn, SpeedAnswer.correct), isTrue);
      expect(session.state!.completedEntryIds, {ids.first});
      expect(await rows(f.db, 'statistics_activity'), hasLength(1));
      expect(session.beginCorrection(), isTrue);
      turn = session.current!;
      expect(session.revealed, isTrue);
      expect(await session.submitAnswer(turn, SpeedAnswer.incorrect), isTrue);
      expect(session.state!.completedEntryIds, isEmpty);
      expect(session.state!.itemProgress[ids.first]!.errors, 1);
      expect(session.state!.itemProgress[ids.first]!.attempts, 1);
      expect(session.state!.totalRetries, 0);
      expect(await rows(f.db, 'statistics_activity'), isEmpty);
      expect(await rows(f.db, 'speed_completion_receipts'), isEmpty);
      expect(await rows(f.db, 'learning_items'), beforeItems);
      expect(session.current!.entryId, ids.last);
      expect(session.beginCorrection(), isTrue);
      (f.db.clock as MutablePikoClock).advance(const Duration(seconds: 1));
      expect(
        await session.submitAnswer(session.current!, SpeedAnswer.correct),
        isTrue,
      );
      expect(session.state!.completedEntryIds, {ids.first});
      expect(await rows(f.db, 'statistics_activity'), hasLength(1));
    },
  );

  test(
    'Speed total retries includes required streak answers and survives games only in memory',
    () {
      var state = SpeedSession.start(
        collectionId: 'collection',
        direction: LearningDirection.targetToNative,
        eligibleEntryIds: ['a'],
        poolSize: 1,
      );
      state = state.answer(entryId: 'a', answer: SpeedAnswer.incorrect);
      expect(state.totalRetries, 0);
      state = state.answer(entryId: 'a', answer: SpeedAnswer.correct);
      expect(state.totalRetries, 1);
      expect(state.isComplete, isFalse);
      state = state.answer(entryId: 'a', answer: SpeedAnswer.correct);
      expect(state.totalRetries, 2);
      expect(state.isComplete, isTrue);
      expect(
        LearningParameters.registry['review.skipOtherQuestions']!.value,
        5,
      );
    },
  );
}
