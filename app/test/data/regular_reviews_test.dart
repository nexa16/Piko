import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';

final instant = DateTime.utc(2026, 10, 14, 9, 10, 11, 123, 456);
LearningItemRecord changed(
  LearningItemRecord before, {
  String? entry,
  LearningDirection? direction,
  int? generation,
  int? revision,
  String? json,
  int? version,
  int? id,
}) => LearningItemRecord(
  id: id ?? before.id,
  entryId: entry ?? before.entryId,
  direction: direction ?? before.direction,
  cardJson: json ?? before.cardJson,
  formatVersion: version ?? before.formatVersion,
  generation: generation ?? before.generation,
  reviewRevision: revision ?? before.reviewRevision,
);
Future<List<Map<String, Object?>>> rows(PikoDatabase db, String table) async =>
    (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
        .map((row) => row.data)
        .toList();

class Fixture {
  Fixture({PikoDatabase? database})
    : db =
          database ??
          PikoDatabase(
            NativeDatabase.memory(),
            clock: MutablePikoClock(instant),
          );
  final PikoDatabase db;
  late final collections = SqliteCollectionsRepository(db);
  late final vocabulary = SqliteVocabularyRepository(db);
  late final learning = SqliteLearningRepository(db);
  late CollectionRecord owner, kept;
  late VocabularyRecord entry, other;
  Future<void> initialize() async {
    owner = await collections.create(
      name: 'Same',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    kept = await collections.create(
      name: 'Same',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    entry = await vocabulary.create(
      collectionId: owner.id,
      targetText: 'One',
      nativeText: 'Eins',
    );
    other = await vocabulary.create(
      collectionId: kept.id,
      targetText: 'Two',
      nativeText: 'Zwei',
    );
  }

  Future<LearningItemRecord> current([
    VocabularyRecord? word,
    bool reverse = false,
  ]) async => (await learning.forEntry((word ?? entry).id))[reverse ? 1 : 0];
  Future<RegularReviewReceipt> review({
    VocabularyRecord? word,
    bool reverse = false,
    LearningRating rating = LearningRating.good,
    DateTime? at,
  }) async => learning.review(
    kind: ReviewKind.regular,
    expectedPrior: await current(word, reverse),
    rating: rating,
    reviewedAt: at ?? instant,
  );
}

void main() {
  test(
    'production events in both directions retain exact payload/order/card/revision across file reopen and continue',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-review-retention-',
      );
      final file = File('${directory.path}/review.sqlite');
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(instant),
      );
      try {
        final f = Fixture(database: db);
        await f.initialize();
        await (db.update(db.learningItems)
              ..where((row) => row.entryId.equals(f.entry.id)))
            .write(const LearningItemsCompanion(generation: Value(9)));
        await f.review(rating: LearningRating.hard);
        await f.review(reverse: true, rating: LearningRating.again);
        await f.review(rating: LearningRating.good);
        await f.review(reverse: true, rating: LearningRating.hard);
        final stored = await rows(db, 'regular_reviews');
        final items = await f.learning.forEntry(f.entry.id);
        final order = [
          for (final item in items)
            (await f.learning.reviewsForItem(
              item.id,
            )).map((event) => event.id).toList(),
        ];
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant.add(const Duration(days: 7))),
        );
        final learning = SqliteLearningRepository(db);
        expect(await rows(db, 'regular_reviews'), stored);
        final reopened = await learning.forEntry(f.entry.id);
        for (var index = 0; index < items.length; index++) {
          expect(reopened[index].cardJson, items[index].cardJson);
          expect(reopened[index].generation, 9);
          expect(reopened[index].reviewRevision, 2);
          final events = await learning.reviewsForItem(items[index].id);
          expect(events.map((event) => event.id), order[index]);
          expect(events.map((event) => event.reviewedAt), [instant, instant]);
          expect(events.map((event) => event.generation), [9, 9]);
        }
        final next = await learning.review(
          kind: ReviewKind.regular,
          expectedPrior: reopened.first,
          rating: LearningRating.good,
          reviewedAt: instant.add(const Duration(days: 1)),
        );
        expect(next.next.reviewRevision, 3);
        expect(next.event.generation, 9);
        expect(await learning.reviewsForItem(reopened.first.id), hasLength(3));
        expect(
          (await learning.forEntry(f.entry.id)).last.cardJson,
          reopened.last.cardJson,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'Undo failure after history reinsertion rolls back vocabulary/items/events and retries exact snapshot',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review();
      await f.review(reverse: true, rating: LearningRating.hard);
      final originalItems = await rows(f.db, 'learning_items');
      final originalEvents = await rows(f.db, 'regular_reviews');
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      await f.db.customStatement(
        "CREATE TRIGGER fail_undo AFTER INSERT ON regular_reviews BEGIN SELECT RAISE(FAIL, 'blocked'); END",
      );
      await expectLater(
        deletion.restore(receipt),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await f.vocabulary.watchById(f.entry.id).first, isNull);
      expect(await f.learning.forEntry(f.entry.id), isEmpty);
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
      expect(deletion.canUndo(receipt), isTrue);
      await f.db.customStatement('DROP TRIGGER fail_undo');
      await deletion.restore(receipt);
      expect(await rows(f.db, 'learning_items'), originalItems);
      expect(await rows(f.db, 'regular_reviews'), originalEvents);
    },
  );
  test(
    'production transaction retains exact UTC/rating/generation and immutable prior/result with stable event UUID',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final initial = await f.current(), reverse = await f.current(null, true);
      expect(initial.generation, 0);
      expect(initial.reviewRevision, 0);
      expect(await f.learning.reviewsForItem(initial.id), isEmpty);
      final transition = LearningScheduler().review(
        initial,
        rating: LearningRating.hard,
        reviewedAt: instant,
      );
      final receipt = await f.learning.review(
        kind: ReviewKind.regular,
        expectedPrior: initial,
        rating: LearningRating.hard,
        reviewedAt: instant,
      );
      expect(receipt.prior.cardJson, initial.cardJson);
      expect(receipt.prior.reviewRevision, 0);
      expect(receipt.next.reviewRevision, 1);
      expect(receipt.next.cardJson, transition.next.cardJson);
      expect(receipt.next.generation, 0);
      expect(
        receipt.event.id,
        matches(RegExp(r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$')),
      );
      expect(receipt.event.itemId, initial.id);
      expect(receipt.event.rating, LearningRating.hard);
      expect(receipt.event.reviewedAt, instant);
      expect(receipt.event.generation, 0);
      final stored = (await rows(f.db, 'regular_reviews')).single;
      expect(stored['reviewed_at'], instant.toIso8601String());
      expect((await f.current()).cardJson, receipt.next.cardJson);
      expect((await f.current(null, true)).cardJson, reverse.cardJson);
      receipt.next.card.stability = 999;
      receipt.prior.card.difficulty = 1;
      expect((await f.current()).cardJson, receipt.next.cardJson);
      await (f.db.update(f.db.learningItems)
            ..where((row) => row.id.equals(initial.id)))
          .write(const LearningItemsCompanion(generation: Value(7)));
      final next = await f.review(rating: LearningRating.again);
      expect(next.event.generation, 7);
      expect(next.next.generation, 7);
      expect(next.next.reviewRevision, 2);
      expect(
        (await f.learning.reviewsForItem(
          initial.id,
        )).map((event) => event.generation),
        [0, 7],
      );
    },
  );

  test(
    'same-instant fixed-point card rejects repeated and concurrent prior even when card JSON stays identical',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final initial = await f.current();
      final reference = fsrs.Scheduler(
        learningSteps: const [],
        relearningSteps: const [],
        enableFuzzing: false,
      );
      var card = fsrs.Card(
        cardId: initial.id,
        state: fsrs.State.review,
        stability: 1000000,
        difficulty: 5,
        lastReview: instant,
        due: instant.add(const Duration(days: 36500)),
      );
      for (var index = 0; index < 6000; index++) {
        card = reference
            .reviewCard(card, fsrs.Rating.good, reviewDateTime: instant)
            .card;
      }
      await f.learning.saveCard(initial.id, card);
      final before = await f.current();
      expect(
        LearningScheduler()
            .review(before, rating: LearningRating.good, reviewedAt: instant)
            .next
            .cardJson,
        before.cardJson,
      );
      final outcomes = await Future.wait(
        List.generate(2, (_) async {
          try {
            return await f.learning.review(
              kind: ReviewKind.regular,
              expectedPrior: before,
              rating: LearningRating.good,
              reviewedAt: instant,
            );
          } catch (error) {
            return error;
          }
        }),
      );
      expect(outcomes.whereType<RegularReviewReceipt>(), hasLength(1));
      expect(
        outcomes.where((result) => result == RegularReviewFailure.staleState),
        hasLength(1),
      );
      expect((await f.current()).cardJson, before.cardJson);
      expect((await f.current()).reviewRevision, 1);
      await expectLater(
        f.learning.review(
          kind: ReviewKind.regular,
          expectedPrior: before,
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(RegularReviewFailure.staleState),
      );
      expect(await f.learning.reviewsForItem(initial.id), hasLength(1));
    },
  );

  for (final stage in ['event', 'card']) {
    test(
      '$stage storage failure rolls back event/card/revision and observers never see partial state; retry succeeds',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final before = await f.current();
        final emitted = <(int, int)>[];
        final initialEmission = Completer<void>(),
            committedEmission = Completer<void>();
        final subscription = f.db
            .customSelect(
              'SELECT l.review_revision AS revision, COUNT(r.id) AS events '
              'FROM learning_items l LEFT JOIN regular_reviews r ON r.item_id = l.id WHERE l.id = ${before.id} GROUP BY l.id',
              readsFrom: {f.db.learningItems, f.db.regularReviews},
            )
            .watch()
            .listen((rows) {
              emitted.add((
                rows.single.read<int>('revision'),
                rows.single.read<int>('events'),
              ));
              if (emitted.last == (0, 0) && !initialEmission.isCompleted) {
                initialEmission.complete();
              }
              if (emitted.last == (1, 1) && !committedEmission.isCompleted) {
                committedEmission.complete();
              }
            });
        addTearDown(subscription.cancel);
        await initialEmission.future;
        final table = stage == 'event' ? 'regular_reviews' : 'learning_items';
        final action = stage == 'event' ? 'INSERT' : 'UPDATE OF card_json';
        await f.db.customStatement(
          "CREATE TRIGGER fail_review AFTER $action ON $table BEGIN SELECT RAISE(FAIL, 'blocked'); END",
        );
        await expectLater(
          f.learning.review(
            kind: ReviewKind.regular,
            expectedPrior: before,
            rating: LearningRating.good,
            reviewedAt: instant,
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
        expect((await f.current()).cardJson, before.cardJson);
        expect((await f.current()).reviewRevision, 0);
        expect(await f.learning.reviewsForItem(before.id), isEmpty);
        await Future<void>.delayed(Duration.zero);
        expect(emitted.every((value) => value == (0, 0)), isTrue);
        await f.db.customStatement('DROP TRIGGER fail_review');
        await f.review();
        await committedEmission.future;
        expect((await f.current()).reviewRevision, 1);
        expect(await f.learning.reviewsForItem(before.id), hasLength(1));
        expect(
          emitted.every((value) => value == (0, 0) || value == (1, 1)),
          isTrue,
        );
      },
    );
  }

  test(
    'missing, wrong ownership/direction/generation/revision, corrupt and invalid-time input cannot create history',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final before = await f.current();
      for (final invalid in [
        changed(before, entry: f.other.id),
        changed(before, direction: LearningDirection.nativeToTarget),
        changed(before, generation: 1),
        changed(before, revision: 1),
      ]) {
        await expectLater(
          f.learning.review(
            kind: ReviewKind.regular,
            expectedPrior: invalid,
            rating: LearningRating.good,
            reviewedAt: instant,
          ),
          throwsA(RegularReviewFailure.staleState),
        );
      }
      for (final invalid in [
        changed(before, generation: -1),
        changed(before, revision: -1),
        changed(before, version: 2),
        changed(before, json: '{}'),
        changed(before, entry: ''),
      ]) {
        await expectLater(
          f.learning.review(
            kind: ReviewKind.regular,
            expectedPrior: invalid,
            rating: LearningRating.good,
            reviewedAt: instant,
          ),
          throwsFormatException,
        );
      }
      await expectLater(
        f.learning.review(
          kind: ReviewKind.regular,
          expectedPrior: before,
          rating: LearningRating.good,
          reviewedAt: instant.toLocal(),
        ),
        throwsArgumentError,
      );
      await f.review();
      final current = await f.current();
      await expectLater(
        f.learning.review(
          kind: ReviewKind.regular,
          expectedPrior: current,
          rating: LearningRating.good,
          reviewedAt: instant.subtract(const Duration(microseconds: 1)),
        ),
        throwsArgumentError,
      );
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      await deletion.delete(f.entry.id);
      await expectLater(
        f.learning.review(
          kind: ReviewKind.regular,
          expectedPrior: current,
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(RegularReviewFailure.itemNotFound),
      );
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
    },
  );

  test(
    'equal-time interleaved review histories retain UUID/order/generation/revision through delete Undo with unrelated new reviews',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await (f.db.update(f.db.learningItems)
            ..where((row) => row.entryId.equals(f.entry.id)))
          .write(const LearningItemsCompanion(generation: Value(5)));
      for (final rating in LearningRating.values) {
        await f.review(rating: rating);
        await f.review(word: f.other);
        await f.review(reverse: true, rating: rating);
      }
      final items = await f.learning.forEntry(f.entry.id);
      final originals = [
        for (final item in items) await f.learning.reviewsForItem(item.id),
      ];
      final payloads = (await rows(f.db, 'regular_reviews'))
          .where((row) => items.any((item) => item.id == row['item_id']))
          .toList();
      final deleted = Completer<void>(), restored = Completer<void>();
      var restoring = false;
      final watch = f.db.select(f.db.regularReviews).watch().listen((rows) {
        final owned = rows
            .where((row) => items.any((item) => item.id == row.itemId))
            .toList();
        if (owned.isEmpty && !deleted.isCompleted) deleted.complete();
        if (restoring && owned.length == 6 && !restored.isCompleted) {
          restored.complete();
        }
      });
      addTearDown(watch.cancel);
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      await deleted.future;
      await f.review(word: f.other, rating: LearningRating.hard);
      final kept = (await rows(f.db, 'regular_reviews')).toList();
      restoring = true;
      await deletion.restore(receipt);
      await restored.future;
      for (var index = 0; index < items.length; index++) {
        final item = items[index],
            current = (await f.learning.forEntry(f.entry.id))[index];
        expect(current.cardJson, item.cardJson);
        expect(current.generation, item.generation);
        expect(current.reviewRevision, item.reviewRevision);
        final events = await f.learning.reviewsForItem(item.id);
        expect(
          events.map((event) => event.id),
          originals[index].map((event) => event.id),
        );
        expect(
          events.map((event) => event.reviewedAt),
          originals[index].map((event) => event.reviewedAt),
        );
      }
      final all = await rows(f.db, 'regular_reviews');
      expect(
        all.where((row) => items.any((item) => item.id == row['item_id'])),
        payloads,
      );
      expect(
        all.where((row) => !items.any((item) => item.id == row['item_id'])),
        kept,
      );
    },
  );

  test(
    'Undo history UUID conflict rolls back complete restoration and permits retry',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final event = (await f.review()).event;
      final original = await f.current();
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      final other = await f.current(f.other);
      await f.db
          .into(f.db.regularReviews)
          .insert(
            RegularReviewsCompanion.insert(
              id: event.id,
              itemId: other.id,
              generation: 0,
              rating: 'hard',
              reviewedAt: instant.toIso8601String(),
            ),
          );
      await expectLater(
        deletion.restore(receipt),
        throwsA(VocabularyUndoFailure.identityConflict),
      );
      expect(await f.vocabulary.watchById(f.entry.id).first, isNull);
      expect(await f.learning.forEntry(f.entry.id), isEmpty);
      await (f.db.delete(
        f.db.regularReviews,
      )..where((row) => row.id.equals(event.id))).go();
      await deletion.restore(receipt);
      expect((await f.current()).cardJson, original.cardJson);
      expect(
        (await f.learning.reviewsForItem(original.id)).single.id,
        event.id,
      );
    },
  );

  test(
    'Collection cascade notifies review observers, preserves other history, and rolls back failed cascade',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review();
      await f.review(reverse: true);
      await f.review(word: f.other);
      final keptItem = await f.current(f.other);
      final kept = (await rows(
        f.db,
        'regular_reviews',
      )).where((row) => row['item_id'] == keptItem.id).toList();
      final before = await rows(f.db, 'regular_reviews');
      final emitted = <List<Map<String, Object?>>>[];
      final initialEmission = Completer<void>();
      final subscription = f.db.select(f.db.regularReviews).watch().listen((
        records,
      ) {
        emitted.add(records.map((row) => row.toJson()).toList());
        if (records.length == 3 && !initialEmission.isCompleted) {
          initialEmission.complete();
        }
      });
      addTearDown(subscription.cancel);
      await initialEmission.future;
      await f.db.customStatement(
        "CREATE TRIGGER fail_cascade AFTER DELETE ON regular_reviews BEGIN SELECT RAISE(FAIL, 'blocked'); END",
      );
      await expectLater(
        f.collections.delete(f.owner.id),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await rows(f.db, 'regular_reviews'), before);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.every((rows) => rows.length == 3), isTrue);
      await f.db.customStatement('DROP TRIGGER fail_cascade');
      final observer = StreamIterator(f.db.select(f.db.regularReviews).watch());
      await observer.moveNext();
      final next = observer.moveNext();
      await f.collections.delete(f.owner.id);
      await next;
      expect(observer.current.single.itemId, keptItem.id);
      await observer.cancel();
      expect(await rows(f.db, 'regular_reviews'), kept);
      expect(await f.learning.forEntry(f.entry.id), isEmpty);
    },
  );

  test(
    'review reads reject corrupt rating/time/generation and SQL enforces fresh domain constraints',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final item = await f.current();
      final reverse = await f.current(null, true);
      await (f.db.delete(
        f.db.learningItems,
      )..where((row) => row.id.equals(reverse.id))).go();
      for (final column in ['generation', 'review_revision']) {
        await expectLater(
          f.db.customStatement(
            'UPDATE learning_items SET $column = -1 WHERE id = ${item.id}',
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
        await expectLater(
          f.db.customStatement(
            "INSERT INTO learning_items (id,entry_id,direction,format_version,card_json,$column) VALUES (99,?,'nativeToTarget',1,?,-1)",
            [
              f.entry.id,
              LearningCardCodec.encode(fsrs.Card(cardId: 99, due: instant)),
            ],
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
      }
      for (final patch in [
        "-1, 'good', '${instant.toIso8601String()}'",
        "0, 'easy', '${instant.toIso8601String()}'",
        "0, 'good', 'local'",
      ]) {
        await expectLater(
          f.db.customStatement(
            "INSERT INTO regular_reviews (id,item_id,generation,rating,reviewed_at) VALUES ('bad',${item.id},$patch)",
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
      }
      await f.db.customStatement('PRAGMA ignore_check_constraints = ON');
      for (final (rating, time, generation) in [
        ('easy', instant.toIso8601String(), 0),
        ('good', 'not-timeZ', 0),
        ('good', instant.toIso8601String(), -1),
      ]) {
        await f.db.customStatement('DELETE FROM regular_reviews');
        await f.db.customStatement(
          'INSERT INTO regular_reviews (id,item_id,generation,rating,reviewed_at) VALUES (?,?,?,?,?)',
          ['bad', item.id, generation, rating, time],
        );
        await expectLater(
          f.learning.reviewsForItem(item.id),
          throwsFormatException,
        );
      }
    },
  );

  for (var version = 1; version <= 6; version++) {
    test(
      'schema$version upgrades to7 preserving existing exact rows and initializing zero discriminator/revision without invented history',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'piko-review-migration-',
        );
        final file = File('${directory.path}/review.sqlite');
        final old = sqlite.sqlite3.open(file.path);
        final schema =
            jsonDecode(
                  await File(
                    'drift_schemas/drift_schema_v$version.json',
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        for (final group in schema['fixed_sql'] as List) {
          old.execute((group['sql'] as List).single['sql'] as String);
        }
        old.execute("INSERT INTO app_settings VALUES ('locale','de')");
        if (version >= 2) {
          old.execute(
            "INSERT INTO collections VALUES ('owner','Legacy','fr','de')",
          );
        }
        if (version >= 3) {
          old.execute(
            "INSERT INTO vocabulary_entries (rowid,id,collection_id,target_text,native_text${version >= 4 ? ',target_key,native_key' : ''}) VALUES (17,'entry','owner',' Raw ',' Text '${version >= 4 ? ",'raw','text'" : ''})",
          );
        }
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
        if (version >= 5) {
          old.execute('INSERT INTO learning_identity_sequence VALUES (1,200)');
          old.execute(
            "INSERT INTO learning_items (id,entry_id,direction,format_version,card_json) VALUES (19,'entry','targetToNative',1,?)",
            [legacy],
          );
        }
        if (version >= 6) {
          old.execute('INSERT INTO vocabulary_order_sequence VALUES (1,100)');
        }
        old.execute('PRAGMA user_version = $version');
        old.close();
        var db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        try {
          expect(await rows(db, 'regular_reviews'), isEmpty);
          expect((await rows(db, 'app_settings')).single['value'], 'de');
          if (version >= 3) {
            final vocabulary =
                (await db
                        .customSelect('SELECT rowid,* FROM vocabulary_entries')
                        .get())
                    .single
                    .data;
            expect(vocabulary['rowid'], 17);
            expect(vocabulary['target_text'], ' Raw ');
            final items = await SqliteLearningRepository(db).forEntry('entry');
            for (final item in items) {
              expect(item.generation, 0);
              expect(item.reviewRevision, 0);
            }
            if (version >= 5) {
              expect(items.single.cardJson, legacy);
              expect(items.single.id, 19);
              expect(
                (await db.select(db.learningIdentitySequence).getSingle())
                    .nextId,
                200,
              );
              for (final column in ['generation', 'review_revision']) {
                await expectLater(
                  db.customStatement(
                    'UPDATE learning_items SET $column = -1 WHERE id = 19',
                  ),
                  throwsA(isA<sqlite.SqliteException>()),
                );
                await expectLater(
                  db.customStatement(
                    "INSERT INTO learning_items (id,entry_id,direction,format_version,card_json,$column) VALUES (99,'entry','nativeToTarget',1,?,-1)",
                    [legacy],
                  ),
                  throwsA(isA<sqlite.SqliteException>()),
                );
              }
            }
            if (version >= 6) {
              expect(
                (await db.select(db.vocabularyOrderSequence).getSingle())
                    .nextRowId,
                100,
              );
            }
          }
          await db.close();
          db = PikoDatabase(
            NativeDatabase(file),
            clock: MutablePikoClock(instant),
          );
          expect(await rows(db, 'regular_reviews'), isEmpty);
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            7,
          );
        } finally {
          await db.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
