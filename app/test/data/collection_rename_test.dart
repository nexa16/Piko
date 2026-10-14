import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import '../support/mutable_clock.dart';

Future<List<CollectionRecord>> seed(PikoDatabase db) async {
  final collections = SqliteCollectionsRepository(db);
  final first = await collections.create(
    name: 'First',
    targetLanguage: VocabularyLanguage.french,
    nativeLanguage: VocabularyLanguage.german,
  );
  final second = await collections.create(
    name: 'Second',
    targetLanguage: VocabularyLanguage.english,
    nativeLanguage: VocabularyLanguage.german,
  );
  final vocabulary = SqliteVocabularyRepository(db);
  final legacy = await vocabulary.create(
    collectionId: first.id,
    targetText: 'Café',
    nativeText: 'Kaffee',
  );
  await db.customStatement(
    'UPDATE vocabulary_entries SET target_text = ? WHERE id = ?',
    ['  Cafe\u0301  ', legacy.id],
  );
  await vocabulary.create(
    collectionId: first.id,
    targetText: 'poire',
    nativeText: 'Birne',
  );
  await vocabulary.create(
    collectionId: second.id,
    targetText: 'pear',
    nativeText: 'Birne',
  );
  final learning = SqliteLearningRepository(db);
  final items = await learning.forEntry(legacy.id);
  for (var i = 0; i < items.length; i++) {
    final now = DateTime.utc(2026, 10, 14);
    await learning.saveCard(
      items[i].id,
      fsrs.Card(
        cardId: items[i].id,
        state: fsrs.State.review,
        stability: 3.25 + i * 8,
        difficulty: 4.5 + i,
        due: now.add(Duration(days: i + 3)),
        lastReview: now,
      ),
    );
  }
  await db.customStatement(
    "INSERT INTO app_settings (key, value) VALUES ('locale', 'de')",
  );
  return [first, second];
}

/// Exact persisted rows, including all stable IDs, display bytes and allocators.
Future<Map<String, Object>> snapshot(
  PikoDatabase db, {
  bool omitNames = false,
}) async {
  final result = <String, Object>{};
  for (final table in [
    'collections',
    'vocabulary_entries',
    'learning_items',
    'learning_identity_sequence',
    'vocabulary_order_sequence',
    'app_settings',
  ]) {
    final rows = await db
        .customSelect(
          'SELECT rowid AS persisted_rowid, * FROM $table ORDER BY rowid',
        )
        .get();
    result[table] = rows.map((row) {
      final fields = Map<String, Object?>.of(row.data);
      if (table == 'collections' && omitNames) fields.remove('name');
      return fields;
    }).toList();
  }
  return result;
}

