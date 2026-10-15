import 'package:flutter_test/flutter_test.dart';
import 'package:piko/core/clock.dart';

import '../support/mutable_clock.dart';

void main() {
  test('system clock supplies a UTC instant within the observation interval', () {
    final before = DateTime.now().toUtc();
    final instant = const SystemPikoClock().now();
    final after = DateTime.now().toUtc();

    expect(instant.isUtc, isTrue);
    expect(instant.isBefore(before), isFalse);
    expect(instant.isAfter(after), isFalse);
  });

  test('injected clock crosses a deadline without wall-clock waiting', () {
    final clock = MutablePikoClock(DateTime.utc(2026, 10, 13, 12));
    final deadline = clock.now().add(const Duration(seconds: 10));

    clock.advance(const Duration(seconds: 9));
    expect(clock.now().isBefore(deadline), isTrue);
    clock.advance(const Duration(seconds: 1));
    expect(clock.now(), deadline);
    clock.advance(const Duration(microseconds: 1));
    expect(clock.now().isAfter(deadline), isTrue);
  });

  test('test clock preserves instants and supports deliberate clock changes', () {
    final clock = MutablePikoClock(DateTime.parse('2026-10-13T12:00:00+02:00'));
    final PikoClock source = clock;
    expect(source.now(), DateTime.utc(2026, 10, 13, 10));
    clock.set(DateTime.utc(2026, 10, 12));
    expect(source.now(), DateTime.utc(2026, 10, 12));
  });
}
