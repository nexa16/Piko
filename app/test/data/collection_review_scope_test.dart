import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'regular_reviews_test.dart' show Fixture, changed, instant, rows;

Future<List<Object>> snapshot(Fixture f) async => [
  await rows(f.db, 'learning_items'),
  await rows(f.db, 'regular_reviews'),
  await rows(f.db, 'vocabulary_entries'),
];

void main() {
  test(
    'scope requires an existing UUID, not the shared Collection name',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      final before = await snapshot(f);
      for (final id in ['', 'missing', f.owner.name]) {
        await expectLater(
          f.learning.forCollection(
            collectionId: id,
            direction: LearningDirection.targetToNative,
          ),
          throwsA(RegularReviewFailure.collectionNotFound),
        );
      }
      expect(await snapshot(f), before);
    },
  );

  test(
    'discovery isolates same-named UUIDs and both fixed directions',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      final second = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Three',
        nativeText: 'Drei',
      );
      final before = await snapshot(f);
      for (final collection in [f.owner, f.kept]) {
        for (final direction in LearningDirection.values) {
          final scope = await f.learning.forCollection(
            collectionId: collection.id,
            direction: direction,
          );
          final items = await scope.items();
          expect(scope.collectionId, collection.id);
          expect(scope.direction, direction);
          expect(items.map((item) => item.direction), everyElement(direction));
          expect(
            items.map((item) => item.entryId).toSet(),
            collection.id == f.owner.id
                ? {f.entry.id, second.id}
                : {f.other.id},
          );
          expect(() => items.clear(), throwsUnsupportedError);
          items.first.card.stability = 999;
          expect((await scope.items()).first.cardJson, items.first.cardJson);
        }
      }
      expect(await snapshot(f), before);
    },
  );

  for (final direction in LearningDirection.values) {
    test(
      'scoped coordinator persists only $direction with actual receipt',
      () async {
        final f = Fixture();
        addTearDown(f.db.close);
        await f.initialize();
        final scope = await f.learning.forCollection(
          collectionId: f.owner.id,
          direction: direction,
        );
        final coordinator = RegularGradingCoordinator(repository: scope);
        addTearDown(coordinator.dispose);
        final allBefore = await rows(f.db, 'learning_items');
        final prior = (await scope.items()).single;
        final handle = coordinator.activate(prior)!;
        coordinator.setHard(handle, true);
        final receipt = (await coordinator.submit(
          handle,
          AnswerGrade.correct,
          reviewedAt: instant,
        ))!;
        expect(receipt.prior.cardJson, prior.cardJson);
        expect(receipt.next.id, prior.id);
        expect(receipt.next.direction, direction);
        expect(receipt.next.reviewRevision, 1);
        expect(receipt.event.rating, LearningRating.hard);
        expect(receipt.event.reviewedAt, instant);
        expect(coordinator.accepted, same(receipt));
        expect((await scope.items()).single.cardJson, receipt.next.cardJson);
        final events = await f.learning.reviewsForItem(prior.id);
        expect(events.single.id, receipt.event.id);
        final allAfter = await rows(f.db, 'learning_items');
        expect(
          allAfter.where((row) => row['id'] != prior.id),
          allBefore.where((row) => row['id'] != prior.id),
        );
      },
    );
  }

  test(
    'foreign, opposite and forged prior submissions cannot cross scope',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      final scope = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final own = (await scope.items()).single;
      final foreign = await f.current(f.other);
      final opposite = await f.current(null, true);
      final before = await snapshot(f);
      for (final prior in [
        foreign,
        opposite,
        changed(foreign, entry: own.entryId, direction: own.direction),
        changed(opposite, direction: own.direction),
      ]) {
        await expectLater(
          scope.review(
            kind: ReviewKind.regular,
            expectedPrior: prior,
            rating: LearningRating.again,
            reviewedAt: instant,
          ),
          throwsA(RegularReviewFailure.outOfScope),
        );
        expect(await snapshot(f), before);
      }
      for (final prior in [
        changed(own, entry: foreign.entryId),
        changed(own, direction: opposite.direction),
        changed(own, revision: 1),
      ]) {
        await expectLater(
          scope.review(
            kind: ReviewKind.regular,
            expectedPrior: prior,
            rating: LearningRating.good,
            reviewedAt: instant,
          ),
          throwsA(RegularReviewFailure.staleState),
        );
        expect(await snapshot(f), before);
      }
    },
  );

  test(
    'authoritative ownership is rechecked after discovery and scope creation',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      final scope = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final prior = (await scope.items()).single;
      // Fixture relocation models changed authoritative ownership without changing
      // the item or its exact card. A cached list/expected prior must not authorize it.
      await (f.db.update(f.db.vocabularyEntries)
            ..where((entry) => entry.id.equals(prior.entryId)))
          .write(VocabularyEntriesCompanion(collectionId: Value(f.kept.id)));
      final moved = await snapshot(f);
      expect(await scope.items(), isEmpty);
      await expectLater(
        scope.review(
          kind: ReviewKind.regular,
          expectedPrior: prior,
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(RegularReviewFailure.outOfScope),
      );
      expect(await snapshot(f), moved);
      final newScope = await f.learning.forCollection(
        collectionId: f.kept.id,
        direction: prior.direction,
      );
      final accepted = await newScope.review(
        kind: ReviewKind.regular,
        expectedPrior: prior,
        rating: LearningRating.good,
        reviewedAt: instant,
      );
      expect(accepted.next.reviewRevision, 1);
      final after = await snapshot(f);
      await expectLater(
        newScope.review(
          kind: ReviewKind.regular,
          expectedPrior: prior,
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(RegularReviewFailure.staleState),
      );
      expect(await snapshot(f), after);
    },
  );

  test(
    'deleted entries and Collections cannot be graded by an old scope',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      for (final collection in [f.owner, f.kept]) {
        final scope = await f.learning.forCollection(
          collectionId: collection.id,
          direction: LearningDirection.targetToNative,
        );
        final prior = (await scope.items()).single;
        if (collection.id == f.owner.id) {
          await (f.db.delete(
            f.db.vocabularyEntries,
          )..where((entry) => entry.id.equals(prior.entryId))).go();
        } else {
          await f.collections.delete(collection.id);
        }
        final afterDelete = await snapshot(f);
        if (collection.id == f.owner.id) {
          expect(await scope.items(), isEmpty);
        } else {
          await expectLater(
            scope.items(),
            throwsA(RegularReviewFailure.collectionNotFound),
          );
        }
        await expectLater(
          scope.review(
            kind: ReviewKind.regular,
            expectedPrior: prior,
            rating: LearningRating.hard,
            reviewedAt: instant,
          ),
          throwsA(RegularReviewFailure.itemNotFound),
        );
        expect(await snapshot(f), afterDelete);
      }
    },
  );

  test(
    'scoped path retains reinforcement, corruption and rollback guards',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      final scope = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final prior = (await scope.items()).single;
      final before = await snapshot(f);
      await expectLater(
        scope.review(
          kind: ReviewKind.reinforcement,
          expectedPrior: changed(prior, json: 'invalid'),
          rating: LearningRating.again,
          reviewedAt: DateTime(2026),
        ),
        throwsA(RegularReviewFailure.reinforcementNotRetained),
      );
      await expectLater(
        scope.review(
          kind: ReviewKind.regular,
          expectedPrior: changed(prior, json: 'invalid'),
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsFormatException,
      );
      await f.db.customStatement(
        "CREATE TRIGGER scope_fail AFTER UPDATE ON learning_items "
        "BEGIN SELECT RAISE(FAIL, 'scope failure'); END",
      );
      await expectLater(
        scope.review(
          kind: ReviewKind.regular,
          expectedPrior: prior,
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(
          isA<SqliteException>().having(
            (error) => error.message,
            'trigger message',
            contains('scope failure'),
          ),
        ),
      );
      expect(await snapshot(f), before);
      await f.db.customStatement('DROP TRIGGER scope_fail');
      final receipt = await scope.review(
        kind: ReviewKind.regular,
        expectedPrior: prior,
        rating: LearningRating.good,
        reviewedAt: instant,
      );
      expect(receipt.next.reviewRevision, 1);
    },
  );
}
