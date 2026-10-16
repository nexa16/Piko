import 'learning_item.dart';

enum VocabularyLearningStatusKind { pendingRetry, newWord, due, nextReview }

/// Read-only directional presentation, never a scheduler level or stored grade.
final class VocabularyLearningStatus {
  const VocabularyLearningStatus({
    required this.kind,
    this.nextReviewAt,
    this.speedCompleted = false,
  }) : assert(
         (kind == VocabularyLearningStatusKind.nextReview) ==
             (nextReviewAt != null),
       );

  factory VocabularyLearningStatus.project({
    required LearningItemRecord item,
    required bool hasCurrentNormalReview,
    required bool hasPendingRetry,
    required bool isRegularDue,
  }) {
    final kind = hasPendingRetry
        ? VocabularyLearningStatusKind.pendingRetry
        : !hasCurrentNormalReview
        ? VocabularyLearningStatusKind.newWord
        : isRegularDue
        ? VocabularyLearningStatusKind.due
        : VocabularyLearningStatusKind.nextReview;
    return VocabularyLearningStatus(
      kind: kind,
      nextReviewAt: kind == VocabularyLearningStatusKind.nextReview
          ? item.card.due
          : null,
      speedCompleted: item.speedCompleted && !hasCurrentNormalReview,
    );
  }

  final VocabularyLearningStatusKind kind;
  final DateTime? nextReviewAt;
  final bool speedCompleted;
}
