import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import '../support/controlled_vocabulary_repository.dart';

const record = VocabularyRecord(
  id: 'saved',
  collectionId: 'owner',
  targetText: 'Café',
  nativeText: 'Kaffee',
);

void main() {
  test(
    'completion activates first invalid saved buffer in session order',
    () async {
      final repository = ControlledVocabularyRepository();
      final session = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(session.dispose);
      session.setTargetText('Café');
      session.setNativeText('Kaffee');
      final first = session.confirmAndNext();
      repository.pending.complete(record);
      await first;
      repository.pending = Completer<VocabularyRecord>();
      session.setTargetText('Water');
      session.setNativeText('Wasser');
      const second = VocabularyRecord(
        id: 'second',
        collectionId: 'owner',
        targetText: 'Water',
        nativeText: 'Wasser',
      );
      final next = session.confirmAndNext();
      repository.pending.complete(second);
      await next;
      session.editSavedEntry(second.id, nativeText: ' ');
      session.editSavedEntry(record.id, targetText: ' ');
      await expectLater(
        session.completeSession(),
        throwsA(
          isA<SavedEntryCompletionBlocked>().having(
            (e) => e.entryId,
            'first',
            record.id,
          ),
        ),
      );
      expect(session.activeEntryId, record.id);
      expect(repository.createCalls, 2);
    },
  );
  test('disposal while draining starts no new final write', () async {
    final repository = ControlledVocabularyRepository();
    final session = EntrySessionController(
      collectionId: 'owner',
      repository: repository,
    );
    session.setTargetText('Café');
    session.setNativeText('Kaffee');
    final saved = session.confirmAndNext();
    repository.pending.complete(record);
    await saved;
    session.editSavedEntry(record.id, nativeText: 'Coffee');
    session.setTargetText('final');
    session.setNativeText('last');
    final result = session.completeSession();
    final expectation = expectLater(result, throwsStateError);
    session.dispose();
    repository.updates.single.result.complete(record);
    await expectation;
    expect(repository.createCalls, 1);
  });
  test(
    'real SQLite final confirmation is normalized once and terminal without a fresh draft',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = await SqliteCollectionsRepository(db).create(
        name: 'Words',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = SqliteVocabularyRepository(db);
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: repository,
      );
      addTearDown(session.dispose);
      session.setTargetText(' Cafe\u0301 ');
      session.setNativeText(' Kaffee ');
      final draft = session.draft;
      final future = session.completeSession();
      expect(identical(session.completeSession(), future), isTrue);
      await future;
      expect(session.isCompleted, isTrue);
      expect(identical(session.draft, draft), isTrue);
      expect(session.activeEntryId, session.confirmedEntries.single.id);
      await session.completeSession();
      final rows = await repository.watchByCollection(owner.id).first;
      expect(rows, hasLength(1));
      expect(rows.single.targetText, 'Café');
      expect(() => session.setTargetText('new'), throwsStateError);
      expect(() => session.confirmAndNext(), throwsStateError);
    },
  );

  test('whitespace completion creates nothing and remains terminal', () async {
    final repository = ControlledVocabularyRepository();
    final session = EntrySessionController(
      collectionId: 'owner',
      repository: repository,
    );
    addTearDown(session.dispose);
    session.setTargetText(' \n');
    session.setNativeText('\t');
    await session.completeSession();
    expect(repository.createCalls, 0);
    expect(session.isCompleted, isTrue);
  });

  test(
    'required and storage failures retain raw draft and allow corrected retry',
    () async {
      final repository = ControlledVocabularyRepository();
      final session = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(session.dispose);
      session.setTargetText(' Café ');
      final draft = session.draft;
      await expectLater(
        session.completeSession(),
        throwsA(VocabularyValidation.requiredNative),
      );
      expect(identical(session.draft, draft), isTrue);
      session.setNativeText(' Kaffee ');
      final fail = session.completeSession();
      repository.pending.completeError(StateError('Disk failure'));
      await expectLater(fail, throwsStateError);
      expect(session.isCompleted, isFalse);
      expect(session.draft.targetText, ' Café ');
      repository.pending = Completer<VocabularyRecord>();
      final retry = session.completeSession();
      await Future<void>.delayed(Duration.zero);
      repository.pending.complete(record);
      await retry;
      expect(session.isCompleted, isTrue);
    },
  );

  test(
    'busy completion blocks competing card save, edits and navigation',
    () async {
      final repository = ControlledVocabularyRepository();
      final session = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(session.dispose);
      session.setTargetText('Café');
      session.setNativeText('Kaffee');
      final result = session.completeSession();
      expect(identical(result, session.completeSession()), isTrue);
      expect(session.isBusy, isTrue);
      expect(() => session.confirmAndNext(), throwsStateError);
      expect(() => session.selectDraft(), throwsStateError);
      expect(() => session.setNativeText('edit'), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(repository.createCalls, 1);
      repository.pending.complete(record);
      await result;
    },
  );

  test(
    'completion drains saved work then activates its failed buffer without writing final draft',
    () async {
      final repository = ControlledVocabularyRepository();
      final session = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(session.dispose);
      session.setTargetText('Café');
      session.setNativeText('Kaffee');
      final saved = session.confirmAndNext();
      repository.pending.complete(record);
      await saved;
      session.editSavedEntry(record.id, nativeText: 'Coffee');
      session.setTargetText('final');
      session.setNativeText('last');
      final result = session.completeSession();
      final error = StateError('Update failed');
      repository.updates.single.result.completeError(error);
      await expectLater(
        result,
        throwsA(
          isA<SavedEntryCompletionBlocked>().having(
            (e) => e.entryId,
            'identity',
            record.id,
          ),
        ),
      );
      expect(session.activeEntryId, record.id);
      expect(repository.createCalls, 1);
      expect(session.draft.targetText, 'final');
      expect(session.isBusy, isFalse);
    },
  );

  test(
    'invalid saved buffer blocks empty final completion and retains raw values',
    () async {
      final repository = ControlledVocabularyRepository();
      final session = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(session.dispose);
      session.setTargetText('Café');
      session.setNativeText('Kaffee');
      final saved = session.confirmAndNext();
      repository.pending.complete(record);
      await saved;
      session.editSavedEntry(record.id, targetText: ' ');
      await expectLater(
        session.completeSession(),
        throwsA(isA<SavedEntryCompletionBlocked>()),
      );
      expect(session.activeEntryId, record.id);
      expect(session.savedEntryState(record.id).draft.targetText, ' ');
      expect(session.isCompleted, isFalse);
    },
  );

  test(
    'disposal during final write allows persistence result but no late session state',
    () async {
      final repository = ControlledVocabularyRepository();
      final session = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      session.setTargetText('Café');
      session.setNativeText('Kaffee');
      final result = session.completeSession();
      await Future<void>.delayed(Duration.zero);
      session.dispose();
      repository.pending.complete(record);
      await result;
      expect(session.confirmedEntries, isEmpty);
      expect(session.draft.targetText, isEmpty);
      expect(session.isCompleted, isFalse);
    },
  );
}
