import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/core/clock.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import '../support/mutable_clock.dart';

class ScriptedClock implements PikoClock {
  ScriptedClock(this.values);
  final List<Object> values;
  @override
  DateTime now() {
    final value = values.removeAt(0);
    if (value is DateTime) return value;
    throw value;
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 14, 5);
  late PikoDatabase database;
  late MutablePikoClock clock;
  late String owner;
  late SqliteVocabularyRepository vocabulary;
  late SqliteVocabularyDeletionService deletion;
  Future<VocabularyRecord> create(String target, String native) => vocabulary
      .create(collectionId: owner, targetText: target, nativeText: native);
  Future<List<Map<String, Object?>>> entries() async =>
      (await database
              .customSelect(
                'SELECT rowid AS original_rowid,* FROM vocabulary_entries ORDER BY rowid',
              )
              .get())
          .map((row) => row.data)
          .toList();
  Future<List<Map<String, Object?>>> learning() async =>
      (await database
              .customSelect('SELECT * FROM learning_items ORDER BY id')
              .get())
          .map((row) => row.data)
          .toList();
  setUp(() async {
    clock = MutablePikoClock(now);
    database = PikoDatabase(NativeDatabase.memory(), clock: clock);
    owner = (await SqliteCollectionsRepository(database).create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    )).id;
    vocabulary = SqliteVocabularyRepository(database);
    deletion = SqliteVocabularyDeletionService(database);
  });
  tearDown(() async {
    deletion.dispose();
    await database.close();
  });

  test(
    'existing vocabulary and learning observers see delete and exact restoration',
    () async {
      final entry = await create('One', 'Eins');
      final entryRemoved = Completer<void>(), entryRestored = Completer<void>();
      final learningRemoved = Completer<void>(),
          learningRestored = Completer<void>();
      var restoring = false;
      final words = vocabulary.watchByCollection(owner).listen((rows) {
        if (rows.isEmpty && !entryRemoved.isCompleted) entryRemoved.complete();
        if (restoring && rows.length == 1 && !entryRestored.isCompleted) {
          expect(rows.single.id, entry.id);
          entryRestored.complete();
        }
      });
      final states = database.select(database.learningItems).watch().listen((
        rows,
      ) {
        if (rows.isEmpty && !learningRemoved.isCompleted) {
          learningRemoved.complete();
        }
        if (restoring && rows.length == 2 && !learningRestored.isCompleted) {
          learningRestored.complete();
        }
      });
      addTearDown(words.cancel);
      addTearDown(states.cancel);
      expect(await vocabulary.watchByCollection(owner).first, hasLength(1));
      expect(
        await database.select(database.learningItems).watch().first,
        hasLength(2),
      );
      final receipt = await deletion.delete(entry.id);
      await Future.wait([entryRemoved.future, learningRemoved.future]);
      restoring = true;
      await deletion.restore(receipt);
      await Future.wait([entryRestored.future, learningRestored.future]);
      final next = await create('Two', 'Zwei');
      expect(
        (await vocabulary.watchByCollection(owner).first).map((r) => r.id),
        [entry.id, next.id],
      );
    },
  );

  test(
    'delete/Undo restores every raw column and divergent learning JSON byte for byte',
    () async {
      final entry = await create('Café', 'Kaffee');
      await (database.update(
        database.vocabularyEntries,
      )..where((r) => r.id.equals(entry.id))).write(
        const VocabularyEntriesCompanion(
          targetText: Value(' Cafe\u0301 '),
          nativeText: Value(' Kaffee '),
        ),
      );
      final items = await database.select(database.learningItems).get();
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final card = fsrs.Card(
          cardId: item.id,
          state: index == 0 ? fsrs.State.review : fsrs.State.relearning,
          step: index == 0 ? null : 2,
          stability: 3.25 + index,
          difficulty: 5.75 - index,
          due: now.add(Duration(days: index + 2)),
          lastReview: now.subtract(Duration(days: index + 1)),
        );
        final json = const JsonEncoder.withIndent('  ').convert(card.toMap());
        await (database.update(database.learningItems)
              ..where((r) => r.id.equals(item.id)))
            .write(LearningItemsCompanion(cardJson: Value(json)));
      }
      final beforeEntries = await entries();
      final beforeLearning = await learning();
      final receipt = await deletion.delete(entry.id);
      expect(receipt.entry.id, entry.id);
      expect(receipt.entry.targetText, ' Cafe\u0301 ');
      expect(receipt.expiresAt, now.add(const Duration(seconds: 8)));
      expect(await entries(), isEmpty);
      expect(await learning(), isEmpty);
      expect(deletion.canUndo(receipt), isTrue);
      final restored = await deletion.restore(receipt);
      expect(restored.id, entry.id);
      expect(await entries(), beforeEntries);
      expect(await learning(), beforeLearning);
      expect(
        () => deletion.restore(receipt),
        throwsA(VocabularyUndoFailure.alreadyUsed),
      );
      expect(deletion.canUndo(receipt), isFalse);
    },
  );

  test(
    'sole/tail row deletion then creation retains original order and nonreused learning IDs',
    () async {
      final first = await create('One', 'Eins');
      final receipt = await deletion.delete(first.id);
      final second = await SqliteVocabularyRepository(
        database,
      ).create(collectionId: owner, targetText: 'Two', nativeText: 'Zwei');
      expect((await entries()).single['original_rowid'], 2);
      await deletion.restore(receipt);
      expect((await entries()).map((r) => r['id']), [first.id, second.id]);
      expect((await learning()).map((r) => r['id']), [1, 2, 3, 4]);
      final tail = await deletion.delete(second.id);
      final third = await create('Three', 'Drei');
      await deletion.restore(tail);
      expect((await entries()).map((r) => r['id']), [
        first.id,
        second.id,
        third.id,
      ]);
    },
  );

  test(
    'strict deadline and observed expiry cannot revive after backwards clock',
    () async {
      final first = await create('One', 'Eins');
      final second = await create('Two', 'Zwei');
      final usable = await deletion.delete(first.id);
      final expired = await deletion.delete(second.id);
      clock.advance(const Duration(milliseconds: 7999));
      await deletion.restore(usable);
      clock.advance(const Duration(milliseconds: 1));
      deletion.expireUndo();
      expect(deletion.canUndo(expired), isFalse);
      expect(
        () => deletion.restore(expired),
        throwsA(VocabularyUndoFailure.expired),
      );
      clock.set(now.subtract(const Duration(days: 1)));
      expect(
        () => deletion.restore(expired),
        throwsA(VocabularyUndoFailure.expired),
      );
      expect((await entries()).single['id'], first.id);
    },
  );

  test(
    'concurrent Undo shares one result and receipts remain issuer-bound',
    () async {
      final entry = await create('One', 'Eins');
      final receipt = await deletion.delete(entry.id);
      final other = SqliteVocabularyDeletionService(database);
      addTearDown(other.dispose);
      expect(other.canUndo(receipt), isFalse);
      expect(
        () => other.restore(receipt),
        throwsA(VocabularyUndoFailure.invalidReceipt),
      );
      final first = deletion.restore(receipt);
      final second = deletion.restore(receipt);
      expect(identical(first, second), isTrue);
      expect(deletion.canUndo(receipt), isFalse);
      await Future.wait([first, second]);
      expect(await entries(), hasLength(1));
      expect(await learning(), hasLength(2));
    },
  );

  test(
    'partial restore failure rolls back every row and allows transient retry',
    () async {
      final entry = await create('One', 'Eins');
      final beforeEntries = await entries();
      final beforeLearning = await learning();
      final receipt = await deletion.delete(entry.id);
      await database.customStatement(
        "CREATE TRIGGER fail_learning_restore BEFORE INSERT ON learning_items BEGIN SELECT RAISE(ABORT,'Injected restore failure'); END",
      );
      await expectLater(
        deletion.restore(receipt),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await entries(), isEmpty);
      expect(await learning(), isEmpty);
      expect(deletion.canUndo(receipt), isTrue);
      await database.customStatement('DROP TRIGGER fail_learning_restore');
      await deletion.restore(receipt);
      expect(await entries(), beforeEntries);
      expect(await learning(), beforeLearning);
    },
  );

  test(
    'collection deletion never resurrects owner or leaves partial restored rows',
    () async {
      final entry = await create('One', 'Eins');
      final receipt = await deletion.delete(entry.id);
      await (database.delete(
        database.collections,
      )..where((r) => r.id.equals(owner))).go();
      await expectLater(
        deletion.restore(receipt),
        throwsA(VocabularyUndoFailure.collectionNotFound),
      );
      expect(await entries(), isEmpty);
      expect(await learning(), isEmpty);
      expect(await database.select(database.collections).get(), isEmpty);
    },
  );

  test(
    'new normalized pair blocks Undo without overwrite, and receipt retries after conflict is removed',
    () async {
      final entry = await create('Café', 'Kaffee');
      final receipt = await deletion.delete(entry.id);
      final replacement = await create(' CAFE\u0301 ', 'KAFFEE');
      final retained = await learning();
      await expectLater(
        deletion.restore(receipt),
        throwsA(VocabularyUndoFailure.duplicatePair),
      );
      expect((await entries()).single['id'], replacement.id);
      expect(await learning(), retained);
      expect(deletion.canUndo(receipt), isTrue);
      final discarded = await deletion.delete(replacement.id);
      deletion.forget(discarded);
      await deletion.restore(receipt);
      expect((await entries()).single['id'], entry.id);
    },
  );

  test(
    'conflicting original rowid fails safely without overwriting the new identity',
    () async {
      final entry = await create('One', 'Eins');
      final receipt = await deletion.delete(entry.id);
      await database.customStatement(
        "INSERT INTO vocabulary_entries(rowid,id,collection_id,target_text,native_text,target_key,native_key) VALUES(1,'conflict',?,'Other','Andere','other','andere')",
        [owner],
      );
      await expectLater(
        deletion.restore(receipt),
        throwsA(VocabularyUndoFailure.identityConflict),
      );
      expect((await entries()).single['id'], 'conflict');
      expect(await learning(), isEmpty);
    },
  );

  test(
    'competing edit/delete and repeated delete preserve a consistent committed snapshot',
    () async {
      final entry = await create('One', 'Eins');
      final edited = vocabulary.update(
        id: entry.id,
        targetText: 'Edited',
        nativeText: 'Bearbeitet',
      );
      final removed = deletion.delete(entry.id);
      await edited;
      final receipt = await removed;
      expect(receipt.entry.targetText, 'Edited');
      expect(await entries(), isEmpty);
      await expectLater(
        deletion.delete(entry.id),
        throwsA(VocabularyValidation.entryNotFound),
      );
      await expectLater(
        vocabulary.update(id: entry.id, targetText: 'Late', nativeText: 'Spät'),
        throwsA(VocabularyValidation.entryNotFound),
      );
      await deletion.restore(receipt);
      expect((await entries()).single['target_text'], 'Edited');
    },
  );

  test(
    'forget/dispose release capabilities without changing already deleted rows',
    () async {
      final first = await create('One', 'Eins');
      final forgotten = await deletion.delete(first.id);
      deletion.forget(forgotten);
      expect(deletion.canUndo(forgotten), isFalse);
      expect(
        () => deletion.restore(forgotten),
        throwsA(VocabularyUndoFailure.invalidReceipt),
      );
      final second = await create('Two', 'Zwei');
      final receipt = await deletion.delete(second.id);
      deletion.dispose();
      expect(deletion.canUndo(receipt), isFalse);
      expect(() => deletion.restore(receipt), throwsStateError);
      expect(await entries(), isEmpty);
      expect(await learning(), isEmpty);
    },
  );

  test(
    'fallible deadline clock rolls deletion back rather than losing its receipt',
    () async {
      final entry = await create('One', 'Eins');
      final beforeEntries = await entries();
      final beforeLearning = await learning();
      final service = SqliteVocabularyDeletionService(
        database,
        clock: ScriptedClock([now, StateError('Clock failed')]),
      );
      addTearDown(service.dispose);
      await expectLater(service.delete(entry.id), throwsStateError);
      expect(await entries(), beforeEntries);
      expect(await learning(), beforeLearning);
    },
  );

  test(
    'transaction-time expiry stays terminal even when cleanup clock goes backwards',
    () async {
      final entry = await create('One', 'Eins');
      final service = SqliteVocabularyDeletionService(
        database,
        clock: ScriptedClock([
          now,
          now,
          now,
          now.add(const Duration(seconds: 8)),
          now.subtract(const Duration(days: 1)),
          now.subtract(const Duration(days: 1)),
        ]),
      );
      addTearDown(service.dispose);
      final receipt = await service.delete(entry.id);
      await expectLater(
        service.restore(receipt),
        throwsA(VocabularyUndoFailure.expired),
      );
      expect(service.canUndo(receipt), isFalse);
      expect(await entries(), isEmpty);
    },
  );

  test(
    'clock cleanup failure produces no late unhandled error and forgets failed restore',
    () async {
      final entry = await create('One', 'Eins');
      final service = SqliteVocabularyDeletionService(
        database,
        clock: ScriptedClock([
          now,
          now,
          now,
          now,
          StateError('Cleanup clock failed'),
        ]),
      );
      addTearDown(service.dispose);
      final receipt = await service.delete(entry.id);
      await database.customStatement(
        "CREATE TRIGGER fail_learning_restore BEFORE INSERT ON learning_items BEGIN SELECT RAISE(ABORT,'Injected failure'); END",
      );
      await expectLater(
        service.restore(receipt),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(
        () => service.restore(receipt),
        throwsA(VocabularyUndoFailure.expired),
      );
    },
  );

  test(
    'schema5 migration retains all rows and initializes durable highwater across reopen',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'piko-delete-order-test-',
      );
      final file = File('${directory.path}/test.sqlite');
      final old = sqlite.sqlite3.open(file.path);
      final schema =
          jsonDecode(
                await File('drift_schemas/drift_schema_v5.json').readAsString(),
              )
              as Map<String, dynamic>;
      try {
        for (final table in schema['fixed_sql'] as List<dynamic>) {
          old.execute((table['sql'] as List<dynamic>).single['sql'] as String);
        }
        old.execute("INSERT INTO app_settings VALUES('locale','de')");
        old.execute(
          "INSERT INTO collections VALUES('owner','Words','fr','de')",
        );
        old.execute(
          "INSERT INTO vocabulary_entries(rowid,id,collection_id,target_text,native_text,target_key,native_key) VALUES(47,'original','owner','One','Eins','one','eins')",
        );
        old.execute('INSERT INTO learning_identity_sequence VALUES(1,3)');
        for (var id = 1; id <= 2; id++) {
          old.execute('INSERT INTO learning_items VALUES(?,?,?,?,?)', [
            id,
            'original',
            id == 1 ? 'targetToNative' : 'nativeToTarget',
            1,
            jsonEncode(fsrs.Card(cardId: id, due: now).toMap()),
          ]);
        }
        old.execute('PRAGMA user_version=5');
      } finally {
        old.close();
      }
      var db = PikoDatabase(NativeDatabase(file), clock: MutablePikoClock(now));
      try {
        final rows = await db
            .customSelect(
              'SELECT rowid AS original_rowid,* FROM vocabulary_entries',
            )
            .get();
        expect(rows.single.read<int>('original_rowid'), 47);
        expect(
          (await db.select(db.vocabularyOrderSequence).getSingle()).nextRowId,
          48,
        );
        expect(
          (await (db.select(
            db.appSettings,
          )..where((row) => row.key.equals('locale'))).getSingle()).value,
          'de',
        );
        expect(await db.select(db.learningItems).get(), hasLength(2));
        final service = SqliteVocabularyDeletionService(db);
        final receipt = await service.delete('original');
        service.forget(receipt);
        service.dispose();
        await db.close();
        db = PikoDatabase(NativeDatabase(file), clock: MutablePikoClock(now));
        await SqliteVocabularyRepository(
          db,
        ).create(collectionId: 'owner', targetText: 'Two', nativeText: 'Zwei');
        expect(
          (await db
                  .customSelect(
                    'SELECT rowid AS original_rowid FROM vocabulary_entries',
                  )
                  .getSingle())
              .read<int>('original_rowid'),
          48,
        );
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          db.schemaVersion,
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
