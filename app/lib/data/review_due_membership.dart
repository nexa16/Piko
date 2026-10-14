import 'learning_item.dart';

/// Read-only due-count evidence. Presence means either the regular card is due
/// or an unexpired same-day retry obligation still owns this item.
final class ReviewDueMembership {
  const ReviewDueMembership({
    required this.entryId,
    required this.itemId,
    required this.generation,
    required this.direction,
    required this.regularDue,
    required this.eligibleRetry,
  });

  final String entryId;
  final int itemId;
  final int generation;
  final LearningDirection direction;
  final bool regularDue;
  final bool eligibleRetry;
}
