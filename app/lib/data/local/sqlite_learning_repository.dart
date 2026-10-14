import 'package:drift/drift.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart';
import '../learning_item.dart';
import '../regular_review.dart';
import '../retry_obligation.dart';
import '../../core/learning_day.dart';
import '../../features/learning/learning_scheduler.dart';
import 'piko_database.dart';

final class SqliteLearningRepository implements RegularReviewWriter {
  SqliteLearningRepository(this.database);
  final PikoDatabase database;
  final _scheduler = LearningScheduler();

  /// Resolves an actual Collection UUID; names never establish review scope.
  Future<CollectionReviewGateway> forCollection({
    required String collectionId,
    required LearningDirection direction,
  }) async {
    final collection = await (database.select(
      database.collections,
    )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
    if (collection == null) throw RegularReviewFailure.collectionNotFound;
    return CollectionReviewGateway._(this, collection.id, direction);
  }

  Future<List<LearningItemRecord>> _scopedItems(
    CollectionReviewGateway scope,
  ) => database.transaction(() async {
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
    return List.unmodifiable(rows.map((row) => _record(row.readTable(items))));
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
    for (final row in rows) {
      validated.add(
        await _retryRecord(
          row.readTable(retries),
          _record(row.readTable(items)),
        ),
      );
    }
    final active = <RetryObligation>[];
    for (final retry in validated) {
      if (!at.isBefore(retry.expiresAt)) {
        await (database.delete(
          retries,
        )..where((row) => row.id.equals(retry.id))).go();
      } else {
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

  Future<void> _completeSuccessfulRetry(
    CollectionReviewGateway scope,
    RetryObligation expected,
    DateTime answeredAt,
  ) async {
    expected.validate();
    if (!answeredAt.isUtc || answeredAt.isBefore(expected.createdAt)) {
      throw ArgumentError.value(
        answeredAt,
        'answeredAt',
        'Must be UTC and not before the round',
      );
    }
    await database.transaction(() async {
      final items = await _scopedItems(scope);
      final matches = items.where((item) => item.id == expected.itemId);
      if (matches.length != 1) throw RegularReviewFailure.outOfScope;
      final item = matches.single;
      if (item.generation != expected.generation) throw RetryFailure.staleState;
      final actual = await _retryFor(item);
      if (actual == null) throw RetryFailure.notFound;
      if (!actual.sameStateAs(expected)) throw RetryFailure.staleState;
      if (!answeredAt.isBefore(actual.expiresAt)) {
        // Commit observed expiry, but never count it as a successful answer.
        await (database.delete(
          database.retryObligations,
        )..where((row) => row.id.equals(actual.id))).go();
        return;
      }
      await (database.delete(
        database.retryObligations,
      )..where((row) => row.id.equals(actual.id))).go();
    });
    // Expiration is reported after its owned transaction can commit the removal.
    if (!answeredAt.isBefore(expected.expiresAt)) throw RetryFailure.expired;
  }

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
      if (scope != null) {
        // Recheck authoritative ownership in the event/card write transaction.
        // Neither a discovered list nor the caller's prior can establish scope.
        final entry = await (database.select(
          database.vocabularyEntries,
        )..where((entry) => entry.id.equals(row.entryId))).getSingleOrNull();
        if (entry == null ||
            entry.collectionId != scope.collectionId ||
            row.direction != scope.direction.name) {
          throw RegularReviewFailure.outOfScope;
        }
      }
      final prior = _record(row);
      if (prior.entryId != expectedPrior.entryId ||
          prior.direction != expectedPrior.direction ||
          prior.formatVersion != expectedPrior.formatVersion ||
          prior.generation != expectedPrior.generation ||
          prior.reviewRevision != expectedPrior.reviewRevision ||
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
              ),
            );
      } else {
        retryNext = null;
      }
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
        ),
        event: event,
        retryPrior: retryPrior,
        retryNext: retryNext,
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
final class CollectionReviewGateway implements ScopedReviewSource {
  const CollectionReviewGateway._(
    this._repository,
    this.collectionId,
    this.direction,
  );
  final SqliteLearningRepository _repository;
  @override
  final String collectionId;
  @override
  final LearningDirection direction;

  /// Non-presentational discovery; SESSION-018 owns due eligibility/selection.
  /// An existing empty Collection returns []; a deleted owner fails explicitly.
  Future<List<LearningItemRecord>> items() => _repository._scopedItems(this);

  /// Decode UTC instants; valid stored timestamp spellings need not sort lexically.
  @override
  Future<List<LearningItemRecord>> dueItems({required DateTime cutoff}) =>
      _repository._dueItems(this, cutoff);

  /// Caller-owned awaited read/cleanup; active same-day retry rounds only.
  Future<List<RetryObligation>> pendingRetries({required DateTime at}) =>
      _repository._pendingRetries(this, at);

  /// Storage boundary only: future reinforcement processing owns answer policy.
  /// This removes current-round state, never writes FSRS or regular history.
  Future<void> completeSuccessfulRetry({
    required RetryObligation expected,
    required DateTime answeredAt,
  }) => _repository._completeSuccessfulRetry(this, expected, answeredAt);

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
