import 'learning_item.dart';
import '../features/learning/learning_scheduler.dart';

/// Reinforcement is processed separately and must not enter regular review history.
enum ReviewKind { regular, reinforcement }

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
  });
  final LearningItemRecord prior;
  final LearningItemRecord next;
  final RegularReviewRecord event;
}

enum RegularReviewFailure { itemNotFound, staleState, reinforcementNotRetained }
