import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/core/clock.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import '../support/mutable_clock.dart';

final class FailingClock implements PikoClock {
  @override
  DateTime now() => throw StateError('Injected migration clock failure');
}

void main() {
  final now = DateTime.utc(2026, 10, 14, 3);
  late PikoDatabase db;
  late String collection;
  setUp(() async {
    db = PikoDatabase(NativeDatabase.memory(), clock: MutablePikoClock(now));
    collection = (await SqliteCollectionsRepository(db).create(
      name: 'Test',
      targetLanguage: VocabularyLanguage.korean,
      nativeLanguage: VocabularyLanguage.german,
    )).id;
  });
  tearDown(() => db.close());

  test(
    'new entry owns two genuine independent FSRS states and edits preserve them',
    () async {
      final vocab = SqliteVocabularyRepository(db);
      final entry = await vocab.create(
        collectionId: collection,
        targetText: '학교',
        nativeText: 'Schule',
      );
      final learning = SqliteLearningRepository(db);
      final items = await learning.forEntry(entry.id);
      expect(
        items.map((item) => item.direction).toSet(),
        LearningDirection.values.toSet(),
      );
      expect(items.map((item) => item.id).toSet(), hasLength(2));
      for (final item in items) {
        expect(item.card, fsrs.Card(cardId: item.id, due: now));
      }
      final card = fsrs.Card(
        cardId: items.first.id,
        state: fsrs.State.review,
        stability: 3.25,
        difficulty: 5.75,
        due: now.add(const Duration(days: 3)),
        lastReview: now,
      );
      await learning.saveCard(items.first.id, card);
      card.stability = 999;
      final changed = await learning.forEntry(entry.id);
      expect(changed.first.card.stability, 3.25);
      expect(changed.last.cardJson, items.last.cardJson);
      changed.first.card.difficulty = 1;
      expect(changed.first.card.difficulty, 5.75);
      await vocab.update(
        id: entry.id,
        targetText: '학교!',
        nativeText: 'Schule!',
      );
      expect(
        (await learning.forEntry(entry.id)).map((item) => item.cardJson),
        changed.map((item) => item.cardJson),
      );
    },
  );

  test(
    'deleted identities are never reused, including after exact ID restoration',
    () async {
      final vocab = SqliteVocabularyRepository(db);
      final first = await vocab.create(
        collectionId: collection,
        targetText: 'a',
        nativeText: 'b',
      );
      final saved = await db.select(db.learningItems).get();
      await db.customStatement('DELETE FROM learning_items');
      final second = await vocab.create(
        collectionId: collection,
        targetText: 'c',
        nativeText: 'd',
      );
      final secondItems = await SqliteLearningRepository(
        db,
      ).forEntry(second.id);
      expect(secondItems.first.id, greaterThan(saved.last.id));
      for (final row in saved) {
        await db.into(db.learningItems).insert(row);
      }
      final third = await vocab.create(
        collectionId: collection,
        targetText: 'e',
        nativeText: 'f',
      );
      expect(
        (await SqliteLearningRepository(db).forEntry(third.id)).first.id,
        greaterThan(secondItems.last.id),
      );
      expect(
        await SqliteLearningRepository(db).forEntry(first.id),
        hasLength(2),
      );
    },
  );

  test(
    'learning insertion failure rolls back vocabulary and allocator without duplicate misreport',
    () async {
      // A real unrelated UNIQUE violation occurs after one direction was inserted.
      await db.customStatement('CREATE TABLE conflict (value TEXT UNIQUE)');
      await db.customStatement("INSERT INTO conflict VALUES ('x')");
      await db.customStatement(
        "CREATE TRIGGER fail_second BEFORE INSERT ON learning_items WHEN NEW.direction = 'nativeToTarget' BEGIN INSERT INTO conflict VALUES ('x'); END",
      );
      await expectLater(
        SqliteVocabularyRepository(
          db,
        ).create(collectionId: collection, targetText: 'a', nativeText: 'b'),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await db.select(db.vocabularyEntries).get(), isEmpty);
      expect(await db.select(db.learningItems).get(), isEmpty);
      expect(
        (await db.select(db.learningIdentitySequence).getSingle()).nextId,
        1,
      );
    },
  );

  test(
    'ownership, direction and pair constraints enforced; collection cascade removes state',
    () async {
      final entry = await SqliteVocabularyRepository(
        db,
      ).create(collectionId: collection, targetText: 'a', nativeText: 'b');
      final row = (await db.select(db.learningItems).get()).first;
      for (final sql in [
        "INSERT INTO learning_items SELECT 100, entry_id, direction, format_version, card_json FROM learning_items WHERE id = ${row.id}",
        "INSERT INTO learning_items VALUES (101, 'missing', 'targetToNative', 1, '{}')",
        "INSERT INTO learning_items VALUES (102, '${entry.id}', 'wrong', 1, '{}')",
      ]) {
        await expectLater(
          db.customStatement(sql),
          throwsA(isA<sqlite.SqliteException>()),
        );
      }
      await db.customStatement('DELETE FROM collections WHERE id = ?', [
        collection,
      ]);
      expect(await db.select(db.learningItems).get(), isEmpty);
    },
  );

  test(
    'codec preserves full state and rejects corruption/version/identity',
    () async {
      final card = fsrs.Card(
        cardId: 7,
        state: fsrs.State.relearning,
        step: 2,
        stability: 1.5,
        difficulty: 9.0,
        due: now,
        lastReview: now.subtract(const Duration(days: 2)),
      );
      final json = LearningCardCodec.encode(card);
      expect(
        LearningCardCodec.decode(json, expectedId: 7, formatVersion: 1).toMap(),
        card.toMap(),
      );
      expect(
        () => LearningCardCodec.decode(json, expectedId: 8, formatVersion: 1),
        throwsFormatException,
      );
      expect(
        () => LearningCardCodec.decode(json, expectedId: 7, formatVersion: 2),
        throwsFormatException,
      );
      for (final change in <String, Object?>{
        'state': 99,
        'step': -1,
        'difficulty': 11,
        'due': 'bad',
        'cardId': '7',
      }.entries) {
        final broken = {...card.toMap(), change.key: change.value};
        expect(
          () => LearningCardCodec.decode(
            jsonEncode(broken),
            expectedId: 7,
            formatVersion: 1,
          ),
          throwsFormatException,
        );
      }
      await expectLater(
        SqliteLearningRepository(db).saveCard(8, card),
        throwsFormatException,
      );
    },
  );

  for (final version in [1, 2, 3, 4]) {
    test(
      'exported schema $version migrates transactionally and backfills at injected instant',
      () async {
        await db.close();
        final directory = await Directory.systemTemp.createTemp(
          'piko-learning-migration-',
        );
        final file = File('${directory.path}/test.sqlite');
        final schema =
            jsonDecode(
                  await File(
                    'drift_schemas/drift_schema_v$version.json',
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        final old = sqlite.sqlite3.open(file.path);
        for (final group in schema['fixed_sql'] as List) {
          old.execute((group['sql'] as List).single['sql'] as String);
        }
        old.execute("INSERT INTO app_settings VALUES ('locale', 'de')");
        if (version >= 2) {
          old.execute(
            "INSERT INTO collections VALUES ('owner', 'Names', 'ko', 'de')",
          );
        }
        if (version == 3) {
          old.execute(
            "INSERT INTO vocabulary_entries VALUES ('entry', 'owner', '학교', 'Schule')",
          );
        }
        if (version == 4) {
          old.execute(
            "INSERT INTO vocabulary_entries VALUES ('entry', 'owner', '학교', 'Schule', '학교', 'schule')",
          );
        }
        if (version >= 3) {
          old.execute(
            "UPDATE vocabulary_entries SET rowid = 7 WHERE id = 'entry'",
          );
          final keys = version == 4 ? ", 'x', 'y'" : '';
          old.execute(
            "INSERT INTO vocabulary_entries SELECT 'second', 'owner', 'X', 'Y'$keys",
          );
          old.execute(
            "UPDATE vocabulary_entries SET rowid = 19 WHERE id = 'second'",
          );
        }
        old.execute('PRAGMA user_version = $version');
        old.close();
        final migrated = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(now),
        );
        try {
          final items = await SqliteLearningRepository(
            migrated,
          ).forEntry('entry');
          expect(items, hasLength(version >= 3 ? 2 : 0));
          for (final item in items) {
            expect(item.card.due, now);
          }
          if (version >= 2) {
            final owner = await migrated
                .select(migrated.collections)
                .getSingle();
            expect(
              [
                owner.id,
                owner.name,
                owner.targetLanguage,
                owner.nativeLanguage,
              ],
              ['owner', 'Names', 'ko', 'de'],
            );
          }
          if (version >= 3) {
            final rows = await migrated
                .customSelect(
                  'SELECT rowid, id, collection_id, target_text, native_text FROM vocabulary_entries ORDER BY rowid',
                )
                .get();
            expect(rows.map((row) => row.data), [
              {
                'rowid': 7,
                'id': 'entry',
                'collection_id': 'owner',
                'target_text': '학교',
                'native_text': 'Schule',
              },
              {
                'rowid': 19,
                'id': 'second',
                'collection_id': 'owner',
                'target_text': 'X',
                'native_text': 'Y',
              },
            ]);
            expect(
              await migrated.select(migrated.learningItems).get(),
              hasLength(4),
            );
          }
          expect(
            (await migrated.select(migrated.appSettings).getSingle()).value,
            'de',
          );
          expect(
            (await migrated.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            db.schemaVersion,
          );
        } finally {
          await migrated.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
  test(
    'v4 failed backfill rolls back schema and retains original version/data',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp(
        'piko-learning-rollback-',
      );
      final file = File('${directory.path}/test.sqlite');
      final schema =
          jsonDecode(
                await File('drift_schemas/drift_schema_v4.json').readAsString(),
              )
              as Map<String, dynamic>;
      final old = sqlite.sqlite3.open(file.path);
      for (final group in schema['fixed_sql'] as List) {
        old.execute((group['sql'] as List).single['sql'] as String);
      }
      old.execute(
        "INSERT INTO collections VALUES ('owner', 'Names', 'ko', 'de')",
      );
      old.execute(
        "INSERT INTO vocabulary_entries VALUES ('entry', 'owner', '학교', 'Schule', '학교', 'schule')",
      );
      old.execute('PRAGMA user_version = 4');
      old.close();
      final failing = PikoDatabase(NativeDatabase(file), clock: FailingClock());
      try {
        await expectLater(
          failing.select(failing.vocabularyEntries).get(),
          throwsStateError,
        );
      } finally {
        await failing.close();
      }
      final retained = sqlite.sqlite3.open(file.path);
      try {
        expect(
          retained.select('PRAGMA user_version').single['user_version'],
          4,
        );
        expect(
          retained
              .select('SELECT target_text FROM vocabulary_entries')
              .single['target_text'],
          '학교',
        );
        expect(
          retained.select(
            "SELECT name FROM sqlite_master WHERE name = 'learning_items'",
          ),
          isEmpty,
        );
      } finally {
        retained.close();
      }
      final retry = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(now),
      );
      try {
        expect(
          await SqliteLearningRepository(retry).forEntry('entry'),
          hasLength(2),
        );
      } finally {
        await retry.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('incoherent persisted memories fail closed', () async {
    final item = await SqliteVocabularyRepository(
      db,
    ).create(collectionId: collection, targetText: 'a', nativeText: 'b');
    final stored = (await SqliteLearningRepository(db).forEntry(item.id)).first;
    for (final fields in [
      {'cardId': stored.id.toDouble()},
      {'state': 2, 'step': null},
      {'stability': 2.0},
      {'lastReview': now.toIso8601String()},
    ]) {
      final corrupt = jsonEncode({...stored.card.toMap(), ...fields});
      await db.customStatement(
        'UPDATE learning_items SET card_json = ? WHERE id = ?',
        [corrupt, stored.id],
      );
      await expectLater(
        SqliteLearningRepository(db).forEntry(item.id),
        throwsFormatException,
      );
    }
  });
  test(
    'file reopen retains divergent complete direction states and identity',
    () async {
      await db.close();
      final directory = await Directory.systemTemp.createTemp(
        'piko-learning-reopen-',
      );
      final file = File('${directory.path}/test.sqlite');
      var disk = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(now),
      );
      try {
        final owner = await SqliteCollectionsRepository(disk).create(
          name: 'Test',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        final entry = await SqliteVocabularyRepository(
          disk,
        ).create(collectionId: owner.id, targetText: 'a', nativeText: 'b');
        final repository = SqliteLearningRepository(disk);
        final items = await repository.forEntry(entry.id);
        for (var index = 0; index < items.length; index++) {
          await repository.saveCard(
            items[index].id,
            fsrs.Card(
              cardId: items[index].id,
              state: fsrs.State.review,
              stability: 2.5 + index,
              difficulty: 5.0 + index,
              due: now.add(Duration(days: 3 + index)),
              lastReview: now,
            ),
          );
        }
        final before = await repository.forEntry(entry.id);
        await disk.close();
        disk = PikoDatabase(NativeDatabase(file));
        final after = await SqliteLearningRepository(disk).forEntry(entry.id);
        expect(
          after.map(
            (item) => (
              item.id,
              item.entryId,
              item.direction,
              item.formatVersion,
              item.cardJson,
            ),
          ),
          before.map(
            (item) => (
              item.id,
              item.entryId,
              item.direction,
              item.formatVersion,
              item.cardJson,
            ),
          ),
        );
      } finally {
        await disk.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
