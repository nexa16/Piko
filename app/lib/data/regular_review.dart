import 'learning_item.dart';
import 'retry_obligation.dart';
import '../features/learning/learning_scheduler.dart';

/// Reinforcement is processed separately and must not enter regular review history.
enum ReviewKind { regular, reinforcement }

/// The existing atomic regular-review write boundary, independent of its storage.
abstract interface class RegularReviewWriter {
  Future<RegularReviewReceipt> review({
    required ReviewKind kind,
    required LearningItemRecord expectedPrior,
    required LearningRating rating,
    required DateTime reviewedAt,
  });
}

/// Authoritative fixed scope and complete due-set discovery for session owners.
abstract interface class ScopedReviewSource implements RegularReviewWriter {
  String get collectionId;
  LearningDirection get direction;
  Future<List<LearningItemRecord>> dueItems({required DateTime cutoff});
}

final class RegularReviewRecord {
  const RegularReviewRecord({
    required this.id,
    required this.itemId,
    required this.generation,
    required this.rating,
    required this.reviewedAt,
  });
  final String id;
  final int itemId;
  final int generation;
  final LearningRating rating;
  final DateTime reviewedAt;
}

/// In-memory correction context; no duplicated card snapshots are stored in history.
final class RegularReviewReceipt {
  const RegularReviewReceipt({
    required this.prior,
    required this.next,
    required this.event,
    this.retryPrior,
    this.retryNext,
  });
  final LearningItemRecord prior;
  final LearningItemRecord next;
  final RegularReviewRecord event;

  /// Exact same-transaction correction context; never a post-receipt queue read.
  final RetryObligation? retryPrior;
  final RetryObligation? retryNext;
}

enum RegularReviewFailure {
  itemNotFound,
  staleState,
  reinforcementNotRetained,
  collectionNotFound,
  outOfScope,
}
