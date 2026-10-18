import 'package:drift/drift.dart';
import '../../core/clock.dart';
import '../../core/learning_day.dart';
import 'statistics_tables.dart';
import '../../features/learning/learning_scheduler.dart';
import '../learning_item.dart';
import '../preferred_direction.dart';
import '../vocabulary_normalization.dart';

part 'piko_database.g.dart';

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class Collections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get targetLanguage => text()();
  TextColumn get nativeLanguage => text()();
  BoolColumn get automaticHintDefault =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get hintDefaultOfferHandled =>
      boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX vocabulary_entry_ownership ON vocabulary_entries(id, collection_id)',
)
class VocabularyEntries extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId =>
      text().references(Collections, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetText => text()();
  TextColumn get nativeText => text()();
  TextColumn get targetKey => text()();
  TextColumn get nativeKey => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get exampleTargetText => text().nullable().check(
    const CustomExpression<bool>(
      'example_target_text IS NULL OR length(example_target_text) BETWEEN 1 AND 1000',
    ),
  )();
  TextColumn get exampleNativeText => text().nullable().check(
    const CustomExpression<bool>(
      '(example_target_text IS NULL AND example_native_text IS NULL) OR '
      '(example_target_text IS NOT NULL AND example_native_text IS NOT NULL '
      'AND length(example_native_text) BETWEEN 1 AND 1000)',
    ),
  )();
  TextColumn get addedAt => text().nullable()();
  TextColumn get hintText => text().nullable().check(
    const CustomExpression<bool>(
      'hint_text IS NULL OR length(hint_text) BETWEEN 1 AND 2000',
    ),
  )();
  TextColumn get hintVisibility => text()
      .withDefault(const Constant('always'))
      .check(
        const CustomExpression<bool>("hint_visibility IN ('always', 'hidden')"),
      )();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK(length(trim(target_text)) > 0)',
    'CHECK(length(trim(native_text)) > 0)',
    'UNIQUE(collection_id, target_key, native_key)',
  ];
}

class VocabularyExamples extends Table {
  TextColumn get entryId =>
      text().references(VocabularyEntries, #id, onDelete: KeyAction.cascade)();
  IntColumn get position =>
      integer().check(const CustomExpression<bool>('position >= 0'))();
  TextColumn get targetText => text().check(
    const CustomExpression<bool>('length(target_text) BETWEEN 1 AND 1000'),
  )();
  TextColumn get nativeText => text().check(
    const CustomExpression<bool>('length(native_text) BETWEEN 1 AND 1000'),
  )();
  @override
  Set<Column<Object>> get primaryKey => {entryId, position};
}

@DataClassName('StoredCategoryDimension')
class CategoryDimensions extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId =>
      text().references(Collections, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get nameKey => text()();
  TextColumn get mode => text()();
  IntColumn get position => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK(length(trim(name)) > 0)',
    "CHECK(mode IN ('single', 'multiple'))",
    'CHECK(position >= 0)',
    'UNIQUE(collection_id, name_key)',
    'UNIQUE(id, collection_id)',
  ];
}

@DataClassName('StoredCategoryValue')
class CategoryValues extends Table {
  TextColumn get id => text()();
  TextColumn get dimensionId =>
      text().references(CategoryDimensions, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get nameKey => text()();
  IntColumn get position => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK(length(trim(name)) > 0)',
    'CHECK(position >= 0)',
    'UNIQUE(dimension_id, name_key)',
    'UNIQUE(id, dimension_id)',
  ];
}

/// Local presentation choices, deliberately absent from Collection interchange.
class CategoryGroupPreferences extends Table {
  TextColumn get dimensionId =>
      text().references(CategoryDimensions, #id, onDelete: KeyAction.cascade)();
  BoolColumn get customValueOrder =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get carryOver => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {dimensionId};
}

@DataClassName('StoredCategoryAssignment')
class VocabularyCategoryAssignments extends Table {
  TextColumn get entryId => text()();
  TextColumn get collectionId => text()();
  TextColumn get dimensionId => text()();
  TextColumn get valueId => text()();
  @override
  Set<Column<Object>> get primaryKey => {entryId, valueId};
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY(entry_id, collection_id) REFERENCES vocabulary_entries(id, collection_id) ON DELETE CASCADE',
    'FOREIGN KEY(dimension_id, collection_id) REFERENCES category_dimensions(id, collection_id) ON DELETE CASCADE',
    'FOREIGN KEY(value_id, dimension_id) REFERENCES category_values(id, dimension_id) ON DELETE CASCADE',
  ];
}

