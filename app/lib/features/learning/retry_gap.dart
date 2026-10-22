/// Confirmed current-round policy; the triggering answer is excluded by applying
/// this gap to the scope ordinal after that answer's atomic increment.
import 'learning_parameters.dart';

int retryGapAfterError(int errors) {
  if (errors < 1) throw ArgumentError.value(errors, 'errors');
  return LearningParameters.retryGaps[(errors - 1).clamp(0, 4)];
}
