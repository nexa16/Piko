import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import '../support/controlled_vocabulary_repository.dart';
import 'inline_category_edit_test.dart' show HeldMetadata;

class EntryCategoryFixture {
  final db = PikoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  late final vocabulary = SqliteVocabularyRepository(db);
  late final categories = SqliteCategoriesRepository(db);
  late final deletion = SqliteVocabularyDeletionService(db);
  late CollectionRecord collection;
  late CategoryDimensionRecord dimension;
  late CategoryValueRecord first, second;
  late EntrySessionController session;
  Future<void> initialize() async {
    collection = await SqliteCollectionsRepository(db).create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    dimension = await categories.createDimension(
      collectionId: collection.id,
      name: 'Topic',
      mode: CategoryMode.multiple,
    );
    first = await categories.createValue(
      dimensionId: dimension.id,
      name: 'First',
    );
    second = await categories.createValue(
      dimensionId: dimension.id,
      name: 'Second',
    );
    session = EntrySessionController(
      collectionId: collection.id,
      repository: vocabulary,
      deletionService: deletion,
    );
  }

  void select(Set<String> values, [String? entryId]) =>
      session.setCategoryValues(
        entryId: entryId,
        dimensionId: dimension.id,
        valueIds: values,
      );
  Future<VocabularyRecord> confirm() {
    session.setTargetText(' Pomme ');
    session.setNativeText(' Apfel ');
    return session.confirmAndNext();
  }

  Future<List<Map<String, Object?>>> learning() async =>
      (await db.customSelect('SELECT * FROM learning_items ORDER BY id').get())
          .map((row) => row.data)
          .toList();
  Future<void> flush() async {
    await db.customSelect('SELECT 1').get();
  }

  Future<void> close() async {
    session.dispose();
    await session.awaitSavedEdits();
    deletion.dispose();
    await db.close();
  }
}

