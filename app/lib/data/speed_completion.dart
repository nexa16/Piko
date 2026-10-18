import 'learning_item.dart';

enum SpeedCompletionFailure {
  inactive,
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
  /// are idempotent across date/timezone changes. Speed preserves Long-term
  /// scheduling/history/retries; a new completion date can earn fresh credit.
  Future<SpeedCompletionResult> completeSpeedItem({
    required LearningItemRecord expectedPrior,
    required int errors,
    required DateTime completedAt,
  });
}
