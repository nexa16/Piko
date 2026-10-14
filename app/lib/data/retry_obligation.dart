import 'learning_item.dart';

/// One current retry round, never an attempt-event history.
final class RetryObligation {
  const RetryObligation({
    required this.id,
    required this.itemId,
    required this.generation,
    required this.revision,
    required this.originReviewId,
    required this.createdAt,
    required this.expiresAt,
    required this.errorCount,
    required this.dueOrdinal,
  });
  final String id;
  final int itemId;
  final int generation;
  final int revision;
  final String originReviewId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int errorCount;
  final int dueOrdinal;

  factory RetryObligation.fromStored({
    required String id,
    required int itemId,
    required int generation,
    required int revision,
    required String originReviewId,
    required String createdAt,
    required String expiresAt,
    required int errorCount,
    required int dueOrdinal,
  }) {
    final created = DateTime.tryParse(createdAt),
        expires = DateTime.tryParse(expiresAt);
    if (created == null || expires == null) {
      throw const FormatException('Invalid retry UTC timestamps');
    }
    final record = RetryObligation(
      id: id,
      itemId: itemId,
      generation: generation,
      revision: revision,
      originReviewId: originReviewId,
      createdAt: created,
      expiresAt: expires,
      errorCount: errorCount,
      dueOrdinal: dueOrdinal,
    );
    record.validate();
    return record;
  }

  void validate() {
    if (id.trim().isEmpty ||
        originReviewId.trim().isEmpty ||
        itemId <= 0 ||
        generation < 0 ||
        revision < 0 ||
        errorCount < 1 ||
        dueOrdinal < 0 ||
        !createdAt.isUtc ||
        !expiresAt.isUtc ||
        !expiresAt.isAfter(createdAt)) {
      throw const FormatException('Invalid retry obligation');
    }
  }

  bool sameStateAs(RetryObligation other) =>
      id == other.id &&
      itemId == other.itemId &&
      generation == other.generation &&
      revision == other.revision &&
      originReviewId == other.originReviewId &&
      errorCount == other.errorCount &&
      dueOrdinal == other.dueOrdinal &&
      createdAt == other.createdAt &&
      expiresAt == other.expiresAt;
}

enum RetryFailure {
  processingRequired,
  notFound,
  staleState,
  expired,
  notEligible,
}

/// Scope-bound monotonic admission state; revision also guards future correction.
final class ScopeAnswerState {
  const ScopeAnswerState({
    required this.collectionId,
    required this.direction,
    required this.ordinal,
    required this.revision,
  });
  final String collectionId;
  final LearningDirection direction;
  final int ordinal;
  final int revision;
  void validate() {
    if (collectionId.trim().isEmpty || ordinal < 0 || revision < 0) {
      throw const FormatException('Invalid scope answer state');
    }
  }

  bool sameStateAs(ScopeAnswerState other) =>
      collectionId == other.collectionId &&
      direction == other.direction &&
      ordinal == other.ordinal &&
      revision == other.revision;
}
