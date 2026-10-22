import 'dart:io';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/speed_completion.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, rows, instant;

void main() {
  test(
    'durable trash survives restart, preserves exact payload/order and never revives expired retries',
    () async {
      final directory = Directory.systemTemp.createTempSync('piko-trash-');
      final file = File('${directory.path}/data.sqlite');
      final clock = MutablePikoClock(instant);
      var db = PikoDatabase(NativeDatabase(file), clock: clock);
      final f = Fixture(database: db);
      await f.initialize();
      await f.review(reverse: true, rating: LearningRating.again);
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: 'One',
        nativeText: 'Eins',
        assignments: {},
        content: const VocabularyContent(
          examples: [
            ExamplePair(targetText: 'One example', nativeText: 'Ein Beispiel'),
          ],
          hintText: 'hint',
        ),
        active: false,
      );
      final before = {
        for (final table in [
          'vocabulary_entries',
          'vocabulary_examples',
          'learning_items',
          'regular_reviews',
          'statistics_activity',
        ])
          table: await rows(db, table),
      };
      final deletion = SqliteVocabularyDeletionService(db);
      await deletion.delete(f.entry.id);
      deletion.dispose();
      await db.close();
      clock.set(instant.add(const Duration(hours: 20)));
      db = PikoDatabase(NativeDatabase(file), clock: clock);
      final reopened = SqliteVocabularyDeletionService(db);
      final groups = await reopened.trashGroups(collectionId: f.owner.id);
      expect(groups.single.entries.single.id, f.entry.id);
      expect(groups.single.entries.single.active, false);
      final result = await reopened.restoreTrashEntry(f.entry.id);
      expect(result.restoredIds, {f.entry.id});
      for (final table in before.keys) {
        expect(await rows(db, table), before[table], reason: table);
      }
      expect(await rows(db, 'retry_obligations'), isEmpty);
      expect(await reopened.trashGroups(collectionId: f.owner.id), isEmpty);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
      directory.deleteSync(recursive: true);
    },
  );

  test(
    'rolling groups, valid subset restore, category omissions and clear invalidate Undo',
    () async {
      final clock = MutablePikoClock(instant);
      final db = PikoDatabase(NativeDatabase.memory(), clock: clock);
      addTearDown(db.close);
      final f = Fixture(database: db);
      await f.initialize();
      final categories = SqliteCategoriesRepository(db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final a = await categories.createValue(
        dimensionId: dimension.id,
        name: 'a',
      );
      final b = await categories.createValue(
        dimensionId: dimension.id,
        name: 'b',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          dimension.id: {a.id, b.id},
        },
      );
      final second = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Two',
        nativeText: 'Zwei',
      );
      final service = SqliteVocabularyDeletionService(db);
      await service.delete(f.entry.id);
      clock.set(instant.add(const Duration(minutes: 2)));
      await service.delete(second.id);
      final group = (await service.trashGroups(
        collectionId: f.owner.id,
      )).single;
      expect(group.entries.length, 2);
      await categories.updateDimension(
        id: dimension.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Two',
        nativeText: 'Zwei',
      );
      final result = await service.restoreTrashGroup(group.id);
      expect(result.restoredIds, {f.entry.id});
      expect(result.omittedCategoryEntryIds, {f.entry.id});
      expect(result.conflicts, {
        second.id: VocabularyUndoFailure.duplicatePair,
      });
      expect(
        (await service.trashGroups(
          collectionId: f.owner.id,
        )).single.entries.single.id,
        second.id,
      );
      expect(await categories.assignments(f.entry.id), isEmpty);
      final receipt = await service.delete(f.entry.id);
      await service.clearTrash(f.owner.id);
      expect(service.canUndo(receipt), false);
      await expectLater(
        service.restoreTrashEntry(f.entry.id),
        throwsA(VocabularyUndoFailure.expired),
      );
    },
  );

  test(
    'deletion snapshot and restore failures roll back durable rows and live payload',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final service = SqliteVocabularyDeletionService(f.db);
      await f.db.customStatement(
        "CREATE TRIGGER fail_trash BEFORE INSERT ON vocabulary_trash BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      final before = await rows(f.db, 'vocabulary_entries');
      await expectLater(service.delete(f.entry.id), throwsA(anything));
      expect(await rows(f.db, 'vocabulary_entries'), before);
      expect(await rows(f.db, 'vocabulary_trash'), isEmpty);
      await f.db.customStatement('DROP TRIGGER fail_trash');
      await service.delete(f.entry.id);
      final retained = await rows(f.db, 'vocabulary_trash');
      await f.db.customStatement(
        "CREATE TRIGGER fail_restore BEFORE INSERT ON learning_items BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        service.restoreTrashEntry(f.entry.id),
        throwsA(anything),
      );
      expect(await rows(f.db, 'vocabulary_trash'), retained);
      expect(await f.vocabulary.watchById(f.entry.id).first, isNull);
    },
  );

  test(
    'per-entry 24h expiry and Collection cascade remove recovery without credit',
    () async {
      final clock = MutablePikoClock(instant);
      final f = Fixture(
        database: PikoDatabase(NativeDatabase.memory(), clock: clock),
      );
      await f.initialize();
      addTearDown(f.db.close);
      final service = SqliteVocabularyDeletionService(f.db);
      await service.delete(f.entry.id);
      clock.set(instant.add(const Duration(hours: 24)));
      await expectLater(
        service.restoreTrashEntry(f.entry.id),
        throwsA(VocabularyUndoFailure.expired),
      );
      expect(await rows(f.db, 'vocabulary_trash'), isEmpty);
      await service.delete(f.other.id);
      await f.collections.delete(f.kept.id);
      expect(await rows(f.db, 'vocabulary_trash'), isEmpty);
      expect(await rows(f.db, 'statistics_activity'), isEmpty);
    },
  );

  test(
    'reset both directions atomically preserves history/statistics and rejects stale submissions',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true);
      final prior = await f.current(), reverse = await f.current(null, true);
      final history = await rows(f.db, 'regular_reviews'),
          stats = await rows(f.db, 'statistics_activity');
      final unrelated = await f.current(f.other);
      await f.learning.resetLearning(
        entryId: f.entry.id,
        directions: {LearningDirection.targetToNative},
      );
      final next = await f.current();
      expect(next.id, prior.id);
      expect(next.generation, prior.generation + 1);
      expect(next.reviewRevision, prior.reviewRevision + 1);
      expect(next.card.lastReview, isNull);
      expect(next.speedCompleted, false);
      expect((await f.current(null, true)).cardJson, reverse.cardJson);
      expect((await f.current(f.other)).cardJson, unrelated.cardJson);
      expect(await rows(f.db, 'regular_reviews'), history);
      expect(await rows(f.db, 'statistics_activity'), stats);
      expect(await rows(f.db, 'retry_obligations'), isEmpty);
      await expectLater(
        f.learning.review(
          kind: ReviewKind.regular,
          expectedPrior: prior,
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(RegularReviewFailure.staleState),
      );
      final scope = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      await expectLater(
        scope.completeSpeedItem(
          expectedPrior: prior,
          errors: 0,
          completedAt: instant,
        ),
        throwsA(SpeedCompletionFailure.staleState),
      );
      final before = await rows(f.db, 'learning_items');
      await f.db.customStatement(
        "CREATE TRIGGER fail_reset BEFORE UPDATE ON learning_items WHEN OLD.direction='nativeToTarget' BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        f.learning.resetLearning(
          entryId: f.entry.id,
          directions: LearningDirection.values.toSet(),
        ),
        throwsA(anything),
      );
      expect(await rows(f.db, 'learning_items'), before);
      await f.db.customStatement('DROP TRIGGER fail_reset');
      await f.learning.resetLearning(
        entryId: f.entry.id,
        directions: LearningDirection.values.toSet(),
      );
      expect((await f.current()).generation, next.generation + 1);
      expect((await f.current(null, true)).generation, reverse.generation + 1);
    },
  );

  test('group recovery rolls back all eligible restores on an unexpected storage error', () async {
    final f = Fixture(); await f.initialize(); addTearDown(f.db.close);
    final second = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'Second', nativeText: 'Zweite');
    final deletion = SqliteVocabularyDeletionService(f.db);
    await deletion.deleteMany(collectionId: f.owner.id, ids: {f.entry.id, second.id});
    final before = await rows(f.db, 'vocabulary_trash');
    final group = (await deletion.trashGroups(collectionId: f.owner.id)).single;
    await f.db.customStatement("CREATE TRIGGER reject_second BEFORE INSERT ON learning_items WHEN NEW.entry_id='${second.id}' BEGIN SELECT RAISE(ABORT,'test'); END");
    await expectLater(deletion.restoreTrashGroup(group.id), throwsA(anything));
    expect(await rows(f.db, 'vocabulary_trash'), before);
    expect(await f.vocabulary.watchById(f.entry.id).first, isNull);
    expect(await f.vocabulary.watchById(second.id).first, isNull);
  });

  test(
    'v22 upgrade, level and group order survive reopen, JSON preserves destination level',
    () async {
      final dir = Directory.systemTemp.createTempSync('piko-level-');
      final dbFile = File('${dir.path}/data.sqlite');
      var db = PikoDatabase(NativeDatabase(dbFile));
      final f = Fixture(database: db);
      await f.initialize();
      final before = await rows(db, 'learning_items');
      await db.close();
      final raw = sqlite.sqlite3.open(dbFile.path);
      raw.execute('ALTER TABLE collections DROP COLUMN level');
      raw.execute('DROP TABLE vocabulary_trash');
      raw.execute('PRAGMA user_version=22');
      raw.close();
      db = PikoDatabase(NativeDatabase(dbFile));
      final repository = SqliteCollectionsRepository(db),
          categories = SqliteCategoriesRepository(db);
      expect((await repository.watchById(f.owner.id).first)!.level, 'A1');
      expect(await rows(db, 'learning_items'), before);
      await repository.setLevel(id: f.owner.id, level: 'C1');
      final first = await categories.createDimension(
            collectionId: f.owner.id,
            name: 'First',
            mode: CategoryMode.single,
          ),
          second = await categories.createDimension(
            collectionId: f.owner.id,
            name: 'Second',
            mode: CategoryMode.single,
          );
      await categories.reorderDimensions(
        collectionId: f.owner.id,
        orderedIds: [second.id, first.id],
      );
      final json = await SqliteVocabularyJsonService(
        db,
      ).exportCollection(f.owner.id);
      expect(
        ((jsonDecode(json) as Map)['collections'] as List).single['level'],
        'C1',
      );
      await db.close();
      db = PikoDatabase(NativeDatabase(dbFile));
      expect(
        (await SqliteCollectionsRepository(
          db,
        ).watchById(f.owner.id).first)!.level,
        'C1',
      );
      expect(
        (await SqliteCategoriesRepository(
          db,
        ).dimensions(f.owner.id)).map((g) => g.id),
        [second.id, first.id],
      );
      final document = jsonDecode(json) as Map<String, dynamic>;
      document['collections'][0]['level'] = 'A2';
      final transfer = SqliteVocabularyJsonService(db);
      final preview = await transfer.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(document),
      );
      await transfer.applyImport(preview);
      expect(
        (await SqliteCollectionsRepository(
          db,
        ).watchById(f.owner.id).first)!.level,
        'C1',
      );
      expect(
        (await SqliteCollectionQueryService(
          db,
        ).query(collectionId: f.owner.id, at: instant)).collection.level,
        'C1',
      );
      await db.close();
      dir.deleteSync(recursive: true);
    },
  );
}
