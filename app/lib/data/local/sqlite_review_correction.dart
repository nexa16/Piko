part of 'sqlite_learning_repository.dart';

extension _SqliteReviewCorrection on SqliteLearningRepository {
  Future<LearningAnswerReceipt> _replaceAnswer(
    CollectionReviewGateway scope,
    LearningAnswerReceipt expected,
    List<RetryWaitMutation> waits,
    LearningRating rating,
    DateTime now,
  ) async {
    expected.prior.card;
    expected.next.card;
    final ScopeAnswerState? issuedScope;
    final RetryObligation? issuedRound;
    final DateTime originalAt;
    switch (expected) {
      case RegularReviewReceipt():
        issuedScope = expected.scopeNext;
        issuedRound = expected.retryNext;
        originalAt = expected.event.reviewedAt;
        if (expected.event.itemId != expected.prior.id ||
            expected.event.generation != expected.prior.generation ||
            _scheduler
                    .review(
                      expected.prior,
                      rating: expected.event.rating,
                      reviewedAt: originalAt,
                    )
                    .next
                    .cardJson !=
                expected.next.cardJson) {
          throw ReviewCorrectionFailure.invalidReceipt;
        }
      case RetryAnswerReceipt():
        issuedScope = expected.scopeNext;
        issuedRound = expected.retryNext;
        originalAt = expected.answeredAt;
        expected.retryPrior.validate();
        if (!_sameItem(expected.prior, expected.next) ||
            expected.retryPrior.itemId != expected.prior.id ||
            expected.retryPrior.generation != expected.prior.generation) {
          throw ReviewCorrectionFailure.invalidReceipt;
        }
      default:
        throw ReviewCorrectionFailure.invalidReceipt;
    }
    if (!now.isUtc || !originalAt.isUtc || now.isBefore(originalAt)) {
      throw ArgumentError.value(
        now,
        'executionAt',
        'Must be UTC and not before original answer',
      );
    }
    if (issuedScope == null ||
        issuedScope.collectionId != scope.collectionId ||
        issuedScope.direction != scope.direction ||
        expected.prior.id != expected.next.id ||
        expected.prior.entryId != expected.next.entryId ||
        expected.prior.direction != expected.next.direction ||
        expected.prior.generation != expected.next.generation ||
        expected.prior.formatVersion != expected.next.formatVersion) {
      throw ReviewCorrectionFailure.invalidReceipt;
    }
    issuedScope.validate();
    issuedRound?.validate();
    return database.transaction(() async {
      final items = await _scopedItems(scope);
      final current = items
          .where((item) => item.id == expected.next.id)
          .firstOrNull;
      if (current == null) throw RegularReviewFailure.outOfScope;
      if (!_sameItem(current, expected.next)) {
        throw ReviewCorrectionFailure.staleState;
      }
      final actualScope = await _scopeState(
        scope.collectionId,
        scope.direction,
      );
      if (!actualScope.sameStateAs(issuedScope!)) {
        throw ReviewCorrectionFailure.staleState;
      }

      // Selection may have armed waits after the accepted answer. Verify their
      // exact chain instead of silently overwriting a later mutation or failing
      // on the ordinary one-item wait path. Unrelated waits remain unchanged.
      final postWait = <String, RetryObligation>{};
      for (final mutation in waits) {
        mutation.prior.validate();
        mutation.next.validate();
        if (mutation.prior.id != mutation.next.id ||
            mutation.next.revision != mutation.prior.revision + 1 ||
            mutation.prior.waitEligibleAt != null ||
            mutation.next.waitEligibleAt == null ||
            mutation.next.itemId != mutation.prior.itemId ||
            mutation.next.generation != mutation.prior.generation ||
            mutation.next.originReviewId != mutation.prior.originReviewId ||
            mutation.next.createdAt != mutation.prior.createdAt ||
            mutation.next.expiresAt != mutation.prior.expiresAt ||
            mutation.next.errorCount != mutation.prior.errorCount ||
            mutation.next.dueOrdinal != mutation.prior.dueOrdinal ||
            postWait.containsKey(mutation.prior.id) &&
                !postWait[mutation.prior.id]!.sameStateAs(mutation.prior)) {
          throw ReviewCorrectionFailure.invalidReceipt;
        }
        postWait[mutation.next.id] = mutation.next;
      }
      if (issuedRound != null && postWait.containsKey(issuedRound.id)) {
        final capturedRound = issuedRound;
        final first = waits.firstWhere(
          (change) => change.prior.id == capturedRound.id,
        );
        if (!first.prior.sameStateAs(capturedRound)) {
          throw ReviewCorrectionFailure.invalidReceipt;
        }
      }
      for (final round in postWait.values) {
        final item = items
            .where(
              (item) =>
                  item.id == round.itemId &&
                  item.generation == round.generation,
            )
            .firstOrNull;
        if (item == null) throw RegularReviewFailure.outOfScope;
        final actual = await _retryFor(item);
        if (actual == null
            ? now.isBefore(round.expiresAt)
            : !actual.sameStateAs(round)) {
          throw ReviewCorrectionFailure.staleState;
        }
      }
      final roundExpected = issuedRound == null
          ? null
          : postWait[issuedRound.id] ?? issuedRound;
      final actualRound = await _retryFor(current);
      if (roundExpected == null
          ? actualRound != null
          : actualRound == null
          ? now.isBefore(roundExpected.expiresAt)
          : !actualRound.sameStateAs(roundExpected)) {
        throw ReviewCorrectionFailure.staleState;
      }

      final nextScope = ScopeAnswerState(
        collectionId: scope.collectionId,
        direction: scope.direction,
        ordinal: actualScope.ordinal,
        revision: actualScope.revision + 1,
      );
      await (database.update(database.scopeAnswerOrdinals)..where(
            (row) =>
                row.collectionId.equals(scope.collectionId) &
                row.direction.equals(scope.direction.name),
          ))
          .write(
            ScopeAnswerOrdinalsCompanion(revision: Value(nextScope.revision)),
          );

      final LearningItemRecord nextItem;
      final RetryObligation? replacement;
      if (expected is RegularReviewReceipt) {
        final event = expected.event;
        final row = await (database.select(
          database.regularReviews,
        )..where((row) => row.id.equals(event.id))).getSingleOrNull();
        if (row == null ||
            row.itemId != event.itemId ||
            row.generation != event.generation ||
            row.rating != event.rating.name ||
            DateTime.tryParse(row.reviewedAt) != originalAt) {
          throw ReviewCorrectionFailure.staleState;
        }
        final calculated = _scheduler.review(
          expected.prior,
          rating: rating,
          reviewedAt: originalAt,
        );
        nextItem = LearningItemRecord(
          id: current.id,
          entryId: current.entryId,
          direction: current.direction,
          cardJson: calculated.next.cardJson,
          formatVersion: current.formatVersion,
          generation: current.generation,
          reviewRevision: current.reviewRevision + 1,
        );
        // Same UUID/row/time; there is still exactly one corresponding review.
        await (database.update(database.regularReviews)
              ..where((row) => row.id.equals(event.id)))
            .write(RegularReviewsCompanion(rating: Value(rating.name)));
        await (database.update(
          database.learningItems,
        )..where((row) => row.id.equals(current.id))).write(
          LearningItemsCompanion(
            cardJson: Value(nextItem.cardJson),
            reviewRevision: Value(nextItem.reviewRevision),
          ),
        );
        final deadline =
            issuedRound?.expiresAt ?? LearningDay.nextBoundaryUtc(originalAt);
        replacement = rating == LearningRating.again && now.isBefore(deadline)
            ? RetryObligation(
                id: issuedRound?.id ?? const Uuid().v4(),
                itemId: current.id,
                generation: current.generation,
                revision: (roundExpected?.revision ?? -1) + 1,
                originReviewId: event.id,
                createdAt: originalAt,
                expiresAt: deadline,
                errorCount: 1,
                dueOrdinal: nextScope.ordinal + retryGapAfterError(1),
                waitEligibleAt: expected.event.rating == LearningRating.again
                    ? roundExpected?.waitEligibleAt
                    : null,
              )
            : null;
      } else {
        final retry = expected as RetryAnswerReceipt;
        nextItem = current;
        final before = retry.retryPrior;
        // Correct the one original retry answer from its exact prior round,
        // keeping UUID/origin/time and never recreating an expired learning day.
        replacement =
            rating == LearningRating.again && now.isBefore(before.expiresAt)
            ? RetryObligation(
                id: before.id,
                itemId: before.itemId,
                generation: before.generation,
                revision: (roundExpected?.revision ?? before.revision) + 1,
                originReviewId: before.originReviewId,
                createdAt: before.createdAt,
                expiresAt: before.expiresAt,
                errorCount: before.errorCount + 1,
                dueOrdinal:
                    nextScope.ordinal +
                    retryGapAfterError(before.errorCount + 1),
                waitEligibleAt: retry.rating == LearningRating.again
                    ? roundExpected?.waitEligibleAt
                    : null,
              )
            : null;
      }
      // Delete first: replacing Again→Good must not leave an origin whose rating
      // is no longer Again. Restoration/insertion remains in this transaction.
      if (actualRound != null) {
        await (database.delete(
          database.retryObligations,
        )..where((row) => row.id.equals(actualRound.id))).go();
      }
      if (replacement != null) {
        replacement.validate();
        await database
            .into(database.retryObligations)
            .insert(
              RetryObligationsCompanion.insert(
                id: replacement.id,
                itemId: replacement.itemId,
                generation: replacement.generation,
                revision: Value(replacement.revision),
                originReviewId: replacement.originReviewId,
                createdAt: replacement.createdAt.toIso8601String(),
                expiresAt: replacement.expiresAt.toIso8601String(),
                errorCount: Value(replacement.errorCount),
                dueOrdinal: Value(replacement.dueOrdinal),
                waitEligibleAt: Value(
                  replacement.waitEligibleAt?.toIso8601String(),
                ),
              ),
            );
      }
      if (expected is RegularReviewReceipt) {
        return RegularReviewReceipt(
          prior: expected.prior,
          next: nextItem,
          event: RegularReviewRecord(
            id: expected.event.id,
            itemId: expected.event.itemId,
            generation: expected.event.generation,
            rating: rating,
            reviewedAt: originalAt,
          ),
          retryPrior: expected.retryPrior,
          retryNext: replacement,
          scopePrior: expected.scopePrior,
          scopeNext: nextScope,
        );
      }
      final retry = expected as RetryAnswerReceipt;
      return RetryAnswerReceipt(
        prior: retry.prior,
        retryPrior: retry.retryPrior,
        retryNext: replacement,
        scopePrior: retry.scopePrior,
        scopeNext: nextScope,
        rating: rating,
        answeredAt: originalAt,
      );
    });
  }
}
