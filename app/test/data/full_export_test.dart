import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart'
    show Selectable, QueryRow, Variable, ResultSetImplementation;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_full_export_service.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_statistics_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'statistics_test.dart' show OffsetCalendar, stored;
import 'vocabulary_json_content_test.dart' show rich;

Map<String, dynamic> decode(String value) =>
    jsonDecode(value) as Map<String, dynamic>;

class PausedExportDatabase extends PikoDatabase {
  PausedExportDatabase()
    : super(
        NativeDatabase.memory(),
        clock: MutablePikoClock(instant),
        learningDayCalendar: OffsetCalendar(),
      );
  bool pause = false;
  final reached = Completer<void>(), release = Completer<void>();
  @override
  Selectable<QueryRow> customSelect(
    String query, {
    List<Variable> variables = const [],
    Set<ResultSetImplementation> readsFrom = const {},
  }) {
    final result = super.customSelect(
      query,
      variables: variables,
      readsFrom: readsFrom,
    );
    if (pause && query.startsWith('SELECT v.* FROM category_values')) {
      pause = false;
      return PausedRead(result, this);
    }
    return result;
  }
}

class PausedRead extends Selectable<QueryRow> {
  PausedRead(this.inner, this.db);
  final Selectable<QueryRow> inner;
  final PausedExportDatabase db;
  @override
  Future<List<QueryRow>> get() async {
    db.reached.complete();
    await db.release.future;
    return inner.get();
  }

