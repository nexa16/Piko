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
import 'entry_session_auto_save_test.dart' show seeded, saved;

class RecheckRepository extends ControlledVocabularyRepository {
  final reads = <Completer<List<VocabularyRecord>>>[];
  @override
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) {
    final result = Completer<List<VocabularyRecord>>();
    reads.add(result);
    return Stream.fromFuture(result.future);
  }
}

Future<void> duplicate(
  EntrySessionController session,
  RecheckRepository repository,
) async {
  session.editSavedEntry('first', targetText: ' Two ', nativeText: ' ZWEI ');
  repository.updates.last.result.completeError(
    VocabularyValidation.duplicatePair,
  );
  await session.awaitSavedEdits();
}

void main() {
  test(
    'duplicate Retry cannot write; reopen clears conflict and autosaves raw pair',
    () async {
      final repository = RecheckRepository();
      final session = await seeded(repository);
      addTearDown(session.dispose);
      await duplicate(session, repository);
      final raw = session.savedEntryState('first').draft;
      session.retrySavedEntry('first');
      expect(repository.updates, hasLength(1));
      session.selectSavedEntry('first');
      // Its own identity never constitutes a duplicate, even if an external
      // writer has already stored the pending pair.
      repository.reads.single.complete([saved('first', 'Two', 'ZWEI')]);
      await Future<void>.delayed(Duration.zero);
      expect(repository.updates, hasLength(2));
      expect(repository.updates.last.target, ' Two ');
      repository.updates.last.result.complete(saved('first', 'Two', 'ZWEI'));
      await session.awaitSavedEdits();
      expect(session.savedEntryState('first').draft, same(raw));
      expect(session.savedEntryState('first').error, isNull);
      expect(session.savedEntryState('first').committed.id, 'first');
    },
  );

  test(
    'unchanged conflict and failed recheck preserve specific duplicate without writes',
    () async {
      final repository = RecheckRepository();
      final session = await seeded(repository);
      addTearDown(session.dispose);
      await duplicate(session, repository);
      session.selectSavedEntry('first');
      repository.reads.last.complete([saved('other', 'two', 'zwei')]);
      await session.awaitSavedEdits();
      expect(
        session.savedEntryState('first').error,
        VocabularyValidation.duplicatePair,
      );
      session.selectDraft();
      session.selectSavedEntry('first');
      repository.reads.last.completeError(StateError('Read unavailable'));
      await session.awaitSavedEdits();
      expect(
        session.savedEntryState('first').error,
        VocabularyValidation.duplicatePair,
      );
      expect(repository.updates, hasLength(1));
    },
  );

  for (final stale in ['input', 'activation', 'disposal']) {
    test('late recheck cannot write after newer $stale', () async {
      final repository = RecheckRepository();
      final session = await seeded(repository);
      await duplicate(session, repository);
      session.selectSavedEntry('first');
      if (stale == 'input') {
        session.editSavedEntry('first', nativeText: ' ');
      } else if (stale == 'activation') {
        session.selectDraft();
      } else {
        session.dispose();
      }
      repository.reads.single.complete([]);
      await session.awaitSavedEdits();
      expect(repository.updates, hasLength(1));
      if (stale != 'disposal') {
        expect(
          session.savedEntryState('first').error,
          stale == 'input'
              ? VocabularyValidation.requiredNative
              : VocabularyValidation.duplicatePair,
        );
        session.dispose();
      }
    });
  }

  test(
    'draft duplicate revalidation never creates or confirms vocabulary',
    () async {
      final repository = RecheckRepository();
      final session = await seeded(repository);
      addTearDown(session.dispose);
      session.setTargetText(' Two ');
      session.setNativeText(' Zwei ');
      repository.pending = Completer<VocabularyRecord>();
      final confirmation = session.confirmAndNext();
      repository.pending.completeError(VocabularyValidation.duplicatePair);
      await expectLater(
        confirmation,
        throwsA(VocabularyValidation.duplicatePair),
      );
      final raw = session.draft;
      session.selectSavedEntry('first');
      session.selectDraft();
      repository.reads.single.complete([]);
      await session.awaitSavedEdits();
      expect(session.draftError, isNull);
      expect(session.draft, same(raw));
      expect(repository.createCalls, 2);
      expect(repository.updates, isEmpty);
      expect(session.confirmedEntries, hasLength(1));
    },
  );

  test(
    'real conflict removal resumes saved edit while exact learning rows survive',
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
      session.setTargetText('One');
      session.setNativeText('Eins');
      final first = await session.confirmAndNext();
      session.setTargetText('Two');
      session.setNativeText('Zwei');
      final second = await session.confirmAndNext();
      final learning =
          (await db
                  .customSelect('SELECT * FROM learning_items ORDER BY id')
                  .get())
              .map((row) => row.data)
              .toList();
      expect(learning, hasLength(4));
      session.selectSavedEntry(first.id);
      session.editSavedEntry(
        first.id,
        targetText: ' TWO ',
        nativeText: ' zwei ',
      );
      await session.awaitSavedEdits();
      session.selectSavedEntry(second.id);
      session.editSavedEntry(second.id, targetText: 'Three');
      await session.awaitSavedEdits();
      session.selectSavedEntry(first.id);
      await session.awaitSavedEdits();
      expect(session.savedEntryState(first.id).error, isNull);
      final row = (await repository.watchById(first.id).first)!;
      expect(row.targetText, 'TWO');
      expect(row.nativeText, 'zwei');
      expect(row.collectionId, owner.id);
      expect(
        (await db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get())
            .map((row) => row.data)
            .toList(),
        learning,
      );
    },
  );
}
