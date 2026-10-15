import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/retry_answer.dart';
import 'package:piko/data/retry_obligation.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant, rows;
import 'retry_gap_migration_test.dart'
    show gateway, retainedTables, storedRows, storedSnapshot;

Future<Fixture> fixture() async {
  final f = Fixture();
  await f.initialize();
  addTearDown(f.db.close);
  return f;
}

Future<RetryObligation> arm(
  Fixture f,
  RetryObligation round, {
  DateTime? at,
}) async => (await (await gateway(f.db, f.owner.id)).armBlockedWaits(
  expectedRounds: [round],
  remainingRegular: const [],
  at: at ?? instant,
)).state.rounds.single;

void expectUnchangedExcept(
  Map<String, Object?> before,
  Map<String, Object?> after,
  Set<String> changedTables,
) {
  for (final table in before.keys) {
    if (!changedTables.contains(table)) {
      expect(after[table], before[table], reason: '$table must remain exact');
    }
  }
}

/// Constraint tests use valid explicit-column insertion controls, so a missing
/// column, duplicate identity or wrong value count cannot masquerade as success.
Future<void> checkWaitColumn(PikoDatabase db) async {
  final original = (await storedRows(db, 'retry_obligations')).single;
  final before = await storedSnapshot(db);
  final check = isA<sqlite.SqliteException>().having(
    (error) => error.message,
    'CHECK rejection',
    contains('CHECK constraint failed'),
  );
  const withoutUtc = '2026-10-14T09:10:21.123456';
  final valid = instant.add(const Duration(seconds: 10)).toIso8601String();
  await expectLater(
    db.customStatement(
      'UPDATE retry_obligations SET wait_eligible_at = ? WHERE id = ?',
      [withoutUtc, original['id']],
    ),
    throwsA(check),
  );
  expect(await storedSnapshot(db), before);
  await db.customStatement('DELETE FROM retry_obligations WHERE id = ?', [
    original['id'],
  ]);
  Future<void> insert(String? wait) => db.customStatement(
    'INSERT INTO retry_obligations '
    '(rowid,id,item_id,generation,revision,origin_review_id,created_at,expires_at,'
    'error_count,due_ordinal,wait_eligible_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
    [
      original['stored_rowid'],
      original['id'],
      original['item_id'],
      original['generation'],
      original['revision'],
      original['origin_review_id'],
      original['created_at'],
      original['expires_at'],
      original['error_count'],
      original['due_ordinal'],
      wait,
    ],
  );
  await expectLater(insert(withoutUtc), throwsA(check));
  expect(await rows(db, 'retry_obligations'), isEmpty);
  await insert(valid);
  expect(
    (await rows(db, 'retry_obligations')).single['wait_eligible_at'],
    valid,
  );
  await db.customStatement(
    'UPDATE retry_obligations SET wait_eligible_at = NULL WHERE id = ?',
    [original['id']],
  );
  expect(await storedSnapshot(db), before);
}

