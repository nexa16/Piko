/// Device-local calendar boundary, persisted as an immutable UTC retry deadline.
abstract final class LearningDay {
  static DateTime nextBoundaryUtc(DateTime instant) {
    if (!instant.isUtc) {
      throw ArgumentError.value(instant, 'instant', 'Must be UTC');
    }
    final local = instant.toLocal();
    var boundary = DateTime(local.year, local.month, local.day, 4);
    if (!boundary.isAfter(local)) {
      // Calendar construction, not 24 hours: local days can change UTC offset.
      boundary = DateTime(local.year, local.month, local.day + 1, 4);
    }
    final utc = boundary.toUtc();
    if (!utc.isAfter(instant)) {
      throw StateError('Invalid learning-day boundary');
    }
    return utc;
  }
}
