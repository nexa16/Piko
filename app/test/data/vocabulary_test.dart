import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';

Future<CollectionRecord> collection(PikoDatabase db, String name) =>
    SqliteCollectionsRepository(db).create(
      name: name,
      targetLanguage: VocabularyLanguage.korean,
      nativeLanguage: VocabularyLanguage.german,
    );

void main() {
  test(
    'distinct meanings sharing either side have separate UUID identities',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = await collection(db, 'Meanings');
      final repository = SqliteVocabularyRepository(db);
      final records = <VocabularyRecord>[];
      for (final pair in [
        ['눈', 'Auge'],
        ['눈', 'Schnee'],
        ['안녕', 'Hallo'],
        ['여보세요', 'Hallo'],
      ]) {
        records.add(
          await repository.create(
            collectionId: owner.id,
            targetText: pair[0],
            nativeText: pair[1],
          ),
        );
      }
      expect(records.map((r) => r.id).toSet(), hasLength(4));
      for (final record in records) {
        expect(
          record.id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        final actual = await repository.watchById(record.id).first;
        expect(actual!.targetText, record.targetText);
        expect(actual.nativeText, record.nativeText);
        expect(actual.collectionId, owner.id);
      }
      expect(
        (await repository.watchByCollection(owner.id).first).map((r) => r.id),
        records.map((r) => r.id),
      );
    },
  );

  test(
    'required texts and missing collection produce typed failures without writes',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = await collection(db, 'Validation');
      final repository = SqliteVocabularyRepository(db);
      Future<VocabularyRecord> create(
        String target,
        String native, {
        String? id,
      }) => repository.create(
        collectionId: id ?? owner.id,
        targetText: target,
        nativeText: native,
      );
      await expectLater(
        create(' \t\n\u00a0', 'Text'),
        throwsA(VocabularyValidation.requiredTarget),
      );
      await expectLater(
        create('Text', ' \t\n'),
        throwsA(VocabularyValidation.requiredNative),
      );
      await expectLater(
        create('Text', 'Text', id: 'missing'),
        throwsA(VocabularyValidation.collectionNotFound),
      );
      expect(await db.select(db.vocabularyEntries).get(), isEmpty);
      // SQLite protects collection integrity even if feature validation is bypassed.
      await expectLater(
        db
            .into(db.vocabularyEntries)
            .insert(
              VocabularyEntriesCompanion.insert(
                id: 'invalid-owner',
                collectionId: 'missing',
                targetText: 'One',
                nativeText: 'Two',
              ),
            ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await expectLater(
        db
            .into(db.vocabularyEntries)
            .insert(
              VocabularyEntriesCompanion.insert(
                id: 'invalid-target',
                collectionId: owner.id,
                targetText: '',
                nativeText: 'Two',
              ),
            ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await expectLater(
        db
            .into(db.vocabularyEntries)
            .insert(
              VocabularyEntriesCompanion.insert(
                id: 'invalid-native',
                collectionId: owner.id,
                targetText: 'One',
                nativeText: '   ',
              ),
            ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await db.select(db.vocabularyEntries).get(), isEmpty);
    },
  );

  test(
    'existing collection watch observes inserts and another collection stays isolated',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = await collection(db, 'First');
      final other = await collection(db, 'Second');
      final repository = SqliteVocabularyRepository(db);
      final observed = Completer<List<VocabularyRecord>>();
      final subscription = repository.watchByCollection(owner.id).listen((
        rows,
      ) {
        if (rows.isNotEmpty && !observed.isCompleted) observed.complete(rows);
      });
      addTearDown(subscription.cancel);
      expect(await repository.watchByCollection(owner.id).first, isEmpty);
      final saved = await repository.create(
        collectionId: owner.id,
        targetText: '  학교  ',
        nativeText: ' Schule ',
      );
      expect((await observed.future).single.id, saved.id);
      // Display input is intact; normalization belongs to VOCAB-012/002.
      expect(saved.targetText, '  학교  ');
      expect(saved.nativeText, ' Schule ');
      expect(await repository.watchByCollection(other.id).first, isEmpty);
      expect(await repository.watchById('missing').first, isNull);
    },
  );

  test(
    'collection foreign-key deletion cascades only its vocabulary identities',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = await collection(db, 'First');
      final other = await collection(db, 'Second');
      final repository = SqliteVocabularyRepository(db);
      final removed = await repository.create(
        collectionId: owner.id,
        targetText: '눈',
        nativeText: 'Auge',
      );
      final retained = await repository.create(
        collectionId: other.id,
        targetText: '학교',
        nativeText: 'Schule',
      );
      await (db.delete(
        db.collections,
      )..where((row) => row.id.equals(owner.id))).go();
      expect(await repository.watchById(removed.id).first, isNull);
      expect((await repository.watchById(retained.id).first)!.id, retained.id);
    },
  );

  test(
    'exported v2 migration preserves settings/collections and vocabulary survives reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-vocabulary-test-',
      );
      final file = File('${directory.path}/test.sqlite');
      final schema =
          jsonDecode(
                await File('drift_schemas/drift_schema_v2.json').readAsString(),
              )
              as Map<String, dynamic>;
      final old = sqlite.sqlite3.open(file.path);
      try {
        for (final table in schema['fixed_sql'] as List<dynamic>) {
          old.execute((table['sql'] as List<dynamic>).single['sql'] as String);
        }
        old.execute("INSERT INTO app_settings VALUES ('locale', 'de')");
        old.execute(
          "INSERT INTO collections VALUES ('existing', 'Retained', 'ko', 'de')",
        );
        old.execute('PRAGMA user_version = 2');
      } finally {
        old.close();
      }
      var db = PikoDatabase(NativeDatabase(file));
      try {
        expect(await SqliteSettingsRepository(db).read('locale'), 'de');
        expect(
          (await SqliteCollectionsRepository(
            db,
          ).watchById('existing').first)!.name,
          'Retained',
        );
        expect(await db.select(db.vocabularyEntries).get(), isEmpty);
        final saved = await SqliteVocabularyRepository(db).create(
          collectionId: 'existing',
          targetText: '눈',
          nativeText: 'Schnee',
        );
        final version = await db
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 3);
        await db.close();
        db = PikoDatabase(NativeDatabase(file));
        final actual = await SqliteVocabularyRepository(
          db,
        ).watchById(saved.id).first;
        expect(actual!.targetText, '눈');
        expect(actual.nativeText, 'Schnee');
        expect(actual.collectionId, 'existing');
        expect(await SqliteSettingsRepository(db).read('locale'), 'de');
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
