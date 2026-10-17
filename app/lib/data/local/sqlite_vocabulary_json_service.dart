import 'sqlite_vocabulary_content.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/clock.dart';
import '../learning_item.dart';
import '../categories_repository.dart';
import '../vocabulary_normalization.dart';
import '../vocabulary_json.dart';
import '../vocabulary_content.dart';
import 'piko_database.dart';
import 'sqlite_categories_repository.dart';
import 'sqlite_vocabulary_repository.dart';

part 'sqlite_vocabulary_json_import.dart';

final class SqliteVocabularyJsonService implements VocabularyJsonService {
  SqliteVocabularyJsonService(this.database, {PikoClock? clock})
    : clock = clock ?? database.clock;
  final PikoDatabase database;
  final PikoClock clock;
  final _importIssuer = Object();

  @override
  Future<VocabularyJsonPreview> analyzeImport({
    required String collectionId,
    required String json,
    Set<VocabularyJsonGroup> groups = VocabularyJsonGroup.all,
  }) => _analyzeImport(collectionId: collectionId, json: json, groups: groups);

  @override
  Future<VocabularyJsonApplyResult> applyImport(
    VocabularyJsonPreview preview,
  ) => _applyImport(preview);

  @override
  String sampleJson() => VocabularyJsonFormat.sample;

