import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/speed_completion.dart';
import 'regular_reviews_test.dart' show Fixture, instant, rows;
import '../features/due_learning_session_test.dart' show source;

void main() {
  test(
    'correction retains preexisting marker and daily credit; removes only its new day',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final gateway = await source(f);
      final prior = (await gateway.items()).single;
      final old = await gateway.completeSpeedItem(
        expectedPrior: prior,
        errors: 0,
        completedAt: instant,
      );
      final oldCredits = await rows(f.db, 'statistics_activity');
      final oldReceipts = await rows(f.db, 'speed_completion_receipts');
      final next = await gateway.completeSpeedItem(
        expectedPrior: old.next,
        errors: 2,
        completedAt: instant.add(const Duration(days: 1)),
      );
      expect(await rows(f.db, 'statistics_activity'), hasLength(2));
      await gateway.reverseSpeedCompletion(expected: next);
      expect(await rows(f.db, 'statistics_activity'), oldCredits);
      expect(await rows(f.db, 'speed_completion_receipts'), oldReceipts);
      expect((await gateway.items()).single.speedCompleted, isTrue);
      expect((await gateway.items()).single.cardJson, prior.cardJson);
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
      await expectLater(
        gateway.reverseSpeedCompletion(expected: next),
        throwsA(SpeedCompletionFailure.staleState),
      );
    },
  );
  test(
    'forged and older receipts fail; transactional failure preserves exact rows for retry',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final gateway = await source(f),
          prior = (await (await source(f)).items()).single;
      final result = await gateway.completeSpeedItem(
        expectedPrior: prior,
        errors: 1,
        completedAt: instant,
      );
      final forged = SpeedCompletionResult(
        prior: result.prior,
        next: result.next,
        alreadyApplied: result.alreadyApplied,
      );
      await expectLater(
        gateway.reverseSpeedCompletion(expected: forged),
        throwsA(SpeedCompletionFailure.staleState),
      );
      final before = <String, Object>{};
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
        'statistics_activity',
        'speed_completion_receipts',
      ]) {
        before[table] = await rows(f.db, table);
      }
      await f.db.customStatement(
        "CREATE TRIGGER fail_speed_reverse BEFORE UPDATE OF speed_completed ON learning_items BEGIN SELECT RAISE(FAIL, 'blocked'); END",
      );
      await expectLater(
        gateway.reverseSpeedCompletion(expected: result),
        throwsA(anything),
      );
      for (final table in before.keys) {
        expect(await rows(f.db, table), before[table], reason: table);
      }
      await f.db.customStatement('DROP TRIGGER fail_speed_reverse');
      await gateway.reverseSpeedCompletion(expected: result);
      expect((await gateway.items()).single.speedCompleted, isFalse);
      expect(await rows(f.db, 'statistics_activity'), isEmpty);
      expect(await rows(f.db, 'speed_completion_receipts'), isEmpty);
    },
  );
  test(
    'another accepted completion or generation reset invalidates previous receipt',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final gateway = await source(f),
          prior = (await (await source(f)).items()).single;
      final first = await gateway.completeSpeedItem(
        expectedPrior: prior,
        errors: 0,
        completedAt: instant,
      );
      final second = await gateway.completeSpeedItem(
        expectedPrior: first.next,
        errors: 0,
        completedAt: instant.add(const Duration(seconds: 1)),
      );
      await expectLater(
        gateway.reverseSpeedCompletion(expected: first),
        throwsA(SpeedCompletionFailure.staleState),
      );
      await f.learning.resetLearning(
        entryId: prior.entryId,
        directions: {LearningDirection.targetToNative},
      );
      final after = await rows(f.db, 'statistics_activity');
      await expectLater(
        gateway.reverseSpeedCompletion(expected: second),
        throwsA(SpeedCompletionFailure.staleState),
      );
      expect(await rows(f.db, 'statistics_activity'), after);
    },
  );
}
