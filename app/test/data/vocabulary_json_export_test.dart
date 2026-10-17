import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'speed_eligibility_test.dart' show completeSnapshot;

Map<String, dynamic> document(String json) =>
    jsonDecode(json) as Map<String, dynamic>;
Map<String, dynamic> onlyCollection(Map<String, dynamic> json) =>
    (json['collections'] as List).single as Map<String, dynamic>;

void main() {
  late Fixture f;
  late SqliteVocabularyJsonService service;
  setUp(() async {
    f = Fixture();
    await f.initialize();
    service = SqliteVocabularyJsonService(f.db);
  });
  tearDown(() => f.db.close());

  test(
    'full snapshot exports every persisted learning field, exact timestamps and expired obligations without mutation',
    () async {
      await f.review(
        rating: LearningRating.good,
        at: instant.subtract(const Duration(days: 2)),
      );
      final forward = await f.current();
      await (f.db.update(
        f.db.learningItems,
      )..where((row) => row.id.equals(forward.id))).write(
        const LearningItemsCompanion(
          generation: Value(7),
          reviewRevision: Value(9),
          speedCompleted: Value(true),
        ),
      );
      final retry = (await f.review(rating: LearningRating.again)).retryNext!;
      await f.review(reverse: true, rating: LearningRating.again);
      final source = await f.learning.forCollection(
        collectionId: f.owner.id,
        direction: LearningDirection.targetToNative,
      );
      await source.armBlockedWaits(
        expectedRounds: [retry],
        remainingRegular: [],
        at: instant.add(const Duration(seconds: 2)),
      );
      await SqliteSettingsRepository(f.db).write('locale', 'de');
      await SqliteSettingsRepository(
        f.db,
      ).write('private.preference', 'DO_NOT_EXPORT');
      (f.db.clock as MutablePikoClock).advance(const Duration(days: 3));
      final before = await completeSnapshot(f.db);
      final encoded = await service.exportCollection(f.owner.id);
      final result = document(encoded);
      expect(result.keys.toSet(), {
        'format',
        'schemaVersion',
        'exportedAt',
        'scheduler',
        'collections',
      });
      expect(result['format'], 'piko-vocabulary');
      expect(result['schemaVersion'], VocabularyJsonFormat.schemaVersion);
      expect(
        result['exportedAt'],
        instant.add(const Duration(days: 3)).toIso8601String(),
      );
      expect(result['scheduler'], {
        'library': 'fsrs',
        'version': '2.0.1',
        'cardFormatVersion': 1,
      });
      final collection = onlyCollection(result);
      expect(collection.keys.toSet(), {
        'id',
        'name',
        'targetLanguage',
        'nativeLanguage',
        'reviewScopes',
        'categoryDimensions',
        'entries',
      });
      expect(collection['id'], f.owner.id);
      expect(collection['name'], f.owner.name);
      expect(collection['targetLanguage'], 'fr');
      expect(collection['nativeLanguage'], 'de');
      final scopes = await f.db.select(f.db.scopeAnswerOrdinals).get();
      expect(collection['reviewScopes'], {
        for (final scope in scopes.where(
          (scope) => scope.collectionId == f.owner.id,
        ))
          scope.direction: {
            'ordinal': scope.ordinal,
            'revision': scope.revision,
          },
      });
      final entry =
          (collection['entries'] as List).single as Map<String, dynamic>;
      expect(entry.keys.toSet(), {
        'id',
        'targetText',
        'nativeText',
        'examples',
        'addedAt',
        'active',
        'hint',
        'categoryAssignments',
        'learning',
      });
      expect(entry['id'], f.entry.id);
      expect(entry['targetText'], f.entry.targetText);
      expect(entry['nativeText'], f.entry.nativeText);
      expect(entry['categoryAssignments'], isEmpty);
      expect(entry['examples'], isEmpty);
      expect(entry['addedAt'], instant.toUtc().toIso8601String());
      expect(entry['hint'], {'text': null, 'visibility': 'hidden'});
      final learning = entry['learning'] as Map<String, dynamic>;
      expect(learning.keys.toSet(), {'targetToNative', 'nativeToTarget'});
      final items = await (f.db.select(
        f.db.learningItems,
      )..where((row) => row.entryId.equals(f.entry.id))).get();
      for (final item in items) {
        final storedReviews = await (f.db.select(
          f.db.regularReviews,
        )..where((row) => row.itemId.equals(item.id))).get();
        final storedRetry = await (f.db.select(
          f.db.retryObligations,
        )..where((row) => row.itemId.equals(item.id))).getSingle();
        expect(learning[item.direction], {
          'id': item.id,
          'formatVersion': item.formatVersion,
          'generation': item.generation,
          'reviewRevision': item.reviewRevision,
          'card': jsonDecode(item.cardJson),
          'reviews': [
            for (final review in storedReviews)
              {
                'id': review.id,
                'generation': review.generation,
                'reviewedAt': review.reviewedAt,
                'rating': review.rating,
              },
          ],
          'retry': {
            'id': storedRetry.id,
            'generation': storedRetry.generation,
            'revision': storedRetry.revision,
            'originReviewId': storedRetry.originReviewId,
            'createdAt': storedRetry.createdAt,
            'expiresAt': storedRetry.expiresAt,
            'waitEligibleAt': storedRetry.waitEligibleAt,
            'errorCount': storedRetry.errorCount,
            'dueOrdinal': storedRetry.dueOrdinal,
          },
          'speedCompleted': item.speedCompleted,
        });
      }
      expect(
        ((learning['targetToNative'] as Map)['reviews'] as List).map(
          (row) => (row as Map)['generation'],
        ),
        [0, 7],
      );
      expect(
        ((learning['targetToNative'] as Map)['retry'] as Map)['waitEligibleAt'],
        instant.add(const Duration(seconds: 12)).toIso8601String(),
      );
      expect(encoded, isNot(contains('DO_NOT_EXPORT')));
      for (final key in [
        'target_key',
        'native_key',
        'rowid',
        'next_id',
        'next_row_id',
        'app_settings',
        'entryId',
        'itemId',
        'collectionId',
      ]) {
        expect(encoded, isNot(contains('"$key"')));
      }
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'definitions and assignments keep their UUID/order and do not include another Collection',
    () async {
      final categories = SqliteCategoriesRepository(f.db);
      final topic = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final unit = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Unit',
        mode: CategoryMode.single,
      );
      final food = await categories.createValue(
        dimensionId: topic.id,
        name: 'Food',
      );
      final travel = await categories.createValue(
        dimensionId: topic.id,
        name: 'Travel',
      );
      final one = await categories.createValue(
        dimensionId: unit.id,
        name: 'One',
      );
      final foreign = await categories.createDimension(
        collectionId: f.kept.id,
        name: 'FOREIGN_DEFINITION',
        mode: CategoryMode.single,
      );
      await categories.createValue(
        dimensionId: foreign.id,
        name: 'FOREIGN_VALUE',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          unit.id: {one.id},
          topic.id: {travel.id, food.id},
        },
      );
      final before = await completeSnapshot(f.db);
      final encoded = await service.exportCollection(f.owner.id);
      final collection = onlyCollection(document(encoded));
      expect(collection['categoryDimensions'], [
        {
          'id': topic.id,
          'name': 'Topic',
          'mode': 'multiple',
          'values': [
            {'id': food.id, 'name': 'Food'},
            {'id': travel.id, 'name': 'Travel'},
          ],
        },
        {
          'id': unit.id,
          'name': 'Unit',
          'mode': 'single',
          'values': [
            {'id': one.id, 'name': 'One'},
          ],
        },
      ]);
      expect(
        ((collection['entries'] as List).single as Map)['categoryAssignments'],
        [
          {
            'dimensionId': topic.id,
            'valueIds': [food.id, travel.id],
          },
          {
            'dimensionId': unit.id,
            'valueIds': [one.id],
          },
        ],
      );
      expect(encoded, isNot(contains('FOREIGN_')));
      expect(encoded, isNot(contains(f.kept.id)));
      expect(encoded, isNot(contains(f.other.id)));
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'vocabulary array follows retained display order after delete, append and Undo',
    () async {
      final second = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Second',
        nativeText: 'Zweite',
      );
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      final third = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Third',
        nativeText: 'Dritte',
      );
      await deletion.restore(receipt);
      final collection = onlyCollection(
        document(await service.exportCollection(f.owner.id)),
      );
      expect((collection['entries'] as List).map((row) => (row as Map)['id']), [
        f.entry.id,
        second.id,
        third.id,
      ]);
      expect(collection['reviewScopes'], {
        'targetToNative': null,
        'nativeToTarget': null,
      });
      for (final entry in collection['entries'] as List) {
        for (final item in ((entry as Map)['learning'] as Map).values) {
          expect((item as Map)['reviews'], isEmpty);
          expect(item['retry'], isNull);
          expect(item['speedCompleted'], isFalse);
        }
      }
    },
  );

  test(
    'an empty Collection exports an empty entries array while a missing UUID fails without writing',
    () async {
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      final before = await completeSnapshot(f.db);
      final collection = onlyCollection(
        document(await service.exportCollection(f.owner.id)),
      );
      expect(collection['entries'], isEmpty);
      expect(collection['categoryDimensions'], isEmpty);
      await expectLater(
        service.exportCollection('missing'),
        throwsA(VocabularyJsonExportFailure.collectionNotFound),
      );
      expect(await completeSnapshot(f.db), before);
      expect(deletion.canUndo(receipt), isTrue);
    },
  );

  test(
    'sample JSON is synthetic, complete and matches the canonical version-one shape',
    () async {
      final before = await completeSnapshot(f.db);
      final sample = document(service.sampleJson());
      expect(sample['format'], VocabularyJsonFormat.format);
      expect(sample['schemaVersion'], 1);
      expect(sample['scheduler'], {
        'library': 'fsrs',
        'version': '2.0.1',
        'cardFormatVersion': 1,
      });
      final collection = onlyCollection(sample);
      expect(collection['id'], '8f8ce022-4a25-47ed-8944-8955dcf353da');
      final entry = (collection['entries'] as List).single as Map;
      for (final direction in LearningDirection.values) {
        final item = (entry['learning'] as Map)[direction.name] as Map;
        final card = item['card'];
        expect(card, isA<Map>());
        LearningCardCodec.decode(
          jsonEncode(card),
          expectedId: item['id'] as int,
          formatVersion: item['formatVersion'] as int,
        );
        expect(item.keys.toSet(), {
          'id',
          'formatVersion',
          'generation',
          'reviewRevision',
          'card',
          'reviews',
          'retry',
          'speedCompleted',
        });
      }
      expect(service.sampleJson(), isNot(contains(f.owner.id)));
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'an expired retry from an older generation is exported exactly as stored without cleanup',
    () async {
      final receipt = await f.review(rating: LearningRating.again);
      final retry = await (f.db.select(
        f.db.retryObligations,
      )..where((row) => row.itemId.equals(receipt.next.id))).getSingle();
      await (f.db.update(
        f.db.learningItems,
      )..where((row) => row.id.equals(receipt.next.id))).write(
        LearningItemsCompanion(generation: Value(receipt.next.generation + 1)),
      );
      (f.db.clock as MutablePikoClock).advance(const Duration(days: 3));
      final before = await completeSnapshot(f.db);
      final collection = onlyCollection(
        document(await service.exportCollection(f.owner.id)),
      );
      final entry = (collection['entries'] as List).single as Map;
      final learning = (entry['learning'] as Map)['targetToNative'] as Map;
      expect(learning['generation'], receipt.next.generation + 1);
      final exportedRetry = learning['retry'];
      final expectedRetry = {
        'id': retry.id,
        'generation': retry.generation,
        'revision': retry.revision,
        'originReviewId': retry.originReviewId,
        'createdAt': retry.createdAt,
        'expiresAt': retry.expiresAt,
        'waitEligibleAt': retry.waitEligibleAt,
        'errorCount': retry.errorCount,
        'dueOrdinal': retry.dueOrdinal,
      };
      expect(exportedRetry, expectedRetry);
      expect(jsonEncode(exportedRetry), jsonEncode(expectedRetry));
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'incomplete learning fails rather than fabricating a missing direction',
    () async {
      final reverse = await f.current(f.entry, true);
      await (f.db.delete(
        f.db.learningItems,
      )..where((row) => row.id.equals(reverse.id))).go();
      final before = await completeSnapshot(f.db);
      await expectLater(
        service.exportCollection(f.owner.id),
        throwsA(VocabularyJsonExportFailure.incompleteLearning),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );
}
