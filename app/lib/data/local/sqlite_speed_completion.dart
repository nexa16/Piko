part of 'sqlite_learning_repository.dart';

extension _SqliteSpeedCompletion on SqliteLearningRepository {
  Future<SpeedCompletionResult> _completeSpeedItem(
    CollectionReviewGateway scope,
    LearningItemRecord expected,
    int errors,
    DateTime completedAt,
  ) async {
    if (errors < 0 || !completedAt.isUtc) {
      throw SpeedCompletionFailure.invalidCompletion;
    }
    final fsrs.Card priorCard;
    try {
      priorCard = expected.card;
    } on FormatException {
      throw SpeedCompletionFailure.invalidCompletion;
    }
    if (priorCard.lastReview != null &&
        completedAt.isBefore(priorCard.lastReview!)) {
      throw SpeedCompletionFailure.invalidCompletion;
    }
    return database.transaction(() async {
      final owner = await (database.select(
        database.collections,
      )..where((row) => row.id.equals(scope.collectionId))).getSingleOrNull();
      if (owner == null) throw SpeedCompletionFailure.collectionNotFound;
      final row = await (database.select(
        database.learningItems,
      )..where((row) => row.id.equals(expected.id))).getSingleOrNull();
      if (row == null) throw SpeedCompletionFailure.itemNotFound;
      final entry =
          await (database.select(database.vocabularyEntries)
                ..where((entryRow) => entryRow.id.equals(row.entryId)))
              .getSingleOrNull();
      if (entry == null) throw SpeedCompletionFailure.itemNotFound;
      if (entry.collectionId != scope.collectionId ||
          row.direction != scope.direction.name ||
          expected.entryId != entry.id ||
          expected.direction != scope.direction) {
        throw SpeedCompletionFailure.outOfScope;
      }
      final current = _record(row);
      final next = LearningItemRecord(
        id: expected.id,
        entryId: expected.entryId,
        direction: expected.direction,
        formatVersion: expected.formatVersion,
        cardJson: errors == 0
            ? expected.cardJson
            : LearningCardCodec.encode(
                _scheduler.initialCard(itemId: expected.id, at: completedAt),
              ),
        generation: expected.generation + (errors == 0 ? 0 : 1),
        reviewRevision: errors == 0 ? expected.reviewRevision : 0,
        speedCompleted: true,
      );
      if (_sameItem(current, next)) {
        return SpeedCompletionResult(
          prior: expected,
          next: current,
          alreadyApplied: true,
        );
      }
      if (!_sameItem(current, expected))
        throw SpeedCompletionFailure.staleState;
      if (errors > 0) {
        // Only this item's old generations become obsolete; no regular history
        // or Collection/direction answer counter is a Speed completion event.
        await (database.delete(database.retryObligations)..where(
              (retry) =>
                  retry.itemId.equals(current.id) &
                  retry.generation.isSmallerOrEqualValue(current.generation),
            ))
            .go();
      }
      final count =
          await (database.update(
            database.learningItems,
          )..where((item) => item.id.equals(current.id))).write(
            errors == 0
                ? const LearningItemsCompanion(speedCompleted: Value(true))
                : LearningItemsCompanion(
                    cardJson: Value(next.cardJson),
                    generation: Value(next.generation),
                    reviewRevision: Value(next.reviewRevision),
                    speedCompleted: const Value(true),
                  ),
          );
      if (count != 1) throw SpeedCompletionFailure.itemNotFound;
      return SpeedCompletionResult(
        prior: expected,
        next: next,
        alreadyApplied: false,
      );
    });
  }
}
