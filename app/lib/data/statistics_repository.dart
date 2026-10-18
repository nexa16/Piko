import '../core/learning_day.dart';

enum StatisticsCoverage { unavailable, partial, complete, future }

final class ActivityCounts {
  const ActivityCounts({this.regular = 0, this.speed = 0});
  final int regular, speed;
}

final class StatisticsDay {
  const StatisticsDay(this.date, this.coverage, this.counts);
  final LearningDate date;
  final StatisticsCoverage coverage;

  /// Null means unavailable/future, never a fabricated zero.
  final ActivityCounts? counts;
}

final class StatisticsSnapshot {
  StatisticsSnapshot({
    required this.asOf,
    required this.startedAt,
    required this.startDate,
    required this.today,
    required Map<LearningDate, ActivityCounts> activity,
    this.averageWindowDays = 30,
    this.streakMinimumReviews = 1,
  }) : activity = Map.unmodifiable(activity) {
    if (averageWindowDays < 1 || streakMinimumReviews < 1) {
      throw ArgumentError('Statistics policy must use positive values');
    }
  }
  final DateTime asOf, startedAt;
  final LearningDate startDate, today;

  /// Immutable historical buckets; future keys stay stored but are not displayed.
  final Map<LearningDate, ActivityCounts> activity;
  final int averageWindowDays, streakMinimumReviews;
  bool get hasRecordedActivity => activity.isNotEmpty;
  ActivityCounts get todayCounts => activity[today] ?? const ActivityCounts();

  StatisticsDay day(LearningDate date) {
    if (date.compareTo(today) > 0) {
      return StatisticsDay(date, StatisticsCoverage.future, null);
    }
    final relative = date.compareTo(startDate);
    if (relative < 0 && !activity.containsKey(date)) {
      return StatisticsDay(date, StatisticsCoverage.unavailable, null);
    }
    return StatisticsDay(
      date,
      relative <= 0 ? StatisticsCoverage.partial : StatisticsCoverage.complete,
      activity[date] ?? const ActivityCounts(),
    );
  }

  double? get average {
    final availableDays = today.civilUtc.difference(DateTime.utc(1)).inDays;
    final first = today.shifted(
      -((averageWindowDays - 1).clamp(0, availableDays)),
    );
    final active = activity.entries.where(
      (entry) =>
          entry.key.compareTo(first) >= 0 &&
          entry.key.compareTo(today) <= 0 &&
          entry.value.regular > 0,
    );
    if (active.isEmpty) return null;
    return active.fold<int>(0, (sum, entry) => sum + entry.value.regular) /
        active.length;
  }

  int get streak {
    bool qualified(LearningDate date) =>
        (day(date).counts?.regular ?? 0) >= streakMinimumReviews;
    if (!qualified(today) && today == LearningDate(1, 1, 1)) return 0;
    var date = qualified(today) ? today : today.shifted(-1);
    var count = 0;
    while (qualified(date)) {
      count++;
      if (date.year == 1 && date.month == 1 && date.day == 1) break;
      date = date.shifted(-1);
    }
    return count;
  }
}

abstract interface class StatisticsRepository {
  /// Initialization and the complete read share a committed snapshot.
  Future<StatisticsSnapshot> snapshot({required DateTime at});
  Stream<void> get changes;
}
