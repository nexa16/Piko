import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/vocabulary/inline_vocabulary_edit_controller.dart';
import '../support/controlled_vocabulary_repository.dart';

class Fixture {
  final db = PikoDatabase(NativeDatabase.memory());
  late final vocabulary = SqliteVocabularyRepository(db);
  late final categories = SqliteCategoriesRepository(db);
  late VocabularyRecord entry;
  late CategoryDimensionRecord dimension;
  late CategoryValueRecord first, second;
  late InlineVocabularyEditController controller;
  Future<void> initialize() async {
    final collection = await SqliteCollectionsRepository(db).create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    entry = await vocabulary.create(
      collectionId: collection.id,
      targetText: 'One',
      nativeText: 'Eins',
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
    await categories.replaceAssignments(
      entryId: entry.id,
      assignments: {
        dimension.id: {first.id},
      },
    );
    controller = await InlineVocabularyEditController.open(
      entryId: entry.id,
      collectionId: collection.id,
      repository: vocabulary,
    );
  }

  Future<List<Map<String, Object?>>> learning() async =>
      (await db.customSelect('SELECT * FROM learning_items ORDER BY id').get())
          .map((row) => row.data)
          .toList();
  Future<void> close() async {
    controller.dispose();
    await controller.awaitSavedEdits();
    await db.close();
  }
}

class Opening implements CategorizedVocabularyOpeningSnapshot {
  Opening(this.entry, this.assignments);
  @override
  final VocabularyRecord entry;
  @override
  final Map<String, Set<String>> assignments;
}

class ControlledCategories extends ControlledVocabularyRepository
    implements CategorizedVocabularyRepository {
  static const entry = VocabularyRecord(
    id: 'entry',
    collectionId: 'owner',
    targetText: 'One',
    nativeText: 'Eins',
  );
  final categoryUpdates = <Map<String, Set<String>>>[];
  Map<String, Set<String>> committed = {
    'dimension': {'first'},
  };
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) async => Opening(entry, committed);
  @override
  Future<Map<String, Set<String>>> categorizedAssignments(
    String entryId,
  ) async => committed;
  @override
  Future<VocabularyRecord> updateCategorized({
    required String id,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) async {
    categoryUpdates.add(assignments);
    final result = await update(
      id: id,
      targetText: targetText,
      nativeText: nativeText,
    );
    committed = assignments;
    return result;
  }
}

class HeldMetadata implements CategoriesRepository {
  HeldMetadata(this.real);
  final CategoriesRepository real;
  final gate = Completer<void>();
  int reads = 0;
  bool fail = false;
  @override
  Future<List<CategoryDimensionRecord>> dimensions(String collectionId) =>
      real.dimensions(collectionId);
  @override
  Future<List<CategoryValueRecord>> values(String dimensionId) async {
    if (fail) throw StateError('Metadata unavailable');
    final snapshot = await real.values(dimensionId);
    if (reads++ == 0) await gate.future;
    return snapshot;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test(
    'explicit external deletion prunes effective opening without becoming an edit or blocking later autosave',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.close);
      final before = await f.learning();
      expect(before, hasLength(2));
      await f.categories.deleteDimension(f.dimension.id);
      await f.controller.refreshCategoryReferences(f.categories);
      expect(f.controller.draft.assignments, isEmpty);
      expect(f.controller.changedSinceOpening, isFalse);
      expect(f.controller.hasUncommittedChanges, isFalse);
      f.controller.setTargetText(' Still editable ');
      await f.controller.awaitSavedEdits();
      expect(f.controller.error, isNull);
      expect(f.controller.draft.targetText, ' Still editable ');
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.targetText,
        'Still editable',
      );
      expect(await f.learning(), before);
    },
  );

  test(
    'metadata failure preserves references; confirmed deletion preserves unrelated assignment and invalid raw draft',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.close);
      f.controller.edit(
        targetText: ' ',
        assignments: {
          f.dimension.id: {f.first.id, f.second.id},
        },
      );
      final broken = HeldMetadata(f.categories)..fail = true;
      await f.controller.refreshCategoryReferences(broken);
      expect(f.controller.draft.assignments[f.dimension.id], {
        f.first.id,
        f.second.id,
      });
      await f.categories.deleteValue(f.first.id);
      await f.controller.refreshCategoryReferences(f.categories);
      expect(f.controller.draft.targetText, ' ');
      expect(f.controller.draft.assignments[f.dimension.id], {f.second.id});
      expect(f.controller.error, VocabularyValidation.requiredTarget);
      expect(f.controller.changedSinceOpening, isTrue);
      f.controller.setTargetText('Valid again');
      await f.controller.awaitSavedEdits();
      expect(f.controller.error, isNull);
      expect((await f.categories.assignments(f.entry.id)).single.valueIds, {
        f.second.id,
      });
    },
  );

  test(
    'older metadata read cannot prune a value created and confirmed while reading',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.close);
      f.controller.setTargetText(' ');
      final held = HeldMetadata(f.categories);
      final refresh = f.controller.refreshCategoryReferences(held);
      while (held.reads == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final added = await f.categories.createValue(
        dimensionId: f.dimension.id,
        name: 'New value',
      );
      f.controller.setCategoryValues(f.dimension.id, {added.id});
      held.gate.complete();
      await refresh;
      expect(held.reads, greaterThanOrEqualTo(2));
      expect(f.controller.draft.assignments[f.dimension.id], {added.id});
      expect(f.controller.draft.targetText, ' ');
      f.controller.setTargetText('After new value');
      await f.controller.awaitSavedEdits();
      expect((await f.categories.assignments(f.entry.id)).single.valueIds, {
        added.id,
      });
    },
  );

  test(
    'metadata refresh never silently resolves a Single conflict in the assignment draft',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.close);
      f.controller.setTargetText(' ');
      f.controller.setCategoryValues(f.dimension.id, {f.first.id, f.second.id});
      await f.categories.updateDimension(
        id: f.dimension.id,
        name: f.dimension.name,
        mode: CategoryMode.single,
      );
      await f.controller.refreshCategoryReferences(f.categories);
      expect(f.controller.draft.assignments[f.dimension.id], {
        f.first.id,
        f.second.id,
      });
      f.controller.setTargetText('Conflicting draft');
      await f.controller.awaitSavedEdits();
      expect(f.controller.error, CategoryValidation.cardinalityViolation);
      expect((await f.categories.assignments(f.entry.id)).single.valueIds, {
        f.first.id,
      });
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.targetText,
        'One',
      );
    },
  );

  test(
    'invalid raw text retains immutable assignment draft until valid pair saves atomically with unchanged learning',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.close);
      final before = await f.learning();
      expect(before, hasLength(2));
      f.controller.setTargetText(' ');
      final selected = {f.second.id};
      f.controller.setCategoryValues(f.dimension.id, selected);
      selected.clear();
      expect(f.controller.draft.assignments[f.dimension.id], {f.second.id});
      expect(
        () => f.controller.draft.assignments[f.dimension.id]!.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => f.controller.draft.assignments.clear(),
        throwsUnsupportedError,
      );
      await f.controller.awaitSavedEdits();
      expect((await f.categories.assignments(f.entry.id)).single.valueIds, {
        f.first.id,
      });
      expect(f.controller.error, VocabularyValidation.requiredTarget);
      f.controller.setTargetText(' New raw ');
      await f.controller.awaitSavedEdits();
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.targetText,
        'New raw',
      );
      expect((await f.categories.assignments(f.entry.id)).single.valueIds, {
        f.second.id,
      });
      expect(f.controller.draft.targetText, ' New raw ');
      expect(f.controller.hasUncommittedChanges, isFalse);
      expect(f.controller.changedSinceOpening, isTrue);
      expect(await f.learning(), before);
    },
  );

  test(
    'duplicate pair rejection retains pending assignments and committed category pair until a valid edit',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.close);
      await f.vocabulary.create(
        collectionId: f.entry.collectionId,
        targetText: 'Two',
        nativeText: 'Zwei',
      );
      f.controller.edit(
        targetText: 'Two',
        nativeText: 'Zwei',
        assignments: {
          f.dimension.id: {f.second.id},
        },
      );
      await f.controller.awaitSavedEdits();
      expect(f.controller.error, VocabularyValidation.duplicatePair);
      expect(f.controller.draft.assignments[f.dimension.id], {f.second.id});
      expect((await f.categories.assignments(f.entry.id)).single.valueIds, {
        f.first.id,
      });
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.targetText,
        'One',
      );
      f.controller.setTargetText('Three');
      await f.controller.awaitSavedEdits();
      expect((await f.categories.assignments(f.entry.id)).single.valueIds, {
        f.second.id,
      });
      expect(f.controller.error, isNull);
    },
  );

  test(
    'Discard restores opening categories, prunes deliberately deleted values, and permits later text editing',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.close);
      final before = await f.learning();
      f.controller.edit(
        targetText: 'Changed',
        assignments: {
          f.dimension.id: {f.second.id},
        },
      );
      await f.controller.awaitSavedEdits();
      await f.categories.deleteValue(f.first.id);
      await f.controller.discard();
      expect(f.controller.draft.targetText, 'One');
      expect(f.controller.draft.assignments, isEmpty);
      expect(await f.categories.assignments(f.entry.id), isEmpty);
      expect(f.controller.changedSinceOpening, isFalse);
      f.controller.setTargetText('After discard');
      await f.controller.awaitSavedEdits();
      expect(f.controller.error, isNull);
      expect(await f.categories.valueById(f.first.id), isNull);
      expect(await f.learning(), before);
    },
  );

  test(
    'Discard fails atomically when opening multiple values conflict with a newly Single dimension',
    () async {
      final f = Fixture();
      await f.initialize();
      f.controller.dispose();
      await f.categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          f.dimension.id: {f.first.id, f.second.id},
        },
      );
      f.controller = await InlineVocabularyEditController.open(
        entryId: f.entry.id,
        collectionId: f.entry.collectionId,
        repository: f.vocabulary,
      );
      addTearDown(f.close);
      f.controller.edit(
        targetText: 'Kept current',
        assignments: {
          f.dimension.id: {f.second.id},
        },
      );
      await f.controller.awaitSavedEdits();
      await f.categories.updateDimension(
        id: f.dimension.id,
        name: f.dimension.name,
        mode: CategoryMode.single,
      );
      await expectLater(
        f.controller.discard(),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.targetText,
        'Kept current',
      );
      expect((await f.categories.assignments(f.entry.id)).single.valueIds, {
        f.second.id,
      });
      expect(f.controller.draft.targetText, 'Kept current');
      expect(
        f.controller.discardError,
        CategoryValidation.cardinalityViolation,
      );
    },
  );

  test(
    'category snapshots serialize/coalesce and stale duplicate failures cannot replace newer required validation',
    () async {
      final repository = ControlledCategories();
      final controller = await InlineVocabularyEditController.open(
        entryId: 'entry',
        collectionId: 'owner',
        repository: repository,
      );
      addTearDown(controller.dispose);
      controller.setTargetText('First write');
      controller.setCategoryValues('dimension', {'second'});
      controller.setTargetText(' ');
      repository.updates.first.result.completeError(
        VocabularyValidation.duplicatePair,
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.updates, hasLength(2));
      expect(repository.categoryUpdates.last['dimension'], {'second'});
      repository.updates.last.result.complete(
        const VocabularyRecord(
          id: 'entry',
          collectionId: 'owner',
          targetText: 'First write',
          nativeText: 'Eins',
        ),
      );
      await controller.awaitSavedEdits();
      expect(controller.draft.targetText, ' ');
      expect(controller.draft.assignments['dimension'], {'second'});
      expect(controller.error, VocabularyValidation.requiredTarget);
      expect(controller.committed.targetText, 'First write');
    },
  );
}
