import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;

class GatedSource implements ScopedReviewSource {
  GatedSource(this.source);
  final ScopedReviewSource source;
  final entered = Completer<void>(), gate = Completer<void>();
  @override
  String get collectionId => source.collectionId;
  @override
  LearningDirection get direction => source.direction;
  @override
  Future<List<LearningItemRecord>> dueItems({required DateTime cutoff}) =>
      source.dueItems(cutoff: cutoff);
  @override
  Future<RegularReviewReceipt> review({
    required ReviewKind kind,
    required LearningItemRecord expectedPrior,
    required LearningRating rating,
    required DateTime reviewedAt,
  }) async {
    entered.complete();
    await gate.future;
    return source.review(
      kind: kind,
      expectedPrior: expectedPrior,
      rating: rating,
      reviewedAt: reviewedAt,
    );
  }
}

Future<CollectionReviewGateway> source(
  Fixture f, [
  LearningDirection direction = LearningDirection.targetToNative,
]) => f.learning.forCollection(collectionId: f.owner.id, direction: direction);

Future<void> addWords(Fixture f, int count) async {
  for (var index = 0; index < count; index++) {
    await f.vocabulary.create(
      collectionId: f.owner.id,
      targetText: 'Word $index',
      nativeText: 'Wort $index',
    );
  }
}

