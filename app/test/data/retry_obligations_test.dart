import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/core/learning_day.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/retry_obligation.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant, rows;

Future<CollectionReviewGateway> scope(
  Fixture f, {
  bool reverse = false,
  bool other = false,
}) => f.learning.forCollection(
  collectionId: (other ? f.kept : f.owner).id,
  direction: reverse
      ? LearningDirection.nativeToTarget
      : LearningDirection.targetToNative,
);
Future<Fixture> fixture() async {
  final f = Fixture();
  await f.initialize();
  addTearDown(f.db.close);
  return f;
}

Future<List<Object?>> snapshot(Fixture f) => Future.wait([
  for (final table in [
    'collections',
    'vocabulary_entries',
    'learning_items',
    'regular_reviews',
    'retry_obligations',
    'scope_answer_ordinals',
    'app_settings',
    'learning_identity_sequence',
    'vocabulary_order_sequence',
  ])
    rows(f.db, table),
]);
RetryObligation changed(
  RetryObligation value, {
  String? id,
  int? generation,
  int? revision,
  String? origin,
  DateTime? expires,
}) => RetryObligation(
  id: id ?? value.id,
  itemId: value.itemId,
  generation: generation ?? value.generation,
  revision: revision ?? value.revision,
  originReviewId: origin ?? value.originReviewId,
  createdAt: value.createdAt,
  expiresAt: expires ?? value.expiresAt,
  errorCount: value.errorCount,
  dueOrdinal: value.dueOrdinal,
  waitEligibleAt: value.waitEligibleAt,
);

