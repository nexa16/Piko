import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import '../support/mutable_clock.dart';

Future<List<Map<String, Object?>>> rows(PikoDatabase db, String table) async =>
    (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
        .map((r) => r.data)
        .toList();
Future<CollectionRecord> create(SqliteCollectionsRepository repository) =>
    repository.create(
      name: 'Same',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
void main() {
  test(
    'UUID deletion atomically cascades vocabulary/progress and refreshes all dependent observers; others/settings/highwaters survive',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final collections = SqliteCollectionsRepository(db),
          vocabulary = SqliteVocabularyRepository(db);
      final deleted = await create(collections),
          kept = await create(collections);
      await vocabulary.create(
        collectionId: deleted.id,
        targetText: 'One',
        nativeText: 'Eins',
      );
      final keptEntry = await vocabulary.create(
        collectionId: kept.id,
        targetText: 'Two',
        nativeText: 'Zwei',
      );
      final items = await db.select(db.learningItems).get();
      final learning = SqliteLearningRepository(db);
      for (var index = 0; index < items.length; index++) {
        final now = DateTime.utc(2026, 10, 14);
        await learning.saveCard(
          items[index].id,
          fsrs.Card(
            cardId: items[index].id,
            state: index.isEven ? fsrs.State.review : fsrs.State.relearning,
            step: index.isEven ? null : 1,
            stability: 4.25 + index,
            difficulty: 5.0 + index / 10,
            due: now.add(Duration(days: index + 2)),
            lastReview: now,
          ),
        );
      }
      // Exact kept payload includes both nonfresh divergent full card JSONs.
      expect(jsonDecode(items.first.cardJson), isA<Map<String, dynamic>>());
      final keptVocabulary = (await rows(
        db,
        'vocabulary_entries',
      )).where((r) => r['collection_id'] == kept.id).toList();
      final keptMetadata = (await rows(
        db,
        'collections',
      )).where((r) => r['id'] == kept.id).toList();
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(key: 'interfaceLocale', value: 'de'),
          );
      final settings = await rows(db, 'app_settings'),
          learningSequence = await rows(db, 'learning_identity_sequence'),
          orderSequence = await rows(db, 'vocabulary_order_sequence');
      final keptLearning = (await rows(
        db,
        'learning_items',
      )).where((r) => r['entry_id'] == keptEntry.id).toList();
      final all = StreamIterator(collections.watchAll()),
          detail = StreamIterator(collections.watchById(deleted.id)),
          words = StreamIterator(vocabulary.watchByCollection(deleted.id)),
          progress = StreamIterator(db.select(db.learningItems).watch());
      addTearDown(() async {
        await all.cancel();
        await detail.cancel();
        await words.cancel();
        await progress.cancel();
      });
      await Future.wait([
        all.moveNext(),
        detail.moveNext(),
        words.moveNext(),
        progress.moveNext(),
      ]);
      expect(progress.current.length, 4);
      final next = Future.wait([
        all.moveNext(),
        detail.moveNext(),
        words.moveNext(),
        progress.moveNext(),
      ]);
      await collections.delete(deleted.id);
      await next;
      expect(all.current.single.id, kept.id);
      expect(detail.current, isNull);
      expect(words.current, isEmpty);
      expect(progress.current.length, 2);
      expect(await rows(db, 'learning_items'), keptLearning);
      expect(await rows(db, 'vocabulary_entries'), keptVocabulary);
      expect(await rows(db, 'collections'), keptMetadata);
      expect(await rows(db, 'app_settings'), settings);
      expect(await rows(db, 'learning_identity_sequence'), learningSequence);
      expect(await rows(db, 'vocabulary_order_sequence'), orderSequence);
      await expectLater(
        collections.delete(deleted.id),
        throwsA(CollectionValidation.collectionNotFound),
      );
      expect((await collections.watchAll().first).single.id, kept.id);
    },
  );
  test(
    'outer transaction rollback preserves cascade and emits no transient empty vocabulary/progress',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final collections = SqliteCollectionsRepository(db);
      final vocabulary = SqliteVocabularyRepository(db);
      final owner = await create(collections);
      await vocabulary.create(
        collectionId: owner.id,
        targetText: 'One',
        nativeText: 'Eins',
      );
      final words = <int>[], progress = <int>[];
      final wordsReady = Completer<void>(), progressReady = Completer<void>();
      final a = vocabulary.watchByCollection(owner.id).listen((value) {
        words.add(value.length);
        if (!wordsReady.isCompleted) wordsReady.complete();
      });
      final b = db.select(db.learningItems).watch().listen((value) {
        progress.add(value.length);
        if (!progressReady.isCompleted) progressReady.complete();
      });
      addTearDown(() async {
        await a.cancel();
        await b.cancel();
      });
      await Future.wait([wordsReady.future, progressReady.future]);
      await expectLater(
        db.transaction(() async {
          await collections.delete(owner.id);
          throw StateError('abort after cascades and notification');
        }),
        throwsStateError,
      );
      expect((await collections.watchById(owner.id).first)!.id, owner.id);
      expect((await vocabulary.watchByCollection(owner.id).first).length, 1);
      expect((await rows(db, 'learning_items')).length, 2);
      expect(words, everyElement(1));
      expect(progress, everyElement(2));
    },
  );
  test(
    'confirmed cascade persists after file reopen without resetting identity allocators',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-collection-delete-',
      );
      final file = File('${directory.path}/test.sqlite');
      var db = PikoDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });
      final collections = SqliteCollectionsRepository(db),
          vocabulary = SqliteVocabularyRepository(db);
      final owner = await create(collections);
      await vocabulary.create(
        collectionId: owner.id,
        targetText: 'One',
        nativeText: 'Eins',
      );
      final learningSequence = await rows(db, 'learning_identity_sequence'),
          orderSequence = await rows(db, 'vocabulary_order_sequence');
      await collections.delete(owner.id);
      await db.close();
      db = PikoDatabase(NativeDatabase(file));
      expect(await rows(db, 'collections'), isEmpty);
      expect(await rows(db, 'vocabulary_entries'), isEmpty);
      expect(await rows(db, 'learning_items'), isEmpty);
      expect(await rows(db, 'learning_identity_sequence'), learningSequence);
      expect(await rows(db, 'vocabulary_order_sequence'), orderSequence);
    },
  );
  test(
    'an older vocabulary Undo cannot resurrect a deleted Collection even if a same-named Collection is recreated',
    () async {
      final db = PikoDatabase(
        NativeDatabase.memory(),
        clock: MutablePikoClock(DateTime.utc(2026, 10, 14)),
      );
      addTearDown(db.close);
      final collections = SqliteCollectionsRepository(db),
          vocabulary = SqliteVocabularyRepository(db);
      final owner = await create(collections);
      final entry = await vocabulary.create(
        collectionId: owner.id,
        targetText: 'One',
        nativeText: 'Eins',
      );
      final service = SqliteVocabularyDeletionService(db);
      addTearDown(service.dispose);
      final receipt = await service.delete(entry.id);
      await collections.delete(owner.id);
      final other = await create(collections);
      await expectLater(
        service.restore(receipt),
        throwsA(VocabularyUndoFailure.collectionNotFound),
      );
      expect(other.id, isNot(owner.id));
      expect(await rows(db, 'vocabulary_entries'), isEmpty);
      expect(await rows(db, 'learning_items'), isEmpty);
    },
  );
}