  @override
  Stream<List<QueryRow>> watch() => inner.watch();
}

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture(
      database: PikoDatabase(
        NativeDatabase.memory(),
        clock: MutablePikoClock(instant),
        learningDayCalendar: OffsetCalendar(),
      ),
    );
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  test(
    'fresh empty export has null statistics without initializing anything',
    () async {
      final db = PikoDatabase(
        NativeDatabase.memory(),
        clock: MutablePikoClock(instant),
      );
      addTearDown(db.close);
      final before = await stored(db);
      final result = decode(await SqliteFullExportService(db).exportAll());
      expect(result['format'], 'piko.full-export');
      expect(result['schemaVersion'], 1);
      expect(result['collectionSchemaVersion'], 5);
      expect(result['collections'], isEmpty);
      expect(result['statistics'], isNull);
      expect(result['exportedAt'], instant.toIso8601String());
      expect(await stored(db), before);
      await SqliteStatisticsRepository(db).snapshot(at: instant);
      final initialized = await stored(db);
      final zero = decode(
        await SqliteFullExportService(db).exportAll(),
      )['statistics'];
      expect(zero['dailyCounts'], isEmpty);
      expect(zero['coverageRanges'], isEmpty);
      expect(zero['partialLearningDates'], [zero['snapshotLearningDate']]);
      expect(await stored(db), initialized);
    },
  );

  test(
    'all payloads equal existing collection export and exclude local preferences',
    () async {
      final f = await fixture();
      await f.db.customStatement(
        'UPDATE collections SET target_language=? WHERE id=?',
        ['ko', f.kept.id],
      );
      final categories = SqliteCategoriesRepository(f.db);
      final group = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final value = await categories.createValue(
        dimensionId: group.id,
        name: 'Fruit',
      );
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: {
          group.id: {value.id},
        },
        content: rich,
      );
      await f.review();
      await f.review(reverse: true);
      await SqliteSettingsRepository(
        f.db,
      ).write('private.setting', 'EXCLUDED_PREFERENCE');
      final before = await stored(f.db);
      final result = decode(await SqliteFullExportService(f.db).exportAll());
      final single = SqliteVocabularyJsonService(f.db);
      final ordinary = [
        for (final id in [f.owner.id, f.kept.id])
          decode(await single.exportCollection(id)),
      ];
      expect(result.keys.toSet(), {
        'format',
        'schemaVersion',
        'collectionSchemaVersion',
        'exportedAt',
        'scheduler',
        'collections',
        'statistics',
      });
      expect(result['collections'], [
        for (final document in ordinary)
          (document['collections'] as List).single,
      ]);
      expect(result['scheduler'], ordinary.first['scheduler']);
      expect(
        ordinary.every((document) => !document.containsKey('statistics')),
        isTrue,
      );
      expect(jsonEncode(result), isNot(contains('EXCLUDED_PREFERENCE')));
      expect(result['statistics']['dailyCounts'], [
        {
          'learningDate': '2026-10-14',
          'longTermReviews': 2,
          'speedCompletions': 0,
        },
      ]);
      expect(await stored(f.db), before);
    },
  );

  test(
    'report retains all dates, partial coverage, future buckets and deleted Collections',
    () async {
      final f = await fixture();
      final stats = SqliteStatisticsRepository(f.db);
      await stats.snapshot(at: instant);
      await stats.recordRegular('old-partial', DateTime.utc(2026, 9, 1, 12));
      await stats.recordRegular(
        'future-hidden',
        DateTime.utc(2026, 10, 23, 12),
      );
      await stats.recordSpeed(
        f.entry.id,
        LearningDirection.targetToNative,
        DateTime.utc(2026, 10, 15, 12),
      );
      await f.collections.delete(f.owner.id);
      await f.collections.delete(f.kept.id);
      (f.db.clock as MutablePikoClock).set(DateTime.utc(2026, 10, 20, 12));
      final before = await stored(f.db);
      final result = decode(await SqliteFullExportService(f.db).exportAll());
      expect(result['collections'], isEmpty);
      expect(result['statistics'], {
        'schemaVersion': 1,
        'recordedSinceUtc': instant.toIso8601String(),
        'recordedSinceLearningDate': '2026-10-14',
        'snapshotLearningDate': '2026-10-20',
        'boundaryLocalTime': '04:00',
        'dayAssignment': 'recordedLocalDate',
        'coverageRanges': [
          {'firstDate': '2026-10-15', 'lastDate': '2026-10-19'},
        ],
        'partialLearningDates': [
          '2026-09-01',
          '2026-10-14',
          '2026-10-20',
          '2026-10-23',
        ],
        'dailyCounts': [
          {
            'learningDate': '2026-09-01',
            'longTermReviews': 1,
            'speedCompletions': 0,
          },
          {
            'learningDate': '2026-10-15',
            'longTermReviews': 0,
            'speedCompletions': 1,
          },
          {
            'learningDate': '2026-10-23',
            'longTermReviews': 1,
            'speedCompletions': 0,
          },
        ],
      });
      expect(await stored(f.db), before);
      (f.db.clock as MutablePikoClock).set(DateTime.utc(2026, 9, 10, 12));
      final earlier = decode(
        await SqliteFullExportService(f.db).exportAll(),
      )['statistics'];
      expect(earlier['coverageRanges'], isEmpty);
      expect(earlier['partialLearningDates'], [
        '2026-09-01',
        '2026-10-14',
        '2026-10-15',
        '2026-10-23',
      ]);
      expect(earlier['dailyCounts'], result['statistics']['dailyCounts']);
      expect(await stored(f.db), before);
    },
  );

  test(
    'full envelope rejected and arbitrary collection statistics ignored without credit',
    () async {
      final f = await fixture();
      await f.review();
      final service = SqliteVocabularyJsonService(f.db);
      final before = await stored(f.db);
      final full = await service.analyzeImport(
        collectionId: f.owner.id,
        json: await SqliteFullExportService(f.db).exportAll(),
      );
      expect(full.canApply, isFalse);
      await expectLater(service.applyImport(full), throwsA(anything));
      final oneFull = decode(await SqliteFullExportService(f.db).exportAll());
      oneFull['collections'] = [(oneFull['collections'] as List).first];
      final onePreview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(oneFull),
      );
      expect(onePreview.canApply, isFalse);
      expect(await stored(f.db), before);
      final document = decode(await service.exportCollection(f.owner.id));
      for (final statistics in [
        null,
        {
          'schemaVersion': 999,
          'unknown': ['ignored'],
        },
        'nonsense',
      ]) {
        document['statistics'] = statistics;
        final preview = await service.analyzeImport(
          collectionId: f.owner.id,
          json: jsonEncode(document),
        );
        expect(preview.canApply, isTrue);
        await service.applyImport(preview);
        expect(await stored(f.db), before);
      }
    },
  );

  test(
    'invalid stored learning aborts the whole export without changing data',
    () async {
      final f = await fixture();
      await f.db.customStatement(
        'UPDATE learning_items SET card_json=? WHERE entry_id=?',
        ['{}', f.other.id],
      );
      final before = await stored(f.db);
      await expectLater(
        SqliteFullExportService(f.db).exportAll(),
        throwsA(anything),
      );
      expect(await stored(f.db), before);
    },
  );

  test(
    'concurrent learning and deletion cannot mix Collection payloads with later statistics',
    () async {
      final db = PausedExportDatabase();
      // One runtime database owns both export and the concurrent write queue.
      final real = Fixture(database: db);
      addTearDown(db.close);
      await real.initialize();
      await SqliteStatisticsRepository(db).snapshot(at: instant);
      db.pause = true;
      final exporting = SqliteFullExportService(db).exportAll();
      await db.reached.future;
      var finished = false;
      final mutation = db.transaction(() async {
        await real.review(word: real.other);
        await real.collections.delete(real.kept.id);
        finished = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      db.release.complete();
      final before = decode(await exporting);
      await mutation;
      final after = decode(await SqliteFullExportService(db).exportAll());
      expect(before['collections'], hasLength(2));
      expect(before['statistics']['dailyCounts'], isEmpty);
      expect(after['collections'], hasLength(1));
      expect(after['statistics']['dailyCounts'], [
        {
          'learningDate': '2026-10-14',
          'longTermReviews': 1,
          'speedCompletions': 0,
        },
      ]);
    },
  );
}
