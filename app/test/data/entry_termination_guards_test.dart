import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import '../../integration_test/support/entry_termination_fixture.dart';
import '../ui/settings_test.dart' as settings;

Map<String, dynamic> clone(Map<String, Object?> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

/// Valid table fixtures for preservation guards, not scheduling acceptance.
class GuardFixture {
  final db = PikoDatabase(NativeDatabase.memory());
  late final collections = SqliteCollectionsRepository(db);
  late final vocabulary = SqliteVocabularyRepository(db);
  late Map<String, dynamic> baseline, checkpoint;
  late CollectionRecord owner;
  late VocabularyRecord entry;

  Future<void> initialize() async {
    final retained = await collections.create(
      name: 'Unrelated retained Collection',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    final retainedEntry = await vocabulary.create(
      collectionId: retained.id,
      targetText: 'pomme',
      nativeText: 'Apfel',
    );
    final items = await (db.select(
      db.learningItems,
    )..where((row) => row.entryId.equals(retainedEntry.id))).get();
    for (final item in items) {
      await insertReview('retained-review-${item.id}', item.id);
      await insertRetry(
        'retained-retry-${item.id}',
        item.id,
        'retained-review-${item.id}',
      );
      await db.customStatement(
        'INSERT INTO scope_answer_ordinals '
        '(collection_id, direction, ordinal, revision) VALUES (?, ?, ?, ?)',
        [retained.id, item.direction, 31 + item.id, 2],
      );
    }
    await db.customStatement(
      "INSERT INTO app_settings (key, value) VALUES ('locale', 'de')",
    );
    baseline = clone(await snapshot(db));
    owner = await collections.create(
      name: 'Owned ungraded Collection',
      targetLanguage: VocabularyLanguage.korean,
      nativeLanguage: VocabularyLanguage.german,
    );
    entry = await vocabulary.create(
      collectionId: owner.id,
      targetText: '학교',
      nativeText: 'Schule',
    );
    final captured = await snapshot(db);
    checkpoint = {
      'baseline': baseline,
      'owner': (captured['collections'] as List).cast<Map>().singleWhere(
        (row) => row['id'] == owner.id,
      ),
      'entry': (captured['vocabulary_entries'] as List).cast<Map>().singleWhere(
        (row) => row['id'] == entry.id,
      ),
      'learning': (captured['learning_items'] as List)
          .cast<Map>()
          .where((row) => row['entry_id'] == entry.id)
          .toList(),
      'ungraded': {for (final table in ungradedTables) table: <Object?>[]},
    };
    expectOwned(checkpoint, captured);
  }

  Future<void> insertReview(String id, int itemId) => db.customStatement(
    'INSERT INTO regular_reviews '
    '(id, item_id, generation, reviewed_at, rating) VALUES (?, ?, 0, ?, ?)',
    [id, itemId, '2026-10-14T09:00:00.000000Z', 'again'],
  );

  Future<void> insertRetry(
    String id,
    int itemId,
    String origin,
  ) => db.customStatement(
    'INSERT INTO retry_obligations '
    '(id, item_id, generation, revision, origin_review_id, created_at, '
    'expires_at, error_count, due_ordinal) VALUES (?, ?, 0, 0, ?, ?, ?, 1, 20)',
    [
      id,
      itemId,
      origin,
      '2026-10-14T09:00:00.000000Z',
      '2026-10-15T04:00:00.000000Z',
    ],
  );
}

void main() {
  test(
    'baseline guard detects mutations and allocator identity changes',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final unrelated = await SqliteCollectionsRepository(db).create(
        name: 'Retained baseline',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = SqliteVocabularyRepository(db);
      await repository.create(
        collectionId: unrelated.id,
        targetText: 'pomme',
        nativeText: 'Apfel',
      );
      await db.customStatement(
        "INSERT INTO app_settings (key, value) VALUES ('interfaceLocale', 'de')",
      );
      final baseline = await snapshot(db);
      Map<String, dynamic> clone() =>
          jsonDecode(jsonEncode(baseline)) as Map<String, dynamic>;
      expectBaseline(baseline, clone());
      final changed = clone();
      (changed['app_settings'] as List).add({
        'key': 'unexpected',
        'value': 'changed',
      });
      expect(
        () => expectBaseline(baseline, changed),
        throwsA(isA<TestFailure>()),
      );
      final allocator = clone();
      ((allocator['learning_identity_sequence'] as List).single
              as Map)['singleton'] =
          2;
      expect(
        () => expectBaseline(baseline, allocator),
        throwsA(isA<TestFailure>()),
      );
      final advanced = clone();
      ((advanced['learning_identity_sequence'] as List).single
              as Map)['next_id'] =
          10;
      expectBaseline(baseline, advanced);
    },
  );
  test(
    'cleanup refuses changed owned rows; exact cleanup preserves baseline and allocator',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final unrelated = await SqliteCollectionsRepository(db).create(
        name: 'Retained baseline',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = SqliteVocabularyRepository(db);
      await repository.create(
        collectionId: unrelated.id,
        targetText: 'pomme',
        nativeText: 'Apfel',
      );
      await db.customStatement(
        "INSERT INTO app_settings (key, value) VALUES ('interfaceLocale', 'de')",
      );
      final baseline = await snapshot(db);
      final owner = await SqliteCollectionsRepository(db).create(
        name: 'Owned',
        targetLanguage: VocabularyLanguage.korean,
        nativeLanguage: VocabularyLanguage.german,
      );
      final entry = await repository.create(
        collectionId: owner.id,
        targetText: '학교',
        nativeText: 'Schule',
      );
      final captured = await snapshot(db);
      final checkpoint = <String, dynamic>{
        'baseline': baseline,
        'owner': (captured['collections'] as List).cast<Map>().singleWhere(
          (row) => row['id'] == owner.id,
        ),
        'entry': (captured['vocabulary_entries'] as List)
            .cast<Map>()
            .singleWhere((row) => row['id'] == entry.id),
        'learning': (captured['learning_items'] as List)
            .cast<Map>()
            .where((row) => row['entry_id'] == entry.id)
            .toList(),
        'ungraded': {for (final table in ungradedTables) table: <Object?>[]},
      };
      await repository.update(
        id: entry.id,
        targetText: '학교',
        nativeText: 'Changed',
      );
      await expectLater(
        cleanupOwned(db, checkpoint),
        throwsA(isA<TestFailure>()),
      );
      expect(await db.select(db.collections).get(), hasLength(2));
      expect(
        (await (db.select(
          db.vocabularyEntries,
        )..where((row) => row.id.equals(entry.id))).getSingle()).nativeText,
        'Changed',
      );
      await repository.update(
        id: entry.id,
        targetText: '학교',
        nativeText: 'Schule',
      );
      await cleanupOwned(db, checkpoint);
      final after = await snapshot(db);
      expectBaseline(baseline, after);
      expect(
        after['learning_identity_sequence'],
        captured['learning_identity_sequence'],
      );
      expect(
        after['vocabulary_order_sequence'],
        captured['vocabulary_order_sequence'],
      );
    },
  );

  for (final table in ungradedTables) {
    test(
      'baseline guard rejects $table mutation, removal and addition',
      () async {
        final f = GuardFixture();
        addTearDown(f.db.close);
        await f.initialize();
        expect(f.baseline[table], hasLength(2));
        final captured = await snapshot(f.db);
        expectBaseline(
          f.baseline,
          captured,
          ownedCollection: f.owner.id,
          ownedEntry: f.entry.id,
        );
        for (final change in ['mutation', 'removal', 'addition']) {
          final changed = clone(captured);
          final rows = changed[table] as List;
          if (change == 'removal') {
            rows.removeLast();
          } else if (change == 'addition') {
            rows.add(Map<String, dynamic>.from(rows.first as Map));
          } else {
            final column = table == 'regular_reviews'
                ? 'rating'
                : table == 'retry_obligations'
                ? 'due_ordinal'
                : 'ordinal';
            (rows.first as Map)[column] = column == 'rating' ? 'good' : 999;
          }
          expect(
            () => expectBaseline(
              f.baseline,
              changed,
              ownedCollection: f.owner.id,
              ownedEntry: f.entry.id,
            ),
            throwsA(isA<TestFailure>()),
            reason: '$table $change must not pass the baseline guard',
          );
        }
        await cleanupOwned(f.db, f.checkpoint);
        expectBaseline(f.baseline, await snapshot(f.db));
      },
    );
  }

  test(
    'cleanup refuses unrelated review, retry and scope-counter changes',
    () async {
      final f = GuardFixture();
      addTearDown(f.db.close);
      await f.initialize();
      for (final (table, column, replacement) in [
        ('regular_reviews', 'rating', 'good'),
        ('retry_obligations', 'due_ordinal', 999),
        ('scope_answer_ordinals', 'ordinal', 999),
      ]) {
        for (final row in (f.baseline[table] as List).cast<Map>()) {
          await f.db.customStatement(
            'UPDATE $table SET $column = ? WHERE rowid = ?',
            [replacement, row['stored_rowid']],
          );
          final changed = await snapshot(f.db);
          await expectLater(
            cleanupOwned(f.db, f.checkpoint),
            throwsA(isA<TestFailure>()),
          );
          expect(await snapshot(f.db), changed);
          await f.db.customStatement(
            'UPDATE $table SET $column = ? WHERE rowid = ?',
            [row[column], row['stored_rowid']],
          );
        }
      }
      final beforeCleanup = await snapshot(f.db);
      await cleanupOwned(f.db, f.checkpoint);
      final after = await snapshot(f.db);
      expectBaseline(f.baseline, after);
      for (final table in sequences) {
        expect(after[table], beforeCleanup[table]);
      }
    },
  );

  for (final descendant in [
    'regular_reviews',
    'retry_obligations',
    'scope-targetToNative',
    'scope-nativeToTarget',
  ]) {
    test(
      'cleanup refuses unexpected owned $descendant without deleting it',
      () async {
        final f = GuardFixture();
        addTearDown(f.db.close);
        await f.initialize();
        final itemId =
            ((f.checkpoint['learning'] as List).first as Map)['id'] as int;
        if (descendant == 'regular_reviews') {
          await f.insertReview('unexpected-owned-review', itemId);
        } else if (descendant == 'retry_obligations') {
          // A foreign origin must not make an owned retry safe to destroy.
          final origin =
              ((f.baseline['regular_reviews'] as List).first as Map)['id']
                  as String;
          await f.insertRetry('unexpected-owned-retry', itemId, origin);
        } else {
          await f.db.customStatement(
            'INSERT INTO scope_answer_ordinals '
            '(collection_id, direction, ordinal, revision) VALUES (?, ?, 0, 0)',
            [f.owner.id, descendant.substring('scope-'.length)],
          );
        }
        final changed = await snapshot(f.db);
        await expectLater(
          cleanupOwned(f.db, f.checkpoint),
          throwsA(isA<TestFailure>()),
        );
        expect(await snapshot(f.db), changed);
        // Even a rewritten checkpoint cannot legitimize graded synthetic data.
        final alteredCheckpoint = clone(f.checkpoint);
        final table = descendant.startsWith('scope-')
            ? 'scope_answer_ordinals'
            : descendant;
        (alteredCheckpoint['ungraded'] as Map)[table] = [
          (changed[table] as List).last,
        ];
        await expectLater(
          cleanupOwned(f.db, alteredCheckpoint),
          throwsA(isA<TestFailure>()),
        );
        expect(await snapshot(f.db), changed);
      },
    );
  }

  test(
    'legacy or malformed checkpoint cannot authorize fixture deletion',
    () async {
      final f = GuardFixture();
      addTearDown(f.db.close);
      await f.initialize();
      final before = await snapshot(f.db);
      for (final malformed in [
        clone(f.checkpoint)..remove('ungraded'),
        clone(f.checkpoint)..['ungraded'] = null,
        clone(f.checkpoint)..['ungraded'] = <String, Object?>{},
      ]) {
        await expectLater(cleanupOwned(f.db, malformed), throwsA(anything));
        expect(await snapshot(f.db), before);
      }
      await cleanupOwned(f.db, f.checkpoint);
      expectBaseline(f.baseline, await snapshot(f.db));
    },
  );

  test(
    'failed cascade rolls back exact fixture state and permits safe retry',
    () async {
      final f = GuardFixture();
      addTearDown(f.db.close);
      await f.initialize();
      await f.db.customStatement(
        'CREATE TRIGGER fail_fixture_cleanup AFTER DELETE ON collections '
        "WHEN OLD.id = '${f.owner.id}' BEGIN SELECT RAISE(FAIL, 'blocked'); END",
      );
      final before = await snapshot(f.db);
      await expectLater(
        cleanupOwned(f.db, f.checkpoint),
        throwsA(isA<Exception>()),
      );
      expect(await snapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER fail_fixture_cleanup');
      await cleanupOwned(f.db, f.checkpoint);
      final after = await snapshot(f.db);
      expectBaseline(f.baseline, after);
      for (final table in sequences) {
        expect(after[table], before[table]);
      }
    },
  );

  for (final language in ['en', 'de']) {
    testWidgets('termination selectors use hydrated $language without writes', (
      tester,
    ) async {
      final h = settings.Harness();
      try {
        await tester.runAsync(
          () => h.repository.real.write('locale', language),
        );
        final before = await tester.runAsync(() => snapshot(h.db));
        await h.mount(tester);
        final copy = await hydratedRuntimeCopy(tester);
        expect(copy.locale, language);
        expect(find.text(copy.text('action.new')), findsOneWidget);
        expect(await tester.runAsync(() => snapshot(h.db)), before);
      } finally {
        await h.cleanup(tester);
      }
    });
  }
}
