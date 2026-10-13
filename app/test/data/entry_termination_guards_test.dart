import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import '../../integration_test/support/entry_termination_fixture.dart';

void main() {
  test(
    'baseline guard detects mutations and allocator identity changes',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final unrelated = await SqliteCollectionsRepository(db).create(
        name: 'Retained baseline',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = SqliteVocabularyRepository(db);
      await repository.create(
        collectionId: unrelated.id,
        targetText: 'pomme',
        nativeText: 'Apfel',
      );
      await db.customStatement(
        "INSERT INTO app_settings (key, value) VALUES ('interfaceLocale', 'de')",
      );
      final baseline = await snapshot(db);
      Map<String, dynamic> clone() =>
          jsonDecode(jsonEncode(baseline)) as Map<String, dynamic>;
      expectBaseline(baseline, clone());
      final changed = clone();
      (changed['app_settings'] as List).add({
        'key': 'unexpected',
        'value': 'changed',
      });
      expect(
        () => expectBaseline(baseline, changed),
        throwsA(isA<TestFailure>()),
      );
      final allocator = clone();
      ((allocator['learning_identity_sequence'] as List).single
              as Map)['singleton'] =
          2;
      expect(
        () => expectBaseline(baseline, allocator),
        throwsA(isA<TestFailure>()),
      );
      final advanced = clone();
      ((advanced['learning_identity_sequence'] as List).single
              as Map)['next_id'] =
          10;
      expectBaseline(baseline, advanced);
    },
  );
  test(
    'cleanup refuses changed owned rows; exact cleanup preserves baseline and allocator',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final unrelated = await SqliteCollectionsRepository(db).create(
        name: 'Retained baseline',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = SqliteVocabularyRepository(db);
      await repository.create(
        collectionId: unrelated.id,
        targetText: 'pomme',
        nativeText: 'Apfel',
      );
      await db.customStatement(
        "INSERT INTO app_settings (key, value) VALUES ('interfaceLocale', 'de')",
      );
      final baseline = await snapshot(db);
      final owner = await SqliteCollectionsRepository(db).create(
        name: 'Owned',
        targetLanguage: VocabularyLanguage.korean,
        nativeLanguage: VocabularyLanguage.german,
      );
      final entry = await repository.create(
        collectionId: owner.id,
        targetText: '학교',
        nativeText: 'Schule',
      );
      final captured = await snapshot(db);
      final checkpoint = <String, dynamic>{
        'baseline': baseline,
        'owner': (captured['collections'] as List).cast<Map>().singleWhere(
          (row) => row['id'] == owner.id,
        ),
        'entry': (captured['vocabulary_entries'] as List)
            .cast<Map>()
            .singleWhere((row) => row['id'] == entry.id),
        'learning': (captured['learning_items'] as List)
            .cast<Map>()
            .where((row) => row['entry_id'] == entry.id)
            .toList(),
      };
      await repository.update(
        id: entry.id,
        targetText: '학교',
        nativeText: 'Changed',
      );
      await expectLater(
        cleanupOwned(db, checkpoint),
        throwsA(isA<TestFailure>()),
      );
      expect(await db.select(db.collections).get(), hasLength(2));
      expect(
        (await (db.select(
          db.vocabularyEntries,
        )..where((row) => row.id.equals(entry.id))).getSingle()).nativeText,
        'Changed',
      );
      await repository.update(
        id: entry.id,
        targetText: '학교',
        nativeText: 'Schule',
      );
      await cleanupOwned(db, checkpoint);
      final after = await snapshot(db);
      expectBaseline(baseline, after);
      expect(
        after['learning_identity_sequence'],
        captured['learning_identity_sequence'],
      );
      expect(
        after['vocabulary_order_sequence'],
        captured['vocabulary_order_sequence'],
      );
    },
  );
}
