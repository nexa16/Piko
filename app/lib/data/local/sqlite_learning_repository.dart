import 'package:drift/drift.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart';
import '../learning_item.dart';
import '../regular_review.dart';
import '../../features/learning/learning_scheduler.dart';
import 'piko_database.dart';

final class SqliteLearningRepository {
  SqliteLearningRepository(this.database);
  final PikoDatabase database;
  final _scheduler = LearningScheduler();

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
  Future<RegularReviewReceipt> review({
    required ReviewKind kind,
    required LearningItemRecord expectedPrior,
    required LearningRating rating,
    required DateTime reviewedAt,
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
