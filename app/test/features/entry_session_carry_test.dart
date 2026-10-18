import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import '../data/regular_reviews_test.dart' show Fixture, rows;
import '../data/statistics_test.dart' show stored;

class CarryFixture {
  final data = Fixture();
  late final categories = SqliteCategoriesRepository(data.db);
  late final deletion = SqliteVocabularyDeletionService(data.db);
  late EntrySessionController session;
  final groups = <CategoryDimensionRecord>[];
  final values = <List<CategoryValueRecord>>[];
  Future<void> initialize() async {
    await data.initialize();
    await data.review();
    for (var i = 0; i < 3; i++) {
      final group = await categories.createDimension(
        collectionId: data.owner.id,
        name: 'Group $i',
        mode: i == 0 ? CategoryMode.single : CategoryMode.multiple,
        carryOver: i < 2,
      );
      groups.add(group);
      values.add([
        for (var j = 0; j < 2; j++)
          await categories.createValue(dimensionId: group.id, name: 'Value $j'),
      ]);
    }
    session = newSession();
  }

  EntrySessionController newSession() => EntrySessionController(
    collectionId: data.owner.id,
    repository: data.vocabulary,
    deletionService: deletion,
  );
  Map<String, Set<String>> get all => {
    groups[0].id: {values[0][0].id},
    groups[1].id: values[1].map((v) => v.id).toSet(),
    groups[2].id: {values[2][0].id},
  };
  Map<String, Set<String>> get enabled => {...all}..remove(groups[2].id);
  void select(Map<String, Set<String>> assignments) {
    for (final g in groups) {
      session.setCategoryValues(
        dimensionId: g.id,
        valueIds: assignments[g.id] ?? {},
      );
    }
  }

  Future<VocabularyRecord> confirm(String word) {
    session.setTargetText(' $word ');
    session.setNativeText(' $word native ');
    return session.confirmAndNext();
  }

  Future<void> close() async {
    session.dispose();
    await session.awaitSavedEdits();
    deletion.dispose();
    await data.db.close();
  }
}

