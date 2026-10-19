import 'categories_repository.dart';
import 'collections_repository.dart';
import 'learning_item.dart';
import 'review_due_membership.dart';
import 'vocabulary_repository.dart';
import 'vocabulary_learning_status.dart';

enum CollectionQueryFailure {
  collectionNotFound,
  invalidFilter,
  incompleteLearning,
}

final class CollectionDirectionSnapshot {
  CollectionDirectionSnapshot({
    required this.review,
    required Iterable<LearningItemRecord> newSpeedItems,
    Map<String, VocabularyLearningStatus> statuses = const {},
    Iterable<LearningItemRecord> items = const [],
  }) : newSpeedItems = List.unmodifiable(newSpeedItems),
       statuses = Map.unmodifiable(statuses),
       items = List.unmodifiable(items);
  final ReviewDueMembershipSnapshot review;
  final List<LearningItemRecord> newSpeedItems;
  final List<LearningItemRecord> items;

  /// One status per visible vocabulary entry; empty only for legacy fixtures.
  final Map<String, VocabularyLearningStatus> statuses;
  int get dueCount =>
      review.where((item) => item.regularDue || item.eligibleRetry).length;

  /// Retry items waiting for their gap/deadline; eligible retries count as due.
  int get pendingRetryCount =>
      review.where((item) => !item.regularDue && !item.eligibleRetry).length;
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
    Map<LearningDirection, CollectionDirectionSnapshot>? allDirections,
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
       directions = Map.unmodifiable(directions),
       allDirections = Map.unmodifiable(allDirections ?? directions);
  final CollectionRecord collection;
  final List<VocabularyRecord> allEntries;
  final List<VocabularyRecord> entries;
  final List<CategoryDimensionRecord> categoryDimensions;
  final Map<String, List<CategoryValueRecord>> categoryValues;
  final Map<String, List<CategoryAssignmentRecord>> assignments;
  final Map<LearningDirection, CollectionDirectionSnapshot> directions;
  final Map<LearningDirection, CollectionDirectionSnapshot> allDirections;

  CollectionQuerySnapshot selected(Set<String> ids) {
    final selected = allEntries
        .where(
          (e) =>
              e.collectionId == collection.id && e.active && ids.contains(e.id),
        )
        .toList();
    final activeIds = selected.map((e) => e.id).toSet();
    return CollectionQuerySnapshot(
      collection: collection,
      allEntries: allEntries,
      entries: selected,
      categoryDimensions: categoryDimensions,
      categoryValues: categoryValues,
      assignments: assignments,
      directions: {
        for (final d in allDirections.entries)
          d.key: CollectionDirectionSnapshot(
            review: ReviewDueMembershipSnapshot(
              memberships: d.value.review.where(
                (m) => activeIds.contains(m.entryId),
              ),
              nextChangeAt: d.value.review.nextChangeAt,
            ),
            newSpeedItems: d.value.items.where(
              (i) => activeIds.contains(i.entryId),
            ),
            items: d.value.items.where((i) => activeIds.contains(i.entryId)),
          ),
      },
    );
  }

  DateTime? get allNextChangeAt {
    final times =
        allDirections.values
            .map((d) => d.review.nextChangeAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    return times.firstOrNull;
  }

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
  /// Search is a trimmed NFC/ordinary-lowercase substring of either language,
  /// combined with the category constraints; accents and sharp S stay distinct.
  Future<CollectionQuerySnapshot> query({
    required String collectionId,
    required DateTime at,
    Map<String, Set<String>> filters = const {},
    String search = '',
  });
}
