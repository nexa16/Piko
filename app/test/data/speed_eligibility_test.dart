import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/review_correction.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'retry_gap_migration_test.dart' show storedSnapshot, storedRows;

Future<Map<String, Object?>> completeSnapshot(PikoDatabase db) async => {
  ...await storedSnapshot(db),
  for (final table in [
    'category_dimensions',
    'category_values',
    'vocabulary_category_assignments',
  ])
    table: await storedRows(db, table),
};

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  Future<void> marker(Fixture f, LearningItemRecord item, bool value) async {
    await (f.db.update(f.db.learningItems)
          ..where((row) => row.id.equals(item.id)))
        .write(LearningItemsCompanion(speedCompleted: Value(value)));
  }

  Future<List<String>> eligible(
    Fixture f, {
    bool reverse = false,
    Set<String>? entryIds,
  }) async => (await f.learning.newSpeedItems(
    collectionId: f.owner.id,
    direction: reverse
        ? LearningDirection.nativeToTarget
        : LearningDirection.targetToNative,
    entryIds: entryIds,
  )).map((item) => item.entryId).toList();

  test(
    'new items default false independently; visible eligibility retains Collection display order and does not write',
    () async {
      final f = await fixture();
      final next = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Three',
        nativeText: 'Drei',
      );
      final last = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Four',
        nativeText: 'Vier',
      );
      expect(
        (await f.learning.forEntry(
          f.entry.id,
        )).every((item) => !item.speedCompleted),
        isTrue,
      );
      final before = await completeSnapshot(f.db);
      expect(await eligible(f), [f.entry.id, next.id, last.id]);
      expect(await eligible(f, reverse: true), [f.entry.id, next.id, last.id]);
      expect(
        await eligible(f, entryIds: {last.id, f.other.id, next.id, 'missing'}),
        [next.id, last.id],
      );
      expect(await eligible(f, entryIds: {}), isEmpty);
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.nativeToTarget,
      );
      expect(
        (await source.newSpeedItems(entryIds: {last.id})).single.entryId,
        last.id,
      );
      await expectLater(
        f.learning.newSpeedItems(
          collectionId: 'missing',
          direction: LearningDirection.targetToNative,
        ),
        throwsA(RegularReviewFailure.collectionNotFound),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'only current-generation ordinary history and the studied direction marker exclude new Speed items',
    () async {
      final f = await fixture();
      await f.review(rating: LearningRating.good);
      expect(await eligible(f), isEmpty);
      expect(await eligible(f, reverse: true), [f.entry.id]);
      final forward = await f.current();
      // A valid new generation can retain older regular history. Eligibility is
      // not inferred from the old card's lastReview, state or due timestamp.
      await (f.db.update(
        f.db.learningItems,
      )..where((row) => row.id.equals(forward.id))).write(
        LearningItemsCompanion(generation: Value(forward.generation + 1)),
      );
      expect(await eligible(f), [f.entry.id]);
      expect((await f.current()).card.lastReview, isNotNull);
      await marker(f, await f.current(), true);
      expect(await eligible(f), isEmpty);
      expect(await eligible(f, reverse: true), [f.entry.id]);
      expect((await f.current(f.entry, true)).speedCompleted, isFalse);
      final reverse = await f.current(f.entry, true);
      expect(reverse.card.lastReview, isNull);
      await marker(f, reverse, true);
      expect(await eligible(f, reverse: true), isEmpty);
      // A marker excludes even when FSRS remains its unchanged initial card.
      expect((await f.current(f.entry, true)).cardJson, reverse.cardJson);
    },
  );

  test(
    'normal review, scheduler transitions and previous-grade correction preserve the marker and guard stale marker snapshots',
    () async {
      final f = await fixture();
      final original = await f.current();
      await marker(f, original, true);
      final beforeReview = await completeSnapshot(f.db);
      await expectLater(
        f.learning.review(
          kind: ReviewKind.regular,
          expectedPrior: original,
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(RegularReviewFailure.staleState),
      );
      expect(await completeSnapshot(f.db), beforeReview);
      final marked = await f.current();
      expect(
        LearningScheduler()
            .review(marked, rating: LearningRating.again, reviewedAt: instant)
            .next
            .speedCompleted,
        isTrue,
      );
      final receipt = await f.review(rating: LearningRating.again);
      expect(receipt.prior.speedCompleted, isTrue);
      expect(receipt.next.speedCompleted, isTrue);
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final corrected = await source.replaceAnswer(
        expected: receipt,
        expectedWaits: [],
        rating: LearningRating.good,
        executionAt: instant.add(const Duration(seconds: 1)),
      );
      expect(corrected.prior.speedCompleted, isTrue);
      expect(corrected.next.speedCompleted, isTrue);
      expect((await f.current()).speedCompleted, isTrue);
      expect((await f.current(f.entry, true)).speedCompleted, isFalse);
      await marker(f, await f.current(), false);
      final beforeStaleCorrection = await completeSnapshot(f.db);
      await expectLater(
        source.replaceAnswer(
          expected: corrected,
          expectedWaits: [],
          rating: LearningRating.hard,
          executionAt: instant.add(const Duration(seconds: 2)),
        ),
        throwsA(ReviewCorrectionFailure.staleState),
      );
      expect(await completeSnapshot(f.db), beforeStaleCorrection);
    },
  );

  test(
    'vocabulary Undo preserves true and false directional markers with every learning record',
    () async {
      final f = await fixture();
      await marker(f, await f.current(), true);
      await f.review(rating: LearningRating.again);
      final before = await completeSnapshot(f.db);
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      await deletion.restore(receipt);
      expect(await completeSnapshot(f.db), before);
      expect((await f.current()).speedCompleted, isTrue);
      expect((await f.current(f.entry, true)).speedCompleted, isFalse);
    },
  );

  test(
    'v11 migration defaults false and preserves all old payloads; markers persist independently after reopen',
    () async {
      final f = Fixture();
      var baselineClosed = false;
      final directory = await Directory.systemTemp.createTemp(
        'piko-speed-v11-',
      );
      final file = File('${directory.path}/migration.sqlite');
      PikoDatabase? db;
      try {
        await f.initialize();
        await f.review(rating: LearningRating.again);
        await f.review(reverse: true, rating: LearningRating.again);
        await SqliteSettingsRepository(f.db).write('locale', 'de');
        final categories = SqliteCategoriesRepository(f.db);
        final dimension = await categories.createDimension(
          collectionId: f.owner.id,
          name: 'Topic',
          mode: CategoryMode.single,
        );
        final value = await categories.createValue(
          dimensionId: dimension.id,
          name: 'Food',
        );
        await categories.replaceAssignments(
          entryId: f.entry.id,
          assignments: {
            dimension.id: {value.id},
          },
        );
        final before = await completeSnapshot(f.db);
        final old = sqlite.sqlite3.open(file.path);
        try {
          final schema =
              jsonDecode(
                    await File(
                      'drift_schemas/drift_schema_v11.json',
                    ).readAsString(),
                  )
                  as Map<String, dynamic>;
          for (final group in schema['fixed_sql'] as List) {
            old.execute((group['sql'] as List).single['sql'] as String);
          }
          for (final table in before.entries) {
            for (final stored in table.value! as List) {
              final row = Map<String, Object?>.of(
                stored as Map<String, Object?>,
              );
              if (table.key == 'learning_items') row.remove('speed_completed');
              final columns = row.keys
                  .map((key) => key == 'stored_rowid' ? 'rowid' : key)
                  .join(',');
              old.execute(
                'INSERT INTO ${table.key} ($columns) VALUES (${List.filled(row.length, '?').join(',')})',
                row.values.toList(),
              );
            }
          }
          old.execute('PRAGMA user_version = 11');
        } finally {
          old.close();
        }
        await f.db.close();
        baselineClosed = true;
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        expect(await completeSnapshot(db), before);
        final migrated = SqliteLearningRepository(db);
        final items = await migrated.forEntry(f.entry.id);
        expect(items.every((item) => !item.speedCompleted), isTrue);
        final first = items.first;
        await (db.update(db.learningItems)
              ..where((row) => row.id.equals(first.id)))
            .write(const LearningItemsCompanion(speedCompleted: Value(true)));
        final marked = await completeSnapshot(db);
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        final retained = await SqliteLearningRepository(
          db,
        ).forEntry(f.entry.id);
        expect(retained.first.speedCompleted, isTrue);
        expect(retained.last.speedCompleted, isFalse);
        expect(await completeSnapshot(db), marked);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        if (!baselineClosed) await f.db.close();
        await db?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
