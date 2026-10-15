import 'categories_repository.dart';
import 'collections_repository.dart';
import 'learning_item.dart';
import 'review_due_membership.dart';
import 'vocabulary_repository.dart';

enum CollectionQueryFailure {
  collectionNotFound,
  invalidFilter,
  incompleteLearning,
}

final class CollectionDirectionSnapshot {
  CollectionDirectionSnapshot({
    required this.review,
    required Iterable<LearningItemRecord> newSpeedItems,
  }) : newSpeedItems = List.unmodifiable(newSpeedItems);
  final ReviewDueMembershipSnapshot review;
  final List<LearningItemRecord> newSpeedItems;
  int get dueCount =>
      review.where((item) => item.regularDue || item.eligibleRetry).length;
  /// Retry items waiting for their gap/deadline; eligible retries count as due.
  int get pendingRetryCount => review.where((item) => !item.regularDue && !item.eligibleRetry).length;
}

final class CollectionQuerySnapshot {
  CollectionQuerySnapshot({
    required this.collection,
    required Iterable<VocabularyRecord> allEntries,
    required Iterable<VocabularyRecord> entries,
    required Iterable<CategoryDimensionRecord> categoryDimensions,
    required Map<String, List<CategoryValueRecord>> categoryValues,
    required Map<String, List<CategoryAssignmentRecord>> assignments,
    required Map<LearningDirection, CollectionDirectionSnapshot> directions,
  }) : allEntries = List.unmodifiable(allEntries),
       entries = List.unmodifiable(entries),
       categoryDimensions = List.unmodifiable(categoryDimensions),
       categoryValues = Map.unmodifiable({
         for (final entry in categoryValues.entries)
           entry.key: List<CategoryValueRecord>.unmodifiable(entry.value),
       }),
       assignments = Map.unmodifiable({
         for (final entry in assignments.entries)
           entry.key: List<CategoryAssignmentRecord>.unmodifiable(entry.value),
       }),
       directions = Map.unmodifiable(directions);
  final CollectionRecord collection;
  final List<VocabularyRecord> allEntries;
  final List<VocabularyRecord> entries;
  final List<CategoryDimensionRecord> categoryDimensions;
  final Map<String, List<CategoryValueRecord>> categoryValues;
  final Map<String, List<CategoryAssignmentRecord>> assignments;
  final Map<LearningDirection, CollectionDirectionSnapshot> directions;
  DateTime? get nextChangeAt {
    DateTime? first;
    for (final direction in directions.values) {
      final next = direction.review.nextChangeAt;
      if (next != null && (first == null || next.isBefore(first))) {
        first = next;
      }
    }
    return first;
  }
}

abstract interface class CollectionQueryService {
  /// One read-only snapshot. Values within a selected dimension use OR;
  /// selected dimensions combine with AND. Empty sets impose no restriction.
  Future<CollectionQuerySnapshot> query({
    required String collectionId,
    required DateTime at,
    Map<String, Set<String>> filters = const {},
  });
}
