/// One current retry round, not an attempt-event history or spacing policy.
final class RetryObligation {
  const RetryObligation({
    required this.id,
    required this.itemId,
    required this.generation,
    required this.revision,
    required this.originReviewId,
    required this.createdAt,
    required this.expiresAt,
  });
  final String id;
  final int itemId;
  final int generation;
  final int revision;
  final String originReviewId;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory RetryObligation.fromStored({
    required String id,
    required int itemId,
    required int generation,
    required int revision,
    required String originReviewId,
    required String createdAt,
    required String expiresAt,
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
      createdAt == other.createdAt &&
      expiresAt == other.expiresAt;
}

enum RetryFailure { processingRequired, notFound, staleState, expired }