  @override
  Future<String> exportCollection(
    String collectionId,
  ) => database.transaction(() async {
    final collection = await (database.select(
      database.collections,
    )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
    if (collection == null) {
      throw VocabularyJsonExportFailure.collectionNotFound;
    }
    final exportedAt = clock.now().toUtc().toIso8601String();
    final entries =
        await (database.select(database.vocabularyEntries)
              ..where((row) => row.collectionId.equals(collectionId))
              ..orderBy([
                (_) => OrderingTerm(
                  expression: const CustomExpression<int>('rowid'),
                ),
              ]))
            .get();
    final dimensions =
        await (database.select(database.categoryDimensions)
              ..where((row) => row.collectionId.equals(collectionId))
              ..orderBy([
                (row) => OrderingTerm(expression: row.position),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    final values =
        (await database
                .customSelect(
                  'SELECT v.* FROM category_values v JOIN category_dimensions d ON d.id = v.dimension_id '
                  'WHERE d.collection_id = ? ORDER BY d.position, d.id, v.position, v.id',
                  variables: [Variable(collectionId)],
                )
                .get())
            .map((row) => database.categoryValues.map(row.data))
            .toList(growable: false);
    final assignments =
        (await database
                .customSelect(
                  'SELECT a.* FROM vocabulary_category_assignments a '
                  'JOIN category_dimensions d ON d.id = a.dimension_id JOIN category_values v ON v.id = a.value_id '
                  'WHERE a.collection_id = ? ORDER BY d.position, d.id, v.position, v.id',
                  variables: [Variable(collectionId)],
                )
                .get())
            .map((row) => database.vocabularyCategoryAssignments.map(row.data))
            .toList(growable: false);
    final items =
        (await database
                .customSelect(
                  'SELECT l.* FROM learning_items l JOIN vocabulary_entries v ON v.id = l.entry_id '
                  'WHERE v.collection_id = ? ORDER BY l.id',
                  variables: [Variable(collectionId)],
                )
                .get())
            .map((row) => database.learningItems.map(row.data))
            .toList(growable: false);
    final reviews =
        (await database
                .customSelect(
                  'SELECT r.* FROM regular_reviews r JOIN learning_items l ON l.id = r.item_id '
                  'JOIN vocabulary_entries v ON v.id = l.entry_id WHERE v.collection_id = ? ORDER BY r.rowid',
                  variables: [Variable(collectionId)],
                )
                .get())
            .map((row) => database.regularReviews.map(row.data))
            .toList(growable: false);
    final retries =
        (await database
                .customSelect(
                  'SELECT r.* FROM retry_obligations r JOIN learning_items l ON l.id = r.item_id '
                  'JOIN vocabulary_entries v ON v.id = l.entry_id WHERE v.collection_id = ? ORDER BY r.rowid',
                  variables: [Variable(collectionId)],
                )
                .get())
            .map((row) => database.retryObligations.map(row.data))
            .toList(growable: false);
    final scopes = await (database.select(
      database.scopeAnswerOrdinals,
    )..where((row) => row.collectionId.equals(collectionId))).get();

    final valuesByDimension = <String, List<StoredCategoryValue>>{};
    for (final value in values) {
      valuesByDimension.putIfAbsent(value.dimensionId, () => []).add(value);
    }
    final assignmentsByEntry = <String, Map<String, List<String>>>{};
    for (final assignment in assignments) {
      assignmentsByEntry
          .putIfAbsent(assignment.entryId, () => {})
          .putIfAbsent(assignment.dimensionId, () => [])
          .add(assignment.valueId);
    }
    final itemsByEntry = <String, Map<String, LearningItem>>{};
    for (final item in items) {
      itemsByEntry.putIfAbsent(item.entryId, () => {})[item.direction] = item;
    }
    final reviewsByItem = <int, List<RegularReview>>{};
    for (final review in reviews) {
      reviewsByItem.putIfAbsent(review.itemId, () => []).add(review);
    }
    final retriesByItem = <int, StoredRetryObligation>{};
    for (final retry in retries) {
      if (retriesByItem.containsKey(retry.itemId)) {
        throw VocabularyJsonExportFailure.incompleteLearning;
      }
      retriesByItem[retry.itemId] = retry;
    }

    Map<String, Object?> learning(LearningItem item) {
      // Validate the supported shape, then decode the original JSON directly.
      // FSRS toMap would normalize timestamps/numbers rather than export them.
      LearningCardCodec.decode(
        item.cardJson,
        expectedId: item.id,
        formatVersion: item.formatVersion,
      );
      final retry = retriesByItem[item.id];
      return {
        'id': item.id,
        'formatVersion': item.formatVersion,
        'generation': item.generation,
        'reviewRevision': item.reviewRevision,
        'card': jsonDecode(item.cardJson),
        'reviews': [
          for (final review in reviewsByItem[item.id] ?? <RegularReview>[])
            {
              'id': review.id,
              'generation': review.generation,
              'reviewedAt': review.reviewedAt,
              'rating': review.rating,
            },
        ],
        'retry': retry == null
            ? null
            : {
                'id': retry.id,
                'generation': retry.generation,
                'revision': retry.revision,
                'originReviewId': retry.originReviewId,
                'createdAt': retry.createdAt,
                'expiresAt': retry.expiresAt,
                'waitEligibleAt': retry.waitEligibleAt,
                'errorCount': retry.errorCount,
                'dueOrdinal': retry.dueOrdinal,
              },
        'speedCompleted': item.speedCompleted,
      };
    }

    final examples = await SqliteVocabularyContent(
      database,
    ).forCollection(collectionId);
    final exportedEntries = <Map<String, Object?>>[];
    for (final entry in entries) {
      final directional = itemsByEntry[entry.id];
      if (directional == null ||
          directional.length != LearningDirection.values.length ||
          LearningDirection.values.any(
            (direction) => !directional.containsKey(direction.name),
          )) {
        throw VocabularyJsonExportFailure.incompleteLearning;
      }
      final content = VocabularyContent.fromStored(
        examples: examples[entry.id] ?? const [],
        hintText: entry.hintText,
        hintVisibility: entry.hintVisibility,
      );
      exportedEntries.add({
        'id': entry.id,
        'targetText': entry.targetText,
        'nativeText': entry.nativeText,
        'active': entry.active,
        'examples': [
          for (final pair in content.examples)
            {'targetText': pair.targetText, 'nativeText': pair.nativeText},
        ],
        'addedAt': entry.addedAt,
        'hint': {
          'text': content.hintText,
          'visibility': content.hintVisibility.name,
        },
        'categoryAssignments': [
          for (final group
              in (assignmentsByEntry[entry.id] ?? <String, List<String>>{})
                  .entries)
            {'dimensionId': group.key, 'valueIds': group.value},
        ],
        'learning': {
          for (final direction in LearningDirection.values)
            direction.name: learning(directional[direction.name]!),
        },
      });
    }
    final document = {
      'format': VocabularyJsonFormat.format,
      'schemaVersion': VocabularyJsonFormat.schemaVersion,
      'exportedAt': exportedAt,
      'scheduler': {
        'library': VocabularyJsonFormat.schedulerLibrary,
        'version': VocabularyJsonFormat.schedulerVersion,
        'cardFormatVersion': LearningCardCodec.version,
      },
      'collections': [
        {
          'id': collection.id,
          'name': collection.name,
          'targetLanguage': collection.targetLanguage,
          'nativeLanguage': collection.nativeLanguage,
          'reviewScopes': {
            for (final direction in LearningDirection.values)
              direction.name: switch (scopes
                  .where((scope) => scope.direction == direction.name)
                  .firstOrNull) {
                final scope? => {
                  'ordinal': scope.ordinal,
                  'revision': scope.revision,
                },
                null => null,
              },
          },
          'categoryDimensions': [
            for (final dimension in dimensions)
              {
                'id': dimension.id,
                'name': dimension.name,
                'mode': dimension.mode,
                'values': [
                  for (final value
                      in valuesByDimension[dimension.id] ??
                          <StoredCategoryValue>[])
                    {'id': value.id, 'name': value.name},
                ],
              },
          ],
          'entries': exportedEntries,
        },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  });
}
