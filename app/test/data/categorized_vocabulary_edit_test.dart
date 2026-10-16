import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'regular_reviews_test.dart' show Fixture;
import 'speed_eligibility_test.dart' show completeSnapshot;

Future<Fixture> fixture() async {
  final f = Fixture();
  await f.initialize();
  addTearDown(f.db.close);
  return f;
}

void main() {
  test(
    'capture, atomic content+assignments and Discard preserve UUID/order/learning exactly',
    () async {
      final f = await fixture(), categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final first = await categories.createValue(
        dimensionId: dimension.id,
        name: 'First',
      );
      final second = await categories.createValue(
        dimensionId: dimension.id,
        name: 'Second',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          dimension.id: {first.id},
        },
      );
      await f.review();
      final before = await completeSnapshot(f.db);
      final opening =
          await f.vocabulary.captureOpeningSnapshot(
                entryId: f.entry.id,
                collectionId: f.owner.id,
              )
              as CategorizedVocabularyOpeningSnapshot;
      expect(
        () => opening.assignments[dimension.id]!.clear(),
        throwsUnsupportedError,
      );
      final requested = {
        dimension.id: {second.id},
      };
      final save = f.vocabulary.updateCategorized(
        id: f.entry.id,
        targetText: 'Changed',
        nativeText: 'Geändert',
        assignments: requested,
      );
      requested[dimension.id]!.clear();
      await save;
      expect(await f.vocabulary.categorizedAssignments(f.entry.id), {
        dimension.id: {second.id},
      });
      await f.vocabulary.restoreOpeningSnapshot(opening);
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'invalid cardinality and late SQL failure roll back texts and all assignments',
    () async {
      final f = await fixture(), categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      final first = await categories.createValue(
        dimensionId: dimension.id,
        name: 'First',
      );
      final second = await categories.createValue(
        dimensionId: dimension.id,
        name: 'Second',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          dimension.id: {first.id},
        },
      );
      final before = await completeSnapshot(f.db);
      await expectLater(
        f.vocabulary.updateCategorized(
          id: f.entry.id,
          targetText: 'Changed',
          nativeText: 'Geändert',
          assignments: {
            dimension.id: {first.id, second.id},
          },
        ),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(await completeSnapshot(f.db), before);
      await f.db.customStatement(
        "CREATE TRIGGER fail_assignment BEFORE INSERT ON vocabulary_category_assignments BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
      );
      await expectLater(
        f.vocabulary.updateCategorized(
          id: f.entry.id,
          targetText: 'Changed',
          nativeText: 'Geändert',
          assignments: {
            dimension.id: {second.id},
          },
        ),
        throwsA(isA<Exception>()),
      );
      expect(await completeSnapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER fail_assignment');
      await f.vocabulary.updateCategorized(
        id: f.entry.id,
        targetText: 'Changed',
        nativeText: 'Geändert',
        assignments: {
          dimension.id: {second.id},
        },
      );
      expect(await f.vocabulary.categorizedAssignments(f.entry.id), {
        dimension.id: {second.id},
      });
    },
  );

  test(
    'Discard respects deleted definitions and fails atomically on a newly Single conflict',
    () async {
      final f = await fixture(), categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final first = await categories.createValue(
        dimensionId: dimension.id,
        name: 'First',
      );
      final second = await categories.createValue(
        dimensionId: dimension.id,
        name: 'Second',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          dimension.id: {first.id, second.id},
        },
      );
      final opening = await f.vocabulary.captureOpeningSnapshot(
        entryId: f.entry.id,
        collectionId: f.owner.id,
      );
      await f.vocabulary.updateCategorized(
        id: f.entry.id,
        targetText: 'Changed',
        nativeText: 'Geändert',
        assignments: {},
      );
      await categories.updateDimension(
        id: dimension.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      final beforeConflict = await completeSnapshot(f.db);
      await expectLater(
        f.vocabulary.restoreOpeningSnapshot(opening),
        throwsA(CategoryValidation.cardinalityViolation),
      );
      expect(await completeSnapshot(f.db), beforeConflict);
      await categories.deleteValue(second.id);
      await f.vocabulary.restoreOpeningSnapshot(opening);
      expect(await f.vocabulary.categorizedAssignments(f.entry.id), {
        dimension.id: {first.id},
      });
      await categories.deleteDimension(dimension.id);
      await f.vocabulary.restoreOpeningSnapshot(opening);
      expect(await f.vocabulary.categorizedAssignments(f.entry.id), isEmpty);
      expect(await categories.dimensionById(dimension.id), isNull);
    },
  );
}
