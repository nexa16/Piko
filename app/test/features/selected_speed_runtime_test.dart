import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/speed_runtime.dart';
import '../data/regular_reviews_test.dart' show Fixture, rows;
import '../support/mutable_clock.dart';

void main() {
  test(
    'explicit order ignores newness, excludes inactive and deduplicates; empty/foreign never fall back',
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
      await f.review();
      await f.db.customStatement(
        'UPDATE learning_items SET speed_completed=1 WHERE entry_id=?',
        [b.id],
      );
      await f.db.customStatement(
        'UPDATE vocabulary_entries SET active=0 WHERE id=?',
        [c.id],
      );
      final runtime = PikoSpeedRuntime(learning: f.learning, clock: f.db.clock);
      final prior = await rows(f.db, 'learning_items');
      for (final direction in LearningDirection.values) {
        final ids = [b.id, f.entry.id, c.id, b.id];
        final work = runtime.prepareSelected(
          collectionId: f.owner.id,
          direction: direction,
          orderedEntryIds: ids,
          poolSize: 1,
        );
        ids.clear();
        final session = await work;
        expect(session.state!.entryIds, [b.id, f.entry.id]);
        await session.stop();
        session.dispose();
      }
      expect(await rows(f.db, 'learning_items'), prior);
      for (final ids in [
        <String>[],
        [c.id],
      ]) {
        await expectLater(
          runtime.prepareSelected(
            collectionId: f.owner.id,
            direction: LearningDirection.targetToNative,
            orderedEntryIds: ids,
            poolSize: 1,
          ),
          throwsA(SpeedLaunchFailure.noSelectedVocabulary),
        );
      }
      await expectLater(
        runtime.prepareSelected(
          collectionId: f.owner.id,
          direction: LearningDirection.targetToNative,
          orderedEntryIds: [f.other.id],
          poolSize: 1,
        ),
        throwsA(RegularReviewFailure.outOfScope),
      );
      await expectLater(
        runtime.prepare(
          collectionId: f.owner.id,
          direction: LearningDirection.targetToNative,
          visibleEntryIds: {f.entry.id, b.id, c.id},
          poolSize: 1,
        ),
        throwsA(SpeedLaunchFailure.noNewVocabulary),
      );
    },
  );

  test(
    'reviewed selected completion preserves both directions and retries, credits one/day/direction including retained marker',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true, rating: LearningRating.again);
      final runtime = PikoSpeedRuntime(learning: f.learning, clock: f.db.clock);
      final tables = [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ];
      Future<Map<String, Object>> snapshot() async => {
        for (final table in tables)
          table: [
            for (final row in await rows(f.db, table))
              {...row}..remove('speed_completed'),
          ],
      };
      final prior = await snapshot();
      for (var day = 0; day < 2; day++) {
        for (final direction in LearningDirection.values) {
          for (var round = 0; round < 2; round++) {
            final clock = f.db.clock as MutablePikoClock;
            clock.advance(const Duration(seconds: 1));
            final session = await runtime.prepareSelected(
              collectionId: f.owner.id,
              direction: direction,
              orderedEntryIds: [f.entry.id],
              poolSize: 1,
            );
            session.setPresentationActive(true);
            for (final answer
                in round == 0
                    ? [SpeedAnswer.correct]
                    : [
                        SpeedAnswer.incorrect,
                        SpeedAnswer.correct,
                        SpeedAnswer.correct,
                      ]) {
              final handle = session.current!;
              session.reveal(handle);
              await session.submitAnswer(handle, answer);
            }
            expect(session.isComplete, isTrue);
            await session.stop();
            session.dispose();
            expect(await snapshot(), prior);
          }
        }
        final clock = f.db.clock as MutablePikoClock;
        clock.advance(const Duration(days: 1));
      }
      final credits = await rows(f.db, 'statistics_activity');
      expect(credits.where((r) => r['mode'] == 'speed').length, 4);
      expect(credits.where((r) => r['mode'] == 'regular').length, 2);
    },
  );
}
