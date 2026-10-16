import 'package:drift/drift.dart';
import '../categories_repository.dart';
import '../collection_query.dart';
import '../collections_repository.dart';
import '../learning_item.dart';
import '../vocabulary_repository.dart';
import '../vocabulary_learning_status.dart';
import '../vocabulary_normalization.dart';
import 'piko_database.dart';
import 'sqlite_categories_repository.dart';
import 'sqlite_learning_repository.dart';

final class SqliteCollectionQueryService implements CollectionQueryService {
  SqliteCollectionQueryService(this.database);
  final PikoDatabase database;

  @override
  Future<CollectionQuerySnapshot> query({
    required String collectionId,
    required DateTime at,
    Map<String, Set<String>> filters = const {},
    String search = '',
  }) {
    if (!at.isUtc) {
      return Future.error(ArgumentError.value(at, 'at', 'Must be UTC'));
    }
    final selected = {
      for (final group in filters.entries)
        if (group.value.isNotEmpty) group.key: Set<String>.of(group.value),
    };
    final searchKey = vocabularyComparisonKey(search);
    return database.transaction(() async {
      final owner = await (database.select(
        database.collections,
      )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
      if (owner == null) throw CollectionQueryFailure.collectionNotFound;
      final entries =
          (await (database.select(database.vocabularyEntries)
                    ..where((row) => row.collectionId.equals(collectionId))
                    ..orderBy([
                      (_) => OrderingTerm(
                        expression: const CustomExpression<int>('rowid'),
                      ),
                    ]))
                  .get())
              .map(
                (row) => VocabularyRecord(
                  id: row.id,
                  collectionId: row.collectionId,
                  targetText: row.targetText,
                  nativeText: row.nativeText,
                ),
              )
              .toList(growable: false);
      final categories = SqliteCategoriesRepository(database);
      final dimensions = await categories.dimensions(collectionId);
      final dimensionIds = dimensions.map((dimension) => dimension.id).toSet();
      final values = <String, List<CategoryValueRecord>>{};
      final valueIds = <String, Set<String>>{};
      for (final dimension in dimensions) {
        values[dimension.id] = await categories.values(dimension.id);
        valueIds[dimension.id] = values[dimension.id]!
            .map((value) => value.id)
            .toSet();
      }
      for (final group in selected.entries) {
        if (!dimensionIds.contains(group.key) ||
            !valueIds[group.key]!.containsAll(group.value)) {
          throw CollectionQueryFailure.invalidFilter;
        }
      }
      final rawAssignments = await (database.select(
        database.vocabularyCategoryAssignments,
      )..where((row) => row.collectionId.equals(collectionId))).get();
      final grouped = <String, Map<String, Set<String>>>{};
      final entryIds = entries.map((entry) => entry.id).toSet();
      for (final assignment in rawAssignments) {
        if (!entryIds.contains(assignment.entryId) ||
            !dimensionIds.contains(assignment.dimensionId) ||
            !valueIds[assignment.dimensionId]!.contains(assignment.valueId)) {
          throw const FormatException(
            'Invalid Collection category assignment ownership',
          );
        }
        grouped
            .putIfAbsent(assignment.entryId, () => {})
            .putIfAbsent(assignment.dimensionId, () => <String>{})
            .add(assignment.valueId);
      }
      final assignments = <String, List<CategoryAssignmentRecord>>{};
      for (final entry in entries) {
        assignments[entry.id] = [];
        for (final dimension in dimensions) {
          final assigned = grouped[entry.id]?[dimension.id];
          if (assigned == null || assigned.isEmpty) continue;
          if (dimension.mode == CategoryMode.single && assigned.length > 1) {
            throw const FormatException('Invalid Single category assignments');
          }
          assignments[entry.id]!.add(
            CategoryAssignmentRecord(
              dimensionId: dimension.id,
              valueIds: {
                for (final value in values[dimension.id]!)
                  if (assigned.contains(value.id)) value.id,
              },
            ),
          );
        }
      }
      final visible = entries
          .where(
            (entry) =>
                (searchKey.isEmpty ||
                    vocabularyComparisonKey(
                      entry.targetText,
                    ).contains(searchKey) ||
                    vocabularyComparisonKey(
                      entry.nativeText,
                    ).contains(searchKey)) &&
                selected.entries.every(
                  (group) =>
                      grouped[entry.id]?[group.key]?.any(
                        group.value.contains,
                      ) ??
                      false,
                ),
          )
          .toList(growable: false);
      final visibleIds = visible.map((entry) => entry.id).toSet();
      final learning = SqliteLearningRepository(database);
      final reviewedItemIds =
          (await database
                  .customSelect(
                    'SELECT DISTINCT r.item_id FROM regular_reviews r '
                    'JOIN learning_items l ON l.id = r.item_id AND l.generation = r.generation '
                    'JOIN vocabulary_entries v ON v.id = l.entry_id '
                    'WHERE v.collection_id = ?',
                    variables: [Variable(collectionId)],
                  )
                  .get())
              .map((row) => row.read<int>('item_id'))
              .toSet();
      final retryExpiries = {
        for (final row
            in await database
                .customSelect(
                  'SELECT r.item_id, r.expires_at FROM retry_obligations r '
                  'JOIN learning_items l ON l.id = r.item_id AND l.generation = r.generation '
                  'JOIN vocabulary_entries v ON v.id = l.entry_id '
                  'WHERE v.collection_id = ?',
                  variables: [Variable(collectionId)],
                )
                .get())
          row.read<int>('item_id'): row.read<String>('expires_at'),
      };
      final directions = <LearningDirection, CollectionDirectionSnapshot>{};
      for (final direction in LearningDirection.values) {
        // Missing/corrupt learning never becomes a successful zero-work state,
        // even when the current filters hide the damaged vocabulary.
        final unfiltered = await learning.forCollection(
          collectionId: collectionId,
          direction: direction,
        );
        final allItems = await unfiltered.items();
        if (allItems.length != entries.length ||
            !allItems
                .map((item) => item.entryId)
                .toSet()
                .containsAll(entryIds)) {
          throw CollectionQueryFailure.incompleteLearning;
        }
        final scoped = await learning.forCollection(
          collectionId: collectionId,
          direction: direction,
          entryIds: visibleIds,
        );
        // This authoritative passive read validates scoped retry origins and
        // timestamps, ignores expired rounds without deleting them, and owns
        // the next invalidation boundary for retries and future regular due.
        final membership = await scoped.dueMemberships(at: at);
        final dueByItem = {for (final item in membership) item.itemId: item};
        directions[direction] = CollectionDirectionSnapshot(
          review: membership,
          newSpeedItems: await scoped.newSpeedItems(),
          statuses: {
            for (final item in allItems.where(
              (item) => visibleIds.contains(item.entryId),
            ))
              item.entryId: VocabularyLearningStatus.project(
                item: item,
                hasCurrentNormalReview: reviewedItemIds.contains(item.id),
                // Read actual retry presence rather than infer it from a
                // regular-due flag: a retry takes priority even if both apply.
                hasPendingRetry:
                    retryExpiries.containsKey(item.id) &&
                    at.isBefore(DateTime.parse(retryExpiries[item.id]!)),
                isRegularDue: dueByItem[item.id]?.regularDue ?? false,
              ),
          },
        );
      }
      return CollectionQuerySnapshot(
        collection: CollectionRecord(
          id: owner.id,
          name: owner.name,
          targetLanguage: VocabularyLanguage.values.singleWhere(
            (language) => language.code == owner.targetLanguage,
          ),
          nativeLanguage: VocabularyLanguage.values.singleWhere(
            (language) => language.code == owner.nativeLanguage,
          ),
        ),
        allEntries: entries,
        entries: visible,
        categoryDimensions: dimensions,
        categoryValues: values,
        assignments: assignments,
        directions: directions,
      );
    });
  }
}
