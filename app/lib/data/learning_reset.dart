import 'learning_item.dart';

abstract interface class LearningResetRepository {
  Future<void> resetLearning({required String entryId, required Set<LearningDirection> directions});
}
