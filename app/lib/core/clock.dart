/// Supplies the current instant without coupling behavior to the device clock.
abstract interface class PikoClock {
  DateTime now();
}

/// Production time source. Local calendar rules should explicitly convert the
/// returned instant to local time where they are applied.
final class SystemPikoClock implements PikoClock {
  const SystemPikoClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
