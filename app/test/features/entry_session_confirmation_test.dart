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

const record = VocabularyRecord(
  id: 'confirmed',
  collectionId: 'owner',
  targetText: 'Café',
  nativeText: 'Kaffee',
);

void main() {
  test(
    'real SQLite confirms normalized text then atomically opens next draft',
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
      controller.setTargetText(' Cafe\u0301 ');
      controller.setNativeText(' Kaffee ');
      expect(await repository.watchByCollection(owner.id).first, isEmpty);
      final states = <(bool, int, String, String)>[];
      controller.addListener(
        () => states.add((
          controller.isConfirming,
          controller.confirmedEntries.length,
          controller.draft.targetText,
          controller.draft.nativeText,
        )),
      );
      final saved = await controller.confirmAndNext();
      expect(saved.targetText, 'Café');
      expect(saved.nativeText, 'Kaffee');
      expect(
        (await repository.watchByCollection(owner.id).first).single.id,
        saved.id,
      );
      expect(controller.confirmedEntries.single.id, saved.id);
      expect(controller.activeEntryId, isNull);
      expect(states, [
        (true, 0, ' Cafe\u0301 ', ' Kaffee '),
        (false, 1, '', ''),
      ]);
      controller.setTargetText('CAFÉ');
      controller.setNativeText('KAFFEE');
      controller.selectSavedEntry(saved.id);
      final invalid = controller.draft;
      await expectLater(
        controller.confirmAndNext(),
        throwsA(VocabularyValidation.duplicatePair),
      );
      expect(identical(controller.draft, invalid), isTrue);
      expect(controller.activeEntryId, saved.id);
      expect(controller.confirmedEntries, hasLength(1));
    },
  );

  test(
    'pending snapshot is stable, double submit shares result, edits and navigation freeze',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.setTargetText(' Cafe\u0301 ');
      controller.setNativeText(' Kaffee ');
      final snapshot = controller.draft;
      final first = controller.confirmAndNext();
      final second = controller.confirmAndNext();
      expect(identical(first, second), isTrue);
      expect(repository.createCalls, 1);
      expect(repository.collectionId, 'owner');
      expect(repository.targetText, ' Cafe\u0301 ');
      expect(repository.nativeText, ' Kaffee ');
      expect(controller.isConfirming, isTrue);
      expect(identical(controller.draft, snapshot), isTrue);
      expect(controller.confirmedEntries, isEmpty);
      expect(() => controller.setTargetText('Lost race'), throwsStateError);
      expect(() => controller.setNativeText('Lost race'), throwsStateError);
      expect(controller.selectDraft, throwsStateError);
      expect(() => controller.selectSavedEntry('unknown'), throwsStateError);
      repository.pending.complete(record);
      expect(await first, same(record));
      expect(await second, same(record));
      expect(controller.isConfirming, isFalse);
      expect(controller.draft.targetText, isEmpty);
      expect(controller.confirmedEntries.single.id, record.id);
      controller.setTargetText('New editable draft');
      expect(controller.draft.targetText, 'New editable draft');
    },
  );

  test(
    'required normalized fields fail without writes or draft changes',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.setTargetText('\u00a0\t');
      controller.setNativeText('Valid');
      final first = controller.draft;
      await expectLater(
        controller.confirmAndNext(),
        throwsA(VocabularyValidation.requiredTarget),
      );
      expect(identical(controller.draft, first), isTrue);
      controller.setTargetText('Valid');
      controller.setNativeText('\u2003\n');
      final second = controller.draft;
      await expectLater(
        controller.confirmAndNext(),
        throwsA(VocabularyValidation.requiredNative),
      );
      expect(identical(controller.draft, second), isTrue);
      expect(repository.createCalls, 0);
      expect(controller.isConfirming, isFalse);
      expect(controller.confirmedEntries, isEmpty);
    },
  );

  test(
    'storage failure retains saved selection/raw draft and allows explicit retry',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.setTargetText('Café');
      controller.setNativeText('Kaffee');
      final saved = controller.confirmAndNext();
      repository.pending.complete(record);
      await saved;
      controller.setTargetText(' eau ');
      controller.setNativeText(' Wasser ');
      controller.selectSavedEntry(record.id);
      final draft = controller.draft;
      repository.pending = Completer<VocabularyRecord>();
      final failed = controller.confirmAndNext();
      final error = StateError('Disk full');
      final expectation = expectLater(failed, throwsA(same(error)));
      repository.pending.completeError(error);
      await expectation;
      expect(controller.activeEntryId, record.id);
      expect(identical(controller.draft, draft), isTrue);
      expect(controller.confirmedEntries, hasLength(1));
      expect(controller.isConfirming, isFalse);
      repository.pending = Completer<VocabularyRecord>();
      final retried = controller.confirmAndNext();
      repository.pending.complete(
        const VocabularyRecord(
          id: 'second',
          collectionId: 'owner',
          targetText: 'eau',
          nativeText: 'Wasser',
        ),
      );
      await retried;
      expect(controller.confirmedEntries, hasLength(2));
      expect(controller.activeEntryId, isNull);
      expect(controller.draft.targetText, isEmpty);
      expect(repository.createCalls, 3);
    },
  );

  for (final succeeds in [true, false]) {
    test(
      'disposed pending confirmation ${succeeds ? "success" : "failure"} never revives or notifies',
      () async {
        final repository = ControlledVocabularyRepository();
        final controller = EntrySessionController(
          collectionId: 'owner',
          repository: repository,
        );
        controller.setTargetText('Café');
        controller.setNativeText('Kaffee');
        var notifications = 0;
        controller.addListener(() {
          notifications++;
        });
        final result = controller.confirmAndNext();
        controller.dispose();
        final expectation = succeeds
            ? expectLater(result, completion(same(record)))
            : expectLater(result, throwsStateError);
        if (succeeds) {
          repository.pending.complete(record);
        } else {
          repository.pending.completeError(StateError('Write failed'));
        }
        await expectation;
        expect(notifications, 1);
        expect(controller.confirmedEntries, isEmpty);
        expect(controller.draft.targetText, isEmpty);
        expect(controller.activeEntryId, isNull);
        expect(controller.isConfirming, isFalse);
        expect(controller.confirmAndNext, throwsStateError);
      },
    );
  }

  test(
    'unexpected foreign confirmation record cannot enter the session',
    () async {
      final repository = ControlledVocabularyRepository();
      final controller = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.setTargetText('Café');
      controller.setNativeText('Kaffee');
      final snapshot = controller.draft;
      final result = controller.confirmAndNext();
      final expectation = expectLater(result, throwsStateError);
      repository.pending.complete(
        const VocabularyRecord(
          id: 'foreign',
          collectionId: 'other',
          targetText: 'Café',
          nativeText: 'Kaffee',
        ),
      );
      await expectation;
      expect(identical(controller.draft, snapshot), isTrue);
      expect(controller.confirmedEntries, isEmpty);
      expect(controller.isConfirming, isFalse);
    },
  );
}
