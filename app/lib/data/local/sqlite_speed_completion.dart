part of 'sqlite_learning_repository.dart';

final _speedCorrections =
    Expando<Map<SpeedCompletionResult, _SpeedCorrection>>();
bool _speedEqual(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length &&
    a.entries.every(
      (entry) => b.containsKey(entry.key) && b[entry.key] == entry.value,
    );

final class _SpeedCorrection {
  _SpeedCorrection(
    this.scope,
    this.ordinal,
    this.markerBefore,
    this.beforeRows,
    this.afterRows,
  );
  final CollectionReviewGateway scope;
  final ScopeAnswerState ordinal;
  final bool markerBefore;
  final Map<String, List<Map<String, Object?>>> beforeRows, afterRows;
}

extension SpeedCorrectionGateway on CollectionReviewGateway {
  void retireSpeedCompletion(SpeedCompletionResult receipt) {
    _speedCorrections[_repository]?.remove(receipt);
  }
}

extension _SqliteSpeedCompletion on SqliteLearningRepository {
  Future<Map<String, List<Map<String, Object?>>>> _speedRows(
    String entryId,
  ) async {
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in ['speed_completion_receipts', 'statistics_activity']) {
      // Capture exact associated records; unrelated vocabulary credit can evolve.
      final rows = await database
          .customSelect(
            table == 'speed_completion_receipts'
                ? 'SELECT * FROM speed_completion_receipts WHERE entry_id = ? ORDER BY rowid'
                : "SELECT * FROM statistics_activity WHERE mode = 'speed' AND instr(credit_key, ?) > 0 ORDER BY rowid",
            variables: [
              Variable<String>(
                table == 'speed_completion_receipts' ? entryId : '"$entryId"',
              ),
            ],
          )
          .get();
      result[table] = rows
          .map((row) => Map<String, Object?>.from(row.data))
          .where(
            (row) => table == 'speed_completion_receipts'
                ? row['entry_id'] == entryId
                : row['mode'] == 'speed' &&
                      (row['credit_key'] as String).contains('"$entryId"'),
          )
          .toList();
    }
    return result;
  }

  Future<void> _reverseSpeedCompletion(
    CollectionReviewGateway scope,
    SpeedCompletionResult expected,
  ) => database.transaction(() async {
    final registered = _speedCorrections[this]?[expected];
    if (registered == null || !identical(registered.scope, scope)) {
      throw SpeedCompletionFailure.staleState;
    }
    final ordinal = await _scopeState(scope.collectionId, scope.direction);
    if (ordinal.ordinal != registered.ordinal.ordinal ||
        ordinal.revision != registered.ordinal.revision) {
      throw SpeedCompletionFailure.staleState;
    }
    final row = await (database.select(
      database.learningItems,
    )..where((row) => row.id.equals(expected.next.id))).getSingleOrNull();
    final entry = await (database.select(
      database.vocabularyEntries,
    )..where((row) => row.id.equals(expected.next.entryId))).getSingleOrNull();
    if (row == null ||
        entry == null ||
        !entry.active ||
        entry.collectionId != scope.collectionId ||
        !_sameItem(_record(row), expected.next)) {
      throw SpeedCompletionFailure.staleState;
    }
    final currentRows = await _speedRows(expected.next.entryId);
    for (final table in registered.afterRows.keys) {
      final current = currentRows[table]!, after = registered.afterRows[table]!;
      if (current.length != after.length ||
          [
            for (var i = 0; i < current.length; i++)
              _speedEqual(current[i], after[i]),
          ].contains(false)) {
        throw SpeedCompletionFailure.staleState;
      }
      final before = registered.beforeRows[table]!;
      for (final row in after.where(
        (row) => !before.any((old) => _speedEqual(old, row)),
      )) {
        final key = table == 'statistics_activity' ? 'credit_key' : null;
        if (key != null) {
          await database.customUpdate(
            'DELETE FROM statistics_activity WHERE credit_key = ?',
            variables: [Variable<String>(row[key] as String)],
            updates: {database.statisticsActivity},
          );
        } else {
          await database.customUpdate(
            'DELETE FROM speed_completion_receipts WHERE entry_id = ? AND direction = ? AND completed_at = ?',
            variables: [
              Variable<String>(row['entry_id'] as String),
              Variable<String>(row['direction'] as String),
              Variable<String>(row['completed_at'] as String),
            ],
            updates: {database.speedCompletionReceipts},
          );
        }
      }
    }
    await (database.update(
      database.learningItems,
    )..where((row) => row.id.equals(expected.prior.id))).write(
      LearningItemsCompanion(speedCompleted: Value(registered.markerBefore)),
    );
    _speedCorrections[this]!.remove(expected);
  });
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
      final beforeRows = await _speedRows(entry.id);
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
      final result = SpeedCompletionResult(
        prior: expected,
        next: next,
        alreadyApplied: !admitted,
      );
      final registry = _speedCorrections[this] ??= {};
      registry.removeWhere((_, receipt) => identical(receipt.scope, scope));
      registry[result] = _SpeedCorrection(
        scope,
        await _scopeState(scope.collectionId, scope.direction),
        current.speedCompleted,
        beforeRows,
        await _speedRows(entry.id),
      );
      return result;
    });
  }
}
