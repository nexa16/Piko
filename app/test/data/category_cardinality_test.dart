import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture;
import 'retry_gap_migration_test.dart' show storedSnapshot, storedRows;

void main() {
  late Fixture f;
  late SqliteCategoriesRepository categories;
  late CategoryDimensionRecord single, multiple;
  late CategoryValueRecord first, second, other;
  setUp(() async {
    f = Fixture();
    await f.initialize();
    categories = SqliteCategoriesRepository(f.db);
    single = await categories.createDimension(
      collectionId: f.owner.id,
      name: 'Unit',
      mode: CategoryMode.single,
    );
    multiple = await categories.createDimension(
      collectionId: f.owner.id,
      name: 'Topic',
      mode: CategoryMode.multiple,
    );
    first = await categories.createValue(dimensionId: single.id, name: 'One');
    second = await categories.createValue(dimensionId: single.id, name: 'Two');
    other = await categories.createValue(
      dimensionId: multiple.id,
      name: 'Food',
    );
  });
  tearDown(() => f.db.close());

  Future<Map<String, Set<String>>> assigned(String entryId) async => {
    for (final group in await categories.assignments(entryId))
      group.dimensionId: group.valueIds,
  };
  Future<Map<String, Object?>> completeSnapshot() async => {
    ...await storedSnapshot(f.db),
    for (final table in [
      'category_dimensions',
      'category_values',
      'vocabulary_category_assignments',
    ])
      table: await storedRows(f.db, table),
  };

  test(
    'Single selection replaces only that dimension; Multiple selection adds and deselection is explicit',
    () async {
      final more = await categories.createValue(
        dimensionId: multiple.id,
        name: 'Travel',
      );
      final before = await storedSnapshot(f.db);
      await categories.setValueSelected(
        entryId: f.entry.id,
        valueId: first.id,
        selected: true,
      );
      await categories.setValueSelected(
        entryId: f.entry.id,
        valueId: other.id,
        selected: true,
      );
      await categories.setValueSelected(
        entryId: f.entry.id,
        valueId: second.id,
        selected: true,
      );
      await categories.setValueSelected(
        entryId: f.entry.id,
        valueId: more.id,
        selected: true,
      );
      expect(await assigned(f.entry.id), {
        single.id: {second.id},
        multiple.id: {other.id, more.id},
      });
      // Deselecting a superseded Single value does not clear the current choice.
      await categories.setValueSelected(
        entryId: f.entry.id,
        valueId: first.id,
        selected: false,
      );
      expect((await assigned(f.entry.id))[single.id], {second.id});
      await categories.setValueSelected(
        entryId: f.entry.id,
        valueId: other.id,
        selected: false,
      );
      await categories.setValueSelected(
        entryId: f.entry.id,
        valueId: second.id,
        selected: false,
      );
      expect(await assigned(f.entry.id), {
        multiple.id: {more.id},
      });
      await expectLater(
        categories.setValueSelected(
          entryId: f.other.id,
          valueId: first.id,
          selected: false,
        ),
        throwsA(CategoryValidation.invalidOwnership),
      );
      await expectLater(
        categories.setValueSelected(
          entryId: 'missing',
          valueId: first.id,
          selected: true,
        ),
        throwsA(CategoryValidation.entryNotFound),
      );
      expect(await storedSnapshot(f.db), before);
    },
  );

  test(
    'full replacement rejects multiple Single values without choosing or changing anything',
    () async {
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          single.id: {first.id},
          multiple.id: {other.id},
        },
      );
      final before = await completeSnapshot();
      await expectLater(
        categories.replaceAssignments(
          entryId: f.entry.id,
          assignments: {
            single.id: {first.id, second.id},
          },
        ),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(await completeSnapshot(), before);
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          single.id: {second.id},
        },
      );
      expect(await assigned(f.entry.id), {
        single.id: {second.id},
      });
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {single.id: {}},
      );
      expect(await assigned(f.entry.id), isEmpty);
    },
  );

  test(
    'name and mode confirm together; any conflicting retained entry blocks the entire update',
    () async {
      final extra = await categories.createValue(
        dimensionId: multiple.id,
        name: 'Travel',
      );
      final retained = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Three',
        nativeText: 'Drei',
      );
      for (final entry in [f.entry, retained]) {
        await categories.replaceAssignments(
          entryId: entry.id,
          assignments: {
            multiple.id: {other.id, extra.id},
          },
        );
      }
      final before = await completeSnapshot();
      await expectLater(
        categories.updateDimension(
          id: multiple.id,
          name: 'New name',
          mode: CategoryMode.single,
        ),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(await completeSnapshot(), before);
      await categories.setValueSelected(
        entryId: f.entry.id,
        valueId: extra.id,
        selected: false,
      );
      final oneStillConflicts = await completeSnapshot();
      await expectLater(
        categories.updateDimension(
          id: multiple.id,
          name: 'New name',
          mode: CategoryMode.single,
        ),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(await completeSnapshot(), oneStillConflicts);
      await categories.setValueSelected(
        entryId: retained.id,
        valueId: extra.id,
        selected: false,
      );
      final resolved = await completeSnapshot();
      await expectLater(
        categories.updateDimension(
          id: multiple.id,
          name: ' unit ',
          mode: CategoryMode.single,
        ),
        throwsA(CategoryValidation.duplicateName),
      );
      expect(await completeSnapshot(), resolved);
      await expectLater(
        categories.updateDimension(
          id: multiple.id,
          name: ' \n ',
          mode: CategoryMode.single,
        ),
        throwsA(CategoryValidation.requiredName),
      );
      expect(await completeSnapshot(), resolved);
      final changed = await categories.updateDimension(
        id: multiple.id,
        name: ' Subject ',
        mode: CategoryMode.single,
      );
      expect(changed.name, 'Subject');
      expect(changed.mode, CategoryMode.single);
      expect(changed.id, multiple.id);
      expect(changed.position, multiple.position);
      expect((await assigned(f.entry.id))[multiple.id], {other.id});
      expect((await assigned(retained.id))[multiple.id], {other.id});
      await categories.updateDimension(
        id: multiple.id,
        name: 'Subject',
        mode: CategoryMode.multiple,
      );
      await categories.setValueSelected(
        entryId: retained.id,
        valueId: extra.id,
        selected: true,
      );
      expect((await assigned(retained.id))[multiple.id], {other.id, extra.id});
    },
  );

  test(
    'JSON-style outer batch reuses cardinality validation and rolls back earlier definitions and assignments',
    () async {
      await f.review(rating: LearningRating.again);
      final before = await completeSnapshot();
      await expectLater(
        f.db.transaction(() async {
          final newDimension = await categories.createDimension(
            collectionId: f.owner.id,
            name: 'Imported',
            mode: CategoryMode.multiple,
            id: '830c8308-e054-45da-a546-615131042e0a',
          );
          final newValue = await categories.createValue(
            dimensionId: newDimension.id,
            name: 'Imported value',
            id: '122cf790-ce4f-47d6-a4c1-aeff1a2646cb',
          );
          await categories.replaceAssignments(
            entryId: f.entry.id,
            assignments: {
              newDimension.id: {newValue.id},
            },
          );
          await categories.replaceAssignments(
            entryId: f.entry.id,
            assignments: {
              single.id: {first.id, second.id},
            },
          );
        }),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(await completeSnapshot(), before);
    },
  );

  test(
    'Undo conflicts atomically with a later Single mode and retains the original receipt for retry',
    () async {
      await f.review(rating: LearningRating.again);
      final extra = await categories.createValue(
        dimensionId: multiple.id,
        name: 'Travel',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          multiple.id: {other.id, extra.id},
        },
      );
      final before = await completeSnapshot();
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      final expiresAt = receipt.expiresAt;
      await categories.updateDimension(
        id: multiple.id,
        name: multiple.name,
        mode: CategoryMode.single,
      );
      final deleted = await completeSnapshot();
      await expectLater(
        deletion.restore(receipt),
        throwsA(VocabularyUndoFailure.categoryConflict),
      );
      expect(await completeSnapshot(), deleted);
      expect(deletion.canUndo(receipt), isTrue);
      expect(receipt.expiresAt, expiresAt);
      await categories.updateDimension(
        id: multiple.id,
        name: multiple.name,
        mode: CategoryMode.multiple,
      );
      await deletion.restore(receipt);
      expect(await assigned(f.entry.id), {
        multiple.id: {other.id, extra.id},
      });
      final restored = await completeSnapshot();
      final restoredAssignments =
          restored.remove('vocabulary_category_assignments') as List;
      final originalAssignments =
          before.remove('vocabulary_category_assignments') as List;
      // Assignment identity is the owner/dimension/value relation; successful
      // restoration need not reproduce internal SQLite assignment rowids.
      Set<(Object?, Object?, Object?, Object?)> identities(List rows) => {
        for (final row in rows.cast<Map>())
          (
            row['entry_id'],
            row['collection_id'],
            row['dimension_id'],
            row['value_id'],
          ),
      };
      expect(identities(restoredAssignments), identities(originalAssignments));
      expect(restored, before);
      expect(deletion.canUndo(receipt), isFalse);
    },
  );
}
