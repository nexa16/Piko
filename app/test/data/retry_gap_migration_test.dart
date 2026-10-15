import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/retry_obligation.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant, rows;

const retainedTables = [
  'app_settings',
  'collections',
  'vocabulary_entries',
  'learning_items',
  'regular_reviews',
  'retry_obligations',
  'learning_identity_sequence',
  'vocabulary_order_sequence',
];

Future<Map<String, Object?>> storedSnapshot(PikoDatabase db) =>
    db.transaction(() async {
      final result = <String, Object?>{};
      for (final table in [...retainedTables, 'scope_answer_ordinals']) {
        result[table] = await storedRows(db, table);
      }
      return result;
    });

Future<List<Map<String, Object?>>> storedRows(
  PikoDatabase db,
  String table,
) async =>
    (await db
            .customSelect(
              'SELECT rowid AS stored_rowid, * FROM $table ORDER BY rowid',
            )
            .get())
        .map((row) => row.data)
        .toList();

Future<CollectionReviewGateway> gateway(
  PikoDatabase db,
  String collectionId, {
  bool reverse = false,
}) => SqliteLearningRepository(db).forCollection(
  collectionId: collectionId,
  direction: reverse
      ? LearningDirection.nativeToTarget
      : LearningDirection.targetToNative,
);

/// Exercise CHECKs using otherwise valid, explicitly named columns. A successful
/// control insertion proves rejection was not caused by a wrong column count,
/// missing dependency or a duplicate current-round identity.
Future<void> checkGapConstraints(
  PikoDatabase db,
  Map<String, Object?> original,
) async {
  final before = await storedRows(db, 'retry_obligations');
  final checkFailure = isA<sqlite.SqliteException>().having(
    (error) => error.message,
    'constraint failure',
    contains('CHECK constraint failed'),
  );
  for (final (column, invalid) in [
    ('error_count', -1),
    ('error_count', 0),
    ('due_ordinal', -1),
  ]) {
    await expectLater(
      db.customStatement(
        'UPDATE retry_obligations SET $column = ? WHERE id = ?',
        [invalid, original['id']],
      ),
      throwsA(checkFailure),
    );
    expect(await storedRows(db, 'retry_obligations'), before);
  }
  await db.customStatement('DELETE FROM retry_obligations WHERE id = ?', [
    original['id'],
  ]);
  final without = await storedRows(db, 'retry_obligations');
  Future<void> insert({
    required int errors,
    required int due,
  }) => db.customStatement(
    'INSERT INTO retry_obligations '
    '(rowid, id, item_id, generation, revision, origin_review_id, created_at, '
    'expires_at, error_count, due_ordinal) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      original['stored_rowid'],
      original['id'],
      original['item_id'],
      original['generation'],
      original['revision'],
      original['origin_review_id'],
      original['created_at'],
      original['expires_at'],
      errors,
      due,
    ],
  );
  for (final (errors, due) in [(-1, 20), (0, 20), (1, -1)]) {
    await expectLater(insert(errors: errors, due: due), throwsA(checkFailure));
    expect(await storedRows(db, 'retry_obligations'), without);
  }
  await insert(
    errors: original['error_count'] as int,
    due: original['due_ordinal'] as int,
  );
  expect(await storedRows(db, 'retry_obligations'), before);
}

