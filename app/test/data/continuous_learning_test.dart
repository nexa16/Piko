import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';

fsrs.Scheduler referenceScheduler() => fsrs.Scheduler(
  desiredRetention: 0.9,
  learningSteps: const [],
  relearningSteps: const [],
  enableFuzzing: false,
);

LearningItemRecord record(fsrs.Card card) => LearningItemRecord(
  id: card.cardId,
  entryId: 'entry',
  direction: LearningDirection.targetToNative,
  cardJson: LearningCardCodec.encode(card),
  formatVersion: LearningCardCodec.version,
);

fsrs.Rating libraryRating(LearningRating rating) => switch (rating) {
  LearningRating.again => fsrs.Rating.again,
  LearningRating.hard => fsrs.Rating.hard,
  LearningRating.good => fsrs.Rating.good,
};

void main() {
  final start = DateTime.utc(2026, 10, 14, 9, 10, 11, 123, 456);
  final scheduler = LearningScheduler();

  test(
    'mixed regular reviews retain continuous memory while lifecycle state remains review',
    () {
      final reference = referenceScheduler();
      var direct = fsrs.Card(cardId: 1, due: start);
      var current = record(direct);
      final memories = <(double, double)>[];
      double? beforeLapse;
      for (final (day, rating) in [
        (0, LearningRating.good),
        (3, LearningRating.good),
        (4, LearningRating.hard),
        (35, LearningRating.again),
        (36, LearningRating.good),
        (100, LearningRating.good),
      ]) {
        final at = start.add(Duration(days: day));
        final priorJson = current.cardJson;
        if (rating == LearningRating.again) {
          beforeLapse = current.card.stability;
        }
        direct = reference
            .reviewCard(direct, libraryRating(rating), reviewDateTime: at)
            .card;
        final transition = scheduler.review(
          current,
          rating: rating,
          reviewedAt: at,
        );
        expect(transition.next.card.toMap(), direct.toMap());
        expect(transition.prior.cardJson, priorJson);
        current = transition.next;
        final card = current.card;
        expect(card.state, fsrs.State.review);
        expect(card.step, isNull);
        expect(card.lastReview, at);
        expect(card.stability, isNot(card.stability!.roundToDouble()));
        expect(card.difficulty, isNot(card.difficulty!.roundToDouble()));
        memories.add((card.stability!, card.difficulty!));
        if (rating == LearningRating.again) {
          expect(card.stability, isNot(beforeLapse!));
        }
      }
      expect(memories.toSet(), hasLength(6));
    },
  );

  test(
    'matching rating counts with different elapsed times yield distinct full estimates',
    () {
      LearningItemRecord sequence(List<int> days) {
        final reference = referenceScheduler();
        var direct = fsrs.Card(cardId: 2, due: start);
        var current = record(direct);
        for (final day in days) {
          final at = start.add(Duration(days: day));
          direct = reference
              .reviewCard(direct, fsrs.Rating.good, reviewDateTime: at)
              .card;
          current = scheduler
              .review(current, rating: LearningRating.good, reviewedAt: at)
              .next;
          expect(current.card.toMap(), direct.toMap());
        }
        return current;
      }

      final frequent = sequence([0, 1, 2, 3]);
      final spaced = sequence([0, 5, 20, 60]);
      expect(frequent.card.state, fsrs.State.review);
      expect(spaced.card.state, fsrs.State.review);
      expect(frequent.card.stability, isNot(spaced.card.stability));
      expect(frequent.card.difficulty, spaced.card.difficulty);
      expect(frequent.card.due, isNot(spaced.card.due));
      expect(
        frequent.card.due.difference(frequent.card.lastReview!),
        isNot(spaced.card.due.difference(spaced.card.lastReview!)),
      );
    },
  );

  test(
    'fractional directional estimates round-trip and continue exactly after SQLite file reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-continuous-memory-',
      );
      final file = File('${directory.path}/memory.sqlite');
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(start),
      );
      try {
        final owner = await SqliteCollectionsRepository(db).create(
          name: 'Memory',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        final vocabulary = SqliteVocabularyRepository(db);
        final entry = await vocabulary.create(
          collectionId: owner.id,
          targetText: '학교',
          nativeText: 'Schule',
        );
        final other = await vocabulary.create(
          collectionId: owner.id,
          targetText: '물',
          nativeText: 'Wasser',
        );
        var learning = SqliteLearningRepository(db);
        final opening = await learning.forEntry(entry.id);
        final id = opening.first.id, oppositeId = opening.last.id;
        await learning.saveCard(
          oppositeId,
          fsrs.Card(
            cardId: oppositeId,
            state: fsrs.State.review,
            stability: 32.125,
            difficulty: 8.625,
            due: start.add(const Duration(days: 20)),
            lastReview: start.subtract(const Duration(days: 7)),
          ),
        );
        final opposite = (await learning.forEntry(entry.id)).last;
        final otherJson = (await learning.forEntry(
          other.id,
        )).map((item) => item.cardJson).toList();
        final vocabularyRows =
            (await db
                    .customSelect(
                      'SELECT rowid, * FROM vocabulary_entries ORDER BY rowid',
                    )
                    .get())
                .map((row) => row.data)
                .toList();
        final highWater =
            (await db.select(db.learningIdentitySequence).getSingle()).nextId;
        final reference = referenceScheduler();
        var direct = opening.first.card;

        Future<void> advance(int day, LearningRating rating) async {
          final before = (await learning.forEntry(entry.id)).first;
          final priorJson = before.cardJson;
          final at = start.add(Duration(days: day));
          direct = reference
              .reviewCard(direct, libraryRating(rating), reviewDateTime: at)
              .card;
          final transition = scheduler.review(
            before,
            rating: rating,
            reviewedAt: at,
          );
          await learning.saveCard(id, transition.next.card);
          final stored = (await learning.forEntry(entry.id)).first;
          expect(stored.card.toMap(), direct.toMap());
          expect(stored.cardJson, transition.next.cardJson);
          expect(stored.id, id);
          expect(stored.entryId, entry.id);
          expect(stored.direction, LearningDirection.targetToNative);
          expect(stored.formatVersion, opening.first.formatVersion);
          expect(before.cardJson, priorJson);
          expect(
            stored.card.stability,
            isNot(stored.card.stability!.roundToDouble()),
          );
          final clone = stored.card;
          clone.stability = 999;
          clone.difficulty = 1;
          expect(
            (await learning.forEntry(entry.id)).first.card.toMap(),
            direct.toMap(),
          );
          expect(
            (await learning.forEntry(entry.id)).last.cardJson,
            opposite.cardJson,
          );
          expect(
            (await learning.forEntry(other.id)).map((item) => item.cardJson),
            otherJson,
          );
        }

        await advance(0, LearningRating.good);
        await advance(3, LearningRating.good);
        await advance(4, LearningRating.hard);
        final persisted = (await learning.forEntry(entry.id)).first.cardJson;
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(start.add(const Duration(days: 50))),
        );
        learning = SqliteLearningRepository(db);
        expect((await learning.forEntry(entry.id)).first.cardJson, persisted);
        await advance(40, LearningRating.again);
        await advance(45, LearningRating.good);
        expect(
          (await db
                  .customSelect(
                    'SELECT rowid, * FROM vocabulary_entries ORDER BY rowid',
                  )
                  .get())
              .map((row) => row.data),
          vocabularyRows,
        );
        expect(
          (await db.select(db.learningIdentitySequence).getSingle()).nextId,
          highWater,
        );
        expect(
          (await SqliteCollectionsRepository(
            db,
          ).watchById(owner.id).first)!.name,
          owner.name,
        );
        final memoryBeforeTextEdit = (await db.select(db.learningItems).get())
            .map(
              (row) => [
                row.id,
                row.entryId,
                row.direction,
                row.formatVersion,
                row.cardJson,
              ],
            )
            .toList();
        await SqliteVocabularyRepository(
          db,
        ).update(id: entry.id, targetText: '학교!', nativeText: 'Schule!');
        expect(
          (await db.select(db.learningItems).get()).map(
            (row) => [
              row.id,
              row.entryId,
              row.direction,
              row.formatVersion,
              row.cardJson,
            ],
          ),
          memoryBeforeTextEdit,
        );
        await db.close();
        db = PikoDatabase(NativeDatabase(file), clock: MutablePikoClock(start));
        expect(
          (await SqliteLearningRepository(
            db,
          ).forEntry(entry.id)).first.card.toMap(),
          direct.toMap(),
        );
        expect(
          (await SqliteVocabularyRepository(
            db,
          ).watchById(entry.id).first)!.targetText,
          '학교!',
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
