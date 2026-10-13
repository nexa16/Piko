import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';

Future<String> owner(PikoDatabase db) async =>
    (await SqliteCollectionsRepository(db).create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    )).id;

Future<void> oldSchema(File file, int version, {bool collision = false}) async {
  final schema =
      jsonDecode(
            await File(
              'drift_schemas/drift_schema_v$version.json',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  final old = sqlite.sqlite3.open(file.path);
  try {
    for (final table in schema['fixed_sql'] as List<dynamic>) {
      old.execute((table['sql'] as List<dynamic>).single['sql'] as String);
    }
    old.execute("INSERT INTO app_settings VALUES ('locale', 'de')");
    if (version >= 2) {
      old.execute(
        "INSERT INTO collections VALUES ('first', 'Words', 'fr', 'de')",
      );
      old.execute(
        "INSERT INTO collections VALUES ('other', 'Other', 'fr', 'de')",
      );
    }
    if (version == 3) {
      old.execute(
        'INSERT INTO vocabulary_entries (rowid,id,collection_id,target_text,native_text) VALUES (?,?,?,?,?)',
        [41, 'entry-a', 'first', '  Cafe\u0301 ', ' Kaffee '],
      );
      old.execute(
        'INSERT INTO vocabulary_entries (rowid,id,collection_id,target_text,native_text) VALUES (?,?,?,?,?)',
        [87, 'entry-b', collision ? 'first' : 'other', 'CAFÉ', 'KAFFEE'],
      );
    }
    old.execute('PRAGMA user_version = $version');
  } finally {
    old.close();
  }
}

void main() {
  test(
    'fresh schema enforces normalized pair uniqueness and canonical writes',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await owner(db);
      final repository = SqliteVocabularyRepository(db);
      final columns = await db
          .customSelect('PRAGMA table_info(vocabulary_entries)')
          .get();
      for (final name in ['target_key', 'native_key']) {
        final column = columns.singleWhere(
          (row) => row.read<String>('name') == name,
        );
        expect(column.read<int>('notnull'), 1);
        expect(column.data['dflt_value'], isNull);
      }
      final export =
          jsonDecode(
                await File('drift_schemas/drift_schema_v4.json').readAsString(),
              )
              as Map<String, dynamic>;
      final exportedTable = (export['fixed_sql'] as List<dynamic>).singleWhere(
        (table) => table['name'] == 'vocabulary_entries',
      );
      expect(
        (exportedTable['sql'] as List<dynamic>).single['sql'],
        contains('UNIQUE(collection_id, target_key, native_key)'),
      );
      final saved = await repository.create(
        collectionId: id,
        targetText: ' Cafe\u0301 ',
        nativeText: ' KAFFEE ',
      );
      expect(saved.targetText, 'Café');
      expect(saved.nativeText, 'KAFFEE');
      final row = await db.select(db.vocabularyEntries).getSingle();
      expect(row.targetKey, 'café');
      expect(row.nativeKey, 'kaffee');
      await expectLater(
        repository.create(
          collectionId: id,
          targetText: 'CAFÉ',
          nativeText: 'Kaffee',
        ),
        throwsA(VocabularyValidation.duplicatePair),
      );
      await expectLater(
        db
            .into(db.vocabularyEntries)
            .insert(
              VocabularyEntriesCompanion.insert(
                id: 'raw-duplicate',
                collectionId: id,
                targetText: 'CAFÉ',
                nativeText: 'kaffee',
                targetKey: 'café',
                nativeKey: 'kaffee',
              ),
            ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await db.select(db.vocabularyEntries).get(), hasLength(1));
    },
  );

  test(
    'exact-ID update allows self match and preserves last valid record on errors',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await owner(db);
      final repository = SqliteVocabularyRepository(db);
      final first = await repository.create(
        collectionId: id,
        targetText: 'pomme',
        nativeText: 'Apfel',
      );
      final second = await repository.create(
        collectionId: id,
        targetText: 'eau',
        nativeText: 'Wasser',
      );
      final self = await repository.update(
        id: first.id,
        targetText: ' POMME ',
        nativeText: ' APFEL ',
      );
      expect(self.id, first.id);
      expect(self.collectionId, first.collectionId);
      expect(self.targetText, 'POMME');
      await expectLater(
        repository.update(
          id: second.id,
          targetText: 'pomme',
          nativeText: 'Apfel',
        ),
        throwsA(VocabularyValidation.duplicatePair),
      );
      await expectLater(
        repository.update(
          id: second.id,
          targetText: ' ',
          nativeText: 'Changed',
        ),
        throwsA(VocabularyValidation.requiredTarget),
      );
      await expectLater(
        repository.update(
          id: second.id,
          targetText: 'Changed',
          nativeText: '\u00a0',
        ),
        throwsA(VocabularyValidation.requiredNative),
      );
      await expectLater(
        repository.update(
          id: 'missing',
          targetText: 'valid',
          nativeText: 'valid',
        ),
        throwsA(VocabularyValidation.entryNotFound),
      );
      var retained = await repository.watchById(second.id).first;
      expect(retained!.targetText, 'eau');
      expect(retained.nativeText, 'Wasser');
      // A real SQLite write failure must propagate, not become duplicate validation.
      await db.customStatement(
        "CREATE TRIGGER reject_vocabulary_update BEFORE UPDATE ON vocabulary_entries BEGIN SELECT RAISE(ABORT, 'Injected update failure'); END",
      );
      await expectLater(
        repository.update(
          id: second.id,
          targetText: 'changed',
          nativeText: 'Changed',
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      retained = await repository.watchById(second.id).first;
      expect(retained!.targetText, 'eau');
      expect(retained.nativeText, 'Wasser');
    },
  );

  test('concurrent normalized duplicates admit exactly one write', () async {
    final db = PikoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await owner(db);
    final repository = SqliteVocabularyRepository(db);
    Future<Object> create(String target, String native) async {
      try {
        return await repository.create(
          collectionId: id,
          targetText: target,
          nativeText: native,
        );
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([
      create(' Cafe\u0301 ', 'Kaffee'),
      create('CAFÉ', 'KAFFEE'),
    ]);
    expect(results.whereType<VocabularyRecord>(), hasLength(1));
    expect(
      results.where((r) => r == VocabularyValidation.duplicatePair),
      hasLength(1),
    );
    expect(await db.select(db.vocabularyEntries).get(), hasLength(1));
  });

  test('sharp S differs from ss while either shared side is allowed', () async {
    final db = PikoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await owner(db);
    final repository = SqliteVocabularyRepository(db);
    for (final pair in [
      ['Maße', 'dimensions'],
      ['Masse', 'dimensions'],
      ['Maße', 'measurements'],
    ]) {
      await repository.create(
        collectionId: id,
        targetText: pair[0],
        nativeText: pair[1],
      );
    }
    await expectLater(
      repository.create(
        collectionId: id,
        targetText: 'MAẞE',
        nativeText: 'DIMENSIONS',
      ),
      throwsA(VocabularyValidation.duplicatePair),
    );
    expect(await db.select(db.vocabularyEntries).get(), hasLength(3));
  });

  for (final version in [1, 2]) {
    test(
      'v$version upgrades directly to schema4 preserving existing records',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'piko-v$version-upgrade-',
        );
        final file = File('${directory.path}/test.sqlite');
        await oldSchema(file, version);
        final db = PikoDatabase(NativeDatabase(file));
        try {
          expect((await db.select(db.appSettings).getSingle()).value, 'de');
          if (version == 2) {
            expect(await db.select(db.collections).get(), hasLength(2));
          }
          final id = version == 2 ? 'first' : await owner(db);
          await SqliteVocabularyRepository(
            db,
          ).create(collectionId: id, targetText: 'One', nativeText: 'Two');
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            4,
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

  test(
    'v3 rebuild retains exact IDs, raw display text, owners and rowids',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-v3-upgrade-',
      );
      final file = File('${directory.path}/test.sqlite');
      await oldSchema(file, 3);
      final db = PikoDatabase(NativeDatabase(file));
      try {
        final rows = await db
            .customSelect(
              'SELECT rowid AS original_rowid, * FROM vocabulary_entries ORDER BY rowid',
            )
            .get();
        expect(rows.map((r) => r.read<int>('original_rowid')), [41, 87]);
        expect(rows.map((r) => r.read<String>('id')), ['entry-a', 'entry-b']);
        expect(rows.map((r) => r.read<String>('collection_id')), [
          'first',
          'other',
        ]);
        expect(rows.first.read<String>('target_text'), '  Cafe\u0301 ');
        expect(rows.first.read<String>('native_text'), ' Kaffee ');
        expect(rows.map((r) => r.read<String>('target_key')), ['café', 'café']);
        expect(rows.map((r) => r.read<String>('native_key')), [
          'kaffee',
          'kaffee',
        ]);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect((await db.select(db.appSettings).getSingle()).value, 'de');
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          4,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'v3 collision aborts with version/schema/raw records intact and retry safe',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-v3-collision-',
      );
      final file = File('${directory.path}/test.sqlite');
      await oldSchema(file, 3, collision: true);
      try {
        for (var attempt = 0; attempt < 2; attempt++) {
          final db = PikoDatabase(NativeDatabase(file));
          try {
            await expectLater(
              db.select(db.appSettings).get(),
              throwsA(isA<VocabularyMigrationCollision>()),
            );
          } finally {
            await db.close();
          }
          final raw = sqlite.sqlite3.open(file.path);
          try {
            expect(raw.select('PRAGMA user_version').single['user_version'], 3);
            expect(
              raw
                  .select('PRAGMA table_info(vocabulary_entries)')
                  .map((r) => r['name']),
              ['id', 'collection_id', 'target_text', 'native_text'],
            );
            final rows = raw.select(
              'SELECT rowid AS original_rowid,* FROM vocabulary_entries ORDER BY rowid',
            );
            expect(rows.map((r) => r['original_rowid']), [41, 87]);
            expect(rows.first['target_text'], '  Cafe\u0301 ');
            expect(rows.first['native_text'], ' Kaffee ');
            expect(rows.last['id'], 'entry-b');
            expect(rows.last['collection_id'], 'first');
            expect(
              raw.select(
                "SELECT name FROM sqlite_master WHERE name='vocabulary_entries_v4'",
              ),
              isEmpty,
            );
          } finally {
            raw.close();
          }
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('v3 foreign-key failure rolls back the completed table rebuild', () async {
    final directory = await Directory.systemTemp.createTemp(
      'piko-v3-rollback-',
    );
    final file = File('${directory.path}/test.sqlite');
    await oldSchema(file, 3);
    final invalid = sqlite.sqlite3.open(file.path);
    invalid.execute(
      "UPDATE vocabulary_entries SET collection_id='missing' WHERE id='entry-a'",
    );
    invalid.close();
    try {
      final db = PikoDatabase(NativeDatabase(file));
      try {
        await expectLater(db.select(db.appSettings).get(), throwsStateError);
      } finally {
        await db.close();
      }
      final raw = sqlite.sqlite3.open(file.path);
      try {
        expect(raw.select('PRAGMA user_version').single['user_version'], 3);
        expect(
          raw
              .select('PRAGMA table_info(vocabulary_entries)')
              .map((r) => r['name']),
          ['id', 'collection_id', 'target_text', 'native_text'],
        );
        final rows = raw.select(
          'SELECT rowid AS original_rowid,* FROM vocabulary_entries ORDER BY rowid',
        );
        expect(rows.map((r) => r['original_rowid']), [41, 87]);
        expect(rows.first['collection_id'], 'missing');
        expect(rows.first['target_text'], '  Cafe\u0301 ');
        expect(
          raw.select(
            "SELECT name FROM sqlite_master WHERE name='vocabulary_entries_v4'",
          ),
          isEmpty,
        );
      } finally {
        raw.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
