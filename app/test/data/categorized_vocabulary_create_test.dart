import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'regular_reviews_test.dart' show Fixture;
import 'speed_eligibility_test.dart' show completeSnapshot;

void main() {
  test(
    'new vocabulary and fresh directional learning commit with immutable assignments',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      final value = await categories.createValue(
        dimensionId: dimension.id,
        name: 'School',
      );
      final requested = {
        dimension.id: {value.id},
      };
      final pending = f.vocabulary.createCategorized(
        collectionId: f.owner.id,
        targetText: '  학교  ',
        nativeText: 'Schule',
        assignments: requested,
      );
      requested[dimension.id]!.clear();
      final entry = await pending;
      expect(entry.targetText, '학교');
      expect(await f.vocabulary.categorizedAssignments(entry.id), {
        dimension.id: {value.id},
      });
      final learning = await (f.db.select(
        f.db.learningItems,
      )..where((row) => row.entryId.equals(entry.id))).get();
      expect(learning.map((row) => row.direction).toSet(), {
        'targetToNative',
        'nativeToTarget',
      });
      for (final row in learning) {
        expect(row.generation, 0);
        expect(row.reviewRevision, 0);
        expect(row.speedCompleted, false);
        expect(row.cardJson, isNotEmpty);
      }
    },
  );

  test(
    'invalid ownership, cardinality and late storage failure never leave partial vocabulary',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final categories = SqliteCategoriesRepository(f.db);
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
      final foreign = await categories.createDimension(
        collectionId: f.kept.id,
        name: 'Other',
        mode: CategoryMode.single,
      );
      final before = await completeSnapshot(f.db);
      for (final (selection, error)
          in <(Map<String, Set<String>>, CategoryValidation)>[
            (
              {
                'missing': {first.id},
              },
              CategoryValidation.dimensionNotFound,
            ),
            ({foreign.id: {}}, CategoryValidation.invalidOwnership),
            (
              {
                dimension.id: {'missing'},
              },
              CategoryValidation.valueNotFound,
            ),
            (
              {
                dimension.id: {first.id, second.id},
              },
              CategoryValidation.cardinalityViolation,
            ),
          ]) {
        await expectLater(
          f.vocabulary.createCategorized(
            collectionId: f.owner.id,
            targetText: '학교',
            nativeText: 'Schule',
            assignments: selection,
          ),
          throwsA(error),
        );
        expect(await completeSnapshot(f.db), before);
      }
      await f.db.customStatement(
        "CREATE TRIGGER fail_assignment BEFORE INSERT ON vocabulary_category_assignments BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
      );
      await expectLater(
        f.vocabulary.createCategorized(
          collectionId: f.owner.id,
          targetText: '학교',
          nativeText: 'Schule',
          assignments: {
            dimension.id: {first.id},
          },
        ),
        throwsA(isA<Exception>()),
      );
      expect(await completeSnapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER fail_assignment');
      final created = await f.vocabulary.createCategorized(
        collectionId: f.owner.id,
        targetText: '학교',
        nativeText: 'Schule',
        assignments: {
          dimension.id: {first.id},
        },
      );
      expect(await f.vocabulary.categorizedAssignments(created.id), {
        dimension.id: {first.id},
      });
    },
  );
}
