import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/core/learning_day.dart';
import 'package:piko/data/statistics_repository.dart';
import 'package:piko/features/statistics/statistics_binding.dart';
import '../support/mutable_clock.dart';
import '../data/statistics_test.dart' show OffsetCalendar;

class ControlledStatistics implements StatisticsRepository {
  final events = StreamController<void>.broadcast(sync: true);
  final requests = <(DateTime, Completer<StatisticsSnapshot>)>[];
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<StatisticsSnapshot> snapshot({required DateTime at}) {
    final result = Completer<StatisticsSnapshot>();
    requests.add((at, result));
    return result.future;
  }
}

StatisticsSnapshot sample(DateTime at, {int count = 3, int yesterday = 2}) {
  final today = LearningDay.dateFor(at, calendar: OffsetCalendar());
  return StatisticsSnapshot(
    asOf: at,
    startedAt: at.subtract(const Duration(days: 40)),
    startDate: today.shifted(-40),
    today: today,
    activity: {
      if (count > 0) today: ActivityCounts(regular: count, speed: 5),
      if (yesterday > 0) today.shifted(-1): ActivityCounts(regular: yesterday),
    },
  );
}

void main() {
  testWidgets(
    'latest query wins; committed activity, errors, stale retry and disposal',
    (tester) async {
      final repo = ControlledStatistics();
      final clock = MutablePikoClock(DateTime.utc(2026, 10, 18, 12));
      final writes = <Future<void>>[];
      final binding = StatisticsBinding(
        repository: repo,
        clock: clock,
        calendar: OffsetCalendar(),
        onPendingWrites: writes.add,
      );
      expect(binding.loading, isTrue);
      expect(binding.snapshot, isNull);
      binding.refresh();
      repo.requests[1].$2.complete(sample(clock.now(), count: 7));
      await tester.pump();
      repo.requests[0].$2.complete(sample(clock.now(), count: 2));
      await tester.pump();
      expect(binding.snapshot!.todayCounts.regular, 7);
      repo.events.add(null);
      expect(binding.ready, isFalse);
      expect(binding.snapshot!.todayCounts.regular, 7);
      repo.requests.last.$2.completeError(
        StateError('synthetic query failure'),
      );
      await tester.pump();
      expect(binding.error, isNotNull);
      expect(binding.snapshot!.todayCounts.regular, 7);
      binding.refresh();
      repo.requests.last.$2.complete(sample(clock.now(), count: 8));
      await tester.pump();
      expect(binding.ready, isTrue);
      expect(binding.snapshot!.todayCounts.regular, 8);
      binding.refresh();
      binding.dispose();
      repo.requests.last.$2.complete(sample(clock.now(), count: 99));
      await tester.pump();
      expect(binding.snapshot!.todayCounts.regular, 8);
      await Future.wait(writes);
      await repo.events.close();
    },
  );

  testWidgets(
    'next local 04:00, background/resume and clock-change invalidate without shifting stored dates',
    (tester) async {
      final repo = ControlledStatistics();
      final changes = StreamController<void>.broadcast(sync: true);
      final clock = MutablePikoClock(DateTime.utc(2026, 10, 18, 3, 59, 59));
      final calendar = OffsetCalendar();
      final binding = StatisticsBinding(
        repository: repo,
        clock: clock,
        calendar: calendar,
        clockChanges: changes.stream,
      );
      repo.requests.last.$2.complete(sample(clock.now()));
      await tester.pump();
      expect(binding.snapshot!.today.key, '2026-10-17');
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(repo.requests, hasLength(2));
      expect(repo.requests.last.$1, clock.now());
      repo.requests.last.$2.complete(sample(clock.now(), count: 0));
      await tester.pump();
      expect(binding.snapshot!.today.key, '2026-10-18');
      binding.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock.advance(const Duration(days: 2));
      repo.events.add(null);
      changes.add(null);
      await tester.pump(const Duration(days: 2));
      expect(repo.requests, hasLength(2));
      binding.didChangeAppLifecycleState(AppLifecycleState.resumed);
      repo.requests.last.$2.complete(sample(clock.now()));
      await tester.pump();
      expect(binding.snapshot!.today.key, '2026-10-20');
      calendar.hours = -8;
      changes.add(null);
      final changed = StatisticsSnapshot(
        asOf: clock.now(),
        startedAt: binding.snapshot!.startedAt,
        startDate: binding.snapshot!.startDate,
        today: LearningDay.dateFor(clock.now(), calendar: calendar),
        activity: binding.snapshot!.activity,
      );
      repo.requests.last.$2.complete(changed);
      await tester.pump();
      expect(binding.snapshot!.today.key, '2026-10-19');
      expect(
        binding.snapshot!.activity[LearningDate(2026, 10, 20)]!.regular,
        3,
      );
      expect(binding.snapshot!.day(LearningDate(2026, 10, 20)).counts, isNull);
      binding.dispose();
      await changes.close();
      await repo.events.close();
    },
  );
}
