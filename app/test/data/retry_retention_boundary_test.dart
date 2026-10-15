import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';

final at = DateTime.utc(2026, 10, 14, 12, 34, 56, 789, 123);
Future<String> createEntry(PikoDatabase db) async {
  final collection = await SqliteCollectionsRepository(db).create(
    name: 'Retention',
    targetLanguage: VocabularyLanguage.french,
    nativeLanguage: VocabularyLanguage.german,
  );
  return (await SqliteVocabularyRepository(db).create(
    collectionId: collection.id,
    targetText: 'One',
    nativeText: 'Eins',
  )).id;
}

Future<List<Map<String, Object?>>> snapshot(
  PikoDatabase db,
  String table,
) async => (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
    .map((row) => row.data)
    .toList();

void main() {
  for (final persisted in [false, true]) {
    test(
      '${persisted ? 'file-backed' : 'memory'} reinforcement rejection retains exact regular history/card/revision for every grade and repeated attempt',
      () async {
        final directory = persisted
            ? await Directory.systemTemp.createTemp('piko-retry-boundary-')
            : null;
        final file = directory == null
            ? null
            : File('${directory.path}/history.sqlite');
        var db = PikoDatabase(
          file == null ? NativeDatabase.memory() : NativeDatabase(file),
          clock: MutablePikoClock(at),
        );
        try {
          final entry = await createEntry(db);
          var repository = SqliteLearningRepository(db);
          final opening = (await repository.forEntry(entry)).first;
          final regular = await repository.review(
            kind: ReviewKind.regular,
            expectedPrior: opening,
            rating: LearningRating.again,
            reviewedAt: at,
          );
          final items = await repository.forEntry(entry);
          final memory = await snapshot(db, 'learning_items'),
              history = await snapshot(db, 'regular_reviews');
          for (var attempt = 0; attempt < 4; attempt++) {
            for (final rating in LearningRating.values) {
              for (final item in items) {
                await expectLater(
                  repository.review(
                    kind: ReviewKind.reinforcement,
                    expectedPrior: item,
                    rating: rating,
                    reviewedAt: at.add(Duration(seconds: attempt + 1)),
                  ),
                  throwsA(RegularReviewFailure.reinforcementNotRetained),
                );
              }
            }
          }
          expect(await snapshot(db, 'learning_items'), memory);
          expect(await snapshot(db, 'regular_reviews'), history);
          expect((await repository.forEntry(entry)).first.reviewRevision, 1);
          expect(
            (await repository.reviewsForItem(opening.id)).single.id,
            regular.event.id,
          );
          if (file != null) {
            await db.close();
            db = PikoDatabase(
              NativeDatabase(file),
              clock: MutablePikoClock(at),
            );
            repository = SqliteLearningRepository(db);
            expect(await snapshot(db, 'learning_items'), memory);
            expect(await snapshot(db, 'regular_reviews'), history);
          }
          final current = (await repository.forEntry(entry)).first;
          final next = await repository.review(
            kind: ReviewKind.regular,
            expectedPrior: current,
            rating: LearningRating.good,
            reviewedAt: at.add(const Duration(days: 1)),
          );
          expect(next.next.reviewRevision, 2);
          expect(
            (await repository.reviewsForItem(
              current.id,
            )).map((event) => event.id),
            [regular.event.id, next.event.id],
          );
          expect(await repository.reviewsForItem(items.last.id), isEmpty);
        } finally {
          await db.close();
          if (directory != null) await directory.delete(recursive: true);
        }
      },
    );
  }
  test(
    'reinforcement is rejected before card validation, FSRS scheduling or access to closed storage',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      await db.close();
      final repository = SqliteLearningRepository(db);
      const invalid = LearningItemRecord(
        id: 0,
        entryId: '',
        direction: LearningDirection.targetToNative,
        cardJson: '{}',
        formatVersion: 99,
        generation: -1,
        reviewRevision: -1,
      );
      for (final rating in LearningRating.values) {
        await expectLater(
          repository.review(
            kind: ReviewKind.reinforcement,
            expectedPrior: invalid,
            rating: rating,
            reviewedAt: DateTime(2026, 10, 14),
          ),
          throwsA(RegularReviewFailure.reinforcementNotRetained),
        );
      }
    },
  );
}
