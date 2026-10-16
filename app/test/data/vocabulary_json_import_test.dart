import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import '../support/mutable_clock.dart';
import 'speed_eligibility_test.dart' show completeSnapshot;

const newId = 'a99f845c-5ba6-44de-a18f-aedfd69594c5';
const dimensionId = '86ef059c-d7ac-4f97-b762-e7df0c72c4da';
const valueId = 'b48c6efa-6e36-4643-b497-2daf3c9c66ac';
const unusedDimensionId = 'f5eb2713-ea1b-4faf-b58d-3a354d44aeed';
const unusedValueId = '6fb5f08e-6fd0-4995-9931-dbc46a7bdd4d';

String input(
  List<Object?> entries, {
  List<Object?>? definitions,
  Map<String, Object?>? source,
  Map<String, Object?>? envelope,
}) => jsonEncode({
  'format': 'piko-vocabulary',
  'schemaVersion': 1,
  'collections': [
    {
      'targetLanguage': 'fr',
      'nativeLanguage': 'de',
      'entries': entries,
      'categoryDimensions': ?definitions,
      ...?source,
    },
  ],
  ...?envelope,
});
Map<String, Object?> definition({
  String id = dimensionId,
  String name = 'Topic',
  String mode = 'multiple',
  String value = valueId,
  String valueName = 'Food',
}) => {
  'id': id,
  'name': name,
  'mode': mode,
  'values': [
    {'id': value, 'name': valueName},
  ],
};
List<Map<String, Object?>> assignment({
  String dimension = dimensionId,
  Set<String> values = const {valueId},
}) => [
  {'dimensionId': dimension, 'valueIds': values.toList()},
];

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  test(
    'analysis is immutable and read-only; confirmed apply updates by UUID, appends fresh words and preserves complete existing learning',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true, rating: LearningRating.again);
      final current = await f.current();
      await (f.db.update(f.db.learningItems)
            ..where((row) => row.id.equals(current.id)))
          .write(const LearningItemsCompanion(speedCompleted: Value(true)));
      final before = await completeSnapshot(f.db);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input([
          {
            'id': f.entry.id,
            'targetText': ' Changed ',
            'learning': {
              'targetToNative': {'card': 'ignored'},
            },
            'unknown': 'ignored',
          },
          {
            'id': newId,
            'targetText': 'New',
            'nativeText': 'Neu',
            'learning': 'ignored',
          },
          {'targetText': 'Without id', 'nativeText': 'Ohne ID'},
        ]),
      );
      expect(preview.canApply, isTrue);
      expect(preview.newCount, 2);
      expect(preview.updatedCount, 1);
      expect(preview.unchangedCount, 0);
      expect(preview.errorCount, 0);
      expect(preview.notices, {VocabularyJsonNotice.importedLearningIgnored});
      expect(() => preview.groups.clear(), throwsUnsupportedError);
      expect(() => preview.issues.clear(), throwsUnsupportedError);
      expect(await completeSnapshot(f.db), before);
      final result = await service.applyImport(preview);
      expect(result.newCount, 2);
      final entries = await f.vocabulary.watchByCollection(f.owner.id).first;
      expect(entries.map((entry) => entry.targetText), [
        'Changed',
        'New',
        'Without id',
      ]);
      expect(entries[0].id, f.entry.id);
      expect(entries[0].nativeText, f.entry.nativeText);
      expect(entries[1].id, newId);
      final after = await completeSnapshot(f.db);
      for (final table in [
        'app_settings',
        'collections',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
        'category_dimensions',
        'category_values',
        'vocabulary_category_assignments',
      ]) {
        expect(after[table], before[table], reason: '$table unchanged');
      }
      final oldLearning = (before['learning_items'] as List).cast<Map>();
      final oldIds = oldLearning.map((row) => row['id']).toSet();
      expect(
        (after['learning_items'] as List)
            .cast<Map>()
            .where((row) => oldIds.contains(row['id']))
            .toList(),
        oldLearning,
      );
      for (final entry in entries.skip(1)) {
        final learning = await f.learning.forEntry(entry.id);
        expect(learning, hasLength(2));
        for (final item in learning) {
          expect(item.generation, 0);
          expect(item.reviewRevision, 0);
          expect(item.speedCompleted, isFalse);
          expect(item.card.lastReview, isNull);
          expect(item.card.due, instant);
          expect(await f.learning.reviewsForItem(item.id), isEmpty);
        }
      }
      await expectLater(
        service.applyImport(preview),
        throwsA(VocabularyJsonApplyFailure.alreadyApplied),
      );
      expect(
        await f.vocabulary.watchByCollection(f.owner.id).first,
        hasLength(3),
      );
    },
  );

  test(
    'full export reimport and repeated explicit-ID import are idempotent and do not reconstruct learning',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      await f.review(rating: LearningRating.again);
      final before = await completeSnapshot(f.db);
      final exported = await service.exportCollection(f.owner.id);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: exported,
      );
      expect(preview.canApply, isTrue);
      expect(preview.unchangedCount, 1);
      await service.applyImport(preview);
      expect(await completeSnapshot(f.db), before);
      final second = await service.analyzeImport(
        collectionId: f.owner.id,
        json: exported,
      );
      await service.applyImport(second);
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'final-pair validation permits swaps while preserving rowids, display order and directional learning identities',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final other = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Three',
        nativeText: 'Drei',
      );
      await f.review(rating: LearningRating.again);
      final before = await completeSnapshot(f.db);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input([
          {
            'id': f.entry.id,
            'targetText': other.targetText,
            'nativeText': other.nativeText,
          },
          {
            'id': other.id,
            'targetText': f.entry.targetText,
            'nativeText': f.entry.nativeText,
          },
        ]),
      );
      expect(preview.canApply, isTrue);
      expect(preview.updatedCount, 2);
      await service.applyImport(preview);
      final after = await completeSnapshot(f.db);
      for (final table in before.keys.where(
        (table) => table != 'vocabulary_entries',
      )) {
        expect(after[table], before[table], reason: table);
      }
      final oldRows = (before['vocabulary_entries'] as List).cast<Map>();
      final newRows = (after['vocabulary_entries'] as List).cast<Map>();
      expect(
        newRows.map(
          (row) => (row['id'], row['original_rowid'] ?? row['stored_rowid']),
        ),
        oldRows.map(
          (row) => (row['id'], row['original_rowid'] ?? row['stored_rowid']),
        ),
      );
      final words = await f.vocabulary.watchByCollection(f.owner.id).first;
      expect(words.map((word) => word.id), [f.entry.id, other.id]);
      expect(words.map((word) => (word.targetText, word.nativeText)), [
        ('Three', 'Drei'),
        ('One', 'Eins'),
      ]);
      final collision = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input([
          {'id': other.id, 'targetText': 'Three', 'nativeText': 'Drei'},
        ]),
      );
      expect(
        collision.issues.map((issue) => issue.code),
        contains(VocabularyJsonIssueCode.duplicatePair),
      );
      expect(collision.issues.single.row, 1);
    },
  );

  test(
    'selected groups preserve omitted and unselected fields, explicit empty assignments clear, and all new words still need both texts',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final value = await categories.createValue(
        dimensionId: dimension.id,
        name: 'Food',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          dimension.id: {value.id},
        },
      );
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        groups: {VocabularyJsonGroup.nativeText},
        json: input(
          [
            {
              'id': f.entry.id,
              'targetText': null,
              'nativeText': ' Neue ',
              'categoryAssignments': 'ignored',
            },
          ],
          source: {'categoryDimensions': 'ignored'},
        ),
      );
      expect(preview.canApply, isTrue);
      await service.applyImport(preview);
      final word = await f.vocabulary.watchById(f.entry.id).first;
      expect(word!.targetText, f.entry.targetText);
      expect(word.nativeText, 'Neue');
      expect((await categories.assignments(f.entry.id)).single.valueIds, {
        value.id,
      });
      final omitted = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input([
          {'id': f.entry.id},
        ]),
      );
      expect(omitted.unchangedCount, 1);
      await service.applyImport(omitted);
      final clear = await service.analyzeImport(
        collectionId: f.owner.id,
        groups: {VocabularyJsonGroup.categoryAssignments},
        json: input([
          {'id': f.entry.id, 'categoryAssignments': []},
        ]),
      );
      expect(clear.updatedCount, 1);
      await service.applyImport(clear);
      expect(await categories.assignments(f.entry.id), isEmpty);
      final incomplete = await service.analyzeImport(
        collectionId: f.owner.id,
        groups: {VocabularyJsonGroup.nativeText},
        json: input([
          {'nativeText': 'Required target too'},
        ]),
      );
      expect(
        incomplete.issues.map((issue) => issue.code),
        contains(VocabularyJsonIssueCode.requiredTarget),
      );
    },
  );

  test(
    'UUID validation blocks foreign IDs, repeated canonical IDs and text matching',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final before = await completeSnapshot(f.db);
      for (final (entries, code) in [
        (
          [
            {'id': f.other.id, 'targetText': 'Foreign', 'nativeText': 'Fremd'},
          ],
          VocabularyJsonIssueCode.foreignId,
        ),
        (
          [
            {'id': 'invalid', 'targetText': 'Valid', 'nativeText': 'Gültig'},
          ],
          VocabularyJsonIssueCode.invalidId,
        ),
        (
          [
            {'id': f.entry.id},
            {'id': f.entry.id.toUpperCase()},
          ],
          VocabularyJsonIssueCode.duplicateId,
        ),
        (
          [
            {
              'targetText': f.entry.targetText,
              'nativeText': f.entry.nativeText,
            },
          ],
          VocabularyJsonIssueCode.duplicatePair,
        ),
      ]) {
        final preview = await service.analyzeImport(
          collectionId: f.owner.id,
          json: input(entries),
        );
        expect(preview.canApply, isFalse);
        expect(preview.issues.map((issue) => issue.code), contains(code));
        await expectLater(
          service.applyImport(preview),
          throwsA(VocabularyJsonApplyFailure.invalidPreview),
        );
        expect(await completeSnapshot(f.db), before);
      }
    },
  );

  test(
    'byte limit precedes parse; envelope, exactly-one-Collection, version and language errors are actionable and read-only',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final before = await completeSnapshot(f.db);
      for (final (json, code) in [
        (
          '"${List.filled(500001, 'ä').join()}"',
          VocabularyJsonIssueCode.tooLarge,
        ),
        ('{not json}', VocabularyJsonIssueCode.invalidJson),
        ('[]', VocabularyJsonIssueCode.invalidEnvelope),
        (
          input([], envelope: {'format': 'other'}),
          VocabularyJsonIssueCode.unsupportedFormat,
        ),
        (
          input([], envelope: {'schemaVersion': 3}),
          VocabularyJsonIssueCode.unsupportedVersion,
        ),
        (
          input([], envelope: {'schemaVersion': 1.0}),
          VocabularyJsonIssueCode.unsupportedVersion,
        ),
        (
          input([], envelope: {'collections': []}),
          VocabularyJsonIssueCode.exactlyOneCollection,
        ),
        (
          input(
            [],
            envelope: {
              'collections': [{}, {}],
            },
          ),
          VocabularyJsonIssueCode.exactlyOneCollection,
        ),
        (
          input([], source: {'targetLanguage': 'de', 'nativeLanguage': 'fr'}),
          VocabularyJsonIssueCode.languageMismatch,
        ),
        (
          input([
            {'id': f.entry.id, 'targetText': ' \n '},
          ]),
          VocabularyJsonIssueCode.requiredTarget,
        ),
      ]) {
        final preview = await service.analyzeImport(
          collectionId: f.owner.id,
          json: json,
        );
        expect(preview.issues.map((issue) => issue.code), contains(code));
        expect(preview.canApply, isFalse);
        expect(await completeSnapshot(f.db), before);
      }
      final missing = await service.analyzeImport(
        collectionId: 'missing',
        json: input([]),
      );
      expect(
        missing.issues.single.code,
        VocabularyJsonIssueCode.collectionNotFound,
      );
    },
  );

  test(
    'only referenced new definitions/values are created; explicit UUIDs resolve, existing metadata wins and assignments use destination mode',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final categories = SqliteCategoriesRepository(f.db);
      final existing = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Local',
        mode: CategoryMode.single,
      );
      final existingValue = await categories.createValue(
        dimensionId: existing.id,
        name: 'Local value',
      );
      final json = input(
        [
          {
            'id': f.entry.id,
            'categoryAssignments': [
              ...assignment(),
              ...assignment(dimension: existing.id, values: {existingValue.id}),
            ],
          },
        ],
        definitions: [
          definition(),
          definition(
            id: unusedDimensionId,
            name: 'Unused',
            value: unusedValueId,
          ),
          definition(
            id: existing.id,
            name: 'Imported rename',
            mode: 'multiple',
            value: existingValue.id,
            valueName: 'Imported value rename',
          ),
        ],
      );
      final before = await completeSnapshot(f.db);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: json,
      );
      expect(preview.canApply, isTrue);
      expect(preview.notices, {
        VocabularyJsonNotice.destinationCategoryMetadataRetained,
      });
      expect(await completeSnapshot(f.db), before);
      await service.applyImport(preview);
      expect((await categories.dimensionById(existing.id))!.name, 'Local');
      expect(
        (await categories.dimensionById(existing.id))!.mode,
        CategoryMode.single,
      );
      expect(
        (await categories.valueById(existingValue.id))!.name,
        'Local value',
      );
      expect((await categories.dimensionById(dimensionId))!.name, 'Topic');
      expect((await categories.valueById(valueId))!.dimensionId, dimensionId);
      expect(await categories.dimensionById(unusedDimensionId), isNull);
      expect(await categories.valueById(unusedValueId), isNull);
      expect(
        (await categories.assignments(
          f.entry.id,
        )).map((group) => group.dimensionId).toSet(),
        {existing.id, dimensionId},
      );
      final unselected = await service.analyzeImport(
        collectionId: f.owner.id,
        groups: {VocabularyJsonGroup.targetText},
        json: input(
          [
            {'id': f.entry.id},
          ],
          definitions: [
            definition(id: unusedDimensionId, value: unusedValueId),
          ],
        ),
      );
      await service.applyImport(unselected);
      expect(await categories.dimensionById(unusedDimensionId), isNull);
    },
  );

  test(
    'category unknown references, ownership, duplicate names and destination cardinality block the entire batch',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final categories = SqliteCategoriesRepository(f.db);
      final local = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.single,
      );
      final one = await categories.createValue(
        dimensionId: local.id,
        name: 'Food',
      );
      final two = await categories.createValue(
        dimensionId: local.id,
        name: 'Travel',
      );
      final foreign = await categories.createDimension(
        collectionId: f.kept.id,
        name: 'Foreign',
        mode: CategoryMode.multiple,
      );
      final foreignValue = await categories.createValue(
        dimensionId: foreign.id,
        name: 'Foreign',
      );
      final before = await completeSnapshot(f.db);
      for (final (groups, definitions, code) in [
        (assignment(), <Object?>[], VocabularyJsonIssueCode.unknownDimension),
        (
          assignment(dimension: local.id),
          <Object?>[],
          VocabularyJsonIssueCode.unknownValue,
        ),
        (
          assignment(dimension: foreign.id, values: {foreignValue.id}),
          <Object?>[],
          VocabularyJsonIssueCode.invalidOwnership,
        ),
        (
          assignment(dimension: local.id, values: {foreignValue.id}),
          <Object?>[],
          VocabularyJsonIssueCode.invalidOwnership,
        ),
        (
          assignment(dimension: local.id, values: {one.id, two.id}),
          [definition(id: local.id, mode: 'multiple', value: one.id)],
          VocabularyJsonIssueCode.cardinalityViolation,
        ),
        (
          assignment(),
          [definition(name: ' tOPIC ')],
          VocabularyJsonIssueCode.duplicateName,
        ),
        (
          assignment(dimension: local.id),
          [definition(id: local.id, name: 'Topic', valueName: ' food ')],
          VocabularyJsonIssueCode.duplicateName,
        ),
      ]) {
        final preview = await service.analyzeImport(
          collectionId: f.owner.id,
          json: input([
            {'id': f.entry.id, 'categoryAssignments': groups},
          ], definitions: definitions),
        );
        expect(preview.issues.map((issue) => issue.code), contains(code));
        expect(preview.canApply, isFalse);
        expect(await completeSnapshot(f.db), before);
      }
    },
  );

  test(
    'stale destination content, learning and category mode are rejected; fresh analysis is recoverable',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final json = input([
        {'id': f.entry.id, 'targetText': 'Proposed'},
      ]);
      final first = await service.analyzeImport(
        collectionId: f.owner.id,
        json: json,
      );
      await f.vocabulary.update(
        id: f.entry.id,
        targetText: 'External edit',
        nativeText: f.entry.nativeText,
      );
      final changed = await completeSnapshot(f.db);
      await expectLater(
        service.applyImport(first),
        throwsA(VocabularyJsonApplyFailure.stalePreview),
      );
      expect(await completeSnapshot(f.db), changed);
      final second = await service.analyzeImport(
        collectionId: f.owner.id,
        json: json,
      );
      await f.review(rating: LearningRating.good);
      final reviewed = await completeSnapshot(f.db);
      await expectLater(
        service.applyImport(second),
        throwsA(VocabularyJsonApplyFailure.stalePreview),
      );
      expect(await completeSnapshot(f.db), reviewed);
      final fresh = await service.analyzeImport(
        collectionId: f.owner.id,
        json: json,
      );
      await service.applyImport(fresh);
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.targetText,
        'Proposed',
      );
    },
  );

  test(
    'revalidation catches foreign UUID ownership acquired after preview and previews cannot cross service issuers',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final json = input([
        {'id': newId, 'targetText': 'New', 'nativeText': 'Neu'},
      ]);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: json,
      );
      await expectLater(
        SqliteVocabularyJsonService(f.db).applyImport(preview),
        throwsA(VocabularyJsonApplyFailure.invalidPreview),
      );
      final foreign = await service.analyzeImport(
        collectionId: f.kept.id,
        json: json,
      );
      await service.applyImport(foreign);
      final before = await completeSnapshot(f.db);
      await expectLater(
        service.applyImport(preview),
        throwsA(VocabularyJsonApplyFailure.stalePreview),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'late database failure rolls back temporary keys, definitions, text edits, new learning and allocators; same preview can retry',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      await f.review(rating: LearningRating.again);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input(
          [
            {
              'id': f.entry.id,
              'targetText': 'Changed',
              'categoryAssignments': assignment(),
            },
            {'id': newId, 'targetText': 'New', 'nativeText': 'Neu'},
          ],
          definitions: [definition()],
        ),
      );
      expect(preview.canApply, isTrue);
      final before = await completeSnapshot(f.db);
      await f.db.customStatement(
        "CREATE TRIGGER import_failure BEFORE INSERT ON vocabulary_entries BEGIN SELECT RAISE(FAIL,'injected import failure'); END",
      );
      await expectLater(
        service.applyImport(preview),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await completeSnapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER import_failure');
      final applied = await service.applyImport(preview);
      expect(applied.updatedCount, 1);
      expect(applied.newCount, 1);
      expect(
        (await SqliteCategoriesRepository(f.db).dimensionById(dimensionId))!.id,
        dimensionId,
      );
    },
  );

  test(
    'simultaneous apply of one ID-less preview is single-flight and cannot duplicate entries',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input([
          {'targetText': 'New', 'nativeText': 'Neu'},
        ]),
      );
      final first = service.applyImport(preview);
      await expectLater(
        service.applyImport(preview),
        throwsA(VocabularyJsonApplyFailure.inProgress),
      );
      await first;
      expect(
        await f.vocabulary.watchByCollection(f.owner.id).first,
        hasLength(2),
      );
    },
  );

  test(
    'final pair comparison uses canonical Unicode lowercase/NFC and retains sharp-S versus ss',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final word = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Straße',
        nativeText: 'École',
      );
      final duplicate = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input([
          {'targetText': ' STRAẞE ', 'nativeText': 'E\u0301COLE'},
        ]),
      );
      expect(
        duplicate.issues.map((issue) => issue.code),
        contains(VocabularyJsonIssueCode.duplicatePair),
      );
      final distinct = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input([
          {
            'id': newId,
            'targetText': ' Strasse ',
            'nativeText': ' E\u0301cole ',
          },
        ]),
      );
      expect(distinct.canApply, isTrue);
      await service.applyImport(distinct);
      final words = await f.vocabulary.watchByCollection(f.owner.id).first;
      expect(
        words.singleWhere((entry) => entry.id == newId).targetText,
        'Strasse',
      );
      expect(
        words.singleWhere((entry) => entry.id == newId).nativeText,
        'École',
      );
      expect(
        words.singleWhere((entry) => entry.id == word.id).targetText,
        'Straße',
      );
    },
  );

  test(
    'new values in existing dimensions are referenced-only and empty groups do not create definitions',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Local',
        mode: CategoryMode.single,
      );
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input(
          [
            {
              'id': f.entry.id,
              'categoryAssignments': [
                ...assignment(dimension: dimension.id),
                ...assignment(dimension: unusedDimensionId, values: {}),
              ],
            },
          ],
          definitions: [
            definition(id: dimension.id, name: 'Ignored name'),
            definition(
              id: unusedDimensionId,
              name: 'Unused',
              value: unusedValueId,
            ),
          ],
        ),
      );
      expect(preview.canApply, isTrue);
      await service.applyImport(preview);
      expect((await categories.values(dimension.id)).single.id, valueId);
      expect((await categories.assignments(f.entry.id)).single.valueIds, {
        valueId,
      });
      expect(await categories.dimensionById(unusedDimensionId), isNull);
    },
  );

  test(
    'changing destination cardinality after analysis rejects the confirmed plan without losing assignments',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final categories = SqliteCategoriesRepository(f.db);
      final dimension = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Local',
        mode: CategoryMode.multiple,
      );
      final one = await categories.createValue(
        dimensionId: dimension.id,
        name: 'One',
      );
      final two = await categories.createValue(
        dimensionId: dimension.id,
        name: 'Two',
      );
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input([
          {
            'id': f.entry.id,
            'categoryAssignments': assignment(
              dimension: dimension.id,
              values: {one.id, two.id},
            ),
          },
        ]),
      );
      expect(preview.canApply, isTrue);
      await categories.updateDimension(
        id: dimension.id,
        name: dimension.name,
        mode: CategoryMode.single,
      );
      final before = await completeSnapshot(f.db);
      await expectLater(
        service.applyImport(preview),
        throwsA(VocabularyJsonApplyFailure.stalePreview),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'empty replacement groups reject a valid new row with an actionable issue and no writes',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final before = await completeSnapshot(f.db);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        groups: {},
        json: input([
          {'targetText': 'New', 'nativeText': 'Neu'},
        ]),
      );
      expect(preview.canApply, isFalse);
      expect(
        preview.issues.single.code,
        VocabularyJsonIssueCode.groupsRequired,
      );
      expect(preview.issues.single.path, 'groups');
      await expectLater(
        service.applyImport(preview),
        throwsA(VocabularyJsonApplyFailure.invalidPreview),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'failure during the second directional learning insertion rolls back the complete import and leaves its preview retryable',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      await f.review(rating: LearningRating.again);
      final before = await completeSnapshot(f.db);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: input(
          [
            {
              'id': f.entry.id,
              'targetText': 'Changed',
              'categoryAssignments': assignment(),
            },
            {'id': newId, 'targetText': 'New', 'nativeText': 'Neu'},
          ],
          definitions: [definition()],
        ),
      );
      expect(preview.canApply, isTrue);
      await f.db.customStatement(
        "CREATE TRIGGER second_learning_failure BEFORE INSERT ON learning_items "
        "WHEN NEW.direction = 'nativeToTarget' "
        "BEGIN SELECT RAISE(FAIL,'injected second learning insertion failure'); END",
      );
      await expectLater(
        service.applyImport(preview),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await completeSnapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER second_learning_failure');
      final applied = await service.applyImport(preview);
      expect(applied.newCount, 1);
      expect(applied.updatedCount, 1);
      expect(await f.learning.forEntry(newId), hasLength(2));
      final committed = await completeSnapshot(f.db);
      final oldIds = (before['learning_items'] as List)
          .cast<Map>()
          .map((row) => row['id'])
          .toSet();
      expect(
        (committed['learning_items'] as List)
            .cast<Map>()
            .where((row) => oldIds.contains(row['id']))
            .toList(),
        before['learning_items'],
      );
      await expectLater(
        service.applyImport(preview),
        throwsA(VocabularyJsonApplyFailure.alreadyApplied),
      );
    },
  );

  test(
    'committed import persists categories, UUID order and untouched learning across file reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-json-import-',
      );
      final file = File('${directory.path}/import.sqlite');
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: MutablePikoClock(instant),
      );
      try {
        final f = Fixture(database: db);
        await f.initialize();
        await f.review(rating: LearningRating.again);
        final service = SqliteVocabularyJsonService(db);
        final preview = await service.analyzeImport(
          collectionId: f.owner.id,
          json: input(
            [
              {'id': f.entry.id, 'targetText': 'Updated'},
              {
                'id': newId,
                'targetText': 'New',
                'nativeText': 'Neu',
                'categoryAssignments': assignment(),
              },
            ],
            definitions: [definition()],
          ),
        );
        await service.applyImport(preview);
        final expected = await completeSnapshot(db);
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: MutablePikoClock(instant),
        );
        expect(await completeSnapshot(db), expected);
        final reopened = SqliteVocabularyJsonService(db);
        final export = await reopened.exportCollection(f.owner.id);
        final repeated = await reopened.analyzeImport(
          collectionId: f.owner.id,
          json: export,
        );
        expect(repeated.newCount, 0);
        expect(repeated.updatedCount, 0);
        expect(repeated.unchangedCount, 2);
        await reopened.applyImport(repeated);
        expect(await completeSnapshot(db), expected);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
