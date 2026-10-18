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
    try {
      expected.card;
    } on FormatException {
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
      if (!entry.active) throw SpeedCompletionFailure.inactive;
      if (entry.collectionId != scope.collectionId ||
          row.direction != scope.direction.name ||
          expected.entryId != entry.id ||
          expected.direction != scope.direction ||
          scope.entryIds != null && !scope.entryIds!.contains(entry.id)) {
        throw SpeedCompletionFailure.outOfScope;
      }
      final current = _record(row);
      final next = LearningItemRecord(
        id: expected.id,
        entryId: expected.entryId,
        direction: expected.direction,
        formatVersion: expected.formatVersion,
        cardJson: expected.cardJson,
        generation: expected.generation,
        reviewRevision: expected.reviewRevision,
        speedCompleted: true,
      );
      if (!_sameItem(current, expected) && !_sameItem(current, next)) {
        throw SpeedCompletionFailure.staleState;
      }
      // A previous completed marker never suppresses a new day's credit.
      // Speed leaves both directions' FSRS, history, retries and ordinals exact.
      final admitted = await SqliteStatisticsRepository(
        database,
      ).recordSpeed(entry.id, scope.direction, completedAt);
      if (!current.speedCompleted) {
        final count =
            await (database.update(
              database.learningItems,
            )..where((item) => item.id.equals(current.id))).write(
              const LearningItemsCompanion(speedCompleted: Value(true)),
            );
        if (count != 1) throw SpeedCompletionFailure.itemNotFound;
      }
      return SpeedCompletionResult(
        prior: expected,
        next: next,
        alreadyApplied: !admitted,
      );
    });
  }
}
