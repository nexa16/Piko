import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/vocabulary/inline_vocabulary_edit_controller.dart';
import '../support/controlled_vocabulary_repository.dart';

const original = VocabularyRecord(
  id: 'existing',
  collectionId: 'owner',
  targetText: 'Café',
  nativeText: 'Kaffee',
);
VocabularyRecord changed(String target, String native) => VocabularyRecord(
  id: original.id,
  collectionId: original.collectionId,
  targetText: target,
  nativeText: native,
);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'real SQLite auto-saves both canonical fields atomically without changing identity or directional progress',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = await SqliteCollectionsRepository(db).create(
        name: 'Words',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = SqliteVocabularyRepository(db);
      final entry = await repository.create(
        collectionId: owner.id,
        targetText: 'Café',
        nativeText: 'Kaffee',
      );
      final items = await db.select(db.learningItems).get();
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final card = fsrs.Card(
          cardId: item.id,
          state: index == 0 ? fsrs.State.review : fsrs.State.relearning,
          step: index == 0 ? null : 2,
          stability: 3.5 + index,
          difficulty: 5.5 - index,
          due: DateTime.utc(2026, 10, 15 + index),
          lastReview: DateTime.utc(2026, 10, 13),
        );
        await db.customStatement(
          'UPDATE learning_items SET card_json = ? WHERE id = ?',
          [jsonEncode(card.toMap()), item.id],
        );
      }
      final progress =
          (await db
                  .customSelect('SELECT * FROM learning_items ORDER BY id')
                  .get())
              .map((r) => r.data)
              .toList();
      final controller = InlineVocabularyEditController(
        entry: entry,
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.edit(targetText: ' E\u0301cole ', nativeText: ' Schule ');
      expect(controller.isSaving, isTrue);
      await controller.awaitSavedEdits();
      final saved = (await repository.watchByCollection(owner.id).first).single;
      expect(saved.id, entry.id);
      expect(saved.collectionId, owner.id);
      expect(saved.targetText, 'École');
      expect(saved.nativeText, 'Schule');
      expect(controller.draft.targetText, ' E\u0301cole ');
      expect(controller.draft.nativeText, ' Schule ');
      expect(controller.hasUncommittedChanges, isFalse);
      expect(controller.error, isNull);
      expect(
        (await db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get())
            .map((r) => r.data)
            .toList(),
        progress,
      );
      await repository.create(
        collectionId: owner.id,
        targetText: 'Other',
        nativeText: 'Andere',
      );
      controller.edit(targetText: ' OTHER ', nativeText: ' ANDERE ');
      await controller.awaitSavedEdits();
      expect(controller.error, VocabularyValidation.duplicatePair);
      expect(controller.committed.targetText, 'École');
      expect(controller.draft.targetText, ' OTHER ');
      controller.setNativeText(' \n ');
      await controller.awaitSavedEdits();
      expect(controller.error, VocabularyValidation.requiredNative);
      expect(
        (await repository.watchById(entry.id).first)!.nativeText,
        'Schule',
      );
    },
  );

  test(
    'accepted A then coalesced B still drains after invalid raw C without clearing its validation',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = InlineVocabularyEditController(
        entry: original,
        repository: repository,
      );
      addTearDown(controller.dispose);
      final openingDraft = controller.draft;
      controller.setNativeText('A');
      controller.setNativeText('unused intermediate');
      controller.setNativeText('B');
      controller.setNativeText(' ');
      final rawC = controller.draft;
      expect(openingDraft.nativeText, 'Kaffee');
      expect(repository.updates, hasLength(1));
      expect(controller.error, VocabularyValidation.requiredNative);
      final drained = controller.awaitSavedEdits();
      repository.updates.first.result.complete(changed('Café', 'A'));
      await flush();
      expect(repository.updates, hasLength(2));
      expect(repository.updates.last.native, 'B');
      expect(controller.error, VocabularyValidation.requiredNative);
      repository.updates.last.result.complete(changed('Café', 'B'));
      await drained;
      expect(identical(controller.draft, rawC), isTrue);
      expect(controller.committed.nativeText, 'B');
      expect(controller.error, VocabularyValidation.requiredNative);
      expect(controller.isSaving, isFalse);
      expect(repository.createCalls, 0);
    },
  );

  test(
    'stale failure A cannot replace current required error or invalidate successful B',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = InlineVocabularyEditController(
        entry: original,
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.setNativeText('A');
      controller.setNativeText('B');
      controller.setTargetText(' ');
      repository.updates.first.result.completeError(
        StateError('Old write failed'),
      );
      await flush();
      expect(controller.error, VocabularyValidation.requiredTarget);
      repository.updates.last.result.complete(changed('Café', 'B'));
      await controller.awaitSavedEdits();
      expect(controller.error, VocabularyValidation.requiredTarget);
      expect(controller.draft.targetText, ' ');
      expect(controller.committed.nativeText, 'B');
      controller.setTargetText('Café');
      repository.updates.last.result.complete(changed('Café', 'B'));
      await controller.awaitSavedEdits();
      expect(controller.error, isNull);
    },
  );

  test(
    'current duplicate/storage failure retains raw pair and last committed record; retry is single-flight',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = InlineVocabularyEditController(
        entry: original,
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.edit(targetText: 'Other', nativeText: 'Andere');
      repository.updates.single.result.completeError(
        VocabularyValidation.duplicatePair,
      );
      await controller.awaitSavedEdits();
      expect(controller.error, VocabularyValidation.duplicatePair);
      expect(controller.committed, original);
      controller.setNativeText('Changed');
      repository.updates.last.result.completeError(StateError('Disk failed'));
      await controller.awaitSavedEdits();
      expect(controller.error, isA<StateError>());
      expect(controller.draft.nativeText, 'Changed');
      controller.retry();
      controller.retry();
      expect(repository.updates, hasLength(3));
      repository.updates.last.result.complete(changed('Other', 'Changed'));
      await controller.awaitSavedEdits();
      expect(controller.error, isNull);
      expect(controller.committed.nativeText, 'Changed');
      controller.setNativeText(' ');
      controller.retry();
      expect(repository.updates, hasLength(3));
      expect(controller.error, VocabularyValidation.requiredNative);
    },
  );

  test(
    'canonical-equivalent raw text stays raw but is not an unpersisted change after drain',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = InlineVocabularyEditController(
        entry: original,
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.edit(targetText: ' Cafe\u0301 ', nativeText: ' Kaffee ');
      expect(controller.isSaving, isTrue);
      expect(controller.hasUncommittedChanges, isFalse);
      repository.updates.single.result.complete(original);
      await controller.awaitSavedEdits();
      expect(controller.draft.targetText, ' Cafe\u0301 ');
      expect(controller.hasUncommittedChanges, isFalse);
      expect(controller.error, isNull);
      final revision = controller.revision;
      controller.edit(targetText: ' Cafe\u0301 ', nativeText: ' Kaffee ');
      expect(controller.revision, revision);
      expect(repository.updates, hasLength(1));
    },
  );

  test('identity/owner mismatch cannot replace committed state', () async {
    final repository = ControlledVocabularyRepository();
    final controller = InlineVocabularyEditController(
      entry: original,
      repository: repository,
    );
    addTearDown(controller.dispose);
    controller.setNativeText('edit');
    repository.updates.single.result.complete(
      const VocabularyRecord(
        id: 'foreign',
        collectionId: 'foreign-owner',
        targetText: 'wrong',
        nativeText: 'wrong',
      ),
    );
    await controller.awaitSavedEdits();
    expect(controller.error, isA<StateError>());
    expect(controller.committed, original);
    expect(controller.draft.nativeText, 'edit');
  });

  test(
    'drain includes valid edits accepted while waiting and never freezes ordinary typing',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = InlineVocabularyEditController(
        entry: original,
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.setNativeText('A');
      final draining = controller.awaitSavedEdits();
      controller.setNativeText('B');
      repository.updates.first.result.complete(changed('Café', 'A'));
      await flush();
      controller.setTargetText('École');
      repository.updates[1].result.complete(changed('Café', 'B'));
      await flush();
      expect(repository.updates, hasLength(3));
      repository.updates.last.result.complete(changed('École', 'B'));
      await draining;
      expect(controller.committed.targetText, 'École');
      expect(controller.error, isNull);
    },
  );

  test(
    'disposal clears exposed editing state; accepted/coalesced writes finish without late notifications',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = InlineVocabularyEditController(
        entry: original,
        repository: repository,
      );
      controller.setNativeText('A');
      controller.setNativeText('B');
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      expect(controller.draft.targetText, isEmpty);
      expect(() => controller.committed, throwsStateError);
      expect(() => controller.edit(nativeText: 'new'), throwsStateError);
      expect(() => controller.retry(), throwsStateError);
      repository.updates.first.result.completeError(
        StateError('Old write failed'),
      );
      await flush();
      repository.updates.last.result.complete(changed('Café', 'B'));
      await controller.awaitSavedEdits();
      expect(notifications, 0);
      expect(controller.error, isNull);
      expect(controller.isSaving, isFalse);
      expect(repository.updates, hasLength(2));
    },
  );
}