class LearningItems extends Table {
  IntColumn get id => integer()();
  TextColumn get entryId =>
      text().references(VocabularyEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get direction => text()();
  IntColumn get formatVersion => integer()();
  TextColumn get cardJson => text()();
  IntColumn get generation => integer()
      .withDefault(const Constant(0))
      .check(const CustomExpression<bool>('generation >= 0'))();
  IntColumn get reviewRevision => integer()
      .withDefault(const Constant(0))
      .check(const CustomExpression<bool>('review_revision >= 0'))();
  BoolColumn get speedCompleted =>
      boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK(id > 0)',
    "CHECK(direction IN ('targetToNative', 'nativeToTarget'))",
    'CHECK(format_version = 1)',
    'UNIQUE(entry_id, direction)',
  ];
}

class RegularReviews extends Table {
  TextColumn get id => text()();
  IntColumn get itemId =>
      integer().references(LearningItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get generation => integer()();

  /// ISO UTC text retains subsecond precision independent of Drift date mapping.
  TextColumn get reviewedAt => text()();
  TextColumn get rating => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK(length(id) > 0)',
    'CHECK(generation >= 0)',
    "CHECK(rating IN ('again', 'hard', 'good'))",
    "CHECK(substr(reviewed_at, -1) = 'Z')",
  ];
}

