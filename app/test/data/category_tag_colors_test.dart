import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/category_tag_roles.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'regular_reviews_test.dart' show Fixture;
import 'statistics_test.dart' show stored;

void main() {
  test(
    'CAT-COLOR-001 deterministic 12/13+, concurrent creation, delete reuse, rename/value changes, rollback/retry and unchanged JSON',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final r = SqliteCategoriesRepository(f.db);
      final before = await stored(f.db);
      final groups = await Future.wait([
        for (var i = 0; i < 13; i++)
          r.createDimension(
            collectionId: f.owner.id,
            name: 'Group $i',
            mode: CategoryMode.multiple,
          ),
      ]);
      final current = await r.dimensions(f.owner.id);
      expect(current.take(12).map((g) => g.tagColorRole), categoryTagRoles);
      expect(current.last.tagColorRole, categoryTagRoles.first);
      final colors = {for (final g in groups) g.id: g.tagColorRole};
      await r.renameDimension(id: groups[2].id, name: 'Renamed');
      final value = await r.createValue(
        dimensionId: groups[2].id,
        name: 'Value',
      );
      await r.renameValue(id: value.id, name: 'Other');
      await r.deleteValue(value.id);
      await r.deleteDimension(groups[1].id);
      final replacement = await r.createDimension(
        collectionId: f.owner.id,
        name: 'Replacement',
        mode: CategoryMode.single,
      );
      expect(replacement.tagColorRole, categoryTagRoles[1]);
      for (final g in await r.dimensions(f.owner.id)) {
        if (colors.containsKey(g.id)) expect(g.tagColorRole, colors[g.id]);
      }
      await f.db.customStatement(
        "CREATE TRIGGER fail_color BEFORE INSERT ON category_group_preferences BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
      );
      await expectLater(
        r.createDimension(
          collectionId: f.owner.id,
          name: 'Retry',
          mode: CategoryMode.single,
        ),
        throwsA(anything),
      );
      expect(
        (await r.dimensions(f.owner.id)).any((g) => g.name == 'Retry'),
        false,
      );
      await f.db.customStatement('DROP TRIGGER fail_color');
      await r.createDimension(
        collectionId: f.owner.id,
        name: 'Retry',
        mode: CategoryMode.single,
      );
      final wire = SqliteVocabularyJsonService(f.db);
      final document =
          jsonDecode(await wire.exportCollection(f.owner.id))
              as Map<String, dynamic>;
      expect(document['schemaVersion'], 5);
      expect(jsonEncode(document), isNot(contains('tagColorRole')));
      expect(jsonEncode(document), isNot(contains('categorySoftgold')));
      final saved = {
        for (final g in await r.dimensions(f.owner.id)) g.id: g.tagColorRole,
      };
      final preview = await wire.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(document),
        groups: {VocabularyJsonGroup.categoryAssignments},
      );
      expect(preview.canApply, true);
      await wire.applyImport(preview);
      expect({
        for (final g in await r.dimensions(f.owner.id)) g.id: g.tagColorRole,
      }, saved);
      final owner =
          (document['collections'] as List).single as Map<String, dynamic>;
      (owner['categoryDimensions'] as List).add({
        'id': '00000000-0000-4000-8000-000000000099',
        'name': 'Imported',
        'mode': 'single',
        'values': [
          {
            'id': '00000000-0000-4000-8000-000000000098',
            'name': 'Imported value',
          },
        ],
      });
      (owner['entries'] as List).first['categoryAssignments'] = [
        {
          'dimensionId': '00000000-0000-4000-8000-000000000099',
          'valueIds': ['00000000-0000-4000-8000-000000000098'],
        },
      ];
      final added = await wire.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(document),
        groups: {VocabularyJsonGroup.categoryAssignments},
      );
      expect(added.canApply, true);
      await wire.applyImport(added);
      expect(
        (await r.dimensionById(
          '00000000-0000-4000-8000-000000000099',
        ))!.tagColorRole,
        isNotNull,
      );
      for (final row in before.entries) {
        if (!row.key.startsWith('category_') &&
            row.key != 'vocabulary_category_assignments')
          expect((await stored(f.db))[row.key], row.value, reason: row.key);
      }
      expect(
        await f.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'CAT-COLOR-001 populated20 upgrade and file reopen preserve all rowids/content/learning and stable group roles',
    () async {
      final dir = Directory.systemTemp.createTempSync('piko-color-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/fixture.sqlite');
      var db = PikoDatabase(NativeDatabase(file));
      final f = Fixture(database: db);
      await f.initialize();
      await f.review();
      final r = SqliteCategoriesRepository(db);
      for (var i = 0; i < 13; i++)
        await r.createDimension(
          collectionId: f.owner.id,
          name: 'Group $i',
          mode: CategoryMode.multiple,
          carryOver: i == 0,
        );
      final before = {
        for (final table in db.allTables)
          table.actualTableName:
              (await db
                      .customSelect(
                        'SELECT rowid AS kept_rowid, * FROM ${table.actualTableName} ORDER BY rowid',
                      )
                      .get())
                  .map(
                    (row) =>
                        Map<String, Object?>.of(row.data)
                          ..remove('tag_color_role'),
                  )
                  .toList(),
      };
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute(
        'ALTER TABLE category_group_preferences DROP COLUMN tag_color_role',
      );
      raw.execute('PRAGMA user_version=20');
      raw.dispose();
      db = PikoDatabase(NativeDatabase(file));
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        21,
      );
      final assigned = await SqliteCategoriesRepository(
        db,
      ).dimensions(f.owner.id);
      expect(assigned.take(12).map((g) => g.tagColorRole), categoryTagRoles);
      expect(assigned.last.tagColorRole, categoryTagRoles.first);
      for (final table in db.allTables) {
        final after =
            (await db
                    .customSelect(
                      'SELECT rowid AS kept_rowid, * FROM ${table.actualTableName} ORDER BY rowid',
                    )
                    .get())
                .map(
                  (row) =>
                      Map<String, Object?>.of(row.data)
                        ..remove('tag_color_role'),
                )
                .toList();
        expect(
          after,
          before[table.actualTableName],
          reason: table.actualTableName,
        );
      }
      final saved = {for (final g in assigned) g.id: g.tagColorRole};
      await db.close();
      db = PikoDatabase(NativeDatabase(file));
      expect({
        for (final g in await SqliteCategoriesRepository(
          db,
        ).dimensions(f.owner.id))
          g.id: g.tagColorRole,
      }, saved);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
    },
  );
  test(
    'unknown local role has deterministic valid fallback without mutation',
    () {
      expect(categoryTagRole('unknown', 'uuid'), categoryTagRole(null, 'uuid'));
      expect(categoryTagRoles, contains(categoryTagRole('unknown', 'uuid')));
    },
  );
}
