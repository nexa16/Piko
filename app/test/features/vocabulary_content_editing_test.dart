import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/vocabulary/inline_vocabulary_edit_controller.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/speed_eligibility_test.dart' show completeSnapshot;

void main() {
  test(
    'Collection offer changes only future drafts; failed preference writes remain blocking until retried',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final session = EntrySessionController(
        collectionId: f.owner.id,
        repository: f.vocabulary,
      );
      addTearDown(session.dispose);
      await session.initializeContentDefault();
      session.setTargetText('Word');
      session.setNativeText('Wort');
      final currentVisibility = session.draft.content.hintVisibility;
      await f.vocabulary.completeHintDefaultOffer(f.owner.id, accept: true);
      expect(session.draft.content.hintVisibility, currentVisibility);
      await session.confirmAndNext();
      expect(session.draft.content.hintVisibility, HintVisibility.always);
      final edits = await InlineVocabularyEditController.open(
        entryId: f.entry.id,
        collectionId: f.owner.id,
        repository: f.vocabulary,
      );
      addTearDown(edits.dispose);
      final failure = StateError('synthetic preference write failure');
      await edits.trackPreferenceWrite(Future<void>.error(failure));
      await edits.awaitSavedEdits();
      expect(edits.error, same(failure));
      edits.setTargetText('Changed');
      await edits.awaitSavedEdits();
      expect(edits.error, same(failure));
      await edits.trackPreferenceWrite(Future.value());
      expect(edits.error, isNull);
      await session.trackPreferenceWrite(null, Future<void>.error(failure));
      await expectLater(session.completeSession(), throwsA(same(failure)));
      expect(session.isCompleted, isFalse);
      await session.trackPreferenceWrite(null, Future.value());
      await session.completeSession();
      expect(session.isCompleted, isTrue);
    },
  );

  for (final finish in [false, true]) {
    test(
      'pre-hydration ${finish ? 'Finish' : 'Save Next'} admits one locked write',
      () async {
        final repository = _HeldContentDefaultRepository();
        final session = EntrySessionController(
          collectionId: 'collection',
          repository: repository,
        );
        addTearDown(session.dispose);
        session.setTargetText(' raw target ');
        session.setNativeText(' raw native ');
        final states = <bool>[];
        session.addListener(() => states.add(session.isBusy));
        final Future<dynamic> pending = finish
            ? session.completeSession()
            : session.confirmAndNext();
        expect(session.isBusy, isTrue);
        final repeated = finish
            ? session.completeSession()
            : session.confirmAndNext();
        expect(identical(pending, repeated), isTrue);
        expect(() => session.setTargetText('racing edit'), throwsStateError);
        expect(
          () => finish ? session.confirmAndNext() : session.completeSession(),
          throwsStateError,
        );
        expect(repository.creates, 0);
        expect(repository.reads, 1);
        repository.defaultRead.complete(HintVisibility.hidden);
        await pending;
        expect(repository.creates, 1);
        expect(repository.saved!.targetText, ' raw target ');
        expect(repository.saved!.content.hintVisibility, HintVisibility.hidden);
        expect(states, [true, false]);
        expect(session.isCompleted, finish);
        expect(session.confirmedEntries, hasLength(1));
      },
    );
  }

  test(
    'failed admitted hydration releases lock without writing or losing draft',
    () async {
      final repository = _HeldContentDefaultRepository();
      final session = EntrySessionController(
        collectionId: 'collection',
        repository: repository,
      );
      addTearDown(session.dispose);
      session.setTargetText(' raw target ');
      session.setNativeText(' raw native ');
      final draft = session.draft;
      final pending = session.completeSession();
      final failure = StateError('default read failed');
      final assertion = expectLater(pending, throwsA(same(failure)));
      repository.defaultRead.completeError(failure);
      await assertion;
      expect(session.isBusy, isFalse);
      expect(session.isCompleted, isFalse);
      expect(session.contentReady, isFalse);
      expect(session.contentDefaultError, same(failure));
      expect(identical(session.draft, draft), isTrue);
      expect(repository.creates, 0);
      session.setTargetText('still editable');
      expect(session.draft.targetText, 'still editable');
    },
  );

  test(
    'new-entry visibility freezes from default; invalid pair preserves raw text/default; successful save is atomic',
    () async {
      final f = Fixture();
      await f.initialize();
      final settings = SqliteSettingsRepository(f.db);
      await settings.write(HintVisibility.settingKey, 'hidden');
      final session = EntrySessionController(
        collectionId: f.owner.id,
        repository: f.vocabulary,
      );
      addTearDown(() async {
        session.dispose();
        await f.db.close();
      });
      await session.initializeContentDefault();
      expect(session.draft.content.hintVisibility, HintVisibility.hidden);
      session.setTargetText('  Café  ');
      session.setNativeText(' Kaffee ');
      session.setContent(
        const VocabularyContent(
          exampleTargetText: ' raw example ',
          hintText: ' raw hint ',
          hintVisibility: HintVisibility.always,
        ),
        makeHintVisibilityDefault: true,
      );
      final before = await completeSnapshot(f.db);
      await expectLater(
        session.confirmAndNext(),
        throwsA(VocabularyContentValidation.examplePairRequired),
      );
      expect(session.draft.content.exampleTargetText, ' raw example ');
      expect(session.draft.targetText, '  Café  ');
      expect(await completeSnapshot(f.db), before);
      session.setContent(
        const VocabularyContent(
          exampleTargetText: ' raw example ',
          exampleNativeText: ' Beispiel ',
          hintText: ' raw hint ',
          hintVisibility: HintVisibility.always,
        ),
      );
      final saved = await session.confirmAndNext();
      expect(
        saved.content,
        const VocabularyContent(
          exampleTargetText: 'raw example',
          exampleNativeText: 'Beispiel',
          hintText: 'raw hint',
        ),
      );
      expect(
        await f.vocabulary.readHintVisibilityDefault(collectionId: f.owner.id),
        HintVisibility.always,
      );
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!
            .content
            .hintVisibility,
        HintVisibility.hidden,
      );
      expect(session.draft.content, const VocabularyContent());
      expect(session.draft.makeHintVisibilityDefault, isFalse);
      final learningBefore = await completeSnapshot(f.db);
      session.editSavedEntry(
        saved.id,
        content: const VocabularyContent(exampleTargetText: ' incomplete '),
      );
      await session.awaitSavedEdits();
      expect(
        session.savedEntryState(saved.id).error,
        VocabularyContentValidation.examplePairRequired,
      );
      expect(
        (await f.vocabulary.watchById(saved.id).first)!.content,
        saved.content,
      );
      session.editSavedEntry(
        saved.id,
        content: const VocabularyContent(
          hintText: ' changed hint ',
          hintVisibility: HintVisibility.hidden,
        ),
      );
      await session.awaitSavedEdits();
      expect(
        (await f.vocabulary.watchById(saved.id).first)!.content.hintText,
        'changed hint',
      );
      final after = await completeSnapshot(f.db);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect(after[table], learningBefore[table]);
      }
    },
  );

  test(
    'inline content keeps invalid raw input, autosaves valid content and Discard restores opening content',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      const opening = VocabularyContent(
        exampleTargetText: 'One example',
        exampleNativeText: 'Ein Beispiel',
        hintText: 'Opening hint',
        hintVisibility: HintVisibility.hidden,
      );
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: const {},
        content: opening,
      );
      final controller = await InlineVocabularyEditController.open(
        entryId: f.entry.id,
        collectionId: f.owner.id,
        repository: f.vocabulary,
      );
      addTearDown(controller.dispose);
      final before = await completeSnapshot(f.db);
      final invalid = VocabularyContent(
        hintText: '🙂' * 2001,
        hintVisibility: HintVisibility.always,
      );
      controller.setContent(invalid, makeHintVisibilityDefault: true);
      await controller.awaitSavedEdits();
      expect(controller.error, VocabularyContentValidation.hintTooLong);
      expect(controller.draft.content.hintText!.runes.length, 2001);
      expect(await completeSnapshot(f.db), before);
      controller.setContent(
        const VocabularyContent(
          hintText: ' edited ',
          hintVisibility: HintVisibility.always,
        ),
      );
      await controller.awaitSavedEdits();
      expect(controller.committed.content.hintText, 'edited');
      expect(controller.draft.content.hintText, ' edited ');
      expect(controller.hasUncommittedChanges, isFalse);
      expect(controller.changedSinceOpening, isTrue);
      await controller.discard();
      expect(controller.draft.content, opening);
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.content,
        opening,
      );
      final after = await completeSnapshot(f.db);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect(after[table], before[table]);
      }
    },
  );

  test(
    'optional-only unfinished draft blocks Finish with required vocabulary, preserving raw hint',
    () async {
      final f = Fixture();
      await f.initialize();
      final session = EntrySessionController(
        collectionId: f.owner.id,
        repository: f.vocabulary,
      );
      addTearDown(() async {
        session.dispose();
        await f.db.close();
      });
      await session.initializeContentDefault();
      session.setContent(
        const VocabularyContent(hintText: ' unfinished hint '),
      );
      final before = await completeSnapshot(f.db);
      await expectLater(session.completeSession(), throwsA(anything));
      expect(session.isCompleted, isFalse);
      expect(session.draft.content.hintText, ' unfinished hint ');
      expect(await completeSnapshot(f.db), before);
    },
  );
}

final class _HeldContentDefaultRepository
    implements VocabularyContentRepository {
  final defaultRead = Completer<HintVisibility>();
  int reads = 0, creates = 0;
  VocabularyRecord? saved;

  @override
  Future<HintVisibility> readHintVisibilityDefault({String? collectionId}) {
    reads++;
    return defaultRead.future;
  }

  @override
  Future<VocabularyRecord> createWithContent({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
    required VocabularyContent content,
    bool makeHintVisibilityDefault = false,
    bool active = true,
  }) async {
    creates++;
    return saved = VocabularyRecord(
      id: 'saved',
      collectionId: collectionId,
      targetText: targetText,
      nativeText: nativeText,
      content: content,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