@DataClassName('StoredRetryObligation')
class RetryObligations extends Table {
  TextColumn get id => text()();
  IntColumn get itemId =>
      integer().references(LearningItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get generation => integer()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get originReviewId =>
      text().references(RegularReviews, #id, onDelete: KeyAction.cascade)();
  TextColumn get createdAt => text()();
  TextColumn get expiresAt => text()();
  TextColumn get waitEligibleAt => text().nullable().check(
    const CustomExpression<bool>(
      "wait_eligible_at IS NULL OR substr(wait_eligible_at, -1) = 'Z'",
    ),
  )();
  IntColumn get errorCount => integer()
      .withDefault(const Constant(1))
      .check(const CustomExpression<bool>('error_count >= 1'))();
  IntColumn get dueOrdinal => integer()
      .withDefault(const Constant(20))
      .check(const CustomExpression<bool>('due_ordinal >= 0'))();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK(length(trim(id)) > 0)',
    'CHECK(generation >= 0)',
    'CHECK(revision >= 0)',
    'UNIQUE(item_id, generation)',
    "CHECK(substr(created_at, -1) = 'Z')",
    "CHECK(substr(expires_at, -1) = 'Z')",
  ];
}

/// Answer admission only, not statistics or an attempt-event log.
class ScopeAnswerOrdinals extends Table {
  TextColumn get collectionId =>
      text().references(Collections, #id, onDelete: KeyAction.cascade)();
  TextColumn get direction => text()();
  IntColumn get ordinal => integer()();
  IntColumn get revision => integer()();
  @override
  Set<Column<Object>> get primaryKey => {collectionId, direction};
  @override
  List<String> get customConstraints => [
    "CHECK(direction IN ('targetToNative', 'nativeToTarget'))",
    'CHECK(ordinal >= 0)',
    'CHECK(revision >= 0)',
  ];
}

/// High-water mark survives deletion and future Undo restoration.
class LearningIdentitySequence extends Table {
  IntColumn get singleton => integer()();
  IntColumn get nextId => integer()();
  @override
  Set<Column<Object>> get primaryKey => {singleton};
  @override
  List<String> get customConstraints => [
    'CHECK(singleton = 1)',
    'CHECK(next_id > 0)',
  ];
}

/// Prevents implicit SQLite rowid reuse while deleted rows await Undo.
class VocabularyOrderSequence extends Table {
  IntColumn get singleton => integer()();
  IntColumn get nextRowId => integer()();
  @override
  Set<Column<Object>> get primaryKey => {singleton};
  @override
  List<String> get customConstraints => [
    'CHECK(singleton = 1)',
    'CHECK(next_row_id > 0)',
  ];
}

@DriftDatabase(
  tables: [
    AppSettings,
    Collections,
    VocabularyEntries,
    VocabularyExamples,
    LearningItems,
    RegularReviews,
    RetryObligations,
    ScopeAnswerOrdinals,
    LearningIdentitySequence,
    VocabularyOrderSequence,
    CategoryDimensions,
    CategoryValues,
    CategoryGroupPreferences,
    VocabularyCategoryAssignments,
    StatisticsOrigins,
    StatisticsActivity,
    SpeedCompletionReceipts,
  ],
)
class PikoDatabase extends _$PikoDatabase {
  PikoDatabase(
    super.executor, {
    this.clock = const SystemPikoClock(),
    this.learningDayCalendar = const DeviceLearningDayCalendar(),
  });
  final PikoClock clock;
  final LearningDayCalendar learningDayCalendar;
  final _scheduler = LearningScheduler();

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _initializeLearningSequence();
      await _initializeVocabularyOrder();
      await _initializePreferredDirection(PreferredDirection.targetToNative);
    },
    onUpgrade: (m, from, to) async {
      await transaction(() async {
        if (from < 2) await m.createTable(collections);
        if (from < 3) {
          await m.createTable(vocabularyEntries);
        } else if (from < 4) {
          await _upgradeVocabularyKeys(m);
        }
        if (from < 5) {
          await m.createTable(learningItems);
          await m.createTable(learningIdentitySequence);
          await _initializeLearningSequence();
          final instant = clock.now().toUtc();
          // Older vocabulary tables do not yet have later optional columns.
          // Identity backfill needs only IDs, not the latest generated mapper.
          final entries = await customSelect(
            'SELECT id FROM vocabulary_entries ORDER BY rowid',
          ).get();
          for (final entry in entries) {
            await createLearningItems(entry.read<String>('id'), at: instant);
          }
          if ((await customSelect(
            'PRAGMA foreign_key_check',
          ).get()).isNotEmpty) {
            throw StateError(
              'Learning migration failed foreign-key validation',
            );
          }
        }
        if (from < 6) {
          await m.createTable(vocabularyOrderSequence);
          await _initializeVocabularyOrder();
        }
        if (from < 7) {
          // Older migrations already create the latest LearningItems shape.
          if (from >= 5) {
            await m.addColumn(learningItems, learningItems.generation);
            await m.addColumn(learningItems, learningItems.reviewRevision);
          }
          await m.createTable(regularReviews);
        }
        if (from < 8) await m.createTable(retryObligations);
        if (from < 9) {
          // Pre-8 migrations create the latest retry shape already. Schema 8
          // had no gap tracking: preserve rounds with first-error/20 baseline,
          // never reconstruct an invented answered history from regular events.
          if (from == 8) {
            await m.addColumn(retryObligations, retryObligations.errorCount);
            await m.addColumn(retryObligations, retryObligations.dueOrdinal);
          }
          await m.createTable(scopeAnswerOrdinals);
        }
        if (from < 10 && from >= 8) {
          await m.addColumn(retryObligations, retryObligations.waitEligibleAt);
        }
        if (from < 11) {
          await _createVocabularyOwnershipIndex();
          await m.createTable(categoryDimensions);
          await m.createTable(categoryValues);
          await m.createTable(vocabularyCategoryAssignments);
        }
        // Pre-5 upgrades already create the latest LearningItems shape.
        if (from < 12 && from >= 5) {
          await m.addColumn(learningItems, learningItems.speedCompleted);
        }
        if (from < 13) {
          await _initializePreferredDirection(
            PreferredDirection.nativeToTarget,
          );
        }
        // Pre-4 upgrades create/rebuild the latest vocabulary shape already.
        if (from < 14 && from >= 4) {
          await m.addColumn(
            vocabularyEntries,
            vocabularyEntries.exampleTargetText,
          );
          await m.addColumn(
            vocabularyEntries,
            vocabularyEntries.exampleNativeText,
          );
          await m.addColumn(vocabularyEntries, vocabularyEntries.hintText);
          await m.addColumn(
            vocabularyEntries,
            vocabularyEntries.hintVisibility,
          );
        }
        if (from < 15) {
          if (from >= 4) {
            await m.addColumn(vocabularyEntries, vocabularyEntries.addedAt);
          }
          await m.createTable(vocabularyExamples);
          await customStatement(
            'INSERT INTO vocabulary_examples(entry_id, position, target_text, native_text) SELECT id, 0, example_target_text, example_native_text FROM vocabulary_entries WHERE example_target_text IS NOT NULL',
          );
        }
        if (from < 16) {
          if (from >= 4) {
            await m.addColumn(vocabularyEntries, vocabularyEntries.active);
          }
          if (from >= 2) {
            await m.addColumn(collections, collections.automaticHintDefault);
            await m.addColumn(collections, collections.hintDefaultOfferHandled);
          }
        }
        if (from < 17) {
          await m.createTable(statisticsOrigins);
          await m.createTable(statisticsActivity);
          await m.createTable(speedCompletionReceipts);
          await m.createIndex(statisticsActivityDate);
        }
        if (from < 18) await m.createTable(categoryGroupPreferences);
        if (from == 18) {
          await m.addColumn(
            categoryGroupPreferences,
            categoryGroupPreferences.carryOver,
          );
        }
      });
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _initializePreferredDirection(PreferredDirection value) =>
      customStatement(
        'INSERT OR IGNORE INTO app_settings (key, value) VALUES (?, ?)',
        [PreferredDirection.settingKey, value.name],
      );

  Future<void> _createVocabularyOwnershipIndex() => customStatement(
    'CREATE UNIQUE INDEX vocabulary_entry_ownership ON vocabulary_entries(id, collection_id)',
  );

  Future<void> _initializeVocabularyOrder() => customStatement(
    'INSERT INTO vocabulary_order_sequence (singleton, next_row_id) SELECT 1, COALESCE(MAX(rowid), 0) + 1 FROM vocabulary_entries',
  );

  Future<int> allocateVocabularyRowId() => transaction(() async {
    final sequence = await select(vocabularyOrderSequence).getSingle();
    final highest = (await customSelect(
      'SELECT COALESCE(MAX(rowid), 0) AS highest FROM vocabulary_entries',
    ).getSingle()).read<int>('highest');
    final next = sequence.nextRowId > highest
        ? sequence.nextRowId
        : highest + 1;
    await (update(vocabularyOrderSequence)
          ..where((row) => row.singleton.equals(1)))
        .write(VocabularyOrderSequenceCompanion(nextRowId: Value(next + 1)));
    return next;
  });

  Future<void> _initializeLearningSequence() => customStatement(
    'INSERT INTO learning_identity_sequence (singleton, next_id) VALUES (1, 1)',
  );

  /// Nested callers retain their vocabulary/migration transaction boundary.
  Future<void> createLearningItems(String entryId, {DateTime? at}) =>
      transaction(() async {
        final instant = (at ?? clock.now()).toUtc();
        for (final direction in LearningDirection.values) {
          final sequence = await select(learningIdentitySequence).getSingle();
          final id = sequence.nextId;
          await (update(learningIdentitySequence)
                ..where((row) => row.singleton.equals(1)))
              .write(LearningIdentitySequenceCompanion(nextId: Value(id + 1)));
          final card = _scheduler.initialCard(itemId: id, at: instant);
          await into(learningItems).insert(
            LearningItemsCompanion.insert(
              id: Value(id),
              entryId: entryId,
              direction: direction.name,
              formatVersion: LearningCardCodec.version,
              cardJson: LearningCardCodec.encode(card),
            ),
          );
        }
      });

  Future<void> _upgradeVocabularyKeys(Migrator migrator) async {
    // Read the old structure explicitly: the v4 generated mapper needs keys.
    final rows = await customSelect(
      'SELECT rowid AS original_rowid, id, collection_id, target_text, native_text FROM vocabulary_entries ORDER BY rowid',
    ).get();
    final keys = <(String, String, String)>{};
    for (final row in rows) {
      final key = (
        row.read<String>('collection_id'),
        vocabularyComparisonKey(row.read<String>('target_text')),
        vocabularyComparisonKey(row.read<String>('native_text')),
      );
      if (!keys.add(key)) throw const VocabularyMigrationCollision();
    }
    await migrator.createTable(
      vocabularyEntries.createAlias('vocabulary_entries_v4'),
    );
    for (final row in rows) {
      final target = row.read<String>('target_text');
      final native = row.read<String>('native_text');
      await customStatement(
        'INSERT INTO vocabulary_entries_v4 (rowid, id, collection_id, target_text, native_text, target_key, native_key) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          row.read<int>('original_rowid'),
          row.read<String>('id'),
          row.read<String>('collection_id'),
          target,
          native,
          vocabularyComparisonKey(target),
          vocabularyComparisonKey(native),
        ],
      );
    }
    await customStatement('DROP TABLE vocabulary_entries');
    await customStatement(
      'ALTER TABLE vocabulary_entries_v4 RENAME TO vocabulary_entries',
    );
    if ((await customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
      throw StateError('Vocabulary migration failed foreign-key validation.');
    }
  }
}

final class VocabularyMigrationCollision implements Exception {
  const VocabularyMigrationCollision();
  @override
  String toString() => 'Vocabulary migration found duplicate normalized pairs.';
}
