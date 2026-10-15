import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import '../support/controlled_vocabulary_repository.dart';

VocabularyRecord saved(String id, String target, String native) =>
    VocabularyRecord(
      id: id,
      collectionId: 'owner',
      targetText: target,
      nativeText: native,
    );

Future<EntrySessionController> seeded(
  ControlledVocabularyRepository repository, {
  bool second = false,
}) async {
  final controller = EntrySessionController(
    collectionId: 'owner',
    repository: repository,
  );
  controller.setTargetText('One');
  controller.setNativeText('Eins');
  final first = controller.confirmAndNext();
  repository.pending.complete(saved('first', 'One', 'Eins'));
  await first;
  if (second) {
    repository.pending = Completer<VocabularyRecord>();
    controller.setTargetText('Two');
    controller.setNativeText('Zwei');
    final next = controller.confirmAndNext();
    repository.pending.complete(saved('second', 'Two', 'Zwei'));
    await next;
  }
  return controller;
}

void main() {
  test(
    'unchanged failed saved edit can retry once, while invalid buffers cannot write',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = await seeded(repository);
      addTearDown(controller.dispose);
      controller.editSavedEntry('first', targetText: 'Unchanged retry');
      repository.updates.first.result.completeError(StateError('Disk full'));
      await controller.awaitSavedEdits();
      final draft = controller.savedEntryState('first').draft;
      controller.retrySavedEntry('first');
      controller.retrySavedEntry('first');
      expect(repository.updates, hasLength(2));
      expect(repository.updates.last.target, 'Unchanged retry');
      repository.updates.last.result.complete(
        saved('first', 'Unchanged retry', 'Eins'),
      );
      await controller.awaitSavedEdits();
      expect(
        identical(controller.savedEntryState('first').draft, draft),
        isTrue,
      );
      expect(controller.savedEntryState('first').error, isNull);
      controller.editSavedEntry('first', nativeText: '\u00a0\n');
      controller.retrySavedEntry('first');
      await controller.awaitSavedEdits();
      expect(repository.updates, hasLength(2));
      expect(
        controller.savedEntryState('first').error,
        VocabularyValidation.requiredNative,
      );
    },
  );

  test(
    'an older failed revision cannot overwrite the newer queued input state',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = await seeded(repository);
      addTearDown(controller.dispose);
      controller.editSavedEntry('first', targetText: 'Old write');
      controller.editSavedEntry('first', targetText: 'Newest write');
      final draft = controller.savedEntryState('first').draft;
      repository.updates.first.result.completeError(
        VocabularyValidation.duplicatePair,
      );
      await Future<void>.value();
      expect(repository.updates, hasLength(2));
      expect(controller.savedEntryState('first').error, isNull);
      expect(
        identical(controller.savedEntryState('first').draft, draft),
        isTrue,
      );
      repository.updates.last.result.complete(
        saved('first', 'Newest write', 'Eins'),
      );
      await controller.awaitSavedEdits();
      expect(
        controller.savedEntryState('first').committed.targetText,
        'Newest write',
      );
      expect(controller.savedEntryState('first').error, isNull);
    },
  );
  test(
    'real saved edits normalize automatically while invalid/duplicate buffers preserve committed pair',
    () async {
      final database = PikoDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final owner = await SqliteCollectionsRepository(database).create(
        name: 'Words',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = SqliteVocabularyRepository(database);
      final controller = EntrySessionController(
        collectionId: owner.id,
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.setTargetText('pomme');
      controller.setNativeText('Apfel');
      final first = await controller.confirmAndNext();
      controller.setTargetText('eau');
      controller.setNativeText('Wasser');
      final second = await controller.confirmAndNext();
      controller.setTargetText('Unconfirmed');
      final draft = controller.draft;
      controller.editSavedEntry(
        first.id,
        targetText: ' Cafe\u0301 ',
        nativeText: ' Kaffee ',
      );
      await controller.awaitSavedEdits();
      var state = controller.savedEntryState(first.id);
      expect(state.draft.targetText, ' Cafe\u0301 ');
      expect(state.draft.nativeText, ' Kaffee ');
      expect(state.committed.targetText, 'Café');
      expect(state.committed.nativeText, 'Kaffee');
      expect(state.error, isNull);
      expect(controller.confirmedEntries.map((entry) => entry.id), [
        first.id,
        second.id,
      ]);
      expect(identical(controller.draft, draft), isTrue);
      controller.editSavedEntry(
        first.id,
        targetText: 'EAU',
        nativeText: 'WASSER',
      );
      await controller.awaitSavedEdits();
      state = controller.savedEntryState(first.id);
      expect(state.error, VocabularyValidation.duplicatePair);
      expect(state.draft.targetText, 'EAU');
      expect(state.committed.targetText, 'Café');
      controller.editSavedEntry(first.id, targetText: ' \t');
      await controller.awaitSavedEdits();
      state = controller.savedEntryState(first.id);
      expect(state.error, VocabularyValidation.requiredTarget);
      expect(state.draft.targetText, ' \t');
      final row = await repository.watchById(first.id).first;
      expect(row!.targetText, 'Café');
      expect(row.nativeText, 'Kaffee');
      expect(row.collectionId, owner.id);
      expect(await repository.watchByCollection(owner.id).first, hasLength(2));
    },
  );

  test(
    'delayed writes serialize/coalesce without replacing newer raw field edits',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = await seeded(repository);
      addTearDown(controller.dispose);
      controller.editSavedEntry('first', targetText: 'First edit');
      controller.editSavedEntry('first', nativeText: 'New native');
      controller.editSavedEntry('first', targetText: 'Latest target');
      expect(repository.updates, hasLength(1));
      expect(repository.updates.first.target, 'First edit');
      final latest = controller.savedEntryState('first').draft;
      repository.updates.first.result.complete(
        saved('first', 'First edit', 'Eins'),
      );
      await Future<void>.value();
      expect(repository.updates, hasLength(2));
      expect(repository.updates.last.target, 'Latest target');
      expect(repository.updates.last.native, 'New native');
      expect(
        identical(controller.savedEntryState('first').draft, latest),
        isTrue,
      );
      expect(
        controller.savedEntryState('first').committed.targetText,
        'First edit',
      );
      repository.updates.last.result.complete(
        saved('first', 'Latest target', 'New native'),
      );
      await controller.awaitSavedEdits();
      expect(
        controller.savedEntryState('first').committed.targetText,
        'Latest target',
      );
      expect(
        identical(controller.savedEntryState('first').draft, latest),
        isTrue,
      );
      expect(controller.savedEntryState('first').isSaving, isFalse);
    },
  );

  test(
    'invalid latest input retains validation while accepted queued valid edit persists',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = await seeded(repository);
      addTearDown(controller.dispose);
      controller.editSavedEntry('first', targetText: 'First edit');
      controller.editSavedEntry('first', nativeText: 'Queued valid');
      controller.editSavedEntry('first', nativeText: '\u00a0\n');
      final invalid = controller.savedEntryState('first').draft;
      expect(
        controller.savedEntryState('first').error,
        VocabularyValidation.requiredNative,
      );
      repository.updates.first.result.complete(
        saved('first', 'First edit', 'Eins'),
      );
      await Future<void>.value();
      expect(repository.updates, hasLength(2));
      expect(repository.updates.last.native, 'Queued valid');
      expect(
        controller.savedEntryState('first').error,
        VocabularyValidation.requiredNative,
      );
      repository.updates.last.result.complete(
        saved('first', 'First edit', 'Queued valid'),
      );
      await controller.awaitSavedEdits();
      final state = controller.savedEntryState('first');
      expect(identical(state.draft, invalid), isTrue);
      expect(state.error, VocabularyValidation.requiredNative);
      expect(state.committed.nativeText, 'Queued valid');
    },
  );

  test(
    'storage failure preserves last valid value and later edited input recovers',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = await seeded(repository);
      addTearDown(controller.dispose);
      controller.editSavedEntry('first', targetText: 'Failed edit');
      final failure = StateError('Disk full');
      repository.updates.first.result.completeError(failure);
      await controller.awaitSavedEdits();
      var state = controller.savedEntryState('first');
      expect(state.error, same(failure));
      expect(state.draft.targetText, 'Failed edit');
      expect(state.committed.targetText, 'One');
      controller.editSavedEntry('first', targetText: 'Recovered');
      repository.updates.last.result.complete(
        saved('first', 'Recovered', 'Eins'),
      );
      await controller.awaitSavedEdits();
      state = controller.savedEntryState('first');
      expect(state.error, isNull);
      expect(state.committed.targetText, 'Recovered');
    },
  );

  test(
    'different entries save independently and drain includes edits queued while awaiting',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = await seeded(repository, second: true);
      addTearDown(controller.dispose);
      controller.editSavedEntry('first', targetText: 'First edit');
      final drain = controller.awaitSavedEdits();
      controller.editSavedEntry('second', nativeText: 'Second edit');
      expect(repository.updates, hasLength(2));
      repository.updates.first.result.complete(
        saved('first', 'First edit', 'Eins'),
      );
      await Future<void>.value();
      controller.editSavedEntry('second', targetText: 'Newest');
      repository.updates[1].result.complete(
        saved('second', 'Two', 'Second edit'),
      );
      await Future<void>.value();
      expect(repository.updates, hasLength(3));
      repository.updates.last.result.complete(
        saved('second', 'Newest', 'Second edit'),
      );
      await drain;
      expect(controller.savedEntryState('first').isSaving, isFalse);
      expect(controller.savedEntryState('second').isSaving, isFalse);
      expect(controller.confirmedEntries.map((entry) => entry.id), [
        'first',
        'second',
      ]);
      expect(controller.confirmedEntries.last.targetText, 'Newest');
    },
  );

  test(
    'unknown edits are rejected and unchanged input creates no writes/notifications',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = await seeded(repository);
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() {
        notifications++;
      });
      expect(
        () => controller.editSavedEntry('foreign', targetText: 'Wrong'),
        throwsArgumentError,
      );
      controller.editSavedEntry('first', targetText: 'One');
      expect(repository.updates, isEmpty);
      expect(notifications, 0);
      controller.setTargetText('Draft only');
      expect(repository.updates, isEmpty);
    },
  );

  test(
    'disposed controller drains already accepted valid edits without late notifications',
    () async {
      final database = PikoDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final owner = await SqliteCollectionsRepository(database).create(
        name: 'Words',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = SqliteVocabularyRepository(database);
      final controller = EntrySessionController(
        collectionId: owner.id,
        repository: repository,
      );
      controller.setTargetText('pomme');
      controller.setNativeText('Apfel');
      final first = await controller.confirmAndNext();
      var notifications = 0;
      controller.addListener(() {
        notifications++;
      });
      controller.editSavedEntry(first.id, targetText: 'Intermediate');
      controller.editSavedEntry(first.id, targetText: 'Final accepted');
      final before = notifications;
      controller.dispose();
      await controller.awaitSavedEdits();
      expect(notifications, before);
      expect(controller.confirmedEntries, isEmpty);
      expect(
        () => controller.editSavedEntry(first.id, targetText: 'Late'),
        throwsStateError,
      );
      expect(() => controller.savedEntryState(first.id), throwsStateError);
      final savedRow = await repository.watchById(first.id).first;
      expect(savedRow!.targetText, 'Final accepted');
      expect(savedRow.id, first.id);
      expect(savedRow.collectionId, owner.id);
    },
  );
}