void main() {
  test(
    'concurrent same-prior Again admits one event/card/obligation only',
    () async {
      final f = await fixture(), prior = await f.current();
      final outcomes = await Future.wait([
        for (var index = 0; index < 2; index++)
          f.learning
              .review(
                kind: ReviewKind.regular,
                expectedPrior: prior,
                rating: LearningRating.again,
                reviewedAt: instant,
              )
              .then<Object>(
                (receipt) => receipt,
                onError: (Object error) => error,
              ),
      ]);
      expect(outcomes.whereType<RegularReviewReceipt>(), hasLength(1));
      expect(
        outcomes.where((result) => result == RegularReviewFailure.staleState),
        hasLength(1),
      );
      expect(await rows(f.db, 'regular_reviews'), hasLength(1));
      expect(await rows(f.db, 'retry_obligations'), hasLength(1));
      expect((await f.current()).reviewRevision, 1);
    },
  );

  test(
    'successful retry DELETE failure rolls back exact round and retries without FSRS/history writes',
    () async {
      final f = await fixture(), gateway = await scope(f);
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      await f.makeRetryEligible(retry);
      final before = await snapshot(f);
      await f.db.customStatement(
        "CREATE TRIGGER complete_retry_fail AFTER DELETE ON retry_obligations BEGIN SELECT RAISE(FAIL,'retry complete'); END",
      );
      await expectLater(
        gateway.completeSuccessfulRetry(expected: retry, answeredAt: instant),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await snapshot(f), before);
      await f.db.customStatement('DROP TRIGGER complete_retry_fail');
      await gateway.completeSuccessfulRetry(
        expected: retry,
        answeredAt: instant,
      );
      expect(await rows(f.db, 'retry_obligations'), isEmpty);
      expect(await rows(f.db, 'learning_items'), before[2]);
      expect(await rows(f.db, 'regular_reviews'), before[3]);
    },
  );

  test(
    'local calendar04 boundary is strictly next, including microsecond cutoff and month rollover',
    () {
      for (final local in [
        DateTime(2026, 10, 31, 3, 59, 59, 999, 999),
        DateTime(2026, 10, 31, 4),
        DateTime(2026, 10, 31, 23),
      ]) {
        final at = local.toUtc();
        final expected = DateTime(
          local.year,
          local.month,
          local.day + (local.hour >= 4 ? 1 : 0),
          4,
        ).toUtc();
        expect(LearningDay.nextBoundaryUtc(at), expected);
        expect(expected.isAfter(at), isTrue);
      }
      expect(
        () => LearningDay.nextBoundaryUtc(DateTime(2026)),
        throwsArgumentError,
      );
    },
  );

  for (final reverse in [false, true]) {
    test(
      'regular Again atomically creates one immutable ${reverse ? "reverse" : "forward"} round with original UTC deadline/receipt',
      () async {
        final f = await fixture();
        await (f.db.update(f.db.learningItems)
              ..where((row) => row.entryId.equals(f.entry.id)))
            .write(const LearningItemsCompanion(generation: Value(7)));
        final prior = await f.current(null, reverse),
            before = await rows(f.db, 'learning_items');
        final receipt = await f.review(
          reverse: reverse,
          rating: LearningRating.again,
        );
        final retry = receipt.retryNext!;
        expect(receipt.retryPrior, isNull);
        expect(retry.id, matches(RegExp(r'^[a-f0-9-]{36}$')));
        expect(retry.originReviewId, receipt.event.id);
        expect(retry.itemId, prior.id);
        expect(retry.generation, 7);
        expect(retry.revision, 0);
        expect(retry.createdAt, instant);
        expect(retry.expiresAt, LearningDay.nextBoundaryUtc(instant));
        expect(
          (await (await scope(
            f,
            reverse: reverse,
          )).pendingRetries(at: instant)).single.sameStateAs(retry),
          isTrue,
        );
        expect(
          await (await scope(f, reverse: !reverse)).pendingRetries(at: instant),
          isEmpty,
        );
        expect(
          await (await scope(f, other: true)).pendingRetries(at: instant),
          isEmpty,
        );
        expect(
          (await rows(
            f.db,
            'learning_items',
          )).where((row) => row['id'] != prior.id).toList(),
          before.where((row) => row['id'] != prior.id).toList(),
        );
        expect(
          receipt.next.cardJson,
          LearningScheduler()
              .review(prior, rating: LearningRating.again, reviewedAt: instant)
              .next
              .cardJson,
        );
      },
    );
  }
  for (final rating in [LearningRating.hard, LearningRating.good]) {
    test(
      '$rating regular success creates no obligation or synthetic completion',
      () async {
        final f = await fixture();
        final receipt = await f.review(rating: rating);
        expect(receipt.retryPrior, isNull);
        expect(receipt.retryNext, isNull);
        expect(await rows(f.db, 'retry_obligations'), isEmpty);
      },
    );
  }

  for (final stage in ['event', 'card', 'queue']) {
    test(
      '$stage failure leaves no partial event/card/round; observers have real initial and committed emissions',
      () async {
        final f = await fixture(), prior = await f.current();
        final before = await snapshot(f);
        final initial = Completer<void>(), committed = Completer<void>();
        final emissions = <(int, int, int)>[];
        final sub = f.db
            .customSelect(
              'SELECT review_revision AS revision, '
              '(SELECT COUNT(*) FROM regular_reviews) AS events, '
              '(SELECT COUNT(*) FROM retry_obligations) AS retries FROM learning_items WHERE id = ${prior.id}',
              readsFrom: {
                f.db.learningItems,
                f.db.regularReviews,
                f.db.retryObligations,
              },
            )
            .watch()
            .listen((rows) {
              final row = rows.single;
              final state = (
                row.read<int>('revision'),
                row.read<int>('events'),
                row.read<int>('retries'),
              );
              emissions.add(state);
              if (state == (0, 0, 0) && !initial.isCompleted) {
                initial.complete();
              }
              if (state == (1, 1, 1) && !committed.isCompleted) {
                committed.complete();
              }
            });
        addTearDown(sub.cancel);
        await initial.future;
        final table = stage == 'event'
            ? 'regular_reviews'
            : stage == 'card'
            ? 'learning_items'
            : 'retry_obligations';
        final operation = stage == 'card' ? 'UPDATE' : 'INSERT';
        await f.db.customStatement(
          "CREATE TRIGGER retry_fail AFTER $operation ON $table BEGIN SELECT RAISE(FAIL,'retry stage'); END",
        );
        await expectLater(
          f.review(rating: LearningRating.again),
          throwsA(isA<sqlite.SqliteException>()),
        );
        expect(await snapshot(f), before);
        expect(emissions, isNotEmpty);
        expect(emissions.every((state) => state == (0, 0, 0)), isTrue);
        await f.db.customStatement('DROP TRIGGER retry_fail');
        await f.review(rating: LearningRating.again);
        await committed.future;
        expect(
          emissions.every((state) => state == (0, 0, 0) || state == (1, 1, 1)),
          isTrue,
        );
      },
    );
  }

  test(
    'active pending round blocks every second regular rating but early reinforcement retention guard stays unchanged',
    () async {
      final f = await fixture();
      final receipt = await f.review(rating: LearningRating.again),
          before = await snapshot(f);
      for (final rating in LearningRating.values) {
        await expectLater(
          f.learning.review(
            kind: ReviewKind.regular,
            expectedPrior: receipt.next,
            rating: rating,
            reviewedAt: instant,
          ),
          throwsA(RetryFailure.processingRequired),
        );
        await expectLater(
          f.learning.review(
            kind: ReviewKind.reinforcement,
            expectedPrior: receipt.next,
            rating: rating,
            reviewedAt: instant,
          ),
          throwsA(RegularReviewFailure.reinforcementNotRetained),
        );
      }
      expect(await snapshot(f), before);
    },
  );

  test(
    'successful reinforcement boundary removes only current round, exact expectations reject wrong owner/revision/generation/ABA',
    () async {
      final f = await fixture(), gateway = await scope(f);
      final first = await f.review(rating: LearningRating.again),
          retry = first.retryNext!;
      final before = await snapshot(f);
      for (final wrong in [
        changed(retry, id: 'different'),
        changed(retry, revision: 1),
        changed(retry, generation: 1),
        changed(retry, origin: 'different'),
        changed(
          retry,
          expires: retry.expiresAt.add(const Duration(microseconds: 1)),
        ),
      ]) {
        await expectLater(
          gateway.completeSuccessfulRetry(expected: wrong, answeredAt: instant),
          throwsA(RetryFailure.staleState),
        );
      }
      await expectLater(
        (await scope(
          f,
          other: true,
        )).completeSuccessfulRetry(expected: retry, answeredAt: instant),
        throwsA(RegularReviewFailure.outOfScope),
      );
      await expectLater(
        (await scope(
          f,
          reverse: true,
        )).completeSuccessfulRetry(expected: retry, answeredAt: instant),
        throwsA(RegularReviewFailure.outOfScope),
      );
      await expectLater(
        gateway.completeSuccessfulRetry(
          expected: retry,
          answeredAt: instant.subtract(const Duration(microseconds: 1)),
        ),
        throwsArgumentError,
      );
      expect(await snapshot(f), before);
      final cards = await rows(f.db, 'learning_items'),
          events = await rows(f.db, 'regular_reviews');
      await f.makeRetryEligible(retry);
      await gateway.completeSuccessfulRetry(
        expected: retry,
        answeredAt: instant,
      );
      expect(await rows(f.db, 'retry_obligations'), isEmpty);
      expect(await rows(f.db, 'learning_items'), cards);
      expect(await rows(f.db, 'regular_reviews'), events);
      await expectLater(
        gateway.completeSuccessfulRetry(expected: retry, answeredAt: instant),
        throwsA(RetryFailure.notFound),
      );
      final next = await f.review(rating: LearningRating.again);
      expect(next.retryNext!.id, isNot(retry.id));
      await expectLater(
        gateway.completeSuccessfulRetry(expected: retry, answeredAt: instant),
        throwsA(RetryFailure.staleState),
      );
      await f.db.customStatement(
        'UPDATE retry_obligations SET revision=1 WHERE id=?',
        [next.retryNext!.id],
      );
      await expectLater(
        gateway.completeSuccessfulRetry(
          expected: next.retryNext!,
          answeredAt: instant,
        ),
        throwsA(RetryFailure.staleState),
      );
      final actual = (await gateway.pendingRetries(at: instant)).single;
      expect(actual.revision, 1);
      await f.makeRetryEligible(actual);
      await gateway.completeSuccessfulRetry(
        expected: actual,
        answeredAt: instant,
      );
    },
  );

  test(
    'decoded exact04 expiry commits without success and cannot reactivate after clock rollback',
    () async {
      final f = await fixture(), gateway = await scope(f);
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      // Different fractional precision is accepted UTC, not a lexical predicate.
      await f.db.customStatement(
        'UPDATE retry_obligations SET expires_at=? WHERE id=?',
        [
          retry.expiresAt.toIso8601String().replaceFirst('.000Z', 'Z'),
          retry.id,
        ],
      );
      final actual = (await gateway.pendingRetries(
        at: retry.expiresAt.subtract(const Duration(microseconds: 1)),
      )).single;
      final cards = await rows(f.db, 'learning_items'),
          history = await rows(f.db, 'regular_reviews');
      await expectLater(
        gateway.completeSuccessfulRetry(
          expected: actual,
          answeredAt: actual.expiresAt,
        ),
        throwsA(RetryFailure.expired),
      );
      expect(await gateway.pendingRetries(at: instant), isEmpty);
      expect(await rows(f.db, 'learning_items'), cards);
      expect(await rows(f.db, 'regular_reviews'), history);
    },
  );

  for (final otherDue in [false, true]) {
    test(
      'pending-aware launch fails honestly with ${otherDue ? "nonempty" : "otherwise empty"} FSRS due pool',
      () async {
        final f = await fixture(), gateway = await scope(f);
        await f.review(rating: LearningRating.again);
        if (otherDue) {
          await f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'Extra',
            nativeText: 'Zusatz',
          );
        }
        expect(
          (await gateway.items()).any(
            (item) => !item.card.due.isAfter(instant),
          ),
          otherDue,
        );
        final before = await snapshot(f);
        await expectLater(
          gateway.dueItems(cutoff: instant),
          throwsA(RetryFailure.processingRequired),
        );
        expect(await snapshot(f), before);
      },
    );
  }

  test(
    'mixed expired+active typed launch commits scoped expiry and rollback clock never restores expired round',
    () async {
      final f = await fixture(), gateway = await scope(f);
      final old = (await f.review(rating: LearningRating.again)).retryNext!;
      final word = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Later',
        nativeText: 'Später',
      );
      final at = old.expiresAt.add(const Duration(microseconds: 1));
      final current = (await f.review(
        word: word,
        rating: LearningRating.again,
        at: at,
      )).retryNext!;
      await expectLater(
        gateway.dueItems(cutoff: at),
        throwsA(RetryFailure.processingRequired),
      );
      expect((await rows(f.db, 'retry_obligations')).map((row) => row['id']), [
        current.id,
      ]);
      expect(
        (await gateway.pendingRetries(at: instant)).map((retry) => retry.id),
        [current.id],
      );
    },
  );

  test(
    'expired replacement rollback retains exact prior, accepted replacement receipt captures old+new same-transaction',
    () async {
      final f = await fixture(), gateway = await scope(f);
      final old = (await f.review(rating: LearningRating.again)).retryNext!,
          before = await snapshot(f);
      await f.db.customStatement(
        "CREATE TRIGGER replace_fail AFTER INSERT ON retry_obligations BEGIN SELECT RAISE(FAIL,'replace'); END",
      );
      await expectLater(
        f.review(rating: LearningRating.again, at: old.expiresAt),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(
        await snapshot(f),
        before,
      ); // A rolled-back internal read publishes no expiry.
      await f.db.customStatement('DROP TRIGGER replace_fail');
      final replacement = await f.review(
        rating: LearningRating.again,
        at: old.expiresAt,
      );
      expect(replacement.retryPrior!.sameStateAs(old), isTrue);
      expect(replacement.retryNext!.id, isNot(old.id));
      expect(replacement.retryNext!.createdAt, old.expiresAt);
      expect(
        replacement.retryNext!.expiresAt,
        LearningDay.nextBoundaryUtc(old.expiresAt),
      );
      expect(
        (await gateway.pendingRetries(at: old.expiresAt)).single.id,
        replacement.retryNext!.id,
      );
    },
  );

  test(
    'corrupt scoped rows fail closed before any expiry cleanup; SQLite constraints protect new table',
    () async {
      final f = await fixture(), gateway = await scope(f);
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      for (final column in ['generation', 'revision']) {
        await expectLater(
          f.db.customStatement('UPDATE retry_obligations SET $column=-1'),
          throwsA(isA<sqlite.SqliteException>()),
        );
      }
      await f.db.customStatement(
        "UPDATE retry_obligations SET expires_at='badZ'",
      );
      final before = await snapshot(f);
      await expectLater(
        gateway.pendingRetries(at: retry.expiresAt),
        throwsFormatException,
      );
      await expectLater(
        gateway.dueItems(cutoff: retry.expiresAt),
        throwsFormatException,
      );
      expect(await snapshot(f), before);
      await f.db.customStatement(
        'UPDATE retry_obligations SET expires_at=?,origin_review_id=?',
        [
          retry.expiresAt.toIso8601String(),
          (await f.review(word: f.other)).event.id,
        ],
      );
      await expectLater(
        gateway.pendingRetries(at: instant),
        throwsFormatException,
      );
    },
  );

  test(
    'file reopen retains exact two-direction obligations/cards/history/deadlines; success boundary changes no FSRS/history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-retry-retention-',
      );
      final file = File('${directory.path}/retry.sqlite');
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(instant),
      );
      try {
        final f = Fixture(database: db);
        await f.initialize();
        await f.review(rating: LearningRating.again);
        await f.review(reverse: true, rating: LearningRating.again);
        final retryRows = await rows(db, 'retry_obligations'),
            cards = await rows(db, 'learning_items'),
            history = await rows(db, 'regular_reviews');
        final before = await snapshot(f);
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant.add(const Duration(minutes: 1))),
        );
        final reopened = Fixture(database: db);
        expect(await snapshot(reopened), before);
        final repository = SqliteLearningRepository(db);
        for (final reverse in [false, true]) {
          final gateway = await repository.forCollection(
            collectionId: f.owner.id,
            direction: reverse
                ? LearningDirection.nativeToTarget
                : LearningDirection.targetToNative,
          );
          final pending = (await gateway.pendingRetries(
            at: instant.add(const Duration(seconds: 1)),
          )).single;
          expect(
            pending.expiresAt,
            DateTime.parse(
              retryRows.singleWhere(
                    (row) => row['id'] == pending.id,
                  )['expires_at']!
                  as String,
            ),
          );
          await reopened.makeRetryEligible(pending);
          await gateway.completeSuccessfulRetry(
            expected: pending,
            answeredAt: instant.add(const Duration(minutes: 1)),
          );
        }
        expect(await rows(db, 'retry_obligations'), isEmpty);
        expect(await rows(db, 'learning_items'), cards);
        expect(await rows(db, 'regular_reviews'), history);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'schema7 upgrade/reopen preserves exact legacy rowids/cards/history/settings/highwaters and creates no past obligations',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-retry-migration-',
      );
      final file = File('${directory.path}/retry.sqlite');
      final old = sqlite.sqlite3.open(file.path);
      final schema =
          jsonDecode(
                await File('drift_schemas/drift_schema_v7.json').readAsString(),
              )
              as Map<String, dynamic>;
      for (final group in schema['fixed_sql'] as List) {
        old.execute((group['sql'] as List).single['sql'] as String);
      }
      old.execute("INSERT INTO app_settings VALUES ('locale','de')");
      old.execute("INSERT INTO collections VALUES ('owner','Same','fr','de')");
      old.execute(
        "INSERT INTO vocabulary_entries (rowid,id,collection_id,target_text,native_text,target_key,native_key) VALUES (17,'entry','owner',' Raw ',' Text ','raw','text')",
      );
      final legacy = const JsonEncoder.withIndent('  ').convert(
        fsrs.Card(
          cardId: 19,
          state: fsrs.State.review,
          stability: 3.125,
          difficulty: 5.625,
          due: instant.add(const Duration(days: 4)),
          lastReview: instant,
        ).toMap(),
      );
      old.execute(
        "INSERT INTO learning_items (id,entry_id,direction,format_version,card_json,generation,review_revision) VALUES (19,'entry','targetToNative',1,?,9,8)",
        [legacy],
      );
      old.execute(
        "INSERT INTO regular_reviews VALUES ('past-again',19,9,?,'again')",
        [instant.toIso8601String()],
      );
      old.execute('INSERT INTO learning_identity_sequence VALUES (1,200)');
      old.execute('INSERT INTO vocabulary_order_sequence VALUES (1,100)');
      final tables = [
        'app_settings',
        'collections',
        'vocabulary_entries',
        'learning_items',
        'regular_reviews',
        'learning_identity_sequence',
        'vocabulary_order_sequence',
      ];
      final before = {
        for (final table in tables)
          table: old
              .select('SELECT rowid,* FROM $table ORDER BY rowid')
              .map((row) => Map<String, Object?>.from(row))
              .toList(),
      };
      old.execute('PRAGMA user_version=7');
      old.close();
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(instant),
      );
      try {
        for (var reopen = 0; reopen < 2; reopen++) {
          for (final table in tables) {
            expect(
              (await db
                      .customSelect('SELECT rowid,* FROM $table ORDER BY rowid')
                      .get())
                  .map((row) => row.data)
                  .toList(),
              [
                for (final row in before[table]!)
                  if (table == 'learning_items')
                    {...row, 'speed_completed': 0}
                  else if (table == 'collections')
                    {
                      ...row,
                      'automatic_hint_default': 0,
                    'level': 'A1',
                      'hint_default_offer_handled': 0,
                    'target_language_name': null,'native_language_name': null,
                    }
                  else if (table == 'vocabulary_entries')
                    {
                      ...row,
                      'example_target_text': null,
                      'example_native_text': null,
                      'hint_text': null,
                      'hint_visibility': 'always',
                    'hint_key': '',
                      'active': 1,
                      'added_at': null,
                    }
                  else
                    row,
                if (table == 'app_settings')
                  {
                    'rowid': 2,
                    'key': 'preferredDirection',
                    'value': 'nativeToTarget',
                  },
              ],
            );
          }
          expect(await rows(db, 'retry_obligations'), isEmpty);
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            db.schemaVersion,
          );
          expect(
            (await SqliteLearningRepository(
              db,
            ).forEntry('entry')).single.cardJson,
            legacy,
          );
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          if (reopen == 0) {
            await db.close();
            db = PikoDatabase(
              NativeDatabase(file),
              clock: MutablePikoClock(instant),
            );
          }
        }
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'vocabulary Undo restores exact active UUID/revision/deadline and failed partial queue restore rolls back then retries',
    () async {
      final f = await fixture();
      await (f.db.update(f.db.learningItems)
            ..where((row) => row.entryId.equals(f.entry.id)))
          .write(const LearningItemsCompanion(generation: Value(5)));
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      await f.db.customStatement(
        'UPDATE retry_obligations SET revision=3 WHERE id=?',
        [retry.id],
      );
      final original = await snapshot(f);
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id),
          absent = await snapshot(f);
      expect(await rows(f.db, 'retry_obligations'), isEmpty);
      await f.db.customStatement(
        "CREATE TRIGGER retry_undo_fail AFTER INSERT ON retry_obligations BEGIN SELECT RAISE(FAIL,'retry undo'); END",
      );
      await expectLater(
        deletion.restore(receipt),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await snapshot(f), absent);
      expect(deletion.canUndo(receipt), isTrue);
      await f.db.customStatement('DROP TRIGGER retry_undo_fail');
      (f.db.clock as MutablePikoClock).advance(const Duration(seconds: 2));
      await deletion.restore(receipt);
      expect(await snapshot(f), original);
      final restored = (await (await scope(
        f,
      )).pendingRetries(at: instant.add(const Duration(seconds: 2)))).single;
      expect(restored.id, retry.id);
      expect(restored.generation, 5);
      expect(restored.revision, 3);
      expect(restored.expiresAt, retry.expiresAt);
    },
  );

  test(
    'retry UUID conflict blocks Undo atomically and permits retry without altering unrelated round',
    () async {
      final f = await fixture();
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      final other = (await f.review(
        word: f.other,
        rating: LearningRating.again,
      )).retryNext!;
      await f.db.customStatement(
        'UPDATE retry_obligations SET id=? WHERE id=?',
        [retry.id, other.id],
      );
      final before = await snapshot(f);
      await expectLater(
        deletion.restore(receipt),
        throwsA(VocabularyUndoFailure.identityConflict),
      );
      expect(await snapshot(f), before);
      expect(deletion.canUndo(receipt), isTrue);
      await f.db.customStatement(
        'UPDATE retry_obligations SET id=? WHERE id=?',
        [other.id, retry.id],
      );
      await deletion.restore(receipt);
      expect(
        (await (await scope(
          f,
          other: true,
        )).pendingRetries(at: instant)).single.id,
        other.id,
      );
      expect(
        (await (await scope(f)).pendingRetries(at: instant)).single.id,
        retry.id,
      );
    },
  );

  test(
    'Undo crossing original04 deadline restores vocabulary/card/history but omits expired retry without resetting deadline',
    () async {
      final boundary = DateTime(2026, 10, 15, 4).toUtc(),
          clock = MutablePikoClock(
            DateTime(
              2026,
              10,
              15,
              4,
            ).toUtc().subtract(const Duration(seconds: 4)),
          );
      final f = Fixture(
        database: PikoDatabase(NativeDatabase.memory(), clock: clock),
      );
      await f.initialize();
      addTearDown(f.db.close);
      final retry = (await f.review(
        rating: LearningRating.again,
        at: clock.now(),
      )).retryNext!;
      expect(retry.expiresAt, boundary);
      final cards = await rows(f.db, 'learning_items'),
          history = await rows(f.db, 'regular_reviews');
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      clock.set(boundary.subtract(const Duration(seconds: 2)));
      final receipt = await deletion.delete(f.entry.id);
      clock.set(boundary.add(const Duration(seconds: 1)));
      expect(deletion.canUndo(receipt), isTrue);
      await deletion.restore(receipt);
      expect(await rows(f.db, 'learning_items'), cards);
      expect(await rows(f.db, 'regular_reviews'), history);
      expect(await rows(f.db, 'retry_obligations'), isEmpty);
      clock.set(boundary.subtract(const Duration(seconds: 1)));
      expect(await (await scope(f)).pendingRetries(at: clock.now()), isEmpty);
    },
  );

  test(
    'slow delete captures full8sec Undo at receipt creation and committed expired deletion cannot be revived by clock rollback',
    () async {
      final boundary = DateTime(2026, 10, 15, 4).toUtc();
      final clock = MutablePikoClock(
        boundary.subtract(const Duration(seconds: 4)),
      );
      final db = PikoDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.createFunction(
              functionName: 'advance_delete_clock',
              directOnly: false,
              function: (_) {
                clock.advance(const Duration(seconds: 5));
                return 0;
              },
            );
          },
        ),
        clock: clock,
      );
      final f = Fixture(database: db);
      await f.initialize();
      addTearDown(db.close);
      await f.review(rating: LearningRating.again, at: clock.now());
      final cards = await rows(db, 'learning_items'),
          history = await rows(db, 'regular_reviews');
      await db.customStatement(
        'CREATE TRIGGER advance_delete AFTER DELETE ON vocabulary_entries BEGIN SELECT advance_delete_clock(); END',
      );
      clock.set(boundary.subtract(const Duration(seconds: 2)));
      final deletion = SqliteVocabularyDeletionService(db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      expect(clock.now(), boundary.add(const Duration(seconds: 3)));
      expect(receipt.expiresAt, clock.now().add(const Duration(seconds: 8)));
      clock.set(boundary.subtract(const Duration(seconds: 1)));
      await deletion.restore(receipt);
      expect(await rows(db, 'learning_items'), cards);
      expect(await rows(db, 'regular_reviews'), history);
      expect(await rows(db, 'retry_obligations'), isEmpty);
    },
  );

  test(
    'Collection retry cascade notifies observers, preserves other scope and failure rolls back all state',
    () async {
      final f = await fixture();
      final own = (await f.review(rating: LearningRating.again)).retryNext!;
      final other = (await f.review(
        word: f.other,
        rating: LearningRating.again,
      )).retryNext!;
      final before = await snapshot(f),
          initial = Completer<void>(),
          deleted = Completer<void>();
      final emissions = <List<String>>[];
      final sub = f.db.select(f.db.retryObligations).watch().listen((rows) {
        final ids = rows.map((row) => row.id).toList();
        emissions.add(ids);
        if (ids.length == 2 && !initial.isCompleted) initial.complete();
        if (ids.length == 1 && ids.single == other.id && !deleted.isCompleted) {
          deleted.complete();
        }
      });
      addTearDown(sub.cancel);
      await initial.future;
      await f.db.customStatement(
        "CREATE TRIGGER cascade_retry_fail AFTER DELETE ON retry_obligations BEGIN SELECT RAISE(FAIL,'retry cascade'); END",
      );
      await expectLater(
        f.collections.delete(f.owner.id),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await snapshot(f), before);
      expect(emissions.every((ids) => ids.length == 2), isTrue);
      await f.db.customStatement('DROP TRIGGER cascade_retry_fail');
      await f.collections.delete(f.owner.id);
      await deleted.future;
      expect((await rows(f.db, 'retry_obligations')).single['id'], other.id);
      expect(
        (await (await scope(
          f,
          other: true,
        )).pendingRetries(at: instant)).single.sameStateAs(other),
        isTrue,
      );
      expect(
        emissions.every(
          (ids) =>
              ids.length == 2 || (ids.length == 1 && ids.single == other.id),
        ),
        isTrue,
      );
      expect(emissions.expand((ids) => ids).contains(own.id), isTrue);
    },
  );
}
