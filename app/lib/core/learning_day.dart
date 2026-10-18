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
  /// A civil date, assigned once using the timezone at the accepted instant.
  static LearningDate dateFor(
    DateTime instant, {
    LearningDayCalendar calendar = const DeviceLearningDayCalendar(),
  }) {
    if (!instant.isUtc) {
      throw ArgumentError.value(instant, 'instant', 'Must be UTC');
    }
    final local = calendar.localDateTime(instant);
    final civil = DateTime.utc(
      local.year,
      local.month,
      local.day - (local.hour < 4 ? 1 : 0),
    );
    return LearningDate(civil.year, civil.month, civil.day);
  }

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

/// Calendar coordinates, not an instant or a duration in a device timezone.
final class LearningDate implements Comparable<LearningDate> {
  factory LearningDate(int year, int month, int day) {
    final civil = DateTime.utc(year, month, day);
    if (year < 1 ||
        year > 9999 ||
        civil.year != year ||
        civil.month != month ||
        civil.day != day) {
      throw const FormatException('Invalid learning date');
    }
    return LearningDate._(year, month, day);
  }
  const LearningDate._(this.year, this.month, this.day);
  factory LearningDate.parse(String key) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
      throw const FormatException('Invalid learning date key');
    }
    final fields = key.split('-').map(int.parse).toList();
    return LearningDate(fields[0], fields[1], fields[2]);
  }
  final int year, month, day;
  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  DateTime get civilUtc => DateTime.utc(year, month, day);
  LearningDate shifted(int days) {
    final civil = DateTime.utc(year, month, day + days);
    return LearningDate(civil.year, civil.month, civil.day);
  }

  @override
  int compareTo(LearningDate other) => key.compareTo(other.key);
  @override
  bool operator ==(Object other) => other is LearningDate && key == other.key;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() => key;
}
