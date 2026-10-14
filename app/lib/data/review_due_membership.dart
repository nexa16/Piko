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

/// One passive due-count read plus the first instant at which that read can
/// change solely because time passes.
///
/// The boundary is advisory invalidation metadata. It does not expire retry
/// state or otherwise mutate learning data.
final class ReviewDueMembershipSnapshot extends Iterable<ReviewDueMembership> {
  ReviewDueMembershipSnapshot({
    required Iterable<ReviewDueMembership> memberships,
    required this.nextChangeAt,
  }) : memberships = List.unmodifiable(memberships) {
    final boundary = nextChangeAt;
    if (boundary != null && !boundary.isUtc) {
      throw ArgumentError.value(boundary, 'nextChangeAt', 'Must be UTC');
    }
  }

  final List<ReviewDueMembership> memberships;
  final DateTime? nextChangeAt;

  @override
  Iterator<ReviewDueMembership> get iterator => memberships.iterator;
}
