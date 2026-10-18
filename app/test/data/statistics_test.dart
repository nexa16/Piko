import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/core/learning_day.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/statistics_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_statistics_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'retry_expiry_test.dart' show TransitionCalendar;

class OffsetCalendar implements LearningDayCalendar {
  OffsetCalendar([this.hours = 0]);
  int hours;
  @override
  DateTime localDateTime(DateTime utc) => utc.add(Duration(hours: hours));
  @override
  DateTime localFourUtc(int year, int month, int day) =>
      DateTime.utc(year, month, day, 4).subtract(Duration(hours: hours));
}

Future<Map<String, Object?>> stored(PikoDatabase db) async => {
  for (final table in db.allTables)
    table.actualTableName:
        (await db
                .customSelect(
                  'SELECT * FROM ${table.actualTableName} ORDER BY rowid',
                )
                .get())
            .map((row) => row.data)
            .toList(),
};

void main() {
  test(
    'learning-date assignment uses local 04:00 across short/long and calendar boundaries',
    () {
      for (final (transition, before, after, year, month, day) in [
        (DateTime.utc(2026, 3, 29, 1), 1, 2, 2026, 3, 29),
        (DateTime.utc(2026, 10, 25, 1), 2, 1, 2026, 10, 25),
        (DateTime.utc(2100), 2, 2, 2024, 3, 1),
        (DateTime.utc(2100), 2, 2, 2027, 1, 1),
      ]) {
        final calendar = TransitionCalendar(
          transition,
          Duration(hours: before),
          Duration(hours: after),
        );
        final boundary = calendar.localFourUtc(year, month, day);
        final date = LearningDate(year, month, day);
        expect(
          LearningDay.dateFor(
            boundary.subtract(const Duration(microseconds: 1)),
            calendar: calendar,
          ),
          date.shifted(-1),
        );
        expect(LearningDay.dateFor(boundary, calendar: calendar), date);
        expect(
          LearningDay.dateFor(
            boundary.add(const Duration(seconds: 1)),
            calendar: calendar,
          ),
          date,
        );
      }
      expect(() => LearningDate.parse('2026-02-30'), throwsFormatException);
      expect(() => LearningDate.parse('2026-2-1'), throwsFormatException);
      expect(() => LearningDay.dateFor(DateTime(2026)), throwsArgumentError);
    },
  );
  Future<Fixture> fixture({OffsetCalendar? calendar}) async {
    final f = Fixture(
      database: PikoDatabase(
        NativeDatabase.memory(),
        clock: MutablePikoClock(instant),
        learningDayCalendar: calendar ?? OffsetCalendar(),
      ),
    );
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  test(
    'regular answers count once across grades/directions; correction and retry add nothing',
    () async {
      final f = await fixture();
      final stats = SqliteStatisticsRepository(f.db);
      await stats.snapshot(at: instant);
      await f.review(rating: LearningRating.hard);
      await f.review(reverse: true);
      final last = await f.review(rating: LearningRating.again);
      final writer = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      var snapshot = await stats.snapshot(at: instant);
      expect(snapshot.todayCounts.regular, 3);
      expect(snapshot.average, 3);
      expect(snapshot.streak, 1);
      final credits = await f.db.select(f.db.statisticsActivity).get();
      await writer.replaceAnswer(
        expected: last,
        expectedWaits: [],
        rating: LearningRating.good,
        executionAt: instant,
      );
      expect(await f.db.select(f.db.statisticsActivity).get(), credits);
      await stats.recordRegular(last.event.id, last.event.reviewedAt);
      snapshot = await stats.snapshot(at: instant);
      expect(snapshot.todayCounts.regular, 3);
      await f.review(rating: LearningRating.again);
      await f.finishRetry();
      expect((await stats.snapshot(at: instant)).todayCounts.regular, 4);
    },
  );

  test(
    'failed initialization and activity write roll back all learning and remain retryable',
    () async {
      final f = await fixture();
      final stats = SqliteStatisticsRepository(f.db);
      final before = await stored(f.db);
      await f.db.customStatement(
        "CREATE TRIGGER stats_init_failure BEFORE INSERT ON statistics_origins BEGIN SELECT RAISE(FAIL,'synthetic'); END",
      );
      await expectLater(f.review(), throwsA(isA<sqlite.SqliteException>()));
      expect(await stored(f.db), before);
      await expectLater(
        stats.snapshot(at: instant),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await f.db.customStatement('DROP TRIGGER stats_init_failure');
      await stats.snapshot(at: instant);
      final initialized = await stored(f.db);
      await f.db.customStatement(
        "CREATE TRIGGER stats_credit_failure BEFORE INSERT ON statistics_activity BEGIN SELECT RAISE(FAIL,'synthetic'); END",
      );
      final expected = await f.current();
      await expectLater(
        f.review(rating: LearningRating.again),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await stored(f.db), initialized);
      await f.db.customStatement('DROP TRIGGER stats_credit_failure');
      final receipt = await f.review();
      await expectLater(
        f.learning.review(
          kind: ReviewKind.regular,
          expectedPrior: expected,
          rating: LearningRating.good,
          reviewedAt: instant,
        ),
        throwsA(RegularReviewFailure.staleState),
      );
      expect((await stats.snapshot(at: instant)).todayCounts.regular, 1);
      expect(
        (await f.learning.reviewsForItem(expected.id)).single.id,
        receipt.event.id,
      );
    },
  );

  test(
    'Speed receipts freeze date across timezone changes and marker does not suppress next-day credit',
    () async {
      final calendar = OffsetCalendar();
      final f = await fixture(calendar: calendar);
      final stats = SqliteStatisticsRepository(f.db);
      final writer = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final expected = await f.current();
      final results = await Future.wait(
        List.generate(
          2,
          (_) => writer.completeSpeedItem(
            expectedPrior: expected,
            errors: 2,
            completedAt: instant,
          ),
        ),
      );
      expect(results.where((result) => result.alreadyApplied), hasLength(1));
      expect((await stats.snapshot(at: instant)).todayCounts.speed, 1);
      calendar.hours = -8;
      final retry = await writer.completeSpeedItem(
        expectedPrior: expected,
        errors: 2,
        completedAt: instant,
      );
      expect(retry.alreadyApplied, isTrue);
      var snapshot = await stats.snapshot(at: instant);
      expect(snapshot.today.key, '2026-10-13');
      expect(snapshot.todayCounts.speed, 0);
      expect(
        snapshot.day(LearningDate(2026, 10, 14)).coverage,
        StatisticsCoverage.future,
      );
      expect(
        snapshot.day(snapshot.today).coverage,
        StatisticsCoverage.unavailable,
      );
      await writer.completeSpeedItem(
        expectedPrior: await f.current(),
        errors: 0,
        completedAt: instant.add(const Duration(seconds: 1)),
      );
      snapshot = await stats.snapshot(at: instant);
      expect(snapshot.todayCounts.speed, 1);
      expect(snapshot.day(snapshot.today).coverage, StatisticsCoverage.partial);
      expect(
        snapshot.day(LearningDate(2026, 10, 12)).coverage,
        StatisticsCoverage.unavailable,
      );
      calendar.hours = 0;
      await writer.completeSpeedItem(
        expectedPrior: await f.current(),
        errors: 4,
        completedAt: instant.add(const Duration(seconds: 2)),
      );
      expect((await stats.snapshot(at: instant)).todayCounts.speed, 1);
      final tomorrow = instant.add(const Duration(days: 1));
      await writer.completeSpeedItem(
        expectedPrior: await f.current(),
        errors: 4,
        completedAt: tomorrow,
      );
      snapshot = await stats.snapshot(at: tomorrow);
      expect(snapshot.todayCounts.speed, 1);
      expect(snapshot.todayCounts.regular, 0);
      expect(snapshot.streak, 0);
      expect(snapshot.average, isNull);
      final reverse = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.nativeToTarget,
      );
      await reverse.completeSpeedItem(
        expectedPrior: await f.current(f.entry, true),
        errors: 1,
        completedAt: tomorrow,
      );
      expect((await stats.snapshot(at: tomorrow)).todayCounts.speed, 2);
    },
  );

  test(
    'Speed transaction rolls back receipt and credit if marker write fails',
    () async {
      final f = await fixture();
      final before = await stored(f.db);
      final writer = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final expected = await f.current();
      await f.db.customStatement(
        "CREATE TRIGGER speed_failure BEFORE UPDATE ON learning_items BEGIN SELECT RAISE(FAIL,'synthetic'); END",
      );
      await expectLater(
        writer.completeSpeedItem(
          expectedPrior: expected,
          errors: 1,
          completedAt: instant,
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await stored(f.db), before);
      await f.db.customStatement('DROP TRIGGER speed_failure');
      await writer.completeSpeedItem(
        expectedPrior: expected,
        errors: 1,
        completedAt: instant,
      );
      expect(
        (await SqliteStatisticsRepository(
          f.db,
        ).snapshot(at: instant)).todayCounts.speed,
        1,
      );
    },
  );

  test(
    'deletion, Undo, import and Collection deletion never erase or fabricate activity',
    () async {
      final f = await fixture();
      final stats = SqliteStatisticsRepository(f.db);
      await f.review();
      final writer = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      await writer.completeSpeedItem(
        expectedPrior: await f.current(),
        errors: 2,
        completedAt: instant,
      );
      final credits = await f.db.select(f.db.statisticsActivity).get();
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      expect((await stats.snapshot(at: instant)).todayCounts.regular, 1);
      await deletion.restore(receipt);
      final json = SqliteVocabularyJsonService(f.db);
      final exported = await json.exportCollection(f.owner.id);
      await json.applyImport(
        await json.analyzeImport(collectionId: f.owner.id, json: exported),
      );
      expect(await f.db.select(f.db.statisticsActivity).get(), credits);
      await f.collections.delete(f.owner.id);
      expect(await f.db.select(f.db.statisticsActivity).get(), credits);
      expect((await stats.snapshot(at: instant)).hasRecordedActivity, isTrue);
      final replacement = await f.vocabulary.create(
        collectionId: f.kept.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
      );
      final otherWriter = await f.learning.forCollection(
        collectionId: f.kept.id,
        direction: LearningDirection.targetToNative,
      );
      await otherWriter.completeSpeedItem(
        expectedPrior: await f.current(replacement),
        errors: 0,
        completedAt: instant,
      );
      expect((await stats.snapshot(at: instant)).todayCounts.speed, 2);
    },
  );

  test(
    'coverage/averages/streaks preserve unavailable, partial, idle and future dates',
    () {
      final today = LearningDate(2026, 4, 10);
      final counts = {
        for (var i = 0; i < 45; i++)
          today.shifted(-i): const ActivityCounts(regular: 2),
      };
      StatisticsSnapshot snapshot(
        Map<LearningDate, ActivityCounts> activity, {
        int minimum = 1,
      }) => StatisticsSnapshot(
        asOf: DateTime.utc(2026, 4, 10, 12),
        startedAt: DateTime.utc(2026, 2, 25, 12),
        startDate: today.shifted(-44),
        today: today,
        activity: activity,
        streakMinimumReviews: minimum,
      );
      expect(snapshot(counts).streak, 45);
      expect(snapshot(counts).average, 2);
      counts[today.shifted(-30)] = const ActivityCounts(regular: 100);
      expect(snapshot(counts).average, 2);
      counts.remove(today);
      expect(snapshot(counts).streak, 44);
      expect(snapshot(counts).day(today).coverage, StatisticsCoverage.complete);
      expect(snapshot(counts).day(today).counts!.regular, 0);
      expect(
        snapshot(counts).day(today.shifted(-44)).coverage,
        StatisticsCoverage.partial,
      );
      expect(snapshot(counts).day(today.shifted(-45)).counts, isNull);
      counts[today.shifted(1)] = const ActivityCounts(regular: 500);
      expect(
        snapshot(counts).day(today.shifted(1)).coverage,
        StatisticsCoverage.future,
      );
      expect(snapshot(counts).average, 2);
      counts.remove(today.shifted(-1));
      expect(snapshot(counts).streak, 0);
      expect(snapshot(counts, minimum: 3).streak, 0);
      expect(snapshot({}).average, isNull);
    },
  );

  test(
    'populated frozen schema16 upgrades and reopens without reconstructing historical activity',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-statistics-migration-',
      );
      final file = File('${directory.path}/old.sqlite');
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute(File('test/support/schema16.sql').readAsStringSync());
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((row) => row['name'] as String)
          .toList();
      final before = {
        for (final table in tables)
          table: raw
              .select('SELECT * FROM $table ORDER BY rowid')
              .map(Map<String, Object?>.from)
              .toList(),
      };
      raw.close();
      final clock = MutablePikoClock(DateTime.utc(2026, 10, 20, 12));
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: clock,
        learningDayCalendar: OffsetCalendar(),
      );
      try {
        var stats = SqliteStatisticsRepository(db);
        final first = await stats.snapshot(at: clock.now());
        expect(first.startedAt, clock.now());
        expect(first.startDate.key, '2026-10-20');
        expect(first.todayCounts.regular, 0);
        expect(first.todayCounts.speed, 0);
        expect(first.average, isNull);
        expect(
          first.day(LearningDate(2026, 10, 18)).coverage,
          StatisticsCoverage.unavailable,
        );
        for (final table in tables) {
          expect(
            (await stored(db))[table],
            before[table],
            reason: '$table remains exact',
          );
        }
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await db.close();
        clock.advance(const Duration(days: 2));
        db = PikoDatabase(
          NativeDatabase(file),
          clock: clock,
          learningDayCalendar: OffsetCalendar(),
        );
        stats = SqliteStatisticsRepository(db);
        final reopened = await stats.snapshot(at: clock.now());
        expect(reopened.startedAt, first.startedAt);
        expect(
          reopened.day(LearningDate(2026, 10, 20)).coverage,
          StatisticsCoverage.partial,
        );
        expect(
          reopened.day(LearningDate(2026, 10, 21)).coverage,
          StatisticsCoverage.complete,
        );
        expect(reopened.day(LearningDate(2026, 10, 21)).counts!.regular, 0);
        expect(await db.select(db.statisticsOrigins).get(), hasLength(1));
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'failed schema16 migration leaves populated tables and version exact, then upgrades safely',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-statistics-rollback-',
      );
      final file = File('${directory.path}/old.sqlite');
      var raw = sqlite.sqlite3.open(file.path);
      raw.execute(File('test/support/schema16.sql').readAsStringSync());
      // Fail only at the final new index, after all three CREATE TABLE statements.
      raw.execute('CREATE TABLE statistics_activity_date (sentinel TEXT)');
      raw.execute("INSERT INTO statistics_activity_date VALUES ('preserve')");
      final beforeSchema = raw
          .select('SELECT * FROM sqlite_master ORDER BY name')
          .map(Map<String, Object?>.from)
          .toList();
      final names = raw
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((row) => row['name'] as String)
          .toList();
      final before = {
        for (final name in names)
          name: raw
              .select('SELECT * FROM $name ORDER BY rowid')
              .map(Map<String, Object?>.from)
              .toList(),
      };
      raw.close();
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(instant),
        learningDayCalendar: OffsetCalendar(),
      );
      try {
        await expectLater(
          SqliteStatisticsRepository(db).snapshot(at: instant),
          throwsA(isA<sqlite.SqliteException>()),
        );
        await db.close();
        raw = sqlite.sqlite3.open(file.path);
        expect(raw.userVersion, 16);
        expect(
          raw
              .select('SELECT * FROM sqlite_master ORDER BY name')
              .map(Map<String, Object?>.from)
              .toList(),
          beforeSchema,
        );
        for (final name in names) {
          expect(
            raw
                .select('SELECT * FROM $name ORDER BY rowid')
                .map(Map<String, Object?>.from)
                .toList(),
            before[name],
          );
        }
        raw.execute('DROP TABLE statistics_activity_date');
        raw.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
          learningDayCalendar: OffsetCalendar(),
        );
        expect(
          (await SqliteStatisticsRepository(
            db,
          ).snapshot(at: instant)).hasRecordedActivity,
          isFalse,
        );
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          18,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'committed 03:59/04:00 activity, credits and frozen Speed replay survive file reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-statistics-boundary-',
      );
      final file = File('${directory.path}/activity.sqlite');
      final clock = MutablePikoClock(DateTime.utc(2026, 12, 31, 23, 59, 59));
      final calendar = OffsetCalendar(4);
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: clock,
        learningDayCalendar: calendar,
      );
      try {
        final f = Fixture(database: db);
        await f.initialize();
        final stats = SqliteStatisticsRepository(db);
        final origin = await stats.snapshot(at: clock.now());
        await f.review(at: clock.now());
        final expected = await f.current();
        final source = await f.learning.forCollection(
          collectionId: f.owner.id,
          direction: expected.direction,
        );
        final beforeBoundary = clock.now();
        await source.completeSpeedItem(
          expectedPrior: expected,
          errors: 2,
          completedAt: beforeBoundary,
        );
        clock.advance(const Duration(seconds: 1));
        await f.review(reverse: true, at: clock.now());
        await source.completeSpeedItem(
          expectedPrior: await f.current(),
          errors: 0,
          completedAt: clock.now(),
        );
        final saved = await stored(db);
        await db.close();
        calendar.hours = -8;
        db = PikoDatabase(
          NativeDatabase(file),
          clock: clock,
          learningDayCalendar: calendar,
        );
        final resumed = SqliteStatisticsRepository(db);
        final replay = await resumed.recordSpeed(
          expected.entryId,
          expected.direction,
          beforeBoundary,
        );
        expect(replay, isFalse);
        expect(await stored(db), saved);
        final snapshot = await resumed.snapshot(at: clock.now());
        expect(snapshot.startedAt, origin.startedAt);
        expect(snapshot.today.key, '2026-12-31');
        expect(snapshot.todayCounts.regular, 1);
        expect(snapshot.todayCounts.speed, 1);
        expect(snapshot.activity[LearningDate(2027, 1, 1)]!.regular, 1);
        expect(snapshot.activity[LearningDate(2027, 1, 1)]!.speed, 1);
        expect(snapshot.day(LearningDate(2027, 1, 1)).counts, isNull);
        expect(snapshot.average, 1);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