void main() {
  test(
    'captured regular work prevents wait arming; first blocked selection arms once without grading or resetting on clock movement',
    () async {
      final f = await fixture(), source = await gateway(f.db, f.owner.id);
      final other = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Remaining',
        nativeText: 'Übrig',
      );
      final remaining = await f.current(other);
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      final before = await storedSnapshot(f.db);
      final unarmed = await source.armBlockedWaits(
        expectedRounds: [round],
        remainingRegular: [remaining],
        at: instant,
      );
      expect(unarmed.mutations, isEmpty);
      expect(unarmed.state.rounds.single.sameStateAs(round), isTrue);
      expect(await storedSnapshot(f.db), before);
      await f.review(word: other);
      final beforeArm = await storedSnapshot(f.db);
      final blockedAt = instant.add(const Duration(seconds: 2));
      final result = await source.armBlockedWaits(
        expectedRounds: [round],
        remainingRegular: const [],
        at: blockedAt,
      );
      final armed = result.state.rounds.single;
      expect(result.mutations, hasLength(1));
      expect(result.mutations.single.prior.sameStateAs(round), isTrue);
      expect(result.mutations.single.next.sameStateAs(armed), isTrue);
      expect(armed.revision, round.revision + 1);
      expect(armed.waitEligibleAt, blockedAt.add(const Duration(seconds: 10)));
      expect(armed.id, round.id);
      expect(armed.originReviewId, round.originReviewId);
      expect(armed.createdAt, round.createdAt);
      expect(armed.expiresAt, round.expiresAt);
      expect(armed.errorCount, round.errorCount);
      expect(armed.dueOrdinal, round.dueOrdinal);
      expectUnchangedExcept(beforeArm, await storedSnapshot(f.db), {
        'retry_obligations',
      });
      final armedSnapshot = await storedSnapshot(f.db);
      for (final at in [
        instant,
        blockedAt.add(const Duration(seconds: 3)),
        armed.waitEligibleAt!,
      ]) {
        final again = await source.armBlockedWaits(
          expectedRounds: [armed],
          remainingRegular: const [],
          at: at,
        );
        expect(again.mutations, isEmpty);
        expect(again.state.rounds.single.sameStateAs(armed), isTrue);
        expect(await storedSnapshot(f.db), armedSnapshot);
      }
    },
  );

  test(
    'exact wait eligibility admits one answer; Incorrect clears only its wait and a later blocked selection starts the next wait',
    () async {
      final f = await fixture(), source = await gateway(f.db, f.owner.id);
      final initial = (await f.review(rating: LearningRating.again)).retryNext!;
      final armed = await arm(f, initial), item = await f.current();
      final before = await storedSnapshot(f.db);
      final boundary = armed.waitEligibleAt!;
      await expectLater(
        source.answerRetry(
          expectedPrior: item,
          expectedRetry: armed,
          rating: LearningRating.good,
          answeredAt: boundary.subtract(const Duration(microseconds: 1)),
        ),
        throwsA(RetryFailure.notEligible),
      );
      expect(await storedSnapshot(f.db), before);
      final incorrect = await source.answerRetry(
        expectedPrior: item,
        expectedRetry: armed,
        rating: LearningRating.again,
        answeredAt: boundary,
      );
      final next = incorrect.retryNext!;
      expect(next.waitEligibleAt, isNull);
      expect(next.revision, armed.revision + 1);
      expect(next.errorCount, 2);
      expect(next.dueOrdinal, incorrect.scopeNext.ordinal + 10);
      expect(next.createdAt, initial.createdAt);
      expect(next.expiresAt, initial.expiresAt);
      expect(incorrect.scopeNext.ordinal, incorrect.scopePrior.ordinal + 1);
      expectUnchangedExcept(before, await storedSnapshot(f.db), {
        'retry_obligations',
        'scope_answer_ordinals',
      });
      final rearmAt = boundary.add(const Duration(seconds: 3));
      final second = await arm(f, next, at: rearmAt);
      expect(second.waitEligibleAt, rearmAt.add(const Duration(seconds: 10)));
      final beforeSuccess = await storedSnapshot(f.db);
      final success = await source.answerRetry(
        expectedPrior: item,
        expectedRetry: second,
        rating: LearningRating.hard,
        answeredAt: second.waitEligibleAt!.add(const Duration(microseconds: 1)),
      );
      expect(success.retryNext, isNull);
      expect(success.retryPrior.sameStateAs(second), isTrue);
      expect(success.scopeNext.ordinal, success.scopePrior.ordinal + 1);
      expect(await rows(f.db, 'retry_obligations'), isEmpty);
      expectUnchangedExcept(beforeSuccess, await storedSnapshot(f.db), {
        'retry_obligations',
        'scope_answer_ordinals',
      });
    },
  );

  test(
    'explicitly seeded ordinal eligibility remains an alternative to an unelapsed wait; eligible work does not arm another wait',
    () async {
      final f = await fixture(), source = await gateway(f.db, f.owner.id);
      final word = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Other retry',
        nativeText: 'Andere Wiederholung',
      );
      final first = (await f.review(rating: LearningRating.again)).retryNext!;
      final second = (await f.review(
        word: word,
        rating: LearningRating.again,
      )).retryNext!;
      final armed = (await source.armBlockedWaits(
        expectedRounds: [first],
        remainingRegular: const [],
        at: instant,
      )).state.rounds.singleWhere((round) => round.id == first.id);
      // Explicit eligibility seed isolates the OR admission boundary. RETRY-002's
      // earned-gap tests independently establish the real intervening-answer rule.
      await f.makeRetryEligible(armed);
      final before = await storedSnapshot(f.db);
      final blocked = await source.armBlockedWaits(
        expectedRounds: [armed, second],
        remainingRegular: const [],
        at: instant.add(const Duration(seconds: 1)),
      );
      expect(blocked.mutations, isEmpty);
      expect(await storedSnapshot(f.db), before);
      expect(
        blocked.state.rounds
            .singleWhere((round) => round.id == second.id)
            .waitEligibleAt,
        isNull,
      );
      final answer = await source.answerRetry(
        expectedPrior: await f.current(),
        expectedRetry: armed,
        rating: LearningRating.good,
        answeredAt: instant.add(const Duration(seconds: 1)),
      );
      expect(answer.retryNext, isNull);
      expect(answer.answeredAt.isBefore(armed.waitEligibleAt!), isTrue);
      expectUnchangedExcept(before, await storedSnapshot(f.db), {
        'retry_obligations',
        'scope_answer_ordinals',
      });
      expect(
        (await source.pendingRetries(at: instant)).single.sameStateAs(second),
        isTrue,
      );
    },
  );

  test(
    'original day expiry wins over later wait deadline and commits no answer or FSRS/history changes',
    () async {
      final f = await fixture(), source = await gateway(f.db, f.owner.id);
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      final armed = await arm(
        f,
        round,
        at: round.expiresAt.subtract(const Duration(seconds: 5)),
      );
      expect(
        armed.waitEligibleAt,
        round.expiresAt.add(const Duration(seconds: 5)),
      );
      final before = await storedSnapshot(f.db);
      await expectLater(
        source.answerRetry(
          expectedPrior: await f.current(),
          expectedRetry: armed,
          rating: LearningRating.good,
          answeredAt: round.expiresAt,
        ),
        throwsA(RetryFailure.expired),
      );
      final expired = await storedSnapshot(f.db);
      expect(await rows(f.db, 'retry_obligations'), isEmpty);
      expectUnchangedExcept(before, expired, {'retry_obligations'});
      expect((await source.retryState(at: instant)).rounds, isEmpty);
      expect(await storedSnapshot(f.db), expired);
    },
  );

  test(
    'wait arming rejects wrong scope, stale regular/round and duplicate round identities without mutation',
    () async {
      final f = await fixture(), source = await gateway(f.db, f.owner.id);
      final round = (await f.review(rating: LearningRating.again)).retryNext!;
      final before = await storedSnapshot(f.db);
      for (final wrong in [
        await gateway(f.db, f.kept.id),
        await gateway(f.db, f.owner.id, reverse: true),
      ]) {
        await expectLater(
          wrong.armBlockedWaits(
            expectedRounds: [round],
            remainingRegular: const [],
            at: instant,
          ),
          throwsA(RegularReviewFailure.outOfScope),
        );
        expect(await storedSnapshot(f.db), before);
      }
      await expectLater(
        source.armBlockedWaits(
          expectedRounds: [round, round],
          remainingRegular: const [],
          at: instant,
        ),
        throwsArgumentError,
      );
      expect(await storedSnapshot(f.db), before);
      final other = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Remaining',
        nativeText: 'Übrig',
      );
      final stale = await f.current(other);
      await f.review(word: other);
      final current = await storedSnapshot(f.db);
      await expectLater(
        source.armBlockedWaits(
          expectedRounds: [round],
          remainingRegular: [stale],
          at: instant,
        ),
        throwsA(RegularReviewFailure.staleState),
      );
      expect(await storedSnapshot(f.db), current);
      final armed = await arm(f, round);
      final armedSnapshot = await storedSnapshot(f.db);
      await expectLater(
        source.armBlockedWaits(
          expectedRounds: [round],
          remainingRegular: const [],
          at: instant,
        ),
        throwsA(RetryFailure.staleState),
      );
      expect(await storedSnapshot(f.db), armedSnapshot);
      expect(armed.revision, round.revision + 1);
    },
  );

  test(
    'partial multi-round arming rolls back; concurrent exact priors admit one mutation transaction',
    () async {
      final f = await fixture(), source = await gateway(f.db, f.owner.id);
      final other = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Second',
        nativeText: 'Zweite',
      );
      final first = (await f.review(rating: LearningRating.again)).retryNext!;
      final second = (await f.review(
        word: other,
        rating: LearningRating.again,
      )).retryNext!;
      final before = await storedSnapshot(f.db);
      await f.db.customStatement(
        'CREATE TRIGGER fail_second_wait AFTER UPDATE ON retry_obligations '
        "WHEN NEW.id = '${second.id}' BEGIN SELECT RAISE(FAIL, 'wait update'); END",
      );
      Future<RetryWaitResult> submit() => source.armBlockedWaits(
        expectedRounds: [first, second],
        remainingRegular: const [],
        at: instant,
      );
      await expectLater(submit(), throwsA(isA<sqlite.SqliteException>()));
      expect(await storedSnapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER fail_second_wait');
      final outcomes = await Future.wait([
        for (var index = 0; index < 2; index++)
          submit().then<Object>(
            (value) => value,
            onError: (Object error) => error,
          ),
      ]);
      expect(outcomes.whereType<RetryWaitResult>(), hasLength(1));
      expect(
        outcomes.where((value) => value == RetryFailure.staleState),
        hasLength(1),
      );
      final result = outcomes.whereType<RetryWaitResult>().single;
      expect(result.mutations, hasLength(2));
      for (final mutation in result.mutations) {
        expect(mutation.next.revision, mutation.prior.revision + 1);
        expect(
          mutation.next.waitEligibleAt,
          instant.add(const Duration(seconds: 10)),
        );
      }
      expectUnchangedExcept(before, await storedSnapshot(f.db), {
        'retry_obligations',
      });
    },
  );

  test(
    'fresh schema10 permits null/UTC wait controls and rejects non-UTC wait values with real column CHECKs',
    () async {
      final f = await fixture();
      await f.review(rating: LearningRating.again);
      await checkWaitColumn(f.db);
    },
  );

  test(
    'schema9 migration preserves all legacy rows with null wait; armed wait and revision survive file reopen without inferred elapsed timing',
    () async {
      final directory = await Directory.systemTemp.createTemp('piko-wait-v9-');
      final file = File('${directory.path}/wait.sqlite');
      PikoDatabase? db;
      try {
        final old = sqlite.sqlite3.open(file.path);
        late Map<String, Object?> before;
        final tables = [...retainedTables, 'scope_answer_ordinals'];
        try {
          final schema =
              jsonDecode(
                    await File(
                      'drift_schemas/drift_schema_v9.json',
                    ).readAsString(),
                  )
                  as Map<String, dynamic>;
          for (final group in schema['fixed_sql'] as List) {
            old.execute((group['sql'] as List).single['sql'] as String);
          }
          old.execute('PRAGMA foreign_keys = ON');
          old.execute(
            "INSERT INTO app_settings (key,value) VALUES ('locale','de')",
          );
          old.execute(
            "INSERT INTO collections (id,name,target_language,native_language) VALUES ('owner','Legacy','fr','de')",
          );
          old.execute(
            'INSERT INTO vocabulary_entries '
            '(rowid,id,collection_id,target_text,native_text,target_key,native_key) '
            "VALUES (17,'entry','owner',' Raw ',' Text ','raw','text')",
          );
          final card = const JsonEncoder.withIndent('  ').convert(
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
            'INSERT INTO learning_items '
            '(id,entry_id,direction,format_version,card_json,generation,review_revision) '
            "VALUES (19,'entry','targetToNative',1,?,9,8)",
            [card],
          );
          old.execute(
            'INSERT INTO regular_reviews '
            '(rowid,id,item_id,generation,reviewed_at,rating) VALUES (61,?,?,9,?,?)',
            ['origin', 19, instant.toIso8601String(), 'again'],
          );
          old.execute(
            'INSERT INTO retry_obligations '
            '(rowid,id,item_id,generation,revision,origin_review_id,created_at,expires_at,error_count,due_ordinal) '
            'VALUES (79,?,?,9,8,?,?,?,?,?)',
            [
              'round',
              19,
              'origin',
              instant.toIso8601String(),
              instant.add(const Duration(hours: 12)).toIso8601String(),
              4,
              31,
            ],
          );
          old.execute(
            "INSERT INTO scope_answer_ordinals (collection_id,direction,ordinal,revision) VALUES ('owner','targetToNative',27,14)",
          );
          old.execute(
            'INSERT INTO learning_identity_sequence (singleton,next_id) VALUES (1,200)',
          );
          old.execute(
            'INSERT INTO vocabulary_order_sequence (singleton,next_row_id) VALUES (1,100)',
          );
          before = {
            for (final table in tables)
              table: old
                  .select(
                    'SELECT rowid AS stored_rowid, * FROM $table ORDER BY rowid',
                  )
                  .map((row) => Map<String, Object?>.from(row))
                  .toList(),
          };
          old.execute('PRAGMA user_version = 9');
        } finally {
          old.close();
        }
        final upgraded = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        db = upgraded;
        final expected = <String, Object?>{
          ...before,
          'retry_obligations': [
            for (final row in (before['retry_obligations'] as List).cast<Map>())
              {...row, 'wait_eligible_at': null},
          ],
        };
        expect(await storedSnapshot(upgraded), expected);
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          10,
        );
        final source = await gateway(upgraded, 'owner');
        final unarmed = (await source.retryState(at: instant)).rounds.single;
        expect(unarmed.waitEligibleAt, isNull);
        expect(unarmed.errorCount, 4);
        expect(unarmed.dueOrdinal, 31);
        expect(unarmed.revision, 8);
        await checkWaitColumn(upgraded);
        final blockedAt = instant.add(const Duration(seconds: 2));
        final armed = (await source.armBlockedWaits(
          expectedRounds: [unarmed],
          remainingRegular: const [],
          at: blockedAt,
        )).state.rounds.single;
        expect(
          armed.waitEligibleAt,
          blockedAt.add(const Duration(seconds: 10)),
        );
        final armedSnapshot = await storedSnapshot(upgraded);
        expectUnchangedExcept(expected, armedSnapshot, {'retry_obligations'});
        await upgraded.close();
        db = null;
        final reopened = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(blockedAt.add(const Duration(seconds: 3))),
        );
        db = reopened;
        expect(await storedSnapshot(reopened), armedSnapshot);
        final resumed = await gateway(reopened, 'owner');
        for (final at in [
          instant,
          blockedAt.add(const Duration(seconds: 3)),
          armed.waitEligibleAt!,
        ]) {
          final retained = await resumed.armBlockedWaits(
            expectedRounds: [armed],
            remainingRegular: const [],
            at: at,
          );
          expect(retained.mutations, isEmpty);
          expect(retained.state.rounds.single.sameStateAs(armed), isTrue);
          expect(retained.state.scope.ordinal, 27);
          expect(retained.state.scope.revision, 14);
          expect(await storedSnapshot(reopened), armedSnapshot);
        }
        expect(
          await reopened.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db?.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'active vocabulary Undo restores exact armed wait and unarmed opposite round without resetting surviving scope state',
    () async {
      final f = await fixture(), source = await gateway(f.db, f.owner.id);
      final forward = (await f.review(rating: LearningRating.again)).retryNext!;
      final opposite = (await f.review(
        reverse: true,
        rating: LearningRating.again,
      )).retryNext!;
      final armed = await arm(f, forward);
      final clock = f.db.clock as MutablePikoClock;
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final tables = [...retainedTables, 'scope_answer_ordinals'];
      final before = {
        for (final table in tables) table: await rows(f.db, table),
      };
      final receipt = await deletion.delete(f.entry.id);
      clock.advance(const Duration(seconds: 3));
      await deletion.restore(receipt);
      final restored = (await source.retryState(at: clock.now())).rounds.single;
      expect(restored.sameStateAs(armed), isTrue);
      expect(restored.waitEligibleAt, instant.add(const Duration(seconds: 10)));
      expect(
        (await (await gateway(
          f.db,
          f.owner.id,
          reverse: true,
        )).retryState(at: clock.now())).rounds.single.sameStateAs(opposite),
        isTrue,
      );
      for (final table in tables) {
        expect(
          await rows(f.db, table),
          before[table],
          reason: '$table Undo retains exact logical rows',
        );
      }
    },
  );
}
