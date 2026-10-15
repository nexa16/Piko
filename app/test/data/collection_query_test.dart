import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'speed_eligibility_test.dart' show completeSnapshot;

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  test(
    'category filtering is OR within a dimension, AND across dimensions, and retains all metadata and display order',
    () async {
      final f = await fixture();
      final query = SqliteCollectionQueryService(f.db),
          categories = SqliteCategoriesRepository(f.db);
      final second = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Two',
        nativeText: 'Zwei',
      );
      final third = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Three',
        nativeText: 'Drei',
      );
      final topic = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final unit = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Unit',
        mode: CategoryMode.single,
      );
      final food = await categories.createValue(
        dimensionId: topic.id,
        name: 'Food',
      );
      final travel = await categories.createValue(
        dimensionId: topic.id,
        name: 'Travel',
      );
      final one = await categories.createValue(
        dimensionId: unit.id,
        name: 'One',
      );
      final two = await categories.createValue(
        dimensionId: unit.id,
        name: 'Two',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          topic.id: {food.id},
          unit.id: {one.id},
        },
      );
      await categories.replaceAssignments(
        entryId: second.id,
        assignments: {
          topic.id: {travel.id},
          unit.id: {one.id},
        },
      );
      await categories.replaceAssignments(
        entryId: third.id,
        assignments: {
          topic.id: {food.id, travel.id},
          unit.id: {two.id},
        },
      );
      final before = await completeSnapshot(f.db);
      final selected = {
        topic.id: {travel.id, food.id},
        unit.id: {one.id},
      };
      final pending = query.query(
        collectionId: f.owner.id,
        at: instant,
        filters: selected,
      );
      selected[unit.id]!
          .clear(); // The query captures caller-owned selection sets.
      final snapshot = await pending;
      expect(snapshot.entries.map((entry) => entry.id), [
        f.entry.id,
        second.id,
      ]);
      expect(snapshot.allEntries.map((entry) => entry.id), [
        f.entry.id,
        second.id,
        third.id,
      ]);
      expect(snapshot.categoryDimensions.map((dimension) => dimension.id), [
        topic.id,
        unit.id,
      ]);
      expect(snapshot.categoryValues[topic.id]!.map((value) => value.id), [
        food.id,
        travel.id,
      ]);
      expect(
        snapshot.assignments[third.id]!.map(
          (assignment) => assignment.dimensionId,
        ),
        [topic.id, unit.id],
      );
      expect(snapshot.assignments[third.id]!.first.valueIds.toList(), [
        food.id,
        travel.id,
      ]);
      for (final direction in LearningDirection.values) {
        expect(snapshot.directions[direction]!.dueCount, 2);
        expect(
          snapshot.directions[direction]!.newSpeedItems.map(
            (item) => item.entryId,
          ),
          [f.entry.id, second.id],
        );
      }
      expect(() => snapshot.entries.clear(), throwsUnsupportedError);
      expect(
        () => snapshot.categoryValues[topic.id]!.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.assignments[third.id]!.first.valueIds.clear(),
        throwsUnsupportedError,
      );
      expect(await completeSnapshot(f.db), before);
      final unselected = await query.query(
        collectionId: f.owner.id,
        at: instant,
        filters: {topic.id: {}},
      );
      expect(unselected.entries, hasLength(3));
    },
  );

  test(
    'passive directional counts separate pending retries from eligibility, never double count and preserve expired rows',
    () async {
      final f = await fixture();
      final query = SqliteCollectionQueryService(f.db);
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      final item = await f.current();
      await f.learning.saveCard(item.id, item.card..due = instant);
      final before = await completeSnapshot(f.db);
      final waiting = await query.query(collectionId: f.owner.id, at: instant);
      final forward = waiting.directions[LearningDirection.targetToNative]!;
      expect(forward.dueCount, 0);
      expect(forward.pendingRetryCount, 1);
      expect(forward.review.single.regularDue, isFalse);
      expect(forward.newSpeedItems, isEmpty);
      expect(waiting.directions[LearningDirection.nativeToTarget]!.dueCount, 1);
      expect(waiting.nextChangeAt, retry.expiresAt);
      expect(await completeSnapshot(f.db), before);
      await f.makeRetryEligible(retry);
      final eligible = await query.query(collectionId: f.owner.id, at: instant);
      expect(
        eligible.directions[LearningDirection.targetToNative]!.dueCount,
        1,
      );
      expect(
        eligible
            .directions[LearningDirection.targetToNative]!
            .pendingRetryCount,
        1,
      );
      final beforeExpiryRead = await completeSnapshot(f.db);
      final expired = await query.query(
        collectionId: f.owner.id,
        at: retry.expiresAt,
      );
      expect(
        expired.directions[LearningDirection.targetToNative]!.pendingRetryCount,
        0,
      );
      expect(expired.directions[LearningDirection.targetToNative]!.dueCount, 1);
      expect(await completeSnapshot(f.db), beforeExpiryRead);
    },
  );

  test(
    'next-change boundary and Speed/review membership belong only to visible entries',
    () async {
      final f = await fixture();
      final second = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Two',
        nativeText: 'Zwei',
      );
      final categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      final value = await categories.createValue(
        dimensionId: dimension.id,
        name: 'Selected',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          dimension.id: {value.id},
        },
      );
      for (final item in await f.learning.forEntry(f.entry.id)) {
        await f.learning.saveCard(
          item.id,
          item.card..due = instant.add(const Duration(minutes: 10)),
        );
      }
      for (final item in await f.learning.forEntry(second.id)) {
        await f.learning.saveCard(
          item.id,
          item.card..due = instant.add(const Duration(minutes: 1)),
        );
      }
      final query = SqliteCollectionQueryService(f.db);
      final selected = await query.query(
        collectionId: f.owner.id,
        at: instant,
        filters: {
          dimension.id: {value.id},
        },
      );
      expect(selected.nextChangeAt, instant.add(const Duration(minutes: 10)));
      for (final direction in LearningDirection.values) {
        expect(selected.directions[direction]!.dueCount, 0);
        expect(
          selected.directions[direction]!.newSpeedItems.map(
            (item) => item.entryId,
          ),
          [f.entry.id],
        );
      }
      final overview = await query.query(collectionId: f.owner.id, at: instant);
      expect(overview.nextChangeAt, instant.add(const Duration(minutes: 1)));
      expect(overview.allEntries, hasLength(2));
    },
  );

  test(
    'no matches, empty Collection, missing owner and invalid filters remain distinct',
    () async {
      final f = await fixture(), query = SqliteCollectionQueryService(f.db);
      final categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      final value = await categories.createValue(
        dimensionId: dimension.id,
        name: 'Unassigned',
      );
      final noMatches = await query.query(
        collectionId: f.owner.id,
        at: instant,
        filters: {
          dimension.id: {value.id},
        },
      );
      expect(noMatches.entries, isEmpty);
      expect(noMatches.allEntries, hasLength(1));
      expect(noMatches.nextChangeAt, isNull);
      expect(
        noMatches.directions.values.every(
          (direction) =>
              direction.review.isEmpty && direction.newSpeedItems.isEmpty,
        ),
        isTrue,
      );
      final before = await completeSnapshot(f.db);
      await expectLater(
        query.query(collectionId: 'missing', at: instant),
        throwsA(CollectionQueryFailure.collectionNotFound),
      );
      await expectLater(
        query.query(
          collectionId: f.owner.id,
          at: instant,
          filters: {
            dimension.id: {'missing'},
          },
        ),
        throwsA(CollectionQueryFailure.invalidFilter),
      );
      await expectLater(
        query.query(
          collectionId: f.kept.id,
          at: instant,
          filters: {
            dimension.id: {value.id},
          },
        ),
        throwsA(CollectionQueryFailure.invalidFilter),
      );
      expect(await completeSnapshot(f.db), before);
      await (f.db.delete(
        f.db.vocabularyEntries,
      )..where((row) => row.id.equals(f.entry.id))).go();
      final empty = await query.query(collectionId: f.owner.id, at: instant);
      expect(empty.allEntries, isEmpty);
      expect(empty.entries, isEmpty);
    },
  );

  test(
    'corrupt card state remains an error instead of a fabricated empty result',
    () async {
      final f = await fixture(), query = SqliteCollectionQueryService(f.db);
      final item = await f.current();
      await f.db.customStatement(
        'UPDATE learning_items SET card_json = ? WHERE id = ?',
        ['{}', item.id],
      );
      final before = await completeSnapshot(f.db);
      await expectLater(
        query.query(collectionId: f.owner.id, at: instant),
        throwsFormatException,
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'missing learning fails even if filters would hide the damaged entry',
    () async {
      final f = await fixture(), query = SqliteCollectionQueryService(f.db);
      final categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      final value = await categories.createValue(
        dimensionId: dimension.id,
        name: 'Unused',
      );
      final reverse = await f.current(f.entry, true);
      await (f.db.delete(
        f.db.learningItems,
      )..where((row) => row.id.equals(reverse.id))).go();
      final before = await completeSnapshot(f.db);
      await expectLater(
        query.query(
          collectionId: f.owner.id,
          at: instant,
          filters: {
            dimension.id: {value.id},
          },
        ),
        throwsA(CollectionQueryFailure.incompleteLearning),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );
}
