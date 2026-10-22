import 'package:drift/drift.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart';
import '../learning_item.dart';
import '../learning_reset.dart';
import '../regular_review.dart';
import '../retry_obligation.dart';
import '../retry_answer.dart';
import '../review_correction.dart';
import '../review_due_membership.dart';
import '../speed_completion.dart';
import '../../core/learning_day.dart';
import '../../features/learning/learning_scheduler.dart';
import '../../features/learning/retry_gap.dart';
import 'piko_database.dart';
import 'sqlite_statistics_repository.dart';
import '../../features/learning/learning_parameters.dart';

part 'sqlite_review_correction.dart';
part 'sqlite_speed_completion.dart';

final class SqliteLearningRepository
    implements RegularReviewWriter, LearningResetRepository {
  SqliteLearningRepository(this.database);
  final PikoDatabase database;
  final _scheduler = LearningScheduler();

  @override
  Future<void> resetLearning({
    required String entryId,
    required Set<LearningDirection> directions,
  }) {
    final selected = Set<LearningDirection>.of(directions);
    if (selected.isEmpty) throw ArgumentError.value(directions, 'directions');
    return database.transaction(() async {
      final entry = await (database.select(
        database.vocabularyEntries,
      )..where((row) => row.id.equals(entryId))).getSingleOrNull();
      if (entry == null) throw RegularReviewFailure.itemNotFound;
      final items =
          await (database.select(database.learningItems)..where(
                (row) =>
                    row.entryId.equals(entryId) &
                    row.direction.isIn(selected.map((d) => d.name)),
              ))
              .get();
      if (items.length != selected.length) {
        throw RegularReviewFailure.itemNotFound;
      }
      final at = database.clock.now().toUtc();
      for (final item in items) {
        _record(item).card;
        final card = _scheduler.initialCard(itemId: item.id, at: at);
        await (database.update(
          database.learningItems,
        )..where((row) => row.id.equals(item.id))).write(
          LearningItemsCompanion(
            cardJson: Value(LearningCardCodec.encode(card)),
            formatVersion: const Value(LearningCardCodec.version),
            generation: Value(item.generation + 1),
            reviewRevision: Value(item.reviewRevision + 1),
            speedCompleted: const Value(false),
          ),
        );
        await (database.delete(
          database.retryObligations,
        )..where((row) => row.itemId.equals(item.id))).go();
        final scope = await _scopeState(
          entry.collectionId,
          LearningDirection.values.byName(item.direction),
        );
        await database
            .into(database.scopeAnswerOrdinals)
            .insertOnConflictUpdate(
              ScopeAnswerOrdinalsCompanion.insert(
                collectionId: entry.collectionId,
                direction: item.direction,
                ordinal: scope.ordinal,
                revision: scope.revision + 1,
              ),
            );
      }
    });
  }

  /// Resolves an actual Collection UUID; names never establish review scope.
  Future<CollectionReviewGateway> forCollection({
    required String collectionId,
    required LearningDirection direction,
    Set<String>? entryIds,
  }) async {
    final selected = entryIds == null
        ? null
        : Set<String>.unmodifiable(entryIds);
    final collection = await (database.select(
      database.collections,
    )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
    if (collection == null) throw RegularReviewFailure.collectionNotFound;
    if (selected != null) {
      final owned = await (database.select(
        database.vocabularyEntries,
      )..where((row) => row.collectionId.equals(collectionId))).get();
      if (!owned.map((entry) => entry.id).toSet().containsAll(selected)) {
        throw RegularReviewFailure.outOfScope;
      }
    }
    return CollectionReviewGateway._(this, collection.id, direction, selected);
  }

  Future<List<LearningItemRecord>> _scopedItems(
    CollectionReviewGateway scope, {
    bool includeInactive = false,
  }) => database.transaction(() async {
    final collection = await (database.select(
      database.collections,
    )..where((row) => row.id.equals(scope.collectionId))).getSingleOrNull();
    if (collection == null) throw RegularReviewFailure.collectionNotFound;
    final items = database.learningItems;
    final entries = database.vocabularyEntries;
    final rows =
        await (database.select(items).join([
                innerJoin(entries, entries.id.equalsExp(items.entryId)),
              ])
              ..where(
                entries.collectionId.equals(scope.collectionId) &
                    items.direction.equals(scope.direction.name),
              )
              ..orderBy([OrderingTerm(expression: items.id)]))
            .get();
    final selected = rows
        .where(
          (row) =>
              scope.entryIds == null ||
              scope.entryIds!.contains(row.readTable(entries).id),
        )
        .map((row) => _record(row.readTable(items)))
        .toList(growable: false);
    if (scope.entryIds != null && selected.length != scope.entryIds!.length) {
      throw RegularReviewFailure.itemNotFound;
    }
    final activeIds = {
      for (final row in rows)
        if (row.readTable(entries).active) row.readTable(entries).id,
    };
    return List.unmodifiable(
      selected.where(
        (item) => includeInactive || activeIds.contains(item.entryId),
      ),
    );
  });

  LearningItemRecord _record(LearningItem row) {
    final record = LearningItemRecord(
      id: row.id,
      entryId: row.entryId,
      direction: LearningDirection.values.byName(row.direction),
      cardJson: row.cardJson,
      formatVersion: row.formatVersion,
      generation: row.generation,
      reviewRevision: row.reviewRevision,
      speedCompleted: row.speedCompleted,
    );
    record.card;
    return record;
  }

  Future<RetryObligation> _retryRecord(
    StoredRetryObligation row,
    LearningItemRecord item,
  ) async {
    final retry = RetryObligation.fromStored(
      id: row.id,
      itemId: row.itemId,
      generation: row.generation,
      revision: row.revision,
      originReviewId: row.originReviewId,
      createdAt: row.createdAt,
      expiresAt: row.expiresAt,
      errorCount: row.errorCount,
      dueOrdinal: row.dueOrdinal,
      waitEligibleAt: row.waitEligibleAt,
    );
    final origin =
        await (database.select(database.regularReviews)
              ..where((event) => event.id.equals(retry.originReviewId)))
            .getSingleOrNull();
    if (retry.itemId != item.id ||
        retry.generation != item.generation ||
        origin == null ||
        origin.itemId != item.id ||
        origin.generation != item.generation ||
        origin.rating != LearningRating.again.name ||
        DateTime.tryParse(origin.reviewedAt) != retry.createdAt) {
      throw const FormatException(
        'Invalid retry origin or learning generation',
      );
    }
    return retry;
  }

  Future<RetryObligation?> _retryFor(LearningItemRecord item) async {
    final row =
        await (database.select(database.retryObligations)..where(
              (retry) =>
                  retry.itemId.equals(item.id) &
                  retry.generation.equals(item.generation),
            ))
            .getSingleOrNull();
    return row == null ? null : _retryRecord(row, item);
  }

  /// This read may expire validated scoped rows. Its caller owns/awaits storage
  /// lifetime; runtime preparation registers the whole operation before reading.
  Future<List<RetryObligation>> _pendingRetries(
    CollectionReviewGateway scope,
    DateTime at,
  ) => database.transaction(() async {
    if (!at.isUtc) throw ArgumentError.value(at, 'at', 'Must be UTC');
    await _scopedItems(
      scope,
    ); // Validate the actual owner, including empty scope.
    final retries = database.retryObligations,
        items = database.learningItems,
        entries = database.vocabularyEntries;
    final rows =
        await (database.select(retries).join([
                innerJoin(items, items.id.equalsExp(retries.itemId)),
                innerJoin(entries, entries.id.equalsExp(items.entryId)),
              ])
              ..where(
                entries.collectionId.equals(scope.collectionId) &
                    items.direction.equals(scope.direction.name),
              )
              ..orderBy([OrderingTerm(expression: items.id)]))
            .get();
    // Validate all rows before any expiry cleanup; corruption fails closed.
    final validated = <RetryObligation>[];
    for (final row in rows.where(
      (row) =>
          scope.entryIds == null ||
          scope.entryIds!.contains(row.readTable(entries).id),
    )) {
      validated.add(
        await _retryRecord(
          row.readTable(retries),
          _record(row.readTable(items)),
        ),
      );
    }
    final activeItems = {
      for (final row in rows)
        if (row.readTable(entries).active) row.readTable(items).id,
    };
    final active = <RetryObligation>[];
    for (final retry in validated) {
      if (!at.isBefore(retry.expiresAt)) {
        await (database.delete(
          retries,
        )..where((row) => row.id.equals(retry.id))).go();
      } else if (activeItems.contains(retry.itemId)) {
        active.add(retry);
      }
    }
    return List.unmodifiable(active);
  });

  Future<List<LearningItemRecord>> _dueItems(
    CollectionReviewGateway scope,
    DateTime cutoff,
  ) async {
    final due = await database.transaction<List<LearningItemRecord>?>(() async {
      if (!cutoff.isUtc) {
        throw ArgumentError.value(cutoff, 'cutoff', 'Must be UTC');
      }
      if ((await _pendingRetries(scope, cutoff)).isNotEmpty) {
        // Until the session consumes reinforcement, never silently show no-due
        // or launch a second regular grade of a pending round.
        return null;
      }
      final items = await _scopedItems(scope);
      return List.unmodifiable(
        items.where((item) => !item.card.due.isAfter(cutoff)),
      );
    });
    // Expiry cleanup commits even if another active retry blocks preparation.
    if (due == null) throw RetryFailure.processingRequired;
    return due;
  }

  Future<ScopeAnswerState> _scopeState(
    String collectionId,
    LearningDirection direction,
  ) async {
    final row =
        await (database.select(database.scopeAnswerOrdinals)..where(
              (row) =>
                  row.collectionId.equals(collectionId) &
                  row.direction.equals(direction.name),
            ))
            .getSingleOrNull();
    final result = ScopeAnswerState(
      collectionId: collectionId,
      direction: direction,
      ordinal: row?.ordinal ?? 0,
      revision: row?.revision ?? 0,
    );
    result.validate();
    return result;
  }

  Future<ScopeAnswerState> _advanceScope(ScopeAnswerState before) async {
    final after = ScopeAnswerState(
      collectionId: before.collectionId,
      direction: before.direction,
      ordinal: before.ordinal + 1,
      revision: before.revision + 1,
    );
    after.validate();
    await database
        .into(database.scopeAnswerOrdinals)
        .insertOnConflictUpdate(
          ScopeAnswerOrdinalsCompanion.insert(
            collectionId: after.collectionId,
            direction: after.direction.name,
            ordinal: after.ordinal,
            revision: after.revision,
          ),
        );
    return after;
  }

  Future<RetryState> _retryState(CollectionReviewGateway scope, DateTime at) =>
      database.transaction(() async {
        final rounds = await _pendingRetries(scope, at);
        final items = await _scopedItems(scope);
        final ordinal = await _scopeState(scope.collectionId, scope.direction);
        return RetryState(scope: ordinal, items: items, rounds: rounds);
      });

  Future<ReviewDueMembershipSnapshot> _dueMemberships(
    CollectionReviewGateway scope,
    DateTime at,
  ) => database.transaction(() async {
    if (!at.isUtc) throw ArgumentError.value(at, 'at', 'Must be UTC');
    final items = await _scopedItems(scope);
    final ordinal = await _scopeState(scope.collectionId, scope.direction);
    final result = <ReviewDueMembership>[];
    // Search reprojects both learning directions. Fetch retry rows in bounded
    // batches rather than issuing one query for every word (usually no retry).
    // Keep origin/generation validation in _retryRecord for every actual round.
    final retries = <int, StoredRetryObligation>{};
    for (var start = 0; start < items.length; start += 500) {
      final ids = items.skip(start).take(500).map((item) => item.id).toList();
      final rows = await (database.select(
        database.retryObligations,
      )..where((row) => row.itemId.isIn(ids))).get();
      for (final row in rows) {
        retries[row.itemId] = row;
      }
    }
    DateTime? nextChangeAt;
    void consider(DateTime candidate) {
      if (candidate.isAfter(at) &&
          (nextChangeAt == null || candidate.isBefore(nextChangeAt!))) {
        nextChangeAt = candidate;
      }
    }

    for (final item in items) {
      final stored = retries[item.id];
      final round = stored == null || stored.generation != item.generation
          ? null
          : await _retryRecord(stored, item);
      final activeRound = round != null && at.isBefore(round.expiresAt)
          ? round
          : null;
      final scheduledRegularDue = !item.card.due.isAfter(at);
      if (activeRound == null) {
        if (!scheduledRegularDue) {
          consider(item.card.due);
          continue;
        }
      } else {
        consider(activeRound.expiresAt);
        if (!activeRound.eligibleAt(ordinal, at)) {
          final wait = activeRound.waitEligibleAt;
          if (wait != null) consider(wait);
        }
      }
      result.add(
        ReviewDueMembership(
          entryId: item.entryId,
          itemId: item.id,
          generation: item.generation,
          direction: item.direction,
          regularDue: activeRound == null && scheduledRegularDue,
          eligibleRetry: activeRound?.eligibleAt(ordinal, at) ?? false,
        ),
      );
    }
    return ReviewDueMembershipSnapshot(
      memberships: result,
      nextChangeAt: nextChangeAt,
    );
  });

  Future<RetrySelection> _initialSelection(
    CollectionReviewGateway scope,
    DateTime cutoff,
  ) => database.transaction(() async {
    if (!cutoff.isUtc) {
      throw ArgumentError.value(cutoff, 'cutoff', 'Must be UTC');
    }
    final state = await _retryState(scope, cutoff);
    final pending = state.rounds.map((round) => round.itemId).toSet();
    return RetrySelection(
      retries: state,
      regular: state.items
          .where(
            (item) =>
                !pending.contains(item.id) && !item.card.due.isAfter(cutoff),
          )
          .toList(),
    );
  });

  Future<RetryWaitResult> _armBlockedWaits(
    CollectionReviewGateway scope,
    List<RetryObligation> expected,
    List<LearningItemRecord> remaining,
    DateTime at,
  ) async {
    if (!at.isUtc) throw ArgumentError.value(at, 'at', 'Must be UTC');
    if (expected.map((round) => round.id).toSet().length != expected.length) {
      throw ArgumentError('Duplicate captured retry identity');
    }
    for (final round in expected) {
      round.validate();
    }
    for (final item in remaining) {
      item.card;
    }
    return database.transaction(() async {
      final state = await _retryState(scope, at);
      for (final item in remaining) {
        final actual = state.items
            .where((row) => row.id == item.id)
            .firstOrNull;
        if (actual == null) throw RegularReviewFailure.outOfScope;
        if (!_sameItem(actual, item)) throw RegularReviewFailure.staleState;
      }
      final captured = <RetryObligation>[];
      for (final round in expected) {
        final item = state.items
            .where((item) => item.id == round.itemId)
            .firstOrNull;
        if (item == null) throw RegularReviewFailure.outOfScope;
        final entry = await (database.select(
          database.vocabularyEntries,
        )..where((row) => row.id.equals(item.entryId))).getSingle();
        if (!entry.active) throw RegularReviewFailure.inactive;
        if (item.generation != round.generation) throw RetryFailure.staleState;
        final actual = state.rounds
            .where((row) => row.id == round.id)
            .firstOrNull;
        if (actual == null) {
          if (!at.isBefore(round.expiresAt)) continue;
          throw RetryFailure.notFound;
        }
        if (!actual.sameStateAs(round)) throw RetryFailure.staleState;
        if (at.isBefore(actual.createdAt)) {
          throw ArgumentError.value(at, 'at', 'Must not precede round');
        }
        captured.add(actual);
      }
      final mutations = <RetryWaitMutation>[];
      // Existing captured work must be consumed; do not arm waits just because
      // the originally requested ordinal gap exceeds the available pool size.
      if (remaining.isEmpty &&
          !captured.any((round) => round.eligibleAt(state.scope, at))) {
        for (final round in captured) {
          if (round.waitEligibleAt != null) continue;
          final next = RetryObligation(
            id: round.id,
            itemId: round.itemId,
            generation: round.generation,
            revision: round.revision + 1,
            originReviewId: round.originReviewId,
            createdAt: round.createdAt,
            expiresAt: round.expiresAt,
            errorCount: round.errorCount,
            dueOrdinal: round.dueOrdinal,
            waitEligibleAt: at.add(
              const Duration(seconds: LearningParameters.retryWaitSeconds),
            ),
          );
          next.validate();
          await (database.update(
            database.retryObligations,
          )..where((row) => row.id.equals(round.id))).write(
            RetryObligationsCompanion(
              revision: Value(next.revision),
              waitEligibleAt: Value(next.waitEligibleAt!.toIso8601String()),
            ),
          );
          mutations.add(RetryWaitMutation(prior: round, next: next));
        }
      }
      return RetryWaitResult(
        state: await _retryState(scope, at),
        mutations: mutations,
      );
    });
  }

  bool _sameItem(LearningItemRecord actual, LearningItemRecord expected) =>
      actual.id == expected.id &&
      actual.entryId == expected.entryId &&
      actual.direction == expected.direction &&
      actual.formatVersion == expected.formatVersion &&
      actual.generation == expected.generation &&
      actual.reviewRevision == expected.reviewRevision &&
      actual.speedCompleted == expected.speedCompleted &&
      actual.cardJson == expected.cardJson;

  Future<RetryAnswerReceipt> _answerRetry(
    CollectionReviewGateway scope,
    RetryObligation expected,
    LearningItemRecord? expectedPrior,
    LearningRating rating,
    DateTime at,
  ) async {
    expected.validate();
    expectedPrior?.card;
    if (!at.isUtc || at.isBefore(expected.createdAt)) {
      throw ArgumentError.value(
        at,
        'answeredAt',
        'Must be UTC and not before the round',
      );
    }
    final result = await database.transaction<RetryAnswerReceipt?>(() async {
      final items = await _scopedItems(scope, includeInactive: true);
      final item = items
          .where((item) => item.id == expected.itemId)
          .firstOrNull;
      if (item == null) throw RegularReviewFailure.outOfScope;
      final entry = await (database.select(
        database.vocabularyEntries,
      )..where((row) => row.id.equals(item.entryId))).getSingle();
      if (!entry.active) throw RegularReviewFailure.inactive;
      if (item.generation != expected.generation ||
          expectedPrior != null && !_sameItem(item, expectedPrior)) {
        throw RetryFailure.staleState;
      }
      final actual = await _retryFor(item);
      if (actual == null) throw RetryFailure.notFound;
      if (!actual.sameStateAs(expected)) throw RetryFailure.staleState;
      if (!at.isBefore(actual.expiresAt)) {
        await (database.delete(
          database.retryObligations,
        )..where((row) => row.id.equals(actual.id))).go();
        return null; // Published expiry is not an answer and never advances count.
      }
      final last = item.card.lastReview;
      if (last != null && at.isBefore(last)) {
        throw ArgumentError.value(
          at,
          'answeredAt',
          'Must not precede regular review',
        );
      }
      final before = await _scopeState(scope.collectionId, scope.direction);
      if (!actual.eligibleAt(before, at)) throw RetryFailure.notEligible;
      final after = await _advanceScope(before);
      final RetryObligation? next;
      if (rating == LearningRating.again) {
        final errors = actual.errorCount + 1;
        next = RetryObligation(
          id: actual.id,
          itemId: actual.itemId,
          generation: actual.generation,
          revision: actual.revision + 1,
          originReviewId: actual.originReviewId,
          createdAt: actual.createdAt,
          expiresAt: actual.expiresAt,
          errorCount: errors,
          dueOrdinal: after.ordinal + retryGapAfterError(errors),
          waitEligibleAt: null,
        );
        next.validate();
        await (database.update(
          database.retryObligations,
        )..where((row) => row.id.equals(actual.id))).write(
          RetryObligationsCompanion(
            revision: Value(next.revision),
            errorCount: Value(next.errorCount),
            dueOrdinal: Value(next.dueOrdinal),
            waitEligibleAt: const Value(null),
          ),
        );
      } else {
        next = null;
        await (database.delete(
          database.retryObligations,
        )..where((row) => row.id.equals(actual.id))).go();
      }
      return RetryAnswerReceipt(
        prior: item,
        retryPrior: actual,
        retryNext: next,
        scopePrior: before,
        scopeNext: after,
        rating: rating,
        answeredAt: at,
      );
    });
    if (result == null) throw RetryFailure.expired;
    return result;
  }

  Future<RetryAnswerReceipt> _completeSuccessfulRetry(
    CollectionReviewGateway scope,
    RetryObligation expected,
    DateTime answeredAt,
  ) => _answerRetry(scope, expected, null, LearningRating.good, answeredAt);

  /// Accepts one regular review of exactly the caller's displayed prior state.
  @override
  Future<RegularReviewReceipt> review({
    required ReviewKind kind,
    required LearningItemRecord expectedPrior,
    required LearningRating rating,
    required DateTime reviewedAt,
  }) => _review(
    kind: kind,
    expectedPrior: expectedPrior,
    rating: rating,
    reviewedAt: reviewedAt,
  );

  Future<RegularReviewReceipt> _review({
    required ReviewKind kind,
    required LearningItemRecord expectedPrior,
    required LearningRating rating,
    required DateTime reviewedAt,
    CollectionReviewGateway? scope,
  }) async {
    // Reject reinforcement at the boundary, before storage or FSRS calculation.
    if (kind != ReviewKind.regular) {
      throw RegularReviewFailure.reinforcementNotRetained;
    }
    expectedPrior.card;
    if (!reviewedAt.isUtc) {
      throw ArgumentError.value(reviewedAt, 'reviewedAt', 'Must be UTC');
    }
    return database.transaction(() async {
      final row = await (database.select(
        database.learningItems,
      )..where((item) => item.id.equals(expectedPrior.id))).getSingleOrNull();
      if (row == null) throw RegularReviewFailure.itemNotFound;
      final entry = await (database.select(
        database.vocabularyEntries,
      )..where((entry) => entry.id.equals(row.entryId))).getSingleOrNull();
      if (entry == null) throw RegularReviewFailure.itemNotFound;
      if (!entry.active) throw RegularReviewFailure.inactive;
      if (scope != null) {
        // Recheck authoritative ownership in the event/card write transaction.
        // Neither a discovered list nor the caller's prior can establish scope.
        if (entry.collectionId != scope.collectionId ||
            row.direction != scope.direction.name ||
            scope.entryIds != null && !scope.entryIds!.contains(entry.id)) {
          throw RegularReviewFailure.outOfScope;
        }
      }
      final prior = _record(row);
      if (prior.entryId != expectedPrior.entryId ||
          prior.direction != expectedPrior.direction ||
          prior.formatVersion != expectedPrior.formatVersion ||
          prior.generation != expectedPrior.generation ||
          prior.reviewRevision != expectedPrior.reviewRevision ||
          prior.speedCompleted != expectedPrior.speedCompleted ||
          prior.cardJson != expectedPrior.cardJson) {
        throw RegularReviewFailure.staleState;
      }
      final lastReview = prior.card.lastReview;
      if (lastReview != null && reviewedAt.isBefore(lastReview)) {
        throw ArgumentError.value(
          reviewedAt,
          'reviewedAt',
          'Must not precede the last review',
        );
      }
      final retryPrior = await _retryFor(prior);
      if (retryPrior != null) {
        if (reviewedAt.isBefore(retryPrior.expiresAt)) {
          throw RetryFailure.processingRequired;
        }
        await (database.delete(
          database.retryObligations,
        )..where((row) => row.id.equals(retryPrior.id))).go();
      }
      final transition = _scheduler.review(
        prior,
        rating: rating,
        reviewedAt: reviewedAt,
      );
      final scopePrior = await _scopeState(entry.collectionId, prior.direction);
      final scopeNext = await _advanceScope(scopePrior);
      final event = RegularReviewRecord(
        id: const Uuid().v4(),
        itemId: prior.id,
        generation: prior.generation,
        rating: rating,
        reviewedAt: reviewedAt,
      );
      await database
          .into(database.regularReviews)
          .insert(
            RegularReviewsCompanion.insert(
              id: event.id,
              itemId: event.itemId,
              generation: event.generation,
              rating: event.rating.name,
              reviewedAt: event.reviewedAt.toIso8601String(),
            ),
          );
      final count =
          await (database.update(
            database.learningItems,
          )..where((item) => item.id.equals(prior.id))).write(
            LearningItemsCompanion(
              cardJson: Value(transition.next.cardJson),
              reviewRevision: Value(prior.reviewRevision + 1),
            ),
          );
      if (count != 1) throw RegularReviewFailure.itemNotFound;
      final RetryObligation? retryNext;
      if (rating == LearningRating.again) {
        retryNext = RetryObligation(
          id: const Uuid().v4(),
          itemId: prior.id,
          generation: prior.generation,
          revision: 0,
          originReviewId: event.id,
          createdAt: reviewedAt,
          expiresAt: LearningDay.nextBoundaryUtc(reviewedAt),
          errorCount: 1,
          dueOrdinal: scopeNext.ordinal + retryGapAfterError(1),
        );
        retryNext.validate();
        await database
            .into(database.retryObligations)
            .insert(
              RetryObligationsCompanion.insert(
                id: retryNext.id,
                itemId: retryNext.itemId,
                generation: retryNext.generation,
                originReviewId: retryNext.originReviewId,
                createdAt: retryNext.createdAt.toIso8601String(),
                expiresAt: retryNext.expiresAt.toIso8601String(),
                errorCount: Value(retryNext.errorCount),
                dueOrdinal: Value(retryNext.dueOrdinal),
              ),
            );
      } else {
        retryNext = null;
      }
      await SqliteStatisticsRepository(
        database,
      ).recordRegular(event.id, reviewedAt);
      return RegularReviewReceipt(
        prior: transition.prior,
        next: LearningItemRecord(
          id: transition.next.id,
          entryId: transition.next.entryId,
          direction: transition.next.direction,
          cardJson: transition.next.cardJson,
          formatVersion: transition.next.formatVersion,
          generation: transition.next.generation,
          reviewRevision: prior.reviewRevision + 1,
          speedCompleted: prior.speedCompleted,
        ),
        event: event,
        retryPrior: retryPrior,
        retryNext: retryNext,
        scopePrior: scopePrior,
        scopeNext: scopeNext,
      );
    });
  }

  Future<List<RegularReviewRecord>> reviewsForItem(int itemId) async {
    final rows =
        await (database.select(database.regularReviews)
              ..where((row) => row.itemId.equals(itemId))
              ..orderBy([
                (_) => OrderingTerm(
                  expression: const CustomExpression<int>('rowid'),
                ),
              ]))
            .get();
    return rows
        .map((row) {
          final at = DateTime.tryParse(row.reviewedAt);
          final ratings = LearningRating.values.where(
            (rating) => rating.name == row.rating,
          );
          if (row.id.trim().isEmpty ||
              row.itemId <= 0 ||
              row.generation < 0 ||
              at == null ||
              !at.isUtc ||
              ratings.length != 1) {
            throw const FormatException('Invalid regular review');
          }
          return RegularReviewRecord(
            id: row.id,
            itemId: row.itemId,
            generation: row.generation,
            rating: ratings.single,
            reviewedAt: at,
          );
        })
        .toList(growable: false);
  }

  Future<List<LearningItemRecord>> forEntry(String entryId) async {
    final rows =
        await (database.select(database.learningItems)
              ..where((row) => row.entryId.equals(entryId))
              ..orderBy([(row) => OrderingTerm(expression: row.id)]))
            .get();
    return rows
        .map((row) {
          return _record(row);
        })
        .toList(growable: false);
  }

  /// Authoritative SPEED-005 eligibility, independent of FSRS dates/state and
  /// historical reviews from older generations. The optional scope is the
  /// Collection's visible search/category subset; results retain display order.
  Future<List<LearningItemRecord>> newSpeedItems({
    required String collectionId,
    required LearningDirection direction,
    Set<String>? entryIds,
  }) {
    final visible = entryIds == null ? null : Set<String>.of(entryIds);
    return database.transaction(() async {
      final owner = await (database.select(
        database.collections,
      )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
      if (owner == null) throw RegularReviewFailure.collectionNotFound;
      final rows = await database
          .customSelect(
            'SELECT l.* FROM learning_items l '
            'JOIN vocabulary_entries v ON v.id = l.entry_id '
            'WHERE v.collection_id = ? AND v.active = 1 AND l.direction = ? AND l.speed_completed = 0 '
            'AND NOT EXISTS (SELECT 1 FROM regular_reviews r '
            'WHERE r.item_id = l.id AND r.generation = l.generation) '
            'ORDER BY v.rowid',
            variables: [Variable(collectionId), Variable(direction.name)],
          )
          .get();
      return List.unmodifiable(
        rows
            .map((row) => _record(database.learningItems.map(row.data)))
            .where((item) => visible == null || visible.contains(item.entryId)),
      );
    });
  }

  /// Direct state support for fixtures; production regular reviews must use [review]
  /// so their event, optimistic revision and complete card commit together.
  Future<void> saveCard(int id, fsrs.Card card) async {
    if (card.cardId != id) {
      throw const FormatException('Learning identity mismatch');
    }
    final encoded = LearningCardCodec.encode(card);
    final count =
        await (database.update(database.learningItems)
              ..where((row) => row.id.equals(id)))
            .write(LearningItemsCompanion(cardJson: Value(encoded)));
    if (count != 1) throw StateError('Learning item does not exist');
  }
}

/// Fixed Collection/direction boundary, not a due set or session launcher.
final class CollectionReviewGateway
    implements
        RetryReviewSource,
        ActivityReviewSource,
        ReviewCorrectionSource,
        SpeedCompletionWriter {
  const CollectionReviewGateway._(
    this._repository,
    this.collectionId,
    this.direction,
    this.entryIds,
  );
  final SqliteLearningRepository _repository;
  @override
  final String collectionId;
  @override
  final LearningDirection direction;

  /// Immutable visible membership; counters remain Collection/direction-scoped.
  final Set<String>? entryIds;

  Future<void> reverseSpeedCompletion({
    required SpeedCompletionResult expected,
  }) => _repository._reverseSpeedCompletion(this, expected);

  @override
  Future<SpeedCompletionResult> completeSpeedItem({
    required LearningItemRecord expectedPrior,
    required int errors,
    required DateTime completedAt,
  }) =>
      _repository._completeSpeedItem(this, expectedPrior, errors, completedAt);

  Future<List<LearningItemRecord>> newSpeedItems({Set<String>? entryIds}) =>
      _repository.newSpeedItems(
        collectionId: collectionId,
        direction: direction,
        entryIds: this.entryIds == null
            ? entryIds
            : entryIds == null
            ? this.entryIds
            : this.entryIds!.intersection(entryIds),
      );

  @override
  Future<LearningAnswerReceipt> replaceAnswer({
    required LearningAnswerReceipt expected,
    required List<RetryWaitMutation> expectedWaits,
    required LearningRating rating,
    required DateTime executionAt,
  }) => _repository._replaceAnswer(
    this,
    expected,
    expectedWaits,
    rating,
    executionAt,
  );

  /// Non-presentational discovery; SESSION-018 owns due eligibility/selection.
  /// An existing empty Collection returns []; a deleted owner fails explicitly.
  Future<List<LearningItemRecord>> items() =>
      _repository._scopedItems(this, includeInactive: true);

  @override
  Future<Set<String>> activeEntryIds({Set<String>? expectedEntryIds}) =>
      _repository.database.transaction(() async {
        final all = await _repository._scopedItems(this, includeInactive: true);
        if (expectedEntryIds != null &&
            !all
                .map((item) => item.entryId)
                .toSet()
                .containsAll(expectedEntryIds)) {
          throw RegularReviewFailure.itemNotFound;
        }
        return {
          for (final item in await _repository._scopedItems(this)) item.entryId,
        };
      });

  /// Decode UTC instants; valid stored timestamp spellings need not sort lexically.
  @override
  Future<List<LearningItemRecord>> dueItems({required DateTime cutoff}) =>
      _repository._dueItems(this, cutoff);

  /// Caller-owned awaited read/cleanup; active same-day retry rounds only.
  Future<List<RetryObligation>> pendingRetries({required DateTime at}) =>
      _repository._pendingRetries(this, at);

  /// Passive badge/count source: never expires, arms or otherwise mutates work.
  Future<ReviewDueMembershipSnapshot> dueMemberships({required DateTime at}) =>
      _repository._dueMemberships(this, at);

  /// Storage boundary only: future reinforcement processing owns answer policy.
  /// This removes current-round state, never writes FSRS or regular history.
  Future<RetryAnswerReceipt> completeSuccessfulRetry({
    required RetryObligation expected,
    required DateTime answeredAt,
  }) => _repository._completeSuccessfulRetry(this, expected, answeredAt);

  @override
  Future<RetryState> retryState({required DateTime at}) =>
      _repository._retryState(this, at);
  @override
  Future<RetryWaitResult> armBlockedWaits({
    required List<RetryObligation> expectedRounds,
    required List<LearningItemRecord> remainingRegular,
    required DateTime at,
  }) =>
      _repository._armBlockedWaits(this, expectedRounds, remainingRegular, at);
  @override
  Future<RetrySelection> initialSelection({required DateTime cutoff}) =>
      _repository._initialSelection(this, cutoff);
  @override
  Future<RetryAnswerReceipt> answerRetry({
    required LearningItemRecord expectedPrior,
    required RetryObligation expectedRetry,
    required LearningRating rating,
    required DateTime answeredAt,
  }) => _repository._answerRetry(
    this,
    expectedRetry,
    expectedPrior,
    rating,
    answeredAt,
  );

  @override
  Future<RegularReviewReceipt> review({
    required ReviewKind kind,
    required LearningItemRecord expectedPrior,
    required LearningRating rating,
    required DateTime reviewedAt,
  }) => _repository._review(
    kind: kind,
    expectedPrior: expectedPrior,
    rating: rating,
    reviewedAt: reviewedAt,
    scope: this,
  );
}
