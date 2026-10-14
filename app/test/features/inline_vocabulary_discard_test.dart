import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/vocabulary/inline_vocabulary_edit_controller.dart';
import '../support/controlled_vocabulary_repository.dart';
import '../support/vocabulary_opening_snapshot.dart';

const original = VocabularyRecord(
  id: 'one',
  collectionId: 'owner',
  targetText: 'A',
  nativeText: 'B',
);
VocabularyRecord pair(String native) => VocabularyRecord(
  id: 'one',
  collectionId: 'owner',
  targetText: 'A',
  nativeText: native,
);
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'discard restores exact legacy bytes and keys; identity/progress/order survive file reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('piko-discard-');
      final file = File('${dir.path}/test.sqlite');
      var db = PikoDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      var repository = SqliteVocabularyRepository(db);
      final owner = await SqliteCollectionsRepository(db).create(
        name: 'Words',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final entry = await repository.create(
        collectionId: owner.id,
        targetText: 'École',
        nativeText: 'Schule',
      );
      await db.customStatement(
        'UPDATE vocabulary_entries SET target_text = ?, native_text = ? WHERE id = ?',
        ['  E\u0301cole ', ' Schule  ', entry.id],
      );
      final cards = await db.select(db.learningItems).get();
      for (var index = 0; index < cards.length; index++) {
        final card = fsrs.Card(
          cardId: cards[index].id,
          state: index == 0 ? fsrs.State.review : fsrs.State.relearning,
          step: index == 0 ? null : 2,
          stability: 4.5 + index,
          difficulty: 6.5 - index,
          due: DateTime.utc(2026, 10, 16 + index),
          lastReview: DateTime.utc(2026, 10, 14),
        );
        await db.customStatement(
          'UPDATE learning_items SET card_json = ? WHERE id = ?',
          [jsonEncode(card.toMap()), card.cardId],
        );
      }
      Future<List<Map<String, dynamic>>> allocators() async => [
        (await db
                .customSelect('SELECT * FROM learning_identity_sequence')
                .getSingle())
            .data,
        (await db
                .customSelect('SELECT * FROM vocabulary_order_sequence')
                .getSingle())
            .data,
      ];
      final originalAllocators = await allocators();
      final before =
          (await db
                  .customSelect('SELECT rowid, * FROM vocabulary_entries')
                  .getSingle())
              .data;
      final learning =
          (await db
                  .customSelect('SELECT * FROM learning_items ORDER BY id')
                  .get())
              .map((r) => r.data)
              .toList();
      final controller = await InlineVocabularyEditController.open(
        entryId: entry.id,
        collectionId: owner.id,
        repository: repository,
      );
      controller.edit(targetText: 'Changed', nativeText: 'Anders');
      await controller.awaitSavedEdits();
      controller.setNativeText(' ');
      final restored = await controller.discard();
      expect(restored.targetText, '  E\u0301cole ');
      expect(restored.nativeText, ' Schule  ');
      expect(controller.error, isNull);
      expect(controller.changedSinceOpening, isFalse);
      controller.dispose();
      await db.close();
      db = PikoDatabase(NativeDatabase(file));
      expect(await allocators(), originalAllocators);
      expect(
        (await db
                .customSelect('SELECT rowid, * FROM vocabulary_entries')
                .getSingle())
            .data,
        before,
      );
      expect(
        (await db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get())
            .map((r) => r.data)
            .toList(),
        learning,
      );
    },
  );

  test(
    'issuer/owner forgery, duplicate rollback, deletion cannot alter or resurrect entries',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = SqliteVocabularyRepository(db);
      final owner = await SqliteCollectionsRepository(db).create(
        name: 'Words',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final entry = await repository.create(
        collectionId: owner.id,
        targetText: 'A',
        nativeText: 'B',
      );
      await expectLater(
        repository.captureOpeningSnapshot(
          entryId: entry.id,
          collectionId: 'foreign',
        ),
        throwsA(VocabularyValidation.entryNotFound),
      );
      final opening = await repository.captureOpeningSnapshot(
        entryId: entry.id,
        collectionId: owner.id,
      );
      expect(
        () => repository.restoreOpeningSnapshot(TestOpeningSnapshot(entry)),
        throwsStateError,
      );
      expect(
        () => SqliteVocabularyRepository(db).restoreOpeningSnapshot(opening),
        throwsStateError,
      );
      final controller = await InlineVocabularyEditController.open(
        entryId: entry.id,
        collectionId: owner.id,
        repository: repository,
      );
      controller.setNativeText('C');
      await controller.awaitSavedEdits();
      final conflict = await repository.create(
        collectionId: owner.id,
        targetText: 'A',
        nativeText: 'B',
      );
      await expectLater(
        controller.discard(),
        throwsA(VocabularyValidation.duplicatePair),
      );
      expect(controller.draft.nativeText, 'C');
      expect(controller.error, isNull);
      expect(controller.discardError, VocabularyValidation.duplicatePair);
      await (db.delete(
        db.vocabularyEntries,
      )..where((row) => row.id.equals(conflict.id))).go();
      expect((await controller.discard()).nativeText, 'B');
      controller.dispose();
      await (db.delete(
        db.collections,
      )..where((row) => row.id.equals(owner.id))).go();
      await expectLater(
        repository.restoreOpeningSnapshot(opening),
        throwsA(VocabularyValidation.entryNotFound),
      );
      expect(await db.select(db.vocabularyEntries).get(), isEmpty);
    },
  );

  test(
    'discard singleflight drains accepted saves then rollback, retains retry snapshot on failure',
    () async {
      final repository = ControlledVocabularyRepository()
        ..openingRecord = original;
      final c = await InlineVocabularyEditController.open(
        entryId: original.id,
        collectionId: original.collectionId,
        repository: repository,
      );
      addTearDown(c.dispose);
      c.setNativeText('C');
      c.setNativeText('D');
      final discard = c.discard();
      expect(identical(c.discard(), discard), isTrue);
      expect(() => c.setNativeText('E'), throwsStateError);
      final failure = expectLater(discard, throwsStateError);
      repository.updates[0].result.complete(pair('C'));
      await tick();
      repository.updates[1].result.complete(pair('D'));
      await tick();
      expect(repository.updates[2].native, 'B');
      repository.updates[2].result.completeError(StateError('restore failed'));
      await failure;
      expect(c.draft.nativeText, 'D');
      expect(c.error, isNull);
      expect(c.discardError, isStateError);
      final retry = c.discard();
      await tick();
      repository.updates[3].result.complete(original);
      await retry;
      expect(c.draft.nativeText, 'B');
    },
  );

  test(
    'listener disposal cannot strand accepted discard and exposes no opening text',
    () async {
      final repository = ControlledVocabularyRepository()
        ..openingRecord = original;
      final c = await InlineVocabularyEditController.open(
        entryId: original.id,
        collectionId: original.collectionId,
        repository: repository,
      );
      var notices = 0;
      c.addListener(() {
        notices++;
        scheduleMicrotask(c.dispose);
      });
      final result = c.discard();
      await tick();
      expect(() => c.opening, throwsStateError);
      expect(() => c.changedSinceOpening, throwsStateError);
      final drain = c.awaitSavedEdits();
      repository.updates.single.result.complete(original);
      await result;
      await drain;
      expect(notices, 1);
      expect(c.draft.targetText, isEmpty);
    },
  );

  test(
    'pending and failed revert keep rollback available even when raw input equals opening',
    () async {
      final repository = ControlledVocabularyRepository()
        ..openingRecord = original;
      final c = await InlineVocabularyEditController.open(
        entryId: original.id,
        collectionId: original.collectionId,
        repository: repository,
      );
      addTearDown(c.dispose);
      c.setNativeText('C');
      c.setNativeText('B');
      expect(c.changedSinceOpening, isTrue);
      repository.updates[0].result.complete(pair('C'));
      await tick();
      repository.updates[1].result.completeError(StateError('revert failed'));
      await c.awaitSavedEdits();
      expect(c.draft.nativeText, 'B');
      expect(c.committed.nativeText, 'C');
      expect(c.changedSinceOpening, isTrue);
    },
  );
}
