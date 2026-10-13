import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';

void main() {
  test(
    'duplicates have distinct UUIDs and invalid collection never persists',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = SqliteCollectionsRepository(db);
      Future<CollectionRecord> create(
        String name, {
        VocabularyLanguage native = VocabularyLanguage.german,
      }) => repository.create(
        name: name,
        targetLanguage: VocabularyLanguage.korean,
        nativeLanguage: native,
      );
      final first = await create(' Same ');
      final second = await create('Same');
      expect(first.id, isNot(second.id));
      expect(
        first.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(first.name, 'Same');
      await expectLater(
        create(' '),
        throwsA(CollectionValidation.requiredName),
      );
      await expectLater(
        create('Name', native: VocabularyLanguage.korean),
        throwsA(CollectionValidation.sameLanguage),
      );
      expect(await db.select(db.collections).get(), hasLength(2));
    },
  );

  test(
    'v1 migration preserves settings and collection persists across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-collection-test-',
      );
      final file = File('${directory.path}/database.sqlite');
      final old = sqlite.sqlite3.open(file.path);
      old.execute(
        'CREATE TABLE app_settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
      );
      old.execute("INSERT INTO app_settings VALUES ('locale', 'de')");
      old.execute('PRAGMA user_version = 1');
      old.close();
      var db = PikoDatabase(NativeDatabase(file));
      try {
        expect(await SqliteSettingsRepository(db).read('locale'), 'de');
        final saved = await SqliteCollectionsRepository(db).create(
          name: '한국어',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        await db.close();
        db = PikoDatabase(NativeDatabase(file));
        final row = await db.select(db.collections).getSingle();
        expect(row.id, saved.id);
        expect(row.name, '한국어');
        expect(row.targetLanguage, 'ko');
      expect(row.nativeLanguage, 'de');
        expect(await SqliteSettingsRepository(db).read('locale'), 'de');
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
