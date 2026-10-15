import 'package:piko/core/clock.dart';

/// Deterministic clock for deadline and calendar tests, with no real waiting.
final class MutablePikoClock implements PikoClock {
  MutablePikoClock(DateTime initialTime) : _time = initialTime.toUtc();

  DateTime _time;

  @override
  DateTime now() => _time;

  void advance(Duration duration) => _time = _time.add(duration);

  /// Supports explicit device-clock changes and boundary scenarios in tests.
  void set(DateTime time) => _time = time.toUtc();
}
