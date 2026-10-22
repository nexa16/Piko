import '../support/freeze_pre20.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture, instant, rows;
import 'statistics_test.dart' show stored;

Future<(CategoryDimensionRecord, List<CategoryValueRecord>)> seed(
  SqliteCategoriesRepository repository,
  String owner,
) async {
  final group = await repository.createDimension(
    collectionId: owner,
    name: 'Topic',
    mode: CategoryMode.multiple,
  );
  for (final name in ['Zebra', 'apple', 'Banana']) {
    // Explicitly seed the legacy/default automatic state; ordinary additions
    // now freeze its effective order and append under CAT-ORDER-001.
    await repository.createValue(
      dimensionId: group.id,
      name: name,
      preserveAutomaticOrder: true,
    );
  }
  return (group, await repository.values(group.id));
}

List<String> ids(List<CategoryValueRecord> values) =>
    values.map((v) => v.id).toList();
List<String> names(List<CategoryValueRecord> values) =>
    values.map((v) => v.name).toList();

void main() {
  test(
    'first ordinary addition freezes effective automatic order, appends and survives shared reads/reopen',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'piko-first-append-',
      );
      final file = File('${directory.path}/data.sqlite');
      var database = PikoDatabase(NativeDatabase(file));
      final f = Fixture(database: database);
      await f.initialize();
      await f.review();
      var repository = SqliteCategoriesRepository(database);
      final (group, original) = await seed(repository, f.owner.id);
      await repository.replaceAssignments(
        entryId: f.entry.id,
        assignments: {group.id: ids(original).toSet()},
      );
      final before = await stored(database);
      await database.customStatement(
        "CREATE TRIGGER reject_append BEFORE INSERT ON category_values BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        repository.createValue(dimensionId: group.id, name: 'Aardvark'),
        throwsA(anything),
      );
      expect(await stored(database), before);
      await database.customStatement('DROP TRIGGER reject_append');
      final appended = await repository.createValue(
        dimensionId: group.id,
        name: 'Aardvark',
      );
      final expected = [...ids(original), appended.id];
      expect(names(await repository.values(group.id)), [
        'apple',
        'Banana',
        'Zebra',
        'Aardvark',
      ]);
      expect(
        (await repository.watchValues(group.id).first).map((v) => v.id),
        expected,
      );
      final query = await SqliteCollectionQueryService(
        database,
      ).query(collectionId: f.owner.id, at: instant);
      expect(query.categoryValues[group.id]!.map((v) => v.id), expected);
      final after = await stored(database);
      for (final table in before.keys.where(
        (table) =>
            table != 'category_values' && table != 'category_group_preferences',
      )) {
        expect(after[table], before[table], reason: table);
      }
      expect(
        (await database.select(database.categoryGroupPreferences).get())
            .singleWhere((p) => p.dimensionId == group.id)
            .customValueOrder,
        true,
      );
      await database.close();
      database = PikoDatabase(NativeDatabase(file));
      repository = SqliteCategoriesRepository(database);
      expect(ids(await repository.values(group.id)), expected);
      expect(
        (await SqliteCollectionQueryService(database).query(
          collectionId: f.owner.id,
          at: instant,
        )).categoryValues[group.id]!.map((v) => v.id),
        expected,
      );
      await database.close();
      directory.deleteSync(recursive: true);
    },
  );

  test(
    'default/no-op, atomic first custom move, rename/create and group independence',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final repository = SqliteCategoriesRepository(f.db);
      final (group, original) = await seed(repository, f.owner.id);
      final (other, _) = await seed(repository, f.kept.id);
      expect(names(original), ['apple', 'Banana', 'Zebra']);
      final before = await stored(f.db);
      await repository.reorderValues(
        dimensionId: group.id,
        expectedOrder: ids(original),
        orderedIds: ids(original),
      );
      expect(await stored(f.db), before);
      final reordered = await repository.reorderValues(
        dimensionId: group.id,
        expectedOrder: ids(original),
        orderedIds: [original[2].id, original[0].id, original[1].id],
      );
      expect(names(reordered), ['Zebra', 'apple', 'Banana']);
      expect(reordered.map((v) => v.position), [0, 1, 2]);
      for (final entry in before.entries) {
        if (!{
          'category_values',
          'category_group_preferences',
        }.contains(entry.key)) {
          expect(
            (await stored(f.db))[entry.key],
            entry.value,
            reason: entry.key,
          );
        }
      }
      await repository.renameValue(id: original[2].id, name: ' Apricot ');
      await repository.createValue(dimensionId: group.id, name: 'Cherry');
      expect(names(await repository.values(group.id)), [
        'Apricot',
        'apple',
        'Banana',
        'Cherry',
      ]);
      expect(names(await repository.values(other.id)), [
        'apple',
        'Banana',
        'Zebra',
      ]);
      await repository.renameValue(
        id: (await repository.values(other.id)).last.id,
        name: 'Aardvark',
      );
      expect(names(await repository.values(other.id)), [
        'Aardvark',
        'apple',
        'Banana',
      ]);
      await expectLater(
        repository.createValue(dimensionId: group.id, name: ' APPLE '),
        throwsA(CategoryValidation.duplicateName),
      );
      expect(
        await f.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'rollback, simultaneous stale moves, frozen inputs and whole snapshot watch',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final repository = SqliteCategoriesRepository(f.db);
      final (group, original) = await seed(repository, f.owner.id);
      final before = await stored(f.db);
      final reverse = ids(original.reversed.toList());
      await f.db.customStatement(
        "CREATE TRIGGER fail_order BEFORE UPDATE OF position ON category_values WHEN NEW.position = 1 BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        repository.reorderValues(
          dimensionId: group.id,
          expectedOrder: ids(original),
          orderedIds: reverse,
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await stored(f.db), before);
      await f.db.customStatement('DROP TRIGGER fail_order');
      final observed = <List<String>>[];
      final subscription = repository
          .watchValues(group.id)
          .listen((values) => observed.add(ids(values)));
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      final expected = ids(original), requested = List<String>.of(reverse);
      final first = repository.reorderValues(
        dimensionId: group.id,
        expectedOrder: expected,
        orderedIds: requested,
      );
      expected.clear();
      requested.clear();
      final second = repository.reorderValues(
        dimensionId: group.id,
        expectedOrder: ids(original),
        orderedIds: [original[1].id, original[0].id, original[2].id],
      );
      final rejected = expectLater(
        second,
        throwsA(CategoryValidation.staleOrder),
      );
      expect(ids(await first), reverse);
      await rejected;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(observed, isNotEmpty);
      for (final sequence in observed) {
        expect(sequence, anyOf(equals(ids(original)), equals(reverse)));
      }
      await expectLater(
        repository.reorderValues(
          dimensionId: group.id,
          expectedOrder: reverse,
          orderedIds: [reverse[0], reverse[0], reverse[1]],
        ),
        throwsA(CategoryValidation.invalidOwnership),
      );
      await expectLater(
        repository.reorderValues(
          dimensionId: group.id,
          expectedOrder: reverse,
          orderedIds: [reverse[0], reverse[1], 'foreign'],
        ),
        throwsA(CategoryValidation.invalidOwnership),
      );
      expect(ids(await repository.values(group.id)), reverse);
    },
  );

  test(
    'existing import leaves local order; new import appends in source batch order',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final repository = SqliteCategoriesRepository(f.db);
      final (group, original) = await seed(repository, f.owner.id);
      final custom = [original[2].id, original[0].id, original[1].id];
      await repository.reorderValues(
        dimensionId: group.id,
        expectedOrder: ids(original),
        orderedIds: custom,
      );
      await repository.replaceAssignments(
        entryId: f.entry.id,
        assignments: {group.id: original.map((v) => v.id).toSet()},
      );
      await f.review(rating: LearningRating.again);
      final service = SqliteVocabularyJsonService(f.db);
      final document =
          jsonDecode(await service.exportCollection(f.owner.id))
              as Map<String, dynamic>;
      expect(document['schemaVersion'], 5);
      expect(jsonEncode(document), isNot(contains('customValueOrder')));
      final collection =
          (document['collections'] as List).single as Map<String, dynamic>;
      final definition =
          (collection['categoryDimensions'] as List).single
              as Map<String, dynamic>;
      definition['values'] = (definition['values'] as List).reversed.toList();
      var preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(document),
        groups: {VocabularyJsonGroup.categoryAssignments},
      );
      expect(preview.canApply, isTrue);
      await service.applyImport(preview);
      expect(ids(await repository.values(group.id)), custom);
      const newIds = [
        '00000000-0000-4000-8000-000000000041',
        '00000000-0000-4000-8000-000000000042',
      ];
      (definition['values'] as List).addAll([
        {'id': newIds[0], 'name': 'Delta'},
        {'id': newIds[1], 'name': 'Cherry'},
      ]);
      final entry =
          (collection['entries'] as List).single as Map<String, dynamic>;
      final assignment =
          (entry['categoryAssignments'] as List).single as Map<String, dynamic>;
      (assignment['valueIds'] as List).addAll(newIds);
      final learningBefore = {
        for (final table in [
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
          'statistics_activity',
        ])
          table: await rows(f.db, table),
      };
      preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(document),
        groups: {VocabularyJsonGroup.categoryAssignments},
      );
      expect(preview.canApply, isTrue);
      await service.applyImport(preview);
      expect(names(await repository.values(group.id)), [
        'Zebra',
        'apple',
        'Banana',
        'Delta',
        'Cherry',
      ]);
      for (final entry in learningBefore.entries) {
        expect(await rows(f.db, entry.key), entry.value);
      }
      final snapshot = await SqliteCollectionQueryService(
        f.db,
      ).query(collectionId: f.owner.id, at: instant);
      expect(
        groupVocabulary(
          snapshot,
          CollectionViewPreferences(grouping: group.id),
        ).map((g) => g.id),
        [...custom, ...newIds],
      );
    },
  );

  test(
    'delete compacts survivors; vocabulary Undo preserves later order and explicit definition deletion',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final repository = SqliteCategoriesRepository(f.db);
      final (group, original) = await seed(repository, f.owner.id);
      await repository.reorderValues(
        dimensionId: group.id,
        expectedOrder: ids(original),
        orderedIds: ids(original.reversed.toList()),
      );
      await repository.replaceAssignments(
        entryId: f.entry.id,
        assignments: {group.id: ids(original).toSet()},
      );
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true, rating: LearningRating.again);
      final learningBefore = await rows(f.db, 'learning_items');
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      await repository.deleteValue(original[1].id);
      final surviving = await repository.values(group.id);
      expect(surviving.map((v) => v.position), [0, 1]);
      await repository.reorderValues(
        dimensionId: group.id,
        expectedOrder: ids(surviving),
        orderedIds: ids(surviving.reversed.toList()),
      );
      await deletion.restore(receipt);
      expect(
        ids(await repository.values(group.id)),
        ids(surviving.reversed.toList()),
      );
      expect(
        (await repository.assignments(f.entry.id)).single.valueIds,
        ids(surviving).toSet(),
      );
      expect(await rows(f.db, 'learning_items'), learningBefore);
      await repository.deleteDimension(group.id);
      expect(await rows(f.db, 'category_group_preferences'), isEmpty);
      expect(
        await f.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'populated schema17 upgrade leaves every old row exact; custom order survives reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-value-order-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/values.sqlite');
      var database = PikoDatabase(NativeDatabase(file));
      final f = Fixture(database: database);
      await f.initialize();
      var repository = SqliteCategoriesRepository(database);
      final (group, original) = await seed(repository, f.owner.id);
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true, rating: LearningRating.again);
      final before = (await stored(database))
        ..remove('category_group_preferences');
      await database.close();
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('DROP TABLE category_group_preferences');
      freezePre20(legacy);
      legacy.execute('PRAGMA user_version = 17');
      legacy.close();
      database = PikoDatabase(NativeDatabase(file));
      repository = SqliteCategoriesRepository(database);
      final upgraded = (await stored(database))
        ..remove('category_group_preferences');
      expect(upgraded, before);
      expect(names(await repository.values(group.id)), [
        'apple',
        'Banana',
        'Zebra',
      ]);
      await repository.reorderValues(
        dimensionId: group.id,
        expectedOrder: ids(original),
        orderedIds: ids(original.reversed.toList()),
      );
      final saved = await stored(database);
      await database.close();
      database = PikoDatabase(NativeDatabase(file));
      addTearDown(database.close);
      expect(await stored(database), saved);
      expect(
        names(await SqliteCategoriesRepository(database).values(group.id)),
        ['Zebra', 'Banana', 'apple'],
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}
