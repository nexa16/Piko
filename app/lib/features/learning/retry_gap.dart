import 'learning_parameters.dart';

/// Confirmed gap after the triggering answer's atomic scope increment.
int retryGapAfterError(int errors) {
  if (errors < 1) throw ArgumentError.value(errors, 'errors');
  return LearningParameters.retryGaps[(errors - 1).clamp(0, 4)];
}
