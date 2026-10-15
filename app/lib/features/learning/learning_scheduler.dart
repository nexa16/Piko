import 'package:fsrs/fsrs.dart' as fsrs;
import '../../data/learning_item.dart';

/// Regular FSRS review ratings supported by the first release.
enum LearningRating { again, hard, good }

/// Immutable calculation result; persistence and review history belong to callers.
final class LearningReviewTransition {
  const LearningReviewTransition._({
    required this.prior,
    required this.next,
    required this.rating,
    required this.reviewedAt,
  });
  final LearningItemRecord prior;
  final LearningItemRecord next;
  final LearningRating rating;
  final DateTime reviewedAt;
}

/// Offline scheduling through the pinned library, without storage or wall-clock use.
final class LearningScheduler {
  final _scheduler = fsrs.Scheduler(
    desiredRetention: 0.9,
    learningSteps: const [],
    relearningSteps: const [],
    enableFuzzing: false,
  );

  LearningReviewTransition review(
    LearningItemRecord before, {
    required LearningRating rating,
    required DateTime reviewedAt,
  }) {
    if (!reviewedAt.isUtc) {
      throw ArgumentError.value(reviewedAt, 'reviewedAt', 'Must be UTC');
    }
    if (before.entryId.trim().isEmpty) {
      throw const FormatException('Missing learning entry identity');
    }
    // Decode an independent card, leaving the exact prior JSON untouched.
    final card = before.card;
    if (card.lastReview != null && reviewedAt.isBefore(card.lastReview!)) {
      throw ArgumentError.value(
        reviewedAt,
        'reviewedAt',
        'Cannot precede the previous review',
      );
    }
    final libraryRating = switch (rating) {
      LearningRating.again => fsrs.Rating.again,
      LearningRating.hard => fsrs.Rating.hard,
      LearningRating.good => fsrs.Rating.good,
    };
    final result = _scheduler.reviewCard(
      card,
      libraryRating,
      reviewDateTime: reviewedAt,
    );
    final encoded = LearningCardCodec.encode(result.card);
    LearningCardCodec.decode(
      encoded,
      expectedId: before.id,
      formatVersion: before.formatVersion,
    );
    return LearningReviewTransition._(
      prior: before,
      next: LearningItemRecord(
        id: before.id,
        entryId: before.entryId,
        direction: before.direction,
        cardJson: encoded,
        formatVersion: before.formatVersion,
        generation: before.generation,
        reviewRevision: before.reviewRevision,
      ),
      rating: rating,
      reviewedAt: reviewedAt,
    );
  }
}
