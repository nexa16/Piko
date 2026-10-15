import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/speed_completion.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant, changed;
import 'speed_eligibility_test.dart' show completeSnapshot;

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  Future<CollectionReviewGateway> source(Fixture f, {bool reverse = false}) =>
      f.learning.forCollection(
        collectionId: f.owner.id,
        direction: reverse
            ? LearningDirection.nativeToTarget
            : LearningDirection.targetToNative,
      );

  test(
    'zero-error completion changes only the studied marker, preserving complete learned state and even expired retries',
    () async {
      final f = await fixture();
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true, rating: LearningRating.again);
      await f.review(word: f.other, rating: LearningRating.again);
      final expected = await f.current();
      final before = await completeSnapshot(f.db);
      final writer = await source(f);
      final completedAt = instant.add(const Duration(days: 3));
      final result = await writer.completeSpeedItem(
        expectedPrior: expected,
        errors: 0,
        completedAt: completedAt,
      );
      expect(result.alreadyApplied, isFalse);
      expect(result.prior, same(expected));
      expect(result.next.cardJson, expected.cardJson);
      expect(result.next.generation, expected.generation);
      expect(result.next.reviewRevision, expected.reviewRevision);
      expect(result.next.speedCompleted, isTrue);
      final after = await completeSnapshot(f.db);
      final expectedRows = (before['learning_items'] as List)
          .cast<Map>()
          .map(
            (row) => {
              ...row,
              if (row['id'] == expected.id) 'speed_completed': 1,
            },
          )
          .toList();
      expect(after, {...before, 'learning_items': expectedRows});
      final repeated = await writer.completeSpeedItem(
        expectedPrior: expected,
        errors: 0,
        completedAt: completedAt,
      );
      expect(repeated.alreadyApplied, isTrue);
      expect(await completeSnapshot(f.db), after);
    },
  );

  for (final reverse in [false, true]) {
    test(
      'errored completion resets only the ${reverse ? 'nativeToTarget' : 'targetToNative'} generation and its obsolete retry, preserving history, opposite and all scopes',
      () async {
        final f = await fixture();
        await f.review(
          rating: LearningRating.good,
          at: instant.subtract(const Duration(days: 2)),
        );
        await f.review(rating: LearningRating.again);
        await f.review(reverse: true, rating: LearningRating.again);
        await f.review(word: f.other, rating: LearningRating.again);
        final expected = await f.current(f.entry, reverse);
        final before = await completeSnapshot(f.db);
        final writer = await source(f, reverse: reverse);
        final completedAt = instant.add(const Duration(seconds: 7));
        final result = await writer.completeSpeedItem(
          expectedPrior: expected,
          errors: 4,
          completedAt: completedAt,
        );
        expect(result.alreadyApplied, isFalse);
        expect(result.next.id, expected.id);
        expect(result.next.generation, expected.generation + 1);
        expect(result.next.reviewRevision, 0);
        expect(result.next.speedCompleted, isTrue);
        expect(
          result.next.cardJson,
          LearningCardCodec.encode(
            LearningScheduler().initialCard(
              itemId: expected.id,
              at: completedAt,
            ),
          ),
        );
        expect(result.next.card.lastReview, isNull);
        expect(result.next.card.due, completedAt);
        final after = await completeSnapshot(f.db);
        for (final table in before.keys.where(
          (table) => table != 'learning_items' && table != 'retry_obligations',
        )) {
          expect(after[table], before[table], reason: '$table remains exact');
        }
        expect(
          (after['learning_items'] as List)
              .cast<Map>()
              .where((row) => row['id'] != expected.id)
              .toList(),
          (before['learning_items'] as List)
              .cast<Map>()
              .where((row) => row['id'] != expected.id)
              .toList(),
        );
        expect(
          after['retry_obligations'],
          (before['retry_obligations'] as List)
              .cast<Map>()
              .where((row) => row['item_id'] != expected.id)
              .toList(),
        );
        final export =
            jsonDecode(
                  await SqliteVocabularyJsonService(
                    f.db,
                  ).exportCollection(f.owner.id),
                )
                as Map;
        final learning =
            (((export['collections'] as List).single as Map)['entries'] as List)
                    .single
                as Map;
        final exported =
            (learning['learning'] as Map)[expected.direction.name] as Map;
        expect(exported['generation'], expected.generation + 1);
        expect(exported['speedCompleted'], isTrue);
        expect(exported['retry'], isNull);
        expect(exported['reviews'], isNotEmpty);
        expect(await writer.newSpeedItems(), isEmpty);
      },
    );
  }

  test(
    'duplicate and concurrent completions are idempotent after unrelated changes, and never reset later studied progress',
    () async {
      final f = await fixture();
      final writer = await source(f);
      final expected = await f.current();
      final completedAt = instant.add(const Duration(seconds: 2));
      final results = await Future.wait(
        List.generate(
          2,
          (_) => writer.completeSpeedItem(
            expectedPrior: expected,
            errors: 1,
            completedAt: completedAt,
          ),
        ),
      );
      expect(results.where((result) => !result.alreadyApplied), hasLength(1));
      expect(results.where((result) => result.alreadyApplied), hasLength(1));
      await f.review(
        reverse: true,
        rating: LearningRating.good,
        at: completedAt,
      );
      final unrelatedChanged = await completeSnapshot(f.db);
      expect(
        (await writer.completeSpeedItem(
          expectedPrior: expected,
          errors: 1,
          completedAt: completedAt,
        )).alreadyApplied,
        isTrue,
      );
      expect(await completeSnapshot(f.db), unrelatedChanged);
      await f.review(
        rating: LearningRating.good,
        at: completedAt.add(const Duration(seconds: 1)),
      );
      final studiedChanged = await completeSnapshot(f.db);
      await expectLater(
        writer.completeSpeedItem(
          expectedPrior: expected,
          errors: 1,
          completedAt: completedAt,
        ),
        throwsA(SpeedCompletionFailure.staleState),
      );
      expect(await completeSnapshot(f.db), studiedChanged);
      expect((await f.current()).generation, expected.generation + 1);
    },
  );

  test(
    'invalid completion, stale generation and wrong owner/direction cannot mutate data',
    () async {
      final f = await fixture();
      final writer = await source(f);
      final expected = await f.current();
      final before = await completeSnapshot(f.db);
      for (final (prior, errors, at, failure) in [
        (expected, -1, instant, SpeedCompletionFailure.invalidCompletion),
        (
          expected,
          0,
          DateTime(2026, 10, 14),
          SpeedCompletionFailure.invalidCompletion,
        ),
        (
          changed(expected, generation: -1),
          0,
          instant,
          SpeedCompletionFailure.invalidCompletion,
        ),
        (
          changed(expected, generation: expected.generation + 1),
          1,
          instant,
          SpeedCompletionFailure.staleState,
        ),
        (
          await f.current(f.other),
          0,
          instant,
          SpeedCompletionFailure.outOfScope,
        ),
        (
          await f.current(f.entry, true),
          0,
          instant,
          SpeedCompletionFailure.outOfScope,
        ),
        (
          changed(
            expected,
            id: 99999,
            json: LearningCardCodec.encode(
              LearningScheduler().initialCard(itemId: 99999, at: instant),
            ),
          ),
          0,
          instant,
          SpeedCompletionFailure.itemNotFound,
        ),
      ]) {
        await expectLater(
          writer.completeSpeedItem(
            expectedPrior: prior,
            errors: errors,
            completedAt: at,
          ),
          throwsA(failure),
        );
        expect(await completeSnapshot(f.db), before);
      }
      await f.collections.delete(f.owner.id);
      final deleted = await completeSnapshot(f.db);
      await expectLater(
        writer.completeSpeedItem(
          expectedPrior: expected,
          errors: 0,
          completedAt: instant,
        ),
        throwsA(SpeedCompletionFailure.collectionNotFound),
      );
      expect(await completeSnapshot(f.db), deleted);
    },
  );

  test(
    'failure after retry deletion rolls back marker/card/generation and keeps the same completion retryable',
    () async {
      final f = await fixture();
      await f.review(rating: LearningRating.again);
      final expected = await f.current();
      final before = await completeSnapshot(f.db);
      final writer = await source(f);
      await f.db.customStatement(
        "CREATE TRIGGER speed_failure BEFORE UPDATE ON learning_items BEGIN SELECT RAISE(FAIL,'injected completion failure'); END",
      );
      await expectLater(
        writer.completeSpeedItem(
          expectedPrior: expected,
          errors: 1,
          completedAt: instant,
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await completeSnapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER speed_failure');
      final completed = await writer.completeSpeedItem(
        expectedPrior: expected,
        errors: 1,
        completedAt: instant,
      );
      expect(completed.alreadyApplied, isFalse);
      expect(completed.next.generation, expected.generation + 1);
      expect(await f.db.select(f.db.retryObligations).get(), isEmpty);
    },
  );

  test(
    'the shared scheduler adapter creates exact initial cards and rejects invalid identity or non-UTC initialization',
    () {
      final scheduler = LearningScheduler();
      final card = scheduler.initialCard(itemId: 17, at: instant);
      expect(card.cardId, 17);
      expect(card.due, instant);
      expect(card.lastReview, isNull);
      expect(card.stability, isNull);
      expect(card.difficulty, isNull);
      expect(card.step, 0);
      expect(
        () => scheduler.initialCard(itemId: 0, at: instant),
        throwsArgumentError,
      );
      expect(
        () => scheduler.initialCard(itemId: 17, at: DateTime(2026)),
        throwsArgumentError,
      );
    },
  );

  test(
    'completion and duplicate acknowledgement survive file reopen without a second generation or extra persistent event',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-speed-completion-',
      );
      final file = File('${directory.path}/completion.sqlite');
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(instant),
      );
      try {
        final f = Fixture(database: db);
        await f.initialize();
        await f.review(rating: LearningRating.again);
        final expected = await f.current();
        final completedAt = instant.add(const Duration(seconds: 5));
        await (await source(f)).completeSpeedItem(
          expectedPrior: expected,
          errors: 2,
          completedAt: completedAt,
        );
        final before = await completeSnapshot(db);
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(completedAt),
        );
        final writer = await SqliteLearningRepository(db).forCollection(
          collectionId: f.owner.id,
          direction: expected.direction,
        );
        final repeated = await writer.completeSpeedItem(
          expectedPrior: expected,
          errors: 2,
          completedAt: completedAt,
        );
        expect(repeated.alreadyApplied, isTrue);
        expect(repeated.next.generation, expected.generation + 1);
        expect(await completeSnapshot(db), before);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