void main() {
  test(
    'only successful new confirmations carry enabled groups, failed/duplicate attempts retain exact draft',
    () async {
      final f = CarryFixture();
      await f.initialize();
      addTearDown(f.close);
      expect(f.session.draft.assignments, isEmpty);
      f.select(f.all);
      final learning = await rows(f.data.db, 'learning_items');
      final first = await f.confirm('A');
      expect(f.session.draft.assignments, f.enabled);
      expect(f.session.hasDraftCategoryEdits, isFalse);
      f.session.setCategoryValues(dimensionId: f.groups[0].id, valueIds: {});
      expect(f.session.hasDraftCategoryEdits, isTrue);
      f.session.setCategoryValues(
        dimensionId: f.groups[1].id,
        valueIds: {f.values[1][1].id},
      );
      await expectLater(
        f.confirm('A'),
        throwsA(VocabularyValidation.duplicatePair),
      );
      expect(f.session.confirmedEntries.map((e) => e.id), [first.id]);
      final raw = f.session.draft;
      await f.data.db.customStatement(
        "CREATE TRIGGER fail_entry BEFORE INSERT ON vocabulary_entries BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      await expectLater(f.session.confirmAndNext(), throwsA(anything));
      expect(f.session.draft, same(raw));
      await f.data.db.customStatement('DROP TRIGGER fail_entry');
      f.session.setTargetText(' B ');
      f.session.setNativeText(' B native ');
      final pending = f.session.confirmAndNext();
      expect(f.session.confirmAndNext(), same(pending));
      await pending;
      expect(f.session.confirmedEntries.length, 2);
      expect(f.session.draft.assignments, {
        f.groups[1].id: {f.values[1][1].id},
      });
      final newLearning = await rows(f.data.db, 'learning_items');
      expect(
        newLearning
            .where((r) => learning.any((old) => old['id'] == r['id']))
            .toList(),
        learning,
      );
      expect(newLearning.length, learning.length + 4);
      await f.session.completeSession();
      expect(
        f.session.isCompleted,
        isTrue,
        reason: 'untouched carry must not force a blank word on Finish',
      );
      expect(f.session.confirmedEntries.length, 2);
      final fresh = f.newSession();
      expect(fresh.draft.assignments, isEmpty);
      fresh.dispose();
    },
  );

  test(
    'saved-card edits and setting changes never rewrite the initialized draft; subsequent drafts use current flags',
    () async {
      final f = CarryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.select(f.all);
      final first = await f.confirm('A');
      final draft = f.session.draft;
      f.session.selectSavedEntry(first.id);
      f.session.setCategoryValues(
        entryId: first.id,
        dimensionId: f.groups[1].id,
        valueIds: {},
      );
      await f.session.awaitSavedEdits();
      f.session.selectDraft();
      expect(f.session.draft, same(draft));
      await f.categories.updateDimension(
        id: f.groups[0].id,
        name: f.groups[0].name,
        mode: CategoryMode.single,
        carryOver: false,
      );
      expect(f.session.draft.assignments, f.enabled);
      await f.confirm('B');
      expect(f.session.draft.assignments, {
        f.groups[1].id: f.enabled[f.groups[1].id]!,
      });
      f.session.setCategoryValues(dimensionId: f.groups[1].id, valueIds: {});
      f.session.selectSavedEntry(first.id);
      f.session.selectDraft();
      expect(f.session.draft.assignments, isEmpty);
      await f.confirm('C');
      expect(f.session.draft.assignments, isEmpty);
    },
  );

  test(
    'source deletion/Undo does not overwrite a carried draft or later preferences, removed definitions never revive',
    () async {
      final f = CarryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.select(f.all);
      final first = await f.confirm('A');
      await f.session.deleteSavedEntry(first.id);
      expect(f.session.draft.assignments, f.enabled);
      await f.categories.deleteValue(f.values[1][0].id);
      await f.categories.deleteDimension(f.groups[0].id);
      await f.categories.updateDimension(
        id: f.groups[1].id,
        name: 'Changed',
        mode: CategoryMode.single,
        carryOver: false,
      );
      await f.session.refreshCategoryReferences(f.categories);
      expect(f.session.draft.assignments, {
        f.groups[1].id: {f.values[1][1].id},
      });
      expect(f.session.hasDraftCategoryEdits, isFalse);
      await f.session.undoDeletion(first.id);
      expect(f.session.draft.assignments, {
        f.groups[1].id: {f.values[1][1].id},
      });
      expect(
        (await f.categories.dimensionById(f.groups[1].id))!.carryOver,
        isFalse,
      );
      expect(await f.categories.dimensionById(f.groups[0].id), isNull);
      await f.confirm('B');
      expect(f.session.draft.assignments, isEmpty);
    },
  );

  test(
    'current cardinality/ownership conflicts roll back every write and preserve recoverable raw input',
    () async {
      final f = CarryFixture();
      await f.initialize();
      addTearDown(f.close);
      f.select(f.all);
      final first = await f.confirm('A');
      // Release the stored conflict while leaving the already copied draft intact.
      await f.categories.replaceAssignments(entryId: first.id, assignments: {});
      await f.categories.updateDimension(
        id: f.groups[1].id,
        name: 'Single now',
        mode: CategoryMode.single,
      );
      f.session.setTargetText(' raw B ');
      f.session.setNativeText(' raw native ');
      final draft = f.session.draft, before = await stored(f.data.db);
      await expectLater(
        f.session.confirmAndNext(),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(f.session.draft, same(draft));
      expect(await stored(f.data.db), before);
      f.session.setCategoryValues(
        dimensionId: f.groups[1].id,
        valueIds: {f.values[1][1].id},
      );
      await f.categories.deleteValue(f.values[1][1].id);
      await expectLater(f.session.confirmAndNext(), throwsA(anything));
      expect(f.session.draft.targetText, ' raw B ');
      await f.session.refreshCategoryReferences(f.categories);
      await f.session.confirmAndNext();
      expect(f.session.draft.assignments, {
        f.groups[0].id: {f.values[0][0].id},
      });
    },
  );

  test(
    'atomic confirmation freezes admitted inputs and returns immutable assignments only from its own collection',
    () async {
      final f = CarryFixture();
      await f.initialize();
      addTearDown(f.close);
      final assignments = f.all;
      final pending = f.data.vocabulary.confirmNewEntry(
        collectionId: f.data.owner.id,
        targetText: 'Frozen',
        nativeText: 'Fest',
        assignments: assignments,
        content: const VocabularyContent(),
      );
      assignments[f.groups[0].id]!.clear();
      final result = await pending;
      expect(result.nextAssignments, f.enabled);
      expect(() => result.nextAssignments.clear(), throwsUnsupportedError);
      expect(
        () => result.nextAssignments[f.groups[0].id]!.clear(),
        throwsUnsupportedError,
      );
      final before = await stored(f.data.db);
      await expectLater(
        f.data.vocabulary.confirmNewEntry(
          collectionId: f.data.kept.id,
          targetText: 'Foreign',
          nativeText: 'Fremd',
          assignments: f.all,
          content: const VocabularyContent(),
        ),
        throwsA(CategoryValidation.invalidOwnership),
      );
      expect(await stored(f.data.db), before);
    },
  );
}
