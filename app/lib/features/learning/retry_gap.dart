/// Confirmed current-round policy; the triggering answer is excluded by applying
/// this gap to the scope ordinal after that answer's atomic increment.
int retryGapAfterError(int errors) {
  if (errors < 1) throw ArgumentError.value(errors, 'errors');
  return switch (errors) {
    1 => 20,
    2 => 10,
    3 => 5,
    4 => 3,
    _ => 1,
  };
}
