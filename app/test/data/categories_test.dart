import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/categories_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'retry_gap_migration_test.dart' show storedSnapshot, storedRows;

void main() {
  late Fixture f;
  late SqliteCategoriesRepository categories;
  var fixtureClosed = false;
  setUp(() async {
    fixtureClosed = false;
    f = Fixture();
    await f.initialize();
    categories = SqliteCategoriesRepository(f.db);
  });
  tearDown(() async {
    if (!fixtureClosed) await f.db.close();
  });

  Future<CategoryDimensionRecord> dimension(String name, {String? owner}) =>
      categories.createDimension(
        collectionId: owner ?? f.owner.id,
        name: name,
        mode: CategoryMode.multiple,
      );

  test(
    'UUID CRUD trims names, scopes duplicate checks and preserves creation order',
    () async {
      final topic = await dimension('  Topic  ');
      final unit = await dimension('Unit');
      expect(topic.name, 'Topic');
      expect(topic.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f-]{27}$')));
      await dimension('Topic', owner: f.kept.id);
      await expectLater(
        dimension(' tOPIC '),
        throwsA(CategoryValidation.duplicateName),
      );
      await expectLater(
        dimension(' \n '),
        throwsA(CategoryValidation.requiredName),
      );
      await expectLater(
        categories.renameDimension(id: unit.id, name: 'TOPIC'),
        throwsA(CategoryValidation.duplicateName),
      );
      final renamed = await categories.renameDimension(
        id: topic.id,
        name: ' Subject ',
      );
      expect(renamed.id, topic.id);
      expect(renamed.position, topic.position);
      expect(renamed.name, 'Subject');
      final food = await categories.createValue(
        dimensionId: topic.id,
        name: ' Food ',
      );
      final travel = await categories.createValue(
        dimensionId: topic.id,
        name: 'Travel',
      );
      await categories.createValue(dimensionId: unit.id, name: 'Food');
      await expectLater(
        categories.createValue(dimensionId: topic.id, name: 'fOOD'),
        throwsA(CategoryValidation.duplicateName),
      );
      await expectLater(
        categories.createValue(dimensionId: topic.id, name: ' \n '),
        throwsA(CategoryValidation.requiredName),
      );
      await expectLater(
        categories.renameValue(id: food.id, name: ' \t '),
        throwsA(CategoryValidation.requiredName),
      );
      await expectLater(
        categories.renameDimension(id: topic.id, name: ' '),
        throwsA(CategoryValidation.requiredName),
      );
      await expectLater(
        categories.renameValue(id: travel.id, name: 'FOOD'),
        throwsA(CategoryValidation.duplicateName),
      );
      expect(
        (await categories.renameValue(id: food.id, name: ' Meals ')).name,
        'Meals',
      );
      expect((await categories.values(topic.id)).map((v) => v.id), [
        food.id,
        travel.id,
      ]);
      expect((await categories.dimensions(f.owner.id)).map((d) => d.id), [
        topic.id,
        unit.id,
      ]);
      await categories.deleteValue(food.id);
      expect(await categories.valueById(food.id), isNull);
      expect((await categories.values(topic.id)).single.id, travel.id);
      await categories.deleteDimension(topic.id);
      expect(await categories.values(topic.id), isEmpty);
      expect((await categories.dimensions(f.owner.id)).single.id, unit.id);
    },
  );

  test(
    'explicit UUIDs resolve stably; missing and reused identities fail without writes',
    () async {
      const id = '329e31b7-bdfd-4248-92d9-12831f346c63';
      final topic = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.single,
        id: id,
      );
      expect((await categories.dimensionById(id))!.id, topic.id);
      await expectLater(
        categories.createDimension(
          collectionId: f.kept.id,
          name: 'Other',
          mode: CategoryMode.single,
          id: id,
        ),
        throwsA(CategoryValidation.identityConflict),
      );
      await expectLater(
        categories.createValue(dimensionId: topic.id, name: 'Same id', id: id),
        throwsA(CategoryValidation.identityConflict),
      );
      await expectLater(
        categories.createDimension(
          collectionId: 'missing',
          name: 'Topic',
          mode: CategoryMode.single,
        ),
        throwsA(CategoryValidation.collectionNotFound),
      );
      await expectLater(
        categories.createValue(dimensionId: 'missing', name: 'Food'),
        throwsA(CategoryValidation.dimensionNotFound),
      );
      await expectLater(
        categories.createValue(
          dimensionId: topic.id,
          name: 'Food',
          id: 'not-uuid',
        ),
        throwsA(CategoryValidation.invalidId),
      );
      await expectLater(
        categories.renameDimension(id: 'missing', name: 'New'),
        throwsA(CategoryValidation.dimensionNotFound),
      );
      await expectLater(
        categories.deleteValue('missing'),
        throwsA(CategoryValidation.valueNotFound),
      );
      expect(await categories.values(topic.id), isEmpty);
    },
  );

  test(
    'assignment replacement validates all owners before writing and supports several dimensions',
    () async {
      final topic = await dimension('Topic'), unit = await dimension('Unit');
      final foreign = await dimension('Topic', owner: f.kept.id);
      final food = await categories.createValue(
        dimensionId: topic.id,
        name: 'Food',
      );
      final travel = await categories.createValue(
        dimensionId: topic.id,
        name: 'Travel',
      );
      final one = await categories.createValue(
        dimensionId: unit.id,
        name: 'One',
      );
      final foreignValue = await categories.createValue(
        dimensionId: foreign.id,
        name: 'Food',
      );
      final learningBefore = await storedSnapshot(f.db);
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          topic.id: {travel.id, food.id},
          unit.id: {one.id},
        },
      );
      final actual = await categories.assignments(f.entry.id);
      expect(actual.map((a) => a.dimensionId), [topic.id, unit.id]);
      expect(actual.first.valueIds.toList(), [food.id, travel.id]);
      final before = await storedRows(f.db, 'vocabulary_category_assignments');
      for (final (invalid, failure) in [
        (
          {
            topic.id: {food.id},
            foreign.id: {foreignValue.id},
          },
          CategoryValidation.invalidOwnership,
        ),
        (
          {
            topic.id: {one.id},
          },
          CategoryValidation.invalidOwnership,
        ),
        (
          {
            topic.id: {'missing'},
          },
          CategoryValidation.valueNotFound,
        ),
        ({'missing': <String>{}}, CategoryValidation.dimensionNotFound),
      ]) {
        await expectLater(
          categories.replaceAssignments(
            entryId: f.entry.id,
            assignments: invalid,
          ),
          throwsA(failure),
        );
        expect(
          await storedRows(f.db, 'vocabulary_category_assignments'),
          before,
        );
      }
      await expectLater(
        f.db.customInsert(
          'INSERT INTO vocabulary_category_assignments(entry_id,collection_id,dimension_id,value_id) VALUES (?,?,?,?)',
          variables: [
            Variable(f.entry.id),
            Variable(f.owner.id),
            Variable(foreign.id),
            Variable(foreignValue.id),
          ],
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await storedSnapshot(f.db), learningBefore);
      await categories.replaceAssignments(entryId: f.entry.id, assignments: {});
      expect(await categories.assignments(f.entry.id), isEmpty);
    },
  );

  test(
    'definition deletion removes only its assignments and leaves complete learning and unrelated owners exact',
    () async {
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true, rating: LearningRating.again);
      await SqliteSettingsRepository(f.db).write('locale', 'de');
      final topic = await dimension('Topic');
      final kept = await dimension('Topic', owner: f.kept.id);
      final food = await categories.createValue(
        dimensionId: topic.id,
        name: 'Food',
      );
      final travel = await categories.createValue(
        dimensionId: topic.id,
        name: 'Travel',
      );
      final other = await categories.createValue(
        dimensionId: kept.id,
        name: 'Other',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          topic.id: {food.id, travel.id},
        },
      );
      await categories.replaceAssignments(
        entryId: f.other.id,
        assignments: {
          kept.id: {other.id},
        },
      );
      final before = await storedSnapshot(f.db);
      await categories.deleteValue(food.id);
      expect((await categories.assignments(f.entry.id)).single.valueIds, {
        travel.id,
      });
      await categories.deleteDimension(topic.id);
      expect(await categories.assignments(f.entry.id), isEmpty);
      expect((await categories.assignments(f.other.id)).single.valueIds, {
        other.id,
      });
      expect(await storedSnapshot(f.db), before);
      await f.collections.delete(f.kept.id);
      expect(await categories.dimensions(f.kept.id), isEmpty);
      expect(await categories.values(kept.id), isEmpty);
      expect(await categories.assignments(f.other.id), isEmpty);
      expect(
        await f.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'vocabulary Undo restores assignments and full learning without reviving deleted category definitions',
    () async {
      await f.review(rating: LearningRating.again);
      final topic = await dimension('Topic');
      final food = await categories.createValue(
        dimensionId: topic.id,
        name: 'Food',
      );
      final travel = await categories.createValue(
        dimensionId: topic.id,
        name: 'Travel',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          topic.id: {food.id, travel.id},
        },
      );
      final before = await storedSnapshot(f.db);
      final service = SqliteVocabularyDeletionService(f.db);
      addTearDown(service.dispose);
      final receipt = await service.delete(f.entry.id);
      expect(await categories.assignments(f.entry.id), isEmpty);
      await service.restore(receipt);
      expect((await categories.assignments(f.entry.id)).single.valueIds, {
        food.id,
        travel.id,
      });
      expect(await storedSnapshot(f.db), before);
      final second = await service.delete(f.entry.id);
      await categories.deleteValue(food.id);
      await service.restore(second);
      expect((await categories.assignments(f.entry.id)).single.valueIds, {
        travel.id,
      });
      expect(await categories.valueById(food.id), isNull);
      expect(await storedSnapshot(f.db), before);
    },
  );

  test('category writes share the surrounding atomic transaction', () async {
    final topic = await dimension('Topic');
    final before = await storedSnapshot(f.db);
    await expectLater(
      f.db.transaction(() async {
        final value = await categories.createValue(
          dimensionId: topic.id,
          name: 'Food',
        );
        await categories.replaceAssignments(
          entryId: f.entry.id,
          assignments: {
            topic.id: {value.id},
          },
        );
        throw StateError('Injected final write failure');
      }),
      throwsStateError,
    );
    expect(await categories.values(topic.id), isEmpty);
    expect(await categories.assignments(f.entry.id), isEmpty);
    expect(await storedSnapshot(f.db), before);
  });

  test(
    'v10 upgrade and reopen preserve every old row, scope, setting, order and allocator',
    () async {
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true, rating: LearningRating.again);
      await SqliteSettingsRepository(f.db).write('locale', 'de');
      final before = await storedSnapshot(f.db);
      final directory = await Directory.systemTemp.createTemp(
        'piko-categories-v10-',
      );
      final file = File('${directory.path}/migration.sqlite');
      PikoDatabase? db;
      try {
        final old = sqlite.sqlite3.open(file.path);
        try {
          final schema =
              jsonDecode(
                    await File(
                      'drift_schemas/drift_schema_v10.json',
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
              // The v10 fixture predates the additive successful-Speed marker.
              if (table.key == 'learning_items') row.remove('speed_completed');
              if (table.key == 'vocabulary_entries') {
                row.removeWhere(
                  (key, _) => const {
                    'example_target_text',
                    'example_native_text',
                    'hint_text',
                    'hint_visibility',
                  }.contains(key),
                );
              }
              final columns = row.keys
                  .map((key) => key == 'stored_rowid' ? 'rowid' : key)
                  .join(',');
              final placeholders = List.filled(row.length, '?').join(',');
              old.execute(
                'INSERT INTO ${table.key} ($columns) VALUES ($placeholders)',
                row.values.toList(),
              );
            }
          }
          old.execute('PRAGMA user_version = 10');
        } finally {
          old.close();
        }
        await f.db.close();
        fixtureClosed = true;
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        expect(await storedSnapshot(db), before);
        final repository = SqliteCategoriesRepository(db);
        expect(await repository.dimensions(f.owner.id), isEmpty);
        final topic = await repository.createDimension(
          collectionId: f.owner.id,
          name: 'Topic',
          mode: CategoryMode.multiple,
        );
        final food = await repository.createValue(
          dimensionId: topic.id,
          name: 'Food',
        );
        await repository.replaceAssignments(
          entryId: f.entry.id,
          assignments: {
            topic.id: {food.id},
          },
        );
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        final reopened = SqliteCategoriesRepository(db);
        expect((await reopened.dimensions(f.owner.id)).single.id, topic.id);
        expect((await reopened.values(topic.id)).single.id, food.id);
        expect((await reopened.assignments(f.entry.id)).single.valueIds, {
          food.id,
        });
        expect(await storedSnapshot(db), before);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
