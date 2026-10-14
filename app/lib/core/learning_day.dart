/// Date-field conversion and local calendar construction, not elapsed-day math.
abstract interface class LearningDayCalendar {
  DateTime localDateTime(DateTime utc);

  /// Accepts calendar overflow (e.g. day 32); returns the local 04:00 as UTC.
  DateTime localFourUtc(int year, int month, int day);
}

/// Production delegates to the device's existing local DateTime rules.
final class DeviceLearningDayCalendar implements LearningDayCalendar {
  const DeviceLearningDayCalendar();
  @override
  DateTime localDateTime(DateTime utc) => utc.toLocal();
  @override
  DateTime localFourUtc(int year, int month, int day) =>
      DateTime(year, month, day, 4).toUtc();
}

/// Device-local boundary by default, persisted as an immutable UTC deadline.
abstract final class LearningDay {
  static DateTime nextBoundaryUtc(
    DateTime instant, {
    LearningDayCalendar calendar = const DeviceLearningDayCalendar(),
  }) {
    if (!instant.isUtc) {
      throw ArgumentError.value(instant, 'instant', 'Must be UTC');
    }
    final local = calendar.localDateTime(instant);
    DateTime boundaryFor(int day) {
      final boundary = calendar.localFourUtc(local.year, local.month, day);
      if (!boundary.isUtc) {
        throw StateError('Calendar must return a UTC boundary');
      }
      return boundary;
    }

    var boundary = boundaryFor(local.day);
    if (!boundary.isAfter(instant)) {
      // Calendar construction, not 24 hours: local days can change UTC offset.
      boundary = boundaryFor(local.day + 1);
    }
    if (!boundary.isAfter(instant)) {
      throw StateError('Invalid learning-day boundary');
    }
    return boundary;
  }
}
