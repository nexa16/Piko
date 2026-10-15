import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant;

Future<void> holdStorage(
  Fixture f,
  Completer<void> ready,
  Completer<void> release,
) => f.db.transaction(() async {
  await f.db.customSelect('SELECT 1').get();
  ready.complete();
  await release.future;
});

void main() {
  for (final (grade, hard, expected) in [
    (AnswerGrade.incorrect, false, LearningRating.again),
    (AnswerGrade.incorrect, true, LearningRating.again),
    (AnswerGrade.correct, false, LearningRating.good),
    (AnswerGrade.correct, true, LearningRating.hard),
  ]) {
    test(
      '${grade.name} Hard=$hard records $expected in actual regular transaction',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final before = await f.current(), reverse = await f.current(null, true);
        final coordinator = RegularGradingCoordinator(repository: f.learning);
        addTearDown(coordinator.dispose);
        final handle = coordinator.activate(before)!;
        coordinator.setHard(handle, hard);
        final expectedCard = LearningScheduler()
            .review(before, rating: expected, reviewedAt: instant)
            .next;
        final receipt = (await coordinator.submit(
          handle,
          grade,
          reviewedAt: instant,
        ))!;
        expect(receipt.event.rating, expected);
        expect(receipt.event.reviewedAt, instant);
        expect(receipt.prior.cardJson, before.cardJson);
        expect(receipt.next.cardJson, expectedCard.cardJson);
        expect((await f.current()).cardJson, expectedCard.cardJson);
        expect((await f.current()).reviewRevision, 1);
        expect(
          (await f.learning.reviewsForItem(before.id)).single.rating,
          expected,
        );
        expect((await f.current(null, true)).cardJson, reverse.cardJson);
        expect(coordinator.hard, hard);
        expect(coordinator.accepted, receipt);
        expect(
          await coordinator.submit(handle, grade, reviewedAt: instant),
          isNull,
        );
        expect(coordinator.setHard(handle, !hard), isFalse);
        expect(coordinator.completeAdvance(handle), isTrue);
        expect(coordinator.hard, isFalse);
        expect(coordinator.current, isNull);
        expect(await f.learning.reviewsForItem(before.id), hasLength(1));
      },
    );
  }

  test(
    'single-flight captures modifier/item/time; competing submissions, switches and callbacks cannot supersede pending grade',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final before = await f.current(), next = await f.current(f.other);
      final pending = <Future<void>>[];
      final coordinator = RegularGradingCoordinator(
        repository: f.learning,
        onPendingWrites: pending.add,
      );
      addTearDown(coordinator.dispose);
      final handle = coordinator.activate(before)!;
      coordinator.setHard(handle, true);
      final ready = Completer<void>(), release = Completer<void>();
      final blocker = holdStorage(f, ready, release);
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await blocker;
        await coordinator.awaitPending();
      });
      await ready.future;
      final writing = coordinator.submit(
        handle,
        AnswerGrade.correct,
        reviewedAt: instant,
      );
      expect(coordinator.isSubmitting, isTrue);
      expect(pending, hasLength(1));
      expect(coordinator.setHard(handle, false), isFalse);
      expect(coordinator.activate(next), isNull);
      expect(coordinator.current, handle);
      expect(coordinator.hard, isTrue);
      expect(coordinator.completeAdvance(handle), isFalse);
      expect(
        await coordinator.submit(
          handle,
          AnswerGrade.incorrect,
          reviewedAt: instant,
        ),
        isNull,
      );
      release.complete();
      await blocker;
      final receipt = (await writing)!;
      await coordinator.awaitPending();
      await Future.wait(pending);
      expect(receipt.event.itemId, before.id);
      expect(receipt.event.rating, LearningRating.hard);
      expect(receipt.event.reviewedAt, instant);
      expect(coordinator.accepted, receipt);
      expect(await f.learning.reviewsForItem(next.id), isEmpty);
      final nextHandle = coordinator.activate(next)!;
      expect(coordinator.hard, isFalse);
      expect(coordinator.current, nextHandle);
      expect(coordinator.setHard(handle, true), isFalse);
      expect(
        await coordinator.submit(
          handle,
          AnswerGrade.correct,
          reviewedAt: instant,
        ),
        isNull,
      );
    },
  );

  test(
    'actual failed write keeps card and Hard for retry; pending failure is drained without second error',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final before = await f.current();
      final registered = <Future<void>>[];
      final coordinator = RegularGradingCoordinator(
        repository: f.learning,
        onPendingWrites: registered.add,
      );
      addTearDown(coordinator.dispose);
      final handle = coordinator.activate(before)!;
      coordinator.setHard(handle, true);
      await f.db.customStatement(
        "CREATE TRIGGER fail_grade AFTER INSERT ON regular_reviews BEGIN SELECT RAISE(FAIL,'blocked'); END",
      );
      await expectLater(
        coordinator.submit(handle, AnswerGrade.correct, reviewedAt: instant),
        throwsA(isA<SqliteException>()),
      );
      await Future.wait(registered);
      expect(coordinator.current, handle);
      expect(coordinator.current!.item.cardJson, before.cardJson);
      expect(coordinator.hard, isTrue);
      expect(coordinator.error, isA<SqliteException>());
      expect(coordinator.isSubmitting, isFalse);
      expect(coordinator.accepted, isNull);
      expect((await f.current()).reviewRevision, 0);
      expect(await f.learning.reviewsForItem(before.id), isEmpty);
      expect(coordinator.completeAdvance(handle), isFalse);
      expect(coordinator.hard, isTrue);
      await f.db.customStatement('DROP TRIGGER fail_grade');
      final receipt = (await coordinator.submit(
        handle,
        AnswerGrade.correct,
        reviewedAt: instant,
      ))!;
      expect(receipt.event.rating, LearningRating.hard);
      expect(coordinator.hard, isTrue);
      expect(coordinator.error, isNull);
      expect((await f.current()).reviewRevision, 1);
      coordinator.activate(receipt.next);
      expect(coordinator.hard, isFalse);
    },
  );

  test(
    'same-ID reactivation and foreign handles reject stale callbacks without changing new modifier or recording',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final before = await f.current();
      final coordinator = RegularGradingCoordinator(repository: f.learning),
          foreign = RegularGradingCoordinator(repository: f.learning);
      addTearDown(coordinator.dispose);
      addTearDown(foreign.dispose);
      final old = coordinator.activate(before)!,
          other = foreign.activate(before)!;
      coordinator.setHard(old, true);
      final current = coordinator.activate(before)!;
      expect(coordinator.hard, isFalse);
      coordinator.setHard(current, true);
      for (final stale in [old, other]) {
        expect(coordinator.setHard(stale, false), isFalse);
        expect(
          await coordinator.submit(
            stale,
            AnswerGrade.incorrect,
            reviewedAt: instant,
          ),
          isNull,
        );
        expect(coordinator.completeAdvance(stale), isFalse);
      }
      expect(coordinator.current, current);
      expect(coordinator.hard, isTrue);
      expect(await f.learning.reviewsForItem(before.id), isEmpty);
    },
  );

  test(
    'dispose pending accepted grade suppresses notification but returns original receipt and drains before storage close',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final before = await f.current();
      final registered = <Future<void>>[];
      final coordinator = RegularGradingCoordinator(
        repository: f.learning,
        onPendingWrites: registered.add,
      );
      final handle = coordinator.activate(before)!;
      coordinator.setHard(handle, true);
      final ready = Completer<void>(), release = Completer<void>();
      final blocker = holdStorage(f, ready, release);
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await blocker;
        await coordinator.awaitPending();
      });
      await ready.future;
      var notifications = 0;
      coordinator.addListener(() => notifications++);
      final writing = coordinator.submit(
        handle,
        AnswerGrade.incorrect,
        reviewedAt: instant,
      );
      coordinator.dispose();
      final ended = notifications;
      expect(coordinator.activate(before), isNull);
      expect(coordinator.setHard(handle, true), isFalse);
      expect(
        await coordinator.submit(
          handle,
          AnswerGrade.correct,
          reviewedAt: instant,
        ),
        isNull,
      );
      final drain = coordinator.awaitPending();
      release.complete();
      await blocker;
      final receipt = (await writing)!;
      await drain;
      await Future.wait(registered);
      expect(receipt.event.itemId, before.id);
      expect(receipt.event.rating, LearningRating.again);
      expect(notifications, ended);
      expect(coordinator.current, isNull);
      expect(coordinator.accepted, isNull);
      expect((await f.current()).reviewRevision, 1);
    },
  );

  test(
    'registration failure prevents writes and retains Hard for retry; registered synchronous disposal cannot notify late',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final before = await f.current();
      final marker = StateError('Registration failed');
      var rejectRegistration = true;
      final pending = <Future<void>>[];
      final coordinator = RegularGradingCoordinator(
        repository: f.learning,
        onPendingWrites: (work) {
          if (rejectRegistration) throw marker;
          pending.add(work);
        },
      );
      final handle = coordinator.activate(before)!;
      coordinator.setHard(handle, true);
      final writing = coordinator.submit(
        handle,
        AnswerGrade.correct,
        reviewedAt: instant,
      );
      await expectLater(writing, throwsA(same(marker)));
      await coordinator.awaitPending();
      expect(coordinator.error, marker);
      expect(coordinator.hard, isTrue);
      expect(coordinator.current, handle);
      expect(coordinator.isSubmitting, isFalse);
      expect((await f.current()).cardJson, before.cardJson);
      expect((await f.current()).reviewRevision, 0);
      expect(await f.learning.reviewsForItem(before.id), isEmpty);
      rejectRegistration = false;
      final receipt = (await coordinator.submit(
        handle,
        AnswerGrade.correct,
        reviewedAt: instant,
      ))!;
      await Future.wait(pending);
      expect(receipt.next.reviewRevision, 1);
      expect(receipt.event.rating, LearningRating.hard);
      expect(coordinator.accepted, receipt);
      coordinator.dispose();
      final next = await f.current(f.other);
      late RegularGradingCoordinator disposing;
      disposing = RegularGradingCoordinator(
        repository: f.learning,
        onPendingWrites: (work) {
          pending.add(work);
          disposing.dispose();
        },
      );
      final nextHandle = disposing.activate(next)!;
      var notifications = 0;
      disposing.addListener(() => notifications++);
      final accepted = (await disposing.submit(
        nextHandle,
        AnswerGrade.correct,
        reviewedAt: instant,
      ))!;
      expect(accepted.event.itemId, next.id);
      await Future.wait(pending);
      expect(notifications, 0);
      expect(disposing.accepted, isNull);
    },
  );
}
