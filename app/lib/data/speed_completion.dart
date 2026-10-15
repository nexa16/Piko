import 'learning_item.dart';

enum SpeedCompletionFailure {
  invalidCompletion,
  collectionNotFound,
  itemNotFound,
  outOfScope,
  staleState,
}

final class SpeedCompletionResult {
  const SpeedCompletionResult({
    required this.prior,
    required this.next,
    required this.alreadyApplied,
  });
  final LearningItemRecord prior;
  final LearningItemRecord next;
  final bool alreadyApplied;
}

/// One fixed Collection/direction boundary. No incomplete attempt is persisted.
abstract interface class SpeedCompletionWriter {
  /// Capture [expectedPrior] at launch and retain one UTC [completedAt] for this
  /// item's accepted completion, including retries. Identical committed requests
  /// are idempotent; a later different studied state is never reset again.
  Future<SpeedCompletionResult> completeSpeedItem({
    required LearningItemRecord expectedPrior,
    required int errors,
    required DateTime completedAt,
  });
}