class HeldCategorizedCreation extends ControlledVocabularyRepository
    implements CategorizedVocabularyRepository {
  Map<String, Set<String>>? accepted;
  @override
  Future<VocabularyRecord> createCategorized({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) {
    accepted = assignments;
    return create(
      collectionId: collectionId,
      targetText: targetText,
      nativeText: nativeText,
    );
  }

  @override
  Future<Map<String, Set<String>>> categorizedAssignments(
    String entryId,
  ) async => accepted ?? const {};
  @override
  Future<VocabularyRecord> updateCategorized({
    required String id,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) => update(id: id, targetText: targetText, nativeText: nativeText);
}

class FallibleAssignmentRead implements CategorizedVocabularyRepository {
  FallibleAssignmentRead(this.real);
  final CategorizedVocabularyRepository real;
  bool failReads = false;
  @override
  Future<Map<String, Set<String>>> categorizedAssignments(String entryId) {
    if (failReads) throw StateError('Presentation read unavailable');
    return real.categorizedAssignments(entryId);
  }

  @override
  Future<VocabularyRecord> createCategorized({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) => real.createCategorized(
    collectionId: collectionId,
    targetText: targetText,
    nativeText: nativeText,
    assignments: assignments,
  );
  @override
  Future<VocabularyRecord> updateCategorized({
    required String id,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) => real.updateCategorized(
    id: id,
    targetText: targetText,
    nativeText: nativeText,
    assignments: assignments,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unused repository method');
}

void main() {
  test(
    'new assignments remain a frozen unsaved draft; confirmation atomically persists and next draft has no carry-over',
    () async {
      final f = EntryCategoryFixture();
      await f.initialize();
      addTearDown(f.close);
      final selected = {f.first.id};
      f.select(selected);
      selected.clear();
      expect(f.session.draft.assignments[f.dimension.id], {f.first.id});
      expect(
        () => f.session.draft.assignments[f.dimension.id]!.clear(),
        throwsUnsupportedError,
      );
      expect(
        await f.vocabulary.watchByCollection(f.collection.id).first,
        isEmpty,
      );
      expect(await f.learning(), isEmpty);
      final saved = await f.confirm();
      expect(saved.targetText, 'Pomme');
      expect((await f.categories.assignments(saved.id)).single.valueIds, {
        f.first.id,
      });
      expect(
        f.session.savedEntryState(saved.id).draft.assignments[f.dimension.id],
        {f.first.id},
      );
      expect(f.session.draft.assignments, isEmpty);
      expect(f.session.draft.targetText, isEmpty);
      expect(await f.learning(), hasLength(2));
    },
  );

  test(
    'Single conflict rejects whole creation and retains raw draft; correcting selection can confirm once',
    () async {
      final f = EntryCategoryFixture();
      await f.initialize();
      addTearDown(f.close);
      await f.categories.updateDimension(
        id: f.dimension.id,
        name: f.dimension.name,
        mode: CategoryMode.single,
      );
      f.select({f.first.id, f.second.id});
      await expectLater(
        f.confirm(),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(f.session.draft.targetText, ' Pomme ');
      expect(f.session.draft.assignments[f.dimension.id], {
        f.first.id,
        f.second.id,
      });
      expect(
        await f.vocabulary.watchByCollection(f.collection.id).first,
        isEmpty,
      );
      expect(await f.learning(), isEmpty);
      f.select({f.second.id});
      final saved = await f.session.confirmAndNext();
      expect((await f.categories.assignments(saved.id)).single.valueIds, {
        f.second.id,
      });
      expect(await f.learning(), hasLength(2));
    },
  );

  test(
    'saved invalid text retains assignment draft and later saves pair plus categories without changing learning',
    () async {
      final f = EntryCategoryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.select({f.first.id});
      final saved = await f.confirm();
      final before = await f.learning();
      expect(before, hasLength(2));
      f.session.editSavedEntry(saved.id, targetText: ' ');
      f.select({f.second.id}, saved.id);
      await f.session.awaitSavedEdits();
      expect((await f.categories.assignments(saved.id)).single.valueIds, {
        f.first.id,
      });
      expect(f.session.savedEntryState(saved.id).draft.targetText, ' ');
      f.session.editSavedEntry(saved.id, targetText: ' Nouvelle pomme ');
      await f.session.awaitSavedEdits();
      expect((await f.categories.assignments(saved.id)).single.valueIds, {
        f.second.id,
      });
      expect(
        (await f.vocabulary.watchById(saved.id).first)!.targetText,
        'Nouvelle pomme',
      );
      expect(
        f.session.savedEntryState(saved.id).draft.targetText,
        ' Nouvelle pomme ',
      );
      expect(await f.learning(), before);
    },
  );

  test(
    'confirmation freezes immutable category snapshot, is single-flight, and disposal suppresses late publication',
    () async {
      final repository = HeldCategorizedCreation();
      final session = EntrySessionController(
        collectionId: 'owner',
        repository: repository,
      );
      session.setTargetText(' raw ');
      session.setNativeText(' Wert ');
      session.setCategoryValues(dimensionId: 'dimension', valueIds: {'first'});
      final first = session.confirmAndNext(), second = session.confirmAndNext();
      expect(identical(first, second), isTrue);
      expect(repository.createCalls, 1);
      expect(repository.accepted, {
        'dimension': {'first'},
      });
      expect(
        () => session.setCategoryValues(
          dimensionId: 'dimension',
          valueIds: {'second'},
        ),
        throwsStateError,
      );
      var notifications = 0;
      session.addListener(() => notifications++);
      session.dispose();
      repository.pending.complete(
        const VocabularyRecord(
          id: 'saved',
          collectionId: 'owner',
          targetText: 'raw',
          nativeText: 'Wert',
        ),
      );
      expect((await first).id, 'saved');
      expect(notifications, 0);
      expect(session.confirmedEntries, isEmpty);
      expect(session.draft.assignments, isEmpty);
    },
  );

  test(
    'final confirmation persists categories and a categories-only draft is not silently discarded',
    () async {
      final f = EntryCategoryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.select({f.first.id});
      await expectLater(
        f.session.completeSession(),
        throwsA(VocabularyValidation.requiredTarget),
      );
      expect(f.session.isCompleted, isFalse);
      expect(f.session.draft.assignments[f.dimension.id], {f.first.id});
      f.session.setTargetText('Final');
      f.session.setNativeText('Letztes');
      await f.session.completeSession();
      final saved = f.session.confirmedEntries.single;
      expect((await f.categories.assignments(saved.id)).single.valueIds, {
        f.first.id,
      });
      expect(f.session.isCompleted, isTrue);
    },
  );

  test(
    'external deletion prunes saved and new draft refs while preserving invalid text and surviving selections',
    () async {
      final f = EntryCategoryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.select({f.first.id});
      final saved = await f.confirm();
      f.session.editSavedEntry(saved.id, targetText: ' ');
      f.select({f.first.id, f.second.id}, saved.id);
      f.session.setTargetText(' New draft ');
      f.select({f.first.id, f.second.id});
      await f.categories.deleteValue(f.first.id);
      await f.session.refreshCategoryReferences(f.categories);
      expect(f.session.draft.targetText, ' New draft ');
      expect(f.session.draft.assignments[f.dimension.id], {f.second.id});
      expect(f.session.savedEntryState(saved.id).draft.targetText, ' ');
      expect(
        f.session.savedEntryState(saved.id).draft.assignments[f.dimension.id],
        {f.second.id},
      );
      expect(
        f.session.savedEntryState(saved.id).error,
        VocabularyValidation.requiredTarget,
      );
      f.session.editSavedEntry(saved.id, targetText: 'After deletion');
      await f.session.awaitSavedEdits();
      expect(f.session.savedEntryState(saved.id).error, isNull);
      expect((await f.categories.assignments(saved.id)).single.valueIds, {
        f.second.id,
      });
    },
  );

  test(
    'Undo restores accepted categories rather than discarded invalid assignment drafts',
    () async {
      final f = EntryCategoryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.select({f.first.id});
      final saved = await f.confirm();
      final before = await f.learning();
      f.session.editSavedEntry(saved.id, targetText: ' ');
      f.select({f.second.id}, saved.id);
      await f.session.deleteSavedEntry(saved.id);
      await f.session.undoDeletion(saved.id);
      expect(f.session.savedEntryState(saved.id).draft.targetText, 'Pomme');
      expect(
        f.session.savedEntryState(saved.id).draft.assignments[f.dimension.id],
        {f.first.id},
      );
      expect(await f.learning(), before);
    },
  );

  test(
    'assignment hydration failure after committed Undo retains success and immutable committed fallback, never invalid raw draft',
    () async {
      final f = EntryCategoryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.session.dispose();
      final fallible = FallibleAssignmentRead(f.vocabulary);
      f.session = EntrySessionController(
        collectionId: f.collection.id,
        repository: fallible,
        deletionService: f.deletion,
      );
      f.select({f.first.id});
      final saved = await f.confirm();
      f.session.editSavedEntry(saved.id, targetText: ' ');
      f.select({f.second.id}, saved.id);
      await f.session.deleteSavedEntry(saved.id);
      fallible.failReads = true;
      final restored = await f.session.undoDeletion(saved.id);
      expect(restored.id, saved.id);
      expect(f.session.undoEntries, isEmpty);
      expect(f.session.savedEntryState(saved.id).error, isNull);
      expect(f.session.savedEntryState(saved.id).draft.targetText, 'Pomme');
      expect(
        f.session.savedEntryState(saved.id).draft.assignments[f.dimension.id],
        {f.first.id},
      );
      expect(
        () => f.session
            .savedEntryState(saved.id)
            .draft
            .assignments[f.dimension.id]!
            .clear(),
        throwsUnsupportedError,
      );
      expect((await f.categories.assignments(saved.id)).single.valueIds, {
        f.first.id,
      });
    },
  );

  test(
    'new value confirmed during older metadata read survives revalidation without automatically confirming vocabulary',
    () async {
      final f = EntryCategoryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.session.setTargetText(' Retained raw ');
      f.select({f.first.id});
      final held = HeldMetadata(f.categories);
      final revalidation = f.session.refreshCategoryReferences(held);
      while (held.reads == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final added = await f.categories.createValue(
        dimensionId: f.dimension.id,
        name: 'Added while reading',
      );
      f.select({added.id});
      held.gate.complete();
      await revalidation;
      expect(held.reads, greaterThanOrEqualTo(2));
      expect(f.session.draft.assignments[f.dimension.id], {added.id});
      expect(f.session.draft.targetText, ' Retained raw ');
      expect(
        await f.vocabulary.watchByCollection(f.collection.id).first,
        isEmpty,
      );
      expect(await f.learning(), isEmpty);
    },
  );
}