void main() {
  test(
    'due uses decoded UTC instants including exact boundary and equivalent text',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      await addWords(f, 4);
      final gateway = await source(f);
      final items = await gateway.items();
      final cutoff = DateTime.utc(2026, 10, 14, 9, 10, 11);
      for (final (index, stamp) in [
        (0, '2026-10-14T09:10:10.999999Z'),
        (1, '2026-10-14T09:10:11Z'),
        (2, '2026-10-14T09:10:11.000+00:00'),
        (3, '2026-10-14T09:10:11.000001Z'),
        (4, '2026-10-15T09:10:11Z'),
      ]) {
        final json = jsonDecode(items[index].cardJson) as Map<String, dynamic>;
        json['due'] = stamp;
        await (f.db.update(f.db.learningItems)
              ..where((row) => row.id.equals(items[index].id)))
            .write(LearningItemsCompanion(cardJson: Value(jsonEncode(json))));
      }
      final before = await rows(f.db, 'learning_items');
      final due = await gateway.dueItems(cutoff: cutoff);
      expect(due.map((item) => item.id), items.take(3).map((item) => item.id));
      expect(() => due.clear(), throwsUnsupportedError);
      expect(await rows(f.db, 'learning_items'), before);
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
      final session = await DueLearningSession.start(
        source: gateway,
        cutoff: cutoff,
      );
      addTearDown(session.dispose);
      expect(
        session.members.map((item) => item.id),
        due.map((item) => item.id),
      );
      await expectLater(
        gateway.dueItems(cutoff: DateTime(2026)),
        throwsArgumentError,
      );
      await expectLater(
        DueLearningSession.start(source: gateway, cutoff: DateTime(2026)),
        throwsArgumentError,
      );
    },
  );

  test(
    'only the current captured member can submit; nondue/foreign handles cannot bypass membership',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      await addWords(f, 1);
      final gateway = await source(f);
      final members = await gateway.items();
      final nondue = members.last;
      final card = nondue.card..due = instant.add(const Duration(days: 1));
      await f.learning.saveCard(nondue.id, card);
      final session = await DueLearningSession.start(
        source: gateway,
        cutoff: instant,
      );
      addTearDown(session.dispose);
      expect(session.members.map((item) => item.id), [members.first.id]);
      final outsider = RegularGradingCoordinator(repository: f.learning);
      addTearDown(outsider.dispose);
      final before = await rows(f.db, 'learning_items');
      for (final item in [
        (await gateway.items()).last,
        await f.current(f.other),
        await f.current(null, true),
      ]) {
        final handle = outsider.activate(item)!;
        expect(session.setHard(handle, true), isFalse);
        expect(
          await session.submit(
            handle,
            AnswerGrade.incorrect,
            reviewedAt: instant,
          ),
          isNull,
        );
      }
      expect(session.current!.item.id, members.first.id);
      expect(session.acceptedReviews, isEmpty);
      expect(await rows(f.db, 'learning_items'), before);
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
    },
  );

  test(
    'initial membership includes all 129 due items without a batch cap or other scope',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      await addWords(f, 128);
      final allBefore = await rows(f.db, 'learning_items');
      final gateway = await source(f);
      final session = await DueLearningSession.start(
        source: gateway,
        cutoff: instant,
      );
      addTearDown(session.dispose);
      expect(session.members, hasLength(129));
      expect(
        session.members.map((item) => item.id),
        (await gateway.items()).map((item) => item.id),
      );
      expect(
        session.members.map((item) => item.direction),
        everyElement(gateway.direction),
      );
      expect(session.collectionId, f.owner.id);
      expect(session.current!.item.id, session.members.first.id);
      expect(() => session.members.clear(), throwsUnsupportedError);
      final added = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'After start',
        nativeText: 'Danach',
      );
      expect(session.members.any((item) => item.entryId == added.id), isFalse);
      await session.stop();
      expect(session.current, isNull);
      expect(session.unreviewedMembers, hasLength(129));
      expect(session.acceptedReviews, isEmpty);
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
      expect(
        (await rows(f.db, 'learning_items')).take(allBefore.length),
        allBefore,
      );
    },
  );

  for (final direction in LearningDirection.values) {
    test(
      'real multi-card traversal $direction records each regular member once',
      () async {
        final f = Fixture();
        addTearDown(f.db.close);
        await f.initialize();
        await addWords(f, 2);
        final gateway = await source(f, direction);
        final session = await DueLearningSession.start(
          source: gateway,
          cutoff: instant,
        );
        addTearDown(session.dispose);
        final before = await rows(f.db, 'learning_items');
        final first = session.current!;
        session.setHard(first, true);
        final firstReceipt = (await session.submit(
          first,
          AnswerGrade.incorrect,
          reviewedAt: instant,
        ))!;
        expect(firstReceipt.event.rating, LearningRating.again);
        expect(session.hard, isFalse);
        expect(session.current!.item.id, session.members[1].id);
        expect(
          await session.submit(first, AnswerGrade.correct, reviewedAt: instant),
          isNull,
        );
        expect(session.setHard(first, true), isFalse);
        for (var index = 1; index < session.members.length; index++) {
          final handle = session.current!;
          final receipt = (await session.submit(
            handle,
            AnswerGrade.correct,
            reviewedAt: instant,
          ))!;
          expect(receipt.event.rating, LearningRating.good);
          expect(receipt.prior.cardJson, session.members[index].cardJson);
        }
        expect(session.regularItemsExhausted, isTrue);
        expect(session.current, isNull);
        expect(session.unreviewedMembers, isEmpty);
        expect(
          session.acceptedReviews.map((receipt) => receipt.prior.id),
          session.members.map((item) => item.id),
        );
        expect(await rows(f.db, 'regular_reviews'), hasLength(3));
        final ids = session.members.map((item) => item.id).toSet();
        expect(
          (await rows(
            f.db,
            'learning_items',
          )).where((row) => !ids.contains(row['id'])),
          before.where((row) => !ids.contains(row['id'])),
        );
        await session.stop();
        expect(session.isStopped, isTrue);
      },
    );
  }

  test(
    'voluntary exit after one grade leaves every unanswered item exact',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      await addWords(f, 2);
      final session = await DueLearningSession.start(
        source: await source(f),
        cutoff: instant,
      );
      addTearDown(session.dispose);
      final before = await rows(f.db, 'learning_items');
      final answered = session.current!;
      await session.submit(answered, AnswerGrade.correct, reviewedAt: instant);
      final unanswered = session.current!;
      session.setHard(unanswered, true);
      final afterGrade = await rows(f.db, 'learning_items');
      await session.stop();
      await session.stop();
      expect(session.current, isNull);
      expect(session.regularItemsExhausted, isFalse);
      expect(session.acceptedReviews, hasLength(1));
      expect(session.unreviewedMembers, hasLength(2));
      expect(
        await session.submit(
          unanswered,
          AnswerGrade.incorrect,
          reviewedAt: instant,
        ),
        isNull,
      );
      expect(session.setHard(unanswered, false), isFalse);
      expect(await rows(f.db, 'learning_items'), afterGrade);
      expect(
        afterGrade.where((row) => row['id'] != answered.item.id),
        before.where((row) => row['id'] != answered.item.id),
      );
      expect(await rows(f.db, 'regular_reviews'), hasLength(1));
    },
  );

  test(
    'pending stop freezes immediately and drains actual SQLite receipt/bookkeeping',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      await addWords(f, 1);
      final gated = GatedSource(await source(f));
      final registered = <Future<void>>[];
      final session = await DueLearningSession.start(
        source: gated,
        cutoff: instant,
        onPendingWrites: registered.add,
      );
      addTearDown(session.dispose);
      addTearDown(() async {
        if (!gated.gate.isCompleted) gated.gate.complete();
        await session.awaitPending();
      });
      final before = await rows(f.db, 'learning_items');
      final handle = session.current!;
      session.setHard(handle, true);
      final submitting = session.submit(
        handle,
        AnswerGrade.correct,
        reviewedAt: instant,
      );
      await gated.entered.future;
      expect(session.isSubmitting, isTrue);
      expect(
        await session.submit(
          handle,
          AnswerGrade.incorrect,
          reviewedAt: instant,
        ),
        isNull,
      );
      expect(session.setHard(handle, false), isFalse);
      final stopping = session.stop();
      var drained = false;
      unawaited(stopping.then((_) => drained = true));
      var runtimeDrained = false;
      unawaited(registered.single.then((_) => runtimeDrained = true));
      var notifications = 0;
      session.addListener(() => notifications++);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      expect(runtimeDrained, isFalse);
      expect(session.current, isNull);
      expect(await rows(f.db, 'learning_items'), before);
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
      gated.gate.complete();
      final receipt = (await submitting)!;
      await stopping;
      await registered.single;
      expect(session.acceptedReviews.single, same(receipt));
      expect(receipt.event.rating, LearningRating.hard);
      expect(session.unreviewedMembers, hasLength(1));
      expect(session.current, isNull);
      expect(notifications, 0);
      expect(
        (await rows(f.db, 'regular_reviews')).single['id'],
        receipt.event.id,
      );
      expect(
        (await rows(
          f.db,
          'learning_items',
        )).where((row) => row['id'] != handle.item.id),
        before.where((row) => row['id'] != handle.item.id),
      );
    },
  );

  test(
    'registration callback can synchronously stop while admitted grade remains tracked',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      late DueLearningSession session;
      Future<void>? stopped, registered;
      session = await DueLearningSession.start(
        source: await source(f),
        cutoff: instant,
        onPendingWrites: (drain) {
          registered = drain;
          stopped = session.stop();
        },
      );
      addTearDown(session.dispose);
      final receipt = (await session.submit(
        session.current!,
        AnswerGrade.correct,
        reviewedAt: instant,
      ))!;
      await stopped;
      await registered;
      expect(session.isStopped, isTrue);
      expect(session.acceptedReviews.single, same(receipt));
      expect(await rows(f.db, 'regular_reviews'), hasLength(1));
    },
  );

  test(
    'failed lifetime registration writes nothing and retains card/Hard for retry',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      var fail = true;
      final session = await DueLearningSession.start(
        source: await source(f),
        cutoff: instant,
        onPendingWrites: (_) {
          if (fail) throw StateError('registration');
        },
      );
      addTearDown(session.dispose);
      final handle = session.current!;
      session.setHard(handle, true);
      final before = await rows(f.db, 'learning_items');
      await expectLater(
        session.submit(handle, AnswerGrade.correct, reviewedAt: instant),
        throwsStateError,
      );
      expect(session.current, same(handle));
      expect(session.hard, isTrue);
      expect(session.acceptedReviews, isEmpty);
      expect(await rows(f.db, 'learning_items'), before);
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
      fail = false;
      expect(
        (await session.submit(
          handle,
          AnswerGrade.correct,
          reviewedAt: instant,
        ))!.event.rating,
        LearningRating.hard,
      );
    },
  );

  test(
    'actual failure retains current membership/Hard; stale or deleted member is never skipped',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      await addWords(f, 1);
      final session = await DueLearningSession.start(
        source: await source(f),
        cutoff: instant,
      );
      addTearDown(session.dispose);
      final handle = session.current!;
      session.setHard(handle, true);
      final before = await rows(f.db, 'learning_items');
      await f.db.customStatement(
        "CREATE TRIGGER session_fail AFTER UPDATE ON learning_items BEGIN SELECT RAISE(FAIL, 'session failure'); END",
      );
      await expectLater(
        session.submit(handle, AnswerGrade.correct, reviewedAt: instant),
        throwsA(isA<SqliteException>()),
      );
      expect(session.current, same(handle));
      expect(session.hard, isTrue);
      expect(session.acceptedReviews, isEmpty);
      expect(await rows(f.db, 'learning_items'), before);
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
      await f.db.customStatement('DROP TRIGGER session_fail');
      await f.learning.review(
        kind: ReviewKind.regular,
        expectedPrior: handle.item,
        rating: LearningRating.good,
        reviewedAt: instant,
      );
      await expectLater(
        session.submit(handle, AnswerGrade.correct, reviewedAt: instant),
        throwsA(RegularReviewFailure.staleState),
      );
      expect(session.current, same(handle));
      await (f.db.delete(
        f.db.vocabularyEntries,
      )..where((row) => row.id.equals(handle.item.entryId))).go();
      await expectLater(
        session.submit(handle, AnswerGrade.correct, reviewedAt: instant),
        throwsA(RegularReviewFailure.itemNotFound),
      );
      expect(session.current, same(handle));
      expect(session.unreviewedMembers, hasLength(2));
      await session.stop();
    },
  );

  for (final dispose in [false, true]) {
    for (final atAdvance in [false, true]) {
      test(
        'listener ${dispose ? "dispose" : "stop"} at ${atAdvance ? "accepted advance" : "pending"} is safe and suppresses late changes',
        () async {
          final f = Fixture();
          addTearDown(f.db.close);
          await f.initialize();
          await addWords(f, 1);
          final session = await DueLearningSession.start(
            source: await source(f),
            cutoff: instant,
          );
          addTearDown(session.dispose);
          var called = false;
          var lateNotifications = 0;
          session.addListener(() {
            if (called) {
              lateNotifications++;
              return;
            }
            final matches = atAdvance
                ? session.acceptedReviews.isNotEmpty
                : session.isSubmitting;
            if (matches) {
              called = true;
              if (dispose) {
                session.dispose();
              } else {
                unawaited(session.stop());
              }
            }
          });
          final receipt = (await session.submit(
            session.current!,
            AnswerGrade.correct,
            reviewedAt: instant,
          ))!;
          await session.awaitPending();
          await Future<void>.delayed(Duration.zero);
          expect(called, isTrue);
          expect(session.isStopped, isTrue);
          expect(session.current, isNull);
          expect(session.acceptedReviews.single, same(receipt));
          expect(session.unreviewedMembers, hasLength(1));
          // Stop's one synchronous transition notification is allowed; none later.
          expect(lateNotifications, dispose ? 0 : 1);
          expect(await rows(f.db, 'regular_reviews'), hasLength(1));
        },
      );
    }
  }

  test(
    'no due session is empty without writes; deleted owner fails instead',
    () async {
      final f = Fixture();
      addTearDown(f.db.close);
      await f.initialize();
      final gateway = await source(f);
      final session = await DueLearningSession.start(
        source: gateway,
        cutoff: instant.subtract(const Duration(microseconds: 1)),
      );
      addTearDown(session.dispose);
      expect(session.members, isEmpty);
      expect(session.current, isNull);
      expect(session.regularItemsExhausted, isTrue);
      await session.stop();
      expect(await rows(f.db, 'regular_reviews'), isEmpty);
      await f.collections.delete(f.owner.id);
      await expectLater(
        DueLearningSession.start(source: gateway, cutoff: instant),
        throwsA(RegularReviewFailure.collectionNotFound),
      );
    },
  );
}
