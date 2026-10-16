import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/data/vocabulary_learning_status.dart';
import 'package:piko/features/learning/learning_scheduler.dart';

import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'speed_eligibility_test.dart' show completeSnapshot;

void main() {
  test(
    'pure status precedence keeps actual retry ahead of overlapping regular due',
    () {
      final scheduler = LearningScheduler();
      final item = LearningItemRecord(
        id: 1,
        entryId: 'entry',
        direction: LearningDirection.targetToNative,
        cardJson: LearningCardCodec.encode(
          scheduler.initialCard(itemId: 1, at: instant),
        ),
        formatVersion: LearningCardCodec.version,
        speedCompleted: true,
      );
      final before = item.cardJson;
      for (final pending in [false, true]) {
        for (final reviewed in [false, true]) {
          for (final due in [false, true]) {
            final status = VocabularyLearningStatus.project(
              item: item,
              hasCurrentNormalReview: reviewed,
              hasPendingRetry: pending,
              isRegularDue: due,
            );
            expect(
              status.kind,
              pending
                  ? VocabularyLearningStatusKind.pendingRetry
                  : !reviewed
                  ? VocabularyLearningStatusKind.newWord
                  : due
                  ? VocabularyLearningStatusKind.due
                  : VocabularyLearningStatusKind.nextReview,
            );
            expect(status.speedCompleted, !reviewed);
            expect(
              status.nextReviewAt,
              status.kind == VocabularyLearningStatusKind.nextReview
                  ? instant
                  : null,
            );
          }
        }
      }
      expect(item.cardJson, before);
      expect(item.reviewRevision, 0);
      expect(item.generation, 0);
    },
  );

  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  test(
    'New and Speed-only status use current history, independently per direction',
    () async {
      final f = await fixture();
      final query = SqliteCollectionQueryService(f.db);
      final initial = await query.query(collectionId: f.owner.id, at: instant);
      for (final direction in LearningDirection.values) {
        final status = initial.directions[direction]!.statuses[f.entry.id]!;
        expect(status.kind, VocabularyLearningStatusKind.newWord);
        expect(status.speedCompleted, isFalse);
        expect(status.nextReviewAt, isNull);
      }
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      await source.completeSpeedItem(
        expectedPrior: await f.current(),
        errors: 0,
        completedAt: instant,
      );
      final markedBefore = await completeSnapshot(f.db);
      final marked = await query.query(collectionId: f.owner.id, at: instant);
      expect(
        marked
            .directions[LearningDirection.targetToNative]!
            .statuses[f.entry.id]!
            .kind,
        VocabularyLearningStatusKind.newWord,
      );
      expect(
        marked
            .directions[LearningDirection.targetToNative]!
            .statuses[f.entry.id]!
            .speedCompleted,
        isTrue,
      );
      expect(
        marked
            .directions[LearningDirection.nativeToTarget]!
            .statuses[f.entry.id]!
            .speedCompleted,
        isFalse,
      );
      expect(await completeSnapshot(f.db), markedBefore);
      await f.review(rating: LearningRating.good);
      final before = await completeSnapshot(f.db);
      final reviewed = await query.query(collectionId: f.owner.id, at: instant);
      final status = reviewed
          .directions[LearningDirection.targetToNative]!
          .statuses[f.entry.id]!;
      expect(status.kind, VocabularyLearningStatusKind.nextReview);
      expect(status.speedCompleted, isFalse);
      expect(status.nextReviewAt, (await f.current()).card.due);
      expect(reviewed.nextChangeAt, status.nextReviewAt);
      expect(
        reviewed
            .directions[LearningDirection.nativeToTarget]!
            .statuses[f.entry.id]!
            .kind,
        VocabularyLearningStatusKind.newWord,
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'pending retry wins through wait eligibility and expires exactly without passive cleanup',
    () async {
      final f = await fixture();
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      final item = await f.current();
      await f.learning.saveCard(item.id, item.card..due = instant);
      final wait = instant.add(const Duration(seconds: 10));
      await (f.db.update(f.db.retryObligations)
            ..where((row) => row.id.equals(retry.id)))
        .write(RetryObligationsCompanion(waitEligibleAt: Value(wait.toIso8601String())));
      final before = await completeSnapshot(f.db);
      final query = SqliteCollectionQueryService(f.db);
      final waiting = await query.query(collectionId: f.owner.id, at: instant);
      final forward = waiting.directions[LearningDirection.targetToNative]!;
      expect(
        forward.statuses[f.entry.id]!.kind,
        VocabularyLearningStatusKind.pendingRetry,
      );
      expect(forward.dueCount, 0);
      expect(waiting.nextChangeAt, wait);
      final eligible = await query.query(collectionId: f.owner.id, at: wait);
      expect(
        eligible
            .directions[LearningDirection.targetToNative]!
            .statuses[f.entry.id]!
            .kind,
        VocabularyLearningStatusKind.pendingRetry,
      );
      expect(
        eligible.directions[LearningDirection.targetToNative]!.dueCount,
        1,
      );
      expect(eligible.nextChangeAt, retry.expiresAt);
      final expired = await query.query(
        collectionId: f.owner.id,
        at: retry.expiresAt,
      );
      expect(
        expired
            .directions[LearningDirection.targetToNative]!
            .statuses[f.entry.id]!
            .kind,
        VocabularyLearningStatusKind.due,
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'expiry reveals future regular review and preserves its next-change boundary',
    () async {
      final f = await fixture();
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      final item = await f.current();
      final future = retry.expiresAt.add(const Duration(hours: 1));
      await f.learning.saveCard(item.id, item.card..due = future);
      // Keep the opposite direction from introducing an earlier ordinary boundary.
      final reverse = await f.current(null, true);
      await f.learning.saveCard(
        reverse.id,
        reverse.card..due = future.add(const Duration(hours: 1)),
      );
      final before = await completeSnapshot(f.db);
      final query = SqliteCollectionQueryService(f.db);
      final active = await query.query(collectionId: f.owner.id, at: instant);
      expect(
        active
            .directions[LearningDirection.targetToNative]!
            .statuses[f.entry.id]!
            .kind,
        VocabularyLearningStatusKind.pendingRetry,
      );
      expect(active.nextChangeAt, retry.expiresAt);
      final expired = await query.query(
        collectionId: f.owner.id,
        at: retry.expiresAt,
      );
      final status = expired
          .directions[LearningDirection.targetToNative]!
          .statuses[f.entry.id]!;
      expect(status.kind, VocabularyLearningStatusKind.nextReview);
      expect(status.nextReviewAt, future);
      expect(expired.nextChangeAt, future);
      final due = await query.query(collectionId: f.owner.id, at: future);
      expect(
        due
            .directions[LearningDirection.targetToNative]!
            .statuses[f.entry.id]!
            .kind,
        VocabularyLearningStatusKind.due,
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'old-generation history and retries never replace New in the current generation',
    () async {
      final f = await fixture();
      await f.review(rating: LearningRating.again);
      final item = await f.current();
      await (f.db.update(
        f.db.learningItems,
      )..where((row) => row.id.equals(item.id))).write(
        LearningItemsCompanion(
          generation: Value(item.generation + 1),
          speedCompleted: const Value(true),
        ),
      );
      final before = await completeSnapshot(f.db);
      final snapshot = await SqliteCollectionQueryService(
        f.db,
      ).query(collectionId: f.owner.id, at: instant);
      final status = snapshot
          .directions[LearningDirection.targetToNative]!
          .statuses[f.entry.id]!;
      expect((await f.current()).card.lastReview, isNotNull);
      expect(status.kind, VocabularyLearningStatusKind.newWord);
      expect(status.speedCompleted, isTrue);
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'filtered statuses are immutable and exclude other entries and Collections',
    () async {
      final f = await fixture();
      await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Hidden',
        nativeText: 'Verborgen',
      );
      await f.review(rating: LearningRating.good);
      await f.review(
        word: f.other,
        reverse: true,
        rating: LearningRating.again,
      );
      final before = await completeSnapshot(f.db);
      final snapshot = await SqliteCollectionQueryService(
        f.db,
      ).query(collectionId: f.owner.id, at: instant, search: 'One');
      for (final direction in LearningDirection.values) {
        expect(snapshot.directions[direction]!.statuses.keys, [f.entry.id]);
        expect(
          () => snapshot.directions[direction]!.statuses.clear(),
          throwsUnsupportedError,
        );
      }
      expect(
        snapshot
            .directions[LearningDirection.targetToNative]!
            .statuses[f.entry.id]!
            .kind,
        VocabularyLearningStatusKind.nextReview,
      );
      expect(
        snapshot
            .directions[LearningDirection.nativeToTarget]!
            .statuses[f.entry.id]!
            .kind,
        VocabularyLearningStatusKind.newWord,
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'file reopen derives the same statuses without storing projection state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-status-reopen-',
      );
      final file = File('${directory.path}/status.sqlite');
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(instant),
      );
      try {
        final f = Fixture(database: db);
        await f.initialize();
        await f.review(rating: LearningRating.again);
        final source = await f.learning.forCollection(
          collectionId: f.owner.id,
          direction: LearningDirection.nativeToTarget,
        );
        await source.completeSpeedItem(
          expectedPrior: await f.current(null, true),
          errors: 0,
          completedAt: instant,
        );
        final before = await completeSnapshot(db);
        final first = await SqliteCollectionQueryService(
          db,
        ).query(collectionId: f.owner.id, at: instant);
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        final reopened = await SqliteCollectionQueryService(
          db,
        ).query(collectionId: f.owner.id, at: instant);
        for (final direction in LearningDirection.values) {
          final expected = first.directions[direction]!.statuses[f.entry.id]!;
          final actual = reopened.directions[direction]!.statuses[f.entry.id]!;
          expect(
            (actual.kind, actual.nextReviewAt, actual.speedCompleted),
            (expected.kind, expected.nextReviewAt, expected.speedCompleted),
          );
        }
        expect(await completeSnapshot(db), before);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
