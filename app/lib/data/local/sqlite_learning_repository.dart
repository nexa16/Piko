import 'package:drift/drift.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart';
import '../learning_item.dart';
import '../regular_review.dart';
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
  Future<List<LearningItemRecord>> dueItems({required DateTime cutoff}) async {
    if (!cutoff.isUtc) {
      throw ArgumentError.value(cutoff, 'cutoff', 'Must be UTC');
    }
    final scoped = await items();
    return List.unmodifiable(
      scoped.where((item) => !item.card.due.isAfter(cutoff)),
    );
  }

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
