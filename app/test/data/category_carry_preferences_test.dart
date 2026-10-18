import '../support/freeze_pre20.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'regular_reviews_test.dart' show Fixture, rows;
import 'statistics_test.dart' show stored;
import 'category_value_order_test.dart' show seed, ids;

void main() {
  test(
    'group settings commit atomically, preserve custom order and stay local to interchange',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final repo = SqliteCategoriesRepository(f.db);
      final (group, values) = await seed(repo, f.owner.id);
      final (other, _) = await seed(repo, f.kept.id);
      expect(group.carryOver, isFalse);
      final original = await stored(f.db);
      await f.db.customStatement(
        "CREATE TRIGGER fail_preference BEFORE INSERT ON category_group_preferences BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      await expectLater(
        repo.updateDimension(
          id: group.id,
          name: 'Changed',
          mode: CategoryMode.single,
          carryOver: true,
        ),
        throwsA(anything),
      );
      expect(await stored(f.db), original);
      await f.db.customStatement('DROP TRIGGER fail_preference');
      final seen = <CategoryDimensionRecord>[];
      final subscription = repo
          .watchDimensions(f.owner.id)
          .listen((groups) => seen.add(groups.single));
      await repo.updateDimension(
        id: group.id,
        name: 'Changed',
        mode: CategoryMode.single,
        carryOver: true,
      );
      await repo.reorderValues(
        dimensionId: group.id,
        expectedOrder: ids(values),
        orderedIds: ids(values.reversed.toList()),
      );
      await repo.renameDimension(id: group.id, name: 'Renamed');
      expect((await repo.dimensionById(group.id))!.carryOver, isTrue);
      expect((await repo.dimensionById(other.id))!.carryOver, isFalse);
      final pref = (await rows(f.db, 'category_group_preferences')).single;
      expect(pref['custom_value_order'], 1);
      expect(pref['carry_over'], 1);
      await repo.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          group.id: {values.first.id},
        },
      );
      final json = SqliteVocabularyJsonService(f.db);
      final exported = await json.exportCollection(f.owner.id);
      expect((jsonDecode(exported) as Map)['schemaVersion'], 5);
      expect(exported, isNot(contains('carryOver')));
      expect(exported, isNot(contains('carry_over')));
      final preview = await json.analyzeImport(
        collectionId: f.owner.id,
        json: exported,
        groups: {VocabularyJsonGroup.categoryAssignments},
      );
      await json.applyImport(preview);
      expect((await repo.dimensionById(group.id))!.carryOver, isTrue);
      await repo.updateDimension(
        id: group.id,
        name: 'Renamed',
        mode: CategoryMode.single,
        carryOver: false,
      );
      expect(
        (await rows(
          f.db,
          'category_group_preferences',
        )).single['custom_value_order'],
        1,
      );
      expect(ids(await repo.values(group.id)), ids(values.reversed.toList()));
      await f.db.customSelect('SELECT 1').get();
      await Future<void>.delayed(Duration.zero);
      expect(
        seen.where((g) => g.name == 'Changed').every((g) => g.carryOver),
        isTrue,
      );
      await subscription.cancel();
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
        'statistics_activity',
      ]) {
        expect(await rows(f.db, table), original[table]);
      }
      await repo.deleteDimension(group.id);
      expect(await rows(f.db, 'category_group_preferences'), isEmpty);
      expect((await repo.dimensionById(other.id))!.carryOver, isFalse);
    },
  );

  test(
    'populated schema18 adds default-off carry without changing rows, custom order survives reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-carry-migration-',
      );
      final file = File('${directory.path}/fixture.sqlite');
      var db = PikoDatabase(NativeDatabase(file));
      try {
        final f = Fixture(database: db);
        await f.initialize();
        await f.review();
        var repo = SqliteCategoriesRepository(db);
        final (group, values) = await seed(repo, f.owner.id);
        final order = ids(values.reversed.toList());
        await repo.reorderValues(
          dimensionId: group.id,
          expectedOrder: ids(values),
          orderedIds: order,
        );
        await db.close();
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute(
          'ALTER TABLE category_group_preferences DROP COLUMN carry_over',
        );
        freezePre20(raw);
        raw.execute('PRAGMA user_version = 18');
        final before = {
          for (final row in raw.select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          ))
            row['name'] as String: raw
                .select('SELECT * FROM "${row['name']}" ORDER BY rowid')
                .map(Map<String, Object?>.from)
                .toList(),
        };
        raw.close();
        db = PikoDatabase(NativeDatabase(file));
        repo = SqliteCategoriesRepository(db);
        expect((await repo.dimensionById(group.id))!.carryOver, isFalse);
        final after = await stored(db);
        for (final table in before.keys) {
          final actual = (after[table] as List)
              .map(
                (row) =>
                    Map<String, Object?>.from(row as Map)..remove('carry_over')..remove('target_language_name')..remove('native_language_name')..remove('hint_key'),
              )
              .toList();
          expect(actual, before[table], reason: table);
        }
        expect(ids(await repo.values(group.id)), order);
        await repo.updateDimension(
          id: group.id,
          name: group.name,
          mode: group.mode,
          carryOver: true,
        );
        final saved = await stored(db);
        await db.close();
        db = PikoDatabase(NativeDatabase(file));
        expect(await stored(db), saved);
        expect(
          (await SqliteCategoriesRepository(
            db,
          ).dimensionById(group.id))!.carryOver,
          isTrue,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
