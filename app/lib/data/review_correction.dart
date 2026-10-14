import 'regular_review.dart';
import 'retry_answer.dart';
import '../features/learning/learning_scheduler.dart';

/// Replace an issued latest answer, never append another submitted answer.
abstract interface class ReviewCorrectionSource {
  Future<LearningAnswerReceipt> replaceAnswer({
    required LearningAnswerReceipt expected,
    required List<RetryWaitMutation> expectedWaits,
    required LearningRating rating,
    required DateTime executionAt,
  });
}

enum ReviewCorrectionFailure { staleState, invalidReceipt }