void main() {
  test(
    'rename alone changes trimmed name, reactive observers and file reopen retain exact related rows',
    () async {
      final directory = await Directory.systemTemp.createTemp('piko-rename-');
      final file = File('${directory.path}/fixture.sqlite');
      var db = PikoDatabase(NativeDatabase(file));
      final subscriptions = <StreamSubscription<Object?>>[];
      try {
        final owners = await seed(db);
        final repository = SqliteCollectionsRepository(db);
        final before = await snapshot(db, omitNames: true);
        final allInitial = Completer<void>(), detailInitial = Completer<void>();
        final allRenamed = Completer<List<CollectionRecord>>();
        final detailRenamed = Completer<CollectionRecord>();
        subscriptions.add(
          repository.watchAll().listen((rows) {
            if (!allInitial.isCompleted) allInitial.complete();
            if (rows.first.name == 'Second' && !allRenamed.isCompleted) {
              allRenamed.complete(rows);
            }
          }),
        );
        subscriptions.add(
          repository.watchById(owners.first.id).listen((record) {
            if (!detailInitial.isCompleted) detailInitial.complete();
            if (record?.name == 'Second' && !detailRenamed.isCompleted) {
              detailRenamed.complete(record!);
            }
          }),
        );
        await Future.wait([allInitial.future, detailInitial.future]);
        final renamed = await repository.rename(
          id: owners.first.id,
          name: '\u2003 Second \u00a0',
        );
        expect(renamed.id, owners.first.id);
        expect(renamed.name, 'Second');
        expect(renamed.targetLanguage, VocabularyLanguage.french);
        expect(renamed.nativeLanguage, VocabularyLanguage.german);
        final listed = await allRenamed.future;
        expect(listed.map((row) => row.id), owners.map((row) => row.id));
        expect(listed.map((row) => row.name), ['Second', 'Second']);
        expect((await detailRenamed.future).id, owners.first.id);
        expect(await snapshot(db, omitNames: true), before);
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
        await db.close();
        db = PikoDatabase(NativeDatabase(file));
        expect(
          (await SqliteCollectionsRepository(
            db,
          ).watchById(renamed.id).first)!.name,
          'Second',
        );
        expect(await snapshot(db, omitNames: true), before);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'required and missing names fail typed without writes; same-name rename is allowed',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = (await seed(db)).first;
      final repository = SqliteCollectionsRepository(db);
      final before = await snapshot(db);
      await expectLater(
        repository.rename(id: owner.id, name: '\u00a0\t\n '),
        throwsA(CollectionValidation.requiredName),
      );
      await expectLater(
        repository.rename(id: 'missing', name: 'Valid'),
        throwsA(CollectionValidation.collectionNotFound),
      );
      expect(await snapshot(db), before);
      expect(
        (await repository.rename(id: owner.id, name: ' First ')).id,
        owner.id,
      );
      expect(await snapshot(db), before);
    },
  );

  test(
    'post-update storage failure rolls back name and trigger side effects; retry succeeds',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = (await seed(db)).first;
      final repository = SqliteCollectionsRepository(db);
      final before = await snapshot(db);
      final beforeWithoutNames = await snapshot(db, omitNames: true);
      final initial = Completer<void>();
      final observedNames = <String>[];
      final subscription = repository.watchById(owner.id).listen((row) {
        observedNames.add(row!.name);
        if (!initial.isCompleted) initial.complete();
      });
      addTearDown(subscription.cancel);
      await initial.future;
      // FAIL leaves statement changes pending, requiring the repository transaction
      // to roll back both the renamed row and a real dependent-row side effect.
      await db.customStatement(
        "CREATE TRIGGER rename_failure AFTER UPDATE OF name ON collections BEGIN UPDATE vocabulary_entries SET native_text = 'Injected' WHERE collection_id = NEW.id; SELECT RAISE(FAIL, 'Injected rename failure'); END",
      );
      await expectLater(
        repository.rename(id: owner.id, name: 'After'),
        throwsA(isA<SqliteException>()),
      );
      expect(await snapshot(db), before);
      expect(observedNames, everyElement('First'));
      expect((await repository.watchById(owner.id).first)!.name, 'First');
      await db.customStatement('DROP TRIGGER rename_failure');
      expect(
        (await repository.rename(id: owner.id, name: 'After')).name,
        'After',
      );
      expect(await snapshot(db, omitNames: true), beforeWithoutNames);
    },
  );

  test(
    'rename retains opening rollback and existing deletion Undo ownership capabilities',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = (await seed(db)).first;
      final repository = SqliteCollectionsRepository(db);
      final vocabulary = SqliteVocabularyRepository(db);
      final deletion = SqliteVocabularyDeletionService(
        db,
        clock: MutablePikoClock(DateTime.utc(2026, 10, 14)),
      );
      addTearDown(deletion.dispose);
      final original =
          (await vocabulary.watchByCollection(owner.id).first).first;
      final opening = await vocabulary.captureOpeningSnapshot(
        entryId: original.id,
        collectionId: owner.id,
      );
      final before = await snapshot(db, omitNames: true);
      await vocabulary.update(
        id: original.id,
        targetText: 'Changed',
        nativeText: 'Geändert',
      );
      await repository.rename(id: owner.id, name: 'Renamed');
      await vocabulary.restoreOpeningSnapshot(opening);
      expect(await snapshot(db, omitNames: true), before);
      final receipt = await deletion.delete(original.id);
      await repository.rename(id: owner.id, name: 'Renamed again');
      final restored = await deletion.restore(receipt);
      expect(restored.id, original.id);
      expect(restored.collectionId, owner.id);
      expect(await snapshot(db, omitNames: true), before);
    },
  );
}
