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
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, rows, instant;

void main() {
  test(
    'rolling groups compare UTC instants across millisecond and microsecond precision',
    () async {
      final firstAt = DateTime.utc(2026, 10, 14, 9, 0, 0, 123);
      final clock = MutablePikoClock(firstAt);
      final f = Fixture(
        database: PikoDatabase(NativeDatabase.memory(), clock: clock),
      );
      await f.initialize();
      addTearDown(f.db.close);
      final words = [f.entry];
      for (var i = 1; i < 4; i++) {
        words.add(
          await f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'word$i',
            nativeText: 'Wort$i',
          ),
        );
      }
      final deletion = SqliteVocabularyDeletionService(f.db);
      await deletion.delete(words[0].id);
      clock.advance(const Duration(microseconds: 456));
      await deletion.delete(words[1].id);
      clock.advance(const Duration(minutes: 2));
      await deletion.delete(words[2].id);
      var groups = await deletion.trashGroups(collectionId: f.owner.id);
      expect(groups, hasLength(1));
      expect(
        groups.single.entries.map((e) => e.id),
        words.take(3).toList().reversed.map((e) => e.id),
      );
      expect(groups.single.deletedAt, clock.now());
      clock.advance(const Duration(minutes: 2, microseconds: 1));
      await deletion.delete(words[3].id);
      groups = await deletion.trashGroups(collectionId: f.owner.id);
      expect(groups, hasLength(2));
      expect(groups.first.entries.single.id, words[3].id);
      expect(
        groups.last.entries.map((e) => e.id),
        words.take(3).toList().reversed.map((e) => e.id),
      );
    },
  );

  for (final crossService in [false, true]) {
    test(
      'old Undo cannot consume a new deletion after trash recovery (cross-service=$crossService)',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        await f.review(rating: LearningRating.again);
        final original = SqliteVocabularyDeletionService(f.db);
        final recovery = crossService
            ? SqliteVocabularyDeletionService(f.db)
            : original;
        final firstReceipt = await original.delete(f.entry.id);
        await recovery.restoreTrashEntry(f.entry.id);
        expect(
          original.canUndo(firstReceipt),
          crossService,
          reason:
              'Same-service recovery retires its handle; another service has no synchronous database notification.',
        );
        await f.vocabulary.updateWithContent(
          id: f.entry.id,
          targetText: 'Updated',
          nativeText: 'Aktualisiert',
          assignments: {},
          content: const VocabularyContent(hintText: 'new content'),
        );
        await f.learning.resetLearning(
          entryId: f.entry.id,
          directions: LearningDirection.values.toSet(),
        );
        await f.review();
        final before = {
          for (final table in [
            'vocabulary_entries',
            'learning_items',
            'regular_reviews',
            'retry_obligations',
            'statistics_activity',
          ])
            table: await rows(f.db, table),
        };
        final secondReceipt = await recovery.delete(f.entry.id);
        // Both operations use the same fixed clock. Date/entry/group equality
        // cannot stand in for the identity of one particular deletion.
        expect(firstReceipt.expiresAt, secondReceipt.expiresAt);
        final retained = await rows(f.db, 'vocabulary_trash');
        await expectLater(
          () => original.restore(firstReceipt),
          throwsA(VocabularyUndoFailure.expired),
        );
        expect(original.canUndo(firstReceipt), false);
        expect(await rows(f.db, 'vocabulary_trash'), retained);
        expect(await f.vocabulary.watchById(f.entry.id).first, isNull);
        await recovery.restore(secondReceipt);
        for (final table in before.keys) {
          expect(await rows(f.db, table), before[table], reason: table);
        }
      },
    );
  }

  test('legacy version1 durable snapshots remain recoverable', () async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    final service = SqliteVocabularyDeletionService(f.db);
    await service.delete(f.entry.id);
    final row = (await rows(f.db, 'vocabulary_trash')).single;
    final snapshot =
        jsonDecode(row['snapshot_json'] as String) as Map<String, dynamic>;
    snapshot['version'] = 1;
    snapshot.remove('deletionIdentity');
    await f.db.customStatement(
      'UPDATE vocabulary_trash SET snapshot_json = ? WHERE entry_id = ?',
      [jsonEncode(snapshot), f.entry.id],
    );
    final result = await service.restoreTrashEntry(f.entry.id);
    expect(result.restoredIds, {f.entry.id});
    expect(
      (await f.vocabulary.watchById(f.entry.id).first)!.targetText,
      f.entry.targetText,
    );
  });

  for (final restoreHours in [1, 20]) {
    test(
      'durable trash after ${restoreHours}h restart preserves payload/order and only live retries',
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
              ExamplePair(
                targetText: 'One example',
                nativeText: 'Ein Beispiel',
              ),
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
        final retriesBefore = await rows(db, 'retry_obligations');
        await deletion.delete(f.entry.id);
        deletion.dispose();
        await db.close();
        clock.set(instant.add(Duration(hours: restoreHours)));
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
        expect(
          await rows(db, 'retry_obligations'),
          restoreHours == 1 ? retriesBefore : isEmpty,
        );
        expect(await reopened.trashGroups(collectionId: f.owner.id), isEmpty);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await db.close();
        directory.deleteSync(recursive: true);
      },
    );
  }

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
      final speedScope = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      await speedScope.completeSpeedItem(
        expectedPrior: await f.current(),
        errors: 0,
        completedAt: instant,
      );
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
      expect(prior.speedCompleted, true);
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

  test(
    'group recovery rolls back all eligible restores on an unexpected storage error',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final second = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Second',
        nativeText: 'Zweite',
      );
      final deletion = SqliteVocabularyDeletionService(f.db);
      final receipts = await deletion.deleteMany(
        collectionId: f.owner.id,
        ids: {f.entry.id, second.id},
      );
      final before = await rows(f.db, 'vocabulary_trash');
      final group = (await deletion.trashGroups(
        collectionId: f.owner.id,
      )).single;
      await f.db.customStatement(
        "CREATE TRIGGER reject_second BEFORE INSERT ON learning_items WHEN NEW.entry_id='${second.id}' BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        deletion.restoreTrashGroup(group.id),
        throwsA(anything),
      );
      expect(await rows(f.db, 'vocabulary_trash'), before);
      expect(await f.vocabulary.watchById(f.entry.id).first, isNull);
      expect(await f.vocabulary.watchById(second.id).first, isNull);
      expect(receipts.every(deletion.canUndo), true);
    },
  );

  test(
    'Clear trash retires Undo only after commit and preserves handles on failure',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final service = SqliteVocabularyDeletionService(f.db);
      final receipt = await service.delete(f.entry.id);
      await f.db.customStatement(
        "CREATE TRIGGER reject_clear BEFORE DELETE ON vocabulary_trash BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(service.clearTrash(f.owner.id), throwsA(anything));
      expect(service.canUndo(receipt), true);
      await f.db.customStatement('DROP TRIGGER reject_clear');
      await service.clearTrash(f.owner.id);
      expect(service.canUndo(receipt), false);
      await expectLater(
        () => service.restore(receipt),
        throwsA(VocabularyUndoFailure.expired),
      );
    },
  );

  test(
    'Undo omits assignments made invalid meanwhile while preserving exact learning',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review();
      final categories = SqliteCategoriesRepository(f.db);
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
      final learning = await rows(f.db, 'learning_items');
      final history = await rows(f.db, 'regular_reviews');
      final service = SqliteVocabularyDeletionService(f.db);
      final receipt = await service.delete(f.entry.id);
      await categories.updateDimension(
        id: dimension.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      await service.restore(receipt);
      expect((receipt as VocabularyRecoveryWarnings).omittedCategories, true);
      expect(await categories.assignments(f.entry.id), isEmpty);
      expect(await rows(f.db, 'learning_items'), learning);
      expect(await rows(f.db, 'regular_reviews'), history);
    },
  );

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
      final resetter = SqliteLearningRepository(db);
      await resetter.resetLearning(
        entryId: f.entry.id,
        directions: LearningDirection.values.toSet(),
      );
      final resetState = await rows(db, 'learning_items');
      final history = await rows(db, 'regular_reviews');
      await db.close();
      db = PikoDatabase(NativeDatabase(dbFile));
      expect(await rows(db, 'learning_items'), resetState);
      expect(await rows(db, 'regular_reviews'), history);
      await db.close();
      dir.deleteSync(recursive: true);
    },
  );

  test(
    'level creation and category order failures commit no partial metadata',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final created = await f.collections.createWithLevel(
        name: 'Level',
        targetLanguage: f.owner.targetLanguage,
        nativeLanguage: f.owner.nativeLanguage,
        level: 'B2',
      );
      expect(created.level, 'B2');
      final count = (await rows(f.db, 'collections')).length;
      await f.db.customStatement(
        "CREATE TRIGGER reject_level BEFORE UPDATE OF level ON collections BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        f.collections.createWithLevel(
          name: 'Failed',
          targetLanguage: f.owner.targetLanguage,
          nativeLanguage: f.owner.nativeLanguage,
          level: 'C2',
        ),
        throwsA(anything),
      );
      expect((await rows(f.db, 'collections')).length, count);
      final categories = SqliteCategoriesRepository(f.db);
      final first = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'First',
        mode: CategoryMode.single,
      );
      final second = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Second',
        mode: CategoryMode.multiple,
      );
      final original = [first.id, second.id], ordered = [second.id, first.id];
      final before = await rows(f.db, 'category_dimensions');
      await expectLater(
        categories.reorderDimensions(
          collectionId: f.owner.id,
          orderedIds: ordered,
          expectedOrder: ordered,
        ),
        throwsA(CategoryValidation.staleOrder),
      );
      await expectLater(
        categories.reorderDimensions(
          collectionId: f.owner.id,
          orderedIds: [first.id, 'foreign'],
        ),
        throwsA(CategoryValidation.invalidOwnership),
      );
      await f.db.customStatement(
        "CREATE TRIGGER reject_group_order BEFORE UPDATE OF position ON category_dimensions WHEN OLD.id='${first.id}' BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        categories.reorderDimensions(
          collectionId: f.owner.id,
          orderedIds: ordered,
          expectedOrder: original,
        ),
        throwsA(anything),
      );
      expect(await rows(f.db, 'category_dimensions'), before);
    },
  );
}
