import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/speed_runtime.dart';
import '../data/regular_reviews_test.dart' show Fixture;

void main() {
  test(
    'filtered preparation is read-only; only individual completion persists',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final rows = await f.db.select(f.db.vocabularyEntries).get();
      final selected = {rows.first.id};
      final pending = <Future<void>>[];
      final runtime = PikoSpeedRuntime(
        learning: SqliteLearningRepository(f.db),
        clock: f.db.clock,
        onPendingWrites: pending.add,
      );
      final before = await f.db
          .customSelect('SELECT * FROM learning_items ORDER BY id')
          .get();
      final session = await runtime.prepare(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
        visibleEntryIds: selected,
        poolSize: 1,
      );
      selected.clear();
      expect(session.state!.entryIds, [rows.first.id]);
      expect(
        (await f.db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get())
            .map((r) => r.data),
        before.map((r) => r.data),
      );
      session.setPresentationActive(true);
      final handle = session.current!;
      expect(session.reveal(handle), isTrue);
      await session.submitAnswer(handle, SpeedAnswer.correct);
      expect(session.isComplete, isTrue);
      await session.stop();
      session.dispose();
      await Future.wait(pending);
      final after = await f.db.select(f.db.learningItems).get();
      expect(
        after.where((item) => item.speedCompleted).map((item) => item.entryId),
        [rows.first.id],
      );
      expect(
        after.where((item) => item.speedCompleted).single.direction,
        LearningDirection.targetToNative.name,
      );
      expect(await f.db.select(f.db.regularReviews).get(), isEmpty);
      await expectLater(
        runtime.prepare(
          collectionId: f.owner.id,
          direction: LearningDirection.targetToNative,
          visibleEntryIds: {rows.first.id},
          poolSize: 1,
        ),
        throwsA(SpeedLaunchFailure.noNewVocabulary),
      );
    },
  );

  test(
    'abandoned errored word writes nothing; a completed errored word resets only studied generation',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final rows = await f.db.select(f.db.vocabularyEntries).get();
      final runtime = PikoSpeedRuntime(
        learning: SqliteLearningRepository(f.db),
        clock: f.db.clock,
      );
      Future<dynamic> snapshot() async =>
          (await f.db
                  .customSelect('SELECT * FROM learning_items ORDER BY id')
                  .get())
              .map((r) => r.data)
              .toList();
      final before = await snapshot();
      var session = await runtime.prepare(
        collectionId: f.owner.id,
        direction: LearningDirection.nativeToTarget,
        visibleEntryIds: {rows.first.id},
        poolSize: 1,
      );
      session.setPresentationActive(true);
      var handle = session.current!;
      session.reveal(handle);
      await session.submitAnswer(handle, SpeedAnswer.incorrect);
      await session.stop();
      session.dispose();
      expect(await snapshot(), before);
      session = await runtime.prepare(
        collectionId: f.owner.id,
        direction: LearningDirection.nativeToTarget,
        visibleEntryIds: {rows.first.id},
        poolSize: 1,
      );
      session.setPresentationActive(true);
      for (final answer in [
        SpeedAnswer.incorrect,
        SpeedAnswer.correct,
        SpeedAnswer.correct,
      ]) {
        handle = session.current!;
        session.reveal(handle);
        await session.submitAnswer(handle, answer);
      }
      expect(session.isComplete, isTrue);
      final after = await f.db.select(f.db.learningItems).get();
      final completed = after.singleWhere((item) => item.speedCompleted);
      expect(completed.direction, LearningDirection.nativeToTarget.name);
      expect(completed.generation, 1);
      expect(completed.reviewRevision, 0);
      expect(await f.db.select(f.db.regularReviews).get(), isEmpty);
      await session.stop();
      session.dispose();
    },
  );
}
