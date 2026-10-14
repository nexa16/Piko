import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/core/learning_day.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/retry_obligation.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, rows;
import 'retry_obligations_test.dart' show snapshot;

/// Synthetic calendar policy, not proof of the host/device timezone database.
/// UTC-coded wall fields let tests model an offset transition without changing
/// settings, using a timezone package or claiming these dates are platform data.
final class TransitionCalendar implements LearningDayCalendar {
  const TransitionCalendar(this.transitionUtc, this.before, this.after);
  final DateTime transitionUtc;
  final Duration before, after;
  Duration offsetAt(DateTime utc) =>
      utc.isBefore(transitionUtc) ? before : after;
  @override
  DateTime localDateTime(DateTime utc) => utc.add(offsetAt(utc));
  @override
  DateTime localFourUtc(int year, int month, int day) {
    final wall = DateTime.utc(year, month, day, 4);
    for (final offset in [before, after]) {
      final candidate = wall.subtract(offset);
      if (offsetAt(candidate) == offset) return candidate;
    }
    throw StateError('Synthetic 04:00 is not defined');
  }
}

void main() {
  for (final (season, transition, beforeHours, afterHours, start) in [
    (
      'spring',
      DateTime.utc(2026, 3, 29, 1),
      1,
      2,
      DateTime.utc(2026, 3, 28, 3),
    ),
    (
      'fall',
      DateTime.utc(2026, 10, 25, 1),
      2,
      1,
      DateTime.utc(2026, 10, 24, 2),
    ),
  ]) {
    test(
      'injected $season policy keeps local04 calendar boundary across ${24 + beforeHours - afterHours}h day, not fixed24h',
      () {
        final calendar = TransitionCalendar(
          transition,
          Duration(hours: beforeHours),
          Duration(hours: afterHours),
        );
        final end = LearningDay.nextBoundaryUtc(start, calendar: calendar);
        expect(
          end.difference(start),
          Duration(hours: 24 + beforeHours - afterHours),
        );
        expect(calendar.localDateTime(start).hour, 4);
        expect(calendar.localDateTime(end).hour, 4);
        expect(
          calendar.localDateTime(end).day,
          calendar.localDateTime(start).day + 1,
        );
        expect(
          LearningDay.nextBoundaryUtc(
            start.subtract(const Duration(microseconds: 1)),
            calendar: calendar,
          ),
          start,
        );
        expect(
          LearningDay.nextBoundaryUtc(
            start.add(const Duration(microseconds: 1)),
            calendar: calendar,
          ),
          end,
        );
        expect(
          LearningDay.nextBoundaryUtc(
            end.subtract(const Duration(microseconds: 1)),
            calendar: calendar,
          ),
          end,
        );
        final following = LearningDay.nextBoundaryUtc(end, calendar: calendar);
        expect(following.difference(end), const Duration(hours: 24));
        expect(
          LearningDay.nextBoundaryUtc(
            end.add(const Duration(microseconds: 1)),
            calendar: calendar,
          ),
          following,
        );
      },
    );
  }

  test(
    'normal-day policy handles strict before/exact/after04 and calendar month/year overflow',
    () {
      final calendar = TransitionCalendar(
        DateTime.utc(2100),
        const Duration(hours: 2),
        const Duration(hours: 2),
      );
      for (final wall in [
        DateTime.utc(2026, 1, 31, 4),
        DateTime.utc(2026, 12, 31, 4),
      ]) {
        final at = wall.subtract(const Duration(hours: 2));
        final nextWall = DateTime.utc(wall.year, wall.month, wall.day + 1, 4);
        final next = nextWall.subtract(const Duration(hours: 2));
        expect(
          LearningDay.nextBoundaryUtc(
            at.subtract(const Duration(microseconds: 1)),
            calendar: calendar,
          ),
          at,
        );
        expect(LearningDay.nextBoundaryUtc(at, calendar: calendar), next);
        expect(
          LearningDay.nextBoundaryUtc(
            at.add(const Duration(microseconds: 1)),
            calendar: calendar,
          ),
          next,
        );
        expect(calendar.localDateTime(next), nextWall);
      }
      final local = DateTime(2026, 12, 31, 4);
      expect(
        LearningDay.nextBoundaryUtc(local.toUtc()),
        DateTime(2027, 1, 1, 4).toUtc(),
      );
    },
  );

  for (final extraDue in [false, true]) {
    test(
      'file reopen: before original04 blocks, exact04 expires to actual ${extraDue ? "nonempty" : "empty"} regular due set with no success/FSRS/history change',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'piko-retry-expiry-',
        );
        final file = File('${directory.path}/expiry.sqlite');
        final created = DateTime(2026, 10, 14, 3).toUtc();
        var db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(created),
        );
        try {
          final f = Fixture(database: db);
          await f.initialize();
          final retry = (await f.review(
            rating: LearningRating.again,
            at: created,
          )).retryNext!;
          expect(retry.expiresAt, DateTime(2026, 10, 14, 4).toUtc());
          if (extraDue) {
            await f.vocabulary.create(
              collectionId: f.owner.id,
              targetText: 'Other due',
              nativeText: 'Weiteres fälliges Wort',
            );
          }
          final before = await snapshot(f);
          await db.close();
          final justBefore = retry.expiresAt.subtract(
            const Duration(microseconds: 1),
          );
          db = PikoDatabase(
            NativeDatabase(file),
            clock: MutablePikoClock(justBefore),
          );
          var repository = SqliteLearningRepository(db);
          var gateway = await repository.forCollection(
            collectionId: f.owner.id,
            direction: LearningDirection.targetToNative,
          );
          final pending = (await gateway.pendingRetries(at: justBefore)).single;
          expect(
            pending.sameStateAs(retry),
            isTrue,
          ); // Original stored deadline, not reopening time.
          await expectLater(
            gateway.dueItems(cutoff: justBefore),
            throwsA(RetryFailure.processingRequired),
          );
          expect(await snapshot(Fixture(database: db)), before);
          final storedItems = await gateway.items();
          final expected = storedItems
              .where((item) => !item.card.due.isAfter(retry.expiresAt))
              .map((item) => item.id)
              .toList();
          expect(expected.isNotEmpty, extraDue);
          final due = await gateway.dueItems(cutoff: retry.expiresAt);
          expect(due.map((item) => item.id).toList(), expected);
          expect(await rows(db, 'retry_obligations'), isEmpty);
          final expired = await snapshot(Fixture(database: db));
          for (var index = 0; index < before.length; index++) {
            if (index != 4) expect(expired[index], before[index]);
          }
          final history = await repository.reviewsForItem(retry.itemId);
          expect(history, hasLength(1));
          expect(history.single.rating, LearningRating.again);
          expect(history.single.id, retry.originReviewId);
          expect(await gateway.pendingRetries(at: created), isEmpty);
          expect(await snapshot(Fixture(database: db)), expired);
          await db.close();
          db = PikoDatabase(
            NativeDatabase(file),
            clock: MutablePikoClock(created),
          );
          repository = SqliteLearningRepository(db);
          gateway = await repository.forCollection(
            collectionId: f.owner.id,
            direction: LearningDirection.targetToNative,
          );
          expect(await gateway.pendingRetries(at: created), isEmpty);
          expect(await snapshot(Fixture(database: db)), expired);
        } finally {
          await db.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
