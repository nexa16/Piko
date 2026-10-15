import 'learning_item.dart';
import 'regular_review.dart';
import 'retry_obligation.dart';
import '../features/learning/learning_scheduler.dart';

/// Actual retry answers are distinct from regular FSRS/history recording.
abstract interface class RetryReviewSource implements ScopedReviewSource {
  Future<RetrySelection> initialSelection({required DateTime cutoff});
  Future<RetryState> retryState({required DateTime at});
  Future<RetryWaitResult> armBlockedWaits({
    required List<RetryObligation> expectedRounds,
    required List<LearningItemRecord> remainingRegular,
    required DateTime at,
  });
  Future<RetryAnswerReceipt> answerRetry({
    required LearningItemRecord expectedPrior,
    required RetryObligation expectedRetry,
    required LearningRating rating,
    required DateTime answeredAt,
  });
}

/// Short-lived correction context for read/selection mutations, not answer events.
final class RetryWaitMutation {
  const RetryWaitMutation({required this.prior, required this.next});
  final RetryObligation prior;
  final RetryObligation next;
}

final class RetryWaitResult {
  RetryWaitResult({
    required this.state,
    required List<RetryWaitMutation> mutations,
  }) : mutations = List.unmodifiable(mutations);
  final RetryState state;
  final List<RetryWaitMutation> mutations;
}

final class RetryState {
  RetryState({
    required this.scope,
    required List<LearningItemRecord> items,
    required List<RetryObligation> rounds,
  }) : items = List.unmodifiable(items),
       rounds = List.unmodifiable(rounds);
  final ScopeAnswerState scope;
  final List<LearningItemRecord> items;
  final List<RetryObligation> rounds;
}

final class RetrySelection {
  RetrySelection({
    required this.retries,
    required List<LearningItemRecord> regular,
  }) : regular = List.unmodifiable(regular);
  final RetryState retries;
  final List<LearningItemRecord> regular;
}

/// Exact in-memory correction context; no retry event or duplicate card is stored.
final class RetryAnswerReceipt implements LearningAnswerReceipt {
  const RetryAnswerReceipt({
    required this.prior,
    required this.retryPrior,
    required this.retryNext,
    required this.scopePrior,
    required this.scopeNext,
    required this.rating,
    required this.answeredAt,
  });
  @override
  final LearningItemRecord prior;
  @override
  LearningItemRecord get next => prior; // Reinforcement never advances FSRS.
  final RetryObligation retryPrior;
  final RetryObligation? retryNext;
  final ScopeAnswerState scopePrior;
  final ScopeAnswerState scopeNext;
  final LearningRating rating;
  final DateTime answeredAt;
}