void main() {
  test(
    'schema8 migration and second reopen retain legacy identities without inferred answer history; upgraded gap CHECKs reject invalid values',
    () async {
      final directory = await Directory.systemTemp.createTemp('piko-gap-v8-');
      final file = File('${directory.path}/migration.sqlite');
      PikoDatabase? db;
      try {
        final old = sqlite.sqlite3.open(file.path);
        late Map<String, Object?> before;
        try {
          final schema =
              jsonDecode(
                    await File(
                      'drift_schemas/drift_schema_v8.json',
                    ).readAsString(),
                  )
                  as Map<String, dynamic>;
          for (final group in schema['fixed_sql'] as List) {
            old.execute((group['sql'] as List).single['sql'] as String);
          }
          old.execute('PRAGMA foreign_keys = ON');
          old.execute(
            'INSERT INTO app_settings (key,value) VALUES (?,?), (?,?)',
            ['locale', 'de', 'unrelated', 'retained'],
          );
          old.execute(
            'INSERT INTO collections (rowid,id,name,target_language,native_language) '
            "VALUES (11,'owner','Legacy','fr','de')",
          );
          old.execute(
            'INSERT INTO vocabulary_entries '
            '(rowid,id,collection_id,target_text,native_text,target_key,native_key) '
            "VALUES (17,'entry','owner',' Raw ',' Text ','raw','text')",
          );
          for (final (itemId, direction, generation, revision, rowid) in [
            (19, 'targetToNative', 9, 8, 79),
            (23, 'nativeToTarget', 4, 5, 83),
          ]) {
            final card = const JsonEncoder.withIndent('  ').convert(
              fsrs.Card(
                cardId: itemId,
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
              'VALUES (?,?,?,?,?,?,?)',
              [itemId, 'entry', direction, 1, card, generation, revision],
            );
            old.execute(
              'INSERT INTO regular_reviews '
              '(rowid,id,item_id,generation,reviewed_at,rating) VALUES (?,?,?,?,?,?)',
              [
                rowid - 10,
                'origin-$itemId',
                itemId,
                generation,
                instant.toIso8601String(),
                'again',
              ],
            );
            old.execute(
              'INSERT INTO retry_obligations '
              '(rowid,id,item_id,generation,revision,origin_review_id,created_at,expires_at) '
              'VALUES (?,?,?,?,?,?,?,?)',
              [
                rowid,
                'round-$itemId',
                itemId,
                generation,
                6,
                'origin-$itemId',
                instant.toIso8601String(),
                instant.add(const Duration(hours: 12)).toIso8601String(),
              ],
            );
          }
          // Additional legacy fixture history must not fabricate an answered count.
          old.execute(
            'INSERT INTO regular_reviews '
            '(rowid,id,item_id,generation,reviewed_at,rating) VALUES (?,?,?,?,?,?)',
            [
              61,
              'earlier-review',
              19,
              9,
              instant.subtract(const Duration(days: 1)).toIso8601String(),
              'good',
            ],
          );
          old.execute(
            'INSERT INTO learning_identity_sequence (singleton,next_id) VALUES (1,200)',
          );
          old.execute(
            'INSERT INTO vocabulary_order_sequence (singleton,next_row_id) VALUES (1,100)',
          );
          before = {
            for (final table in retainedTables)
              table: old
                  .select(
                    'SELECT rowid AS stored_rowid, * FROM $table ORDER BY rowid',
                  )
                  .map((row) => Map<String, Object?>.from(row))
                  .toList(),
          };
          old.execute('PRAGMA user_version = 8');
        } finally {
          old.close();
        }
        for (var reopen = 0; reopen < 2; reopen++) {
          final current = PikoDatabase(
            NativeDatabase(file),
            clock: MutablePikoClock(instant),
          );
          db = current;
          for (final table in retainedTables) {
            final actual = await storedRows(current, table);
            final expected = (before[table] as List)
                .cast<Map<String, Object?>>();
            expect(actual, [
              for (final row in expected)
                if (table == 'retry_obligations')
                  {
                    ...row,
                    'error_count': 1,
                    'due_ordinal': 20,
                    'wait_eligible_at': null,
                  }
                else if (table == 'learning_items')
                  {...row, 'speed_completed': 0}
                else
                  row,
            ], reason: '$table survives schema8 migration/reopen exactly');
          }
          expect(await rows(current, 'scope_answer_ordinals'), isEmpty);
          for (final reverse in [false, true]) {
            final state = await (await gateway(
              current,
              'owner',
              reverse: reverse,
            )).retryState(at: instant);
            expect(state.scope.ordinal, 0);
            expect(state.scope.revision, 0);
            final round = state.rounds.single;
            expect(round.errorCount, 1);
            expect(round.dueOrdinal, 20);
            expect(round.revision, 6);
          }
          expect(await rows(current, 'scope_answer_ordinals'), isEmpty);
          expect(
            (await current.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            current.schemaVersion,
          );
          expect(
            await current.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          await checkGapConstraints(
            current,
            (await storedRows(current, 'retry_obligations')).first,
          );
          await current.close();
          db = null;
        }
      } finally {
        await db?.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('fresh schema9 enforces actual retry gap column CHECKs', () async {
    final f = Fixture();
    addTearDown(f.db.close);
    await f.initialize();
    await f.review(rating: LearningRating.again);
    final before = await storedSnapshot(f.db);
    await checkGapConstraints(
      f.db,
      (await storedRows(f.db, 'retry_obligations')).single,
    );
    expect(await storedSnapshot(f.db), before);
  });

  test(
    'file reopen retains production regular/retry mutations and independent scope state; eligibility is explicitly seeded for retention only',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-gap-retention-',
      );
      final file = File('${directory.path}/retention.sqlite');
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(instant),
      );
      try {
        final f = Fixture(database: db);
        await f.initialize();
        final forward = await gateway(db, f.owner.id);
        final reverse = await gateway(db, f.owner.id, reverse: true);
        var round = (await f.review(rating: LearningRating.again)).retryNext!;
        final opposite = (await f.review(
          reverse: true,
          rating: LearningRating.again,
        )).retryNext!;
        await f.review(word: f.other);
        final originalCard = await f.current();
        for (var error = 0; error < 2; error++) {
          // These fixtures verify persistence, not that the gap was earned.
          await f.makeRetryEligible(round);
          final receipt = await forward.answerRetry(
            expectedPrior: originalCard,
            expectedRetry: round,
            rating: LearningRating.again,
            answeredAt: instant.add(Duration(seconds: error + 1)),
          );
          round = receipt.retryNext!;
        }
        expect(round.errorCount, 3);
        expect(round.dueOrdinal, 38);
        expect(round.revision, 2);
        final forwardState = (await forward.retryState(at: instant)).scope;
        expect(forwardState.ordinal, 33);
        expect(forwardState.revision, 3);
        final reverseState = await reverse.retryState(at: instant);
        expect(reverseState.scope.ordinal, 1);
        expect(reverseState.scope.revision, 1);
        expect(reverseState.rounds.single.sameStateAs(opposite), isTrue);
        await db.customStatement(
          "INSERT INTO app_settings (key,value) VALUES ('locale','de')",
        );
        final before = await storedSnapshot(db);
        final ownerId = f.owner.id, entryId = f.entry.id;
        final keptId = f.kept.id;
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant.add(const Duration(seconds: 3))),
        );
        expect(await storedSnapshot(db), before);
        final resumed = await gateway(db, ownerId);
        final state = await resumed.retryState(
          at: instant.add(const Duration(seconds: 3)),
        );
        expect(state.scope.sameStateAs(forwardState), isTrue);
        expect(state.rounds.single.sameStateAs(round), isTrue);
        await expectLater(
          resumed.answerRetry(
            expectedPrior: originalCard,
            expectedRetry: round,
            rating: LearningRating.good,
            answeredAt: instant.add(const Duration(seconds: 3)),
          ),
          throwsA(RetryFailure.notEligible),
        );
        expect(await storedSnapshot(db), before);
        // Seed only forward admission, then exercise a real resumed answer.
        await Fixture(database: db).makeRetryEligible(round);
        final accepted = await resumed.answerRetry(
          expectedPrior: (await SqliteLearningRepository(db).forEntry(entryId))
              .singleWhere(
                (item) => item.direction == LearningDirection.targetToNative,
              ),
          expectedRetry: round,
          rating: LearningRating.hard,
          answeredAt: instant.add(const Duration(seconds: 4)),
        );
        expect(accepted.retryNext, isNull);
        expect(accepted.scopeNext.ordinal, 39);
        expect(accepted.scopeNext.revision, 4);
        expect(
          await storedRows(db, 'learning_items'),
          before['learning_items'],
        );
        expect(
          await storedRows(db, 'regular_reviews'),
          before['regular_reviews'],
        );
        final oppositeState = await (await gateway(
          db,
          ownerId,
          reverse: true,
        )).retryState(at: instant.add(const Duration(seconds: 4)));
        expect(oppositeState.scope.sameStateAs(reverseState.scope), isTrue);
        expect(oppositeState.rounds.single.sameStateAs(opposite), isTrue);
        expect(
          (await (await gateway(
            db,
            keptId,
          )).retryState(at: instant)).scope.ordinal,
          1,
        );
        final after = await storedSnapshot(db);
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        expect(await storedSnapshot(db), after);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'Collection deletion cascades both scope directions and publishes retained unrelated counters',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true);
      await f.review(word: f.other);
      await f.review(word: f.other, reverse: true);
      final before = await storedSnapshot(f.db);
      final retained = (before['scope_answer_ordinals'] as List)
          .cast<Map>()
          .where((row) => row['collection_id'] == f.kept.id)
          .toList();
      final observer = StreamIterator(
        f.db.select(f.db.scopeAnswerOrdinals).watch(),
      );
      try {
        expect(await observer.moveNext(), isTrue);
        expect(observer.current, hasLength(4));
        final changed = observer.moveNext();
        await f.collections.delete(f.owner.id);
        expect(await changed, isTrue);
        expect(observer.current, hasLength(2));
        expect(observer.current.map((row) => row.collectionId).toSet(), {
          f.kept.id,
        });
        expect(observer.current.map((row) => row.direction).toSet(), {
          'targetToNative',
          'nativeToTarget',
        });
        expect(await storedRows(f.db, 'scope_answer_ordinals'), retained);
        final after = await storedSnapshot(f.db);
        for (final table in [
          'app_settings',
          'learning_identity_sequence',
          'vocabulary_order_sequence',
        ]) {
          expect(after[table], before[table]);
        }
        final keptItems = (before['learning_items'] as List)
            .cast<Map>()
            .where((row) => row['entry_id'] == f.other.id)
            .toList();
        final keptIds = keptItems.map((row) => row['id']).toSet();
        expect(after['learning_items'], keptItems);
        expect(
          after['regular_reviews'],
          (before['regular_reviews'] as List)
              .cast<Map>()
              .where((row) => keptIds.contains(row['item_id']))
              .toList(),
        );
        expect(after['retry_obligations'], isEmpty);
      } finally {
        await observer.cancel();
      }
    },
  );
}
