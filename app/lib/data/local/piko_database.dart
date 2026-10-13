import 'package:drift/drift.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../../core/clock.dart';
import '../learning_item.dart';
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
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class VocabularyEntries extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId =>
      text().references(Collections, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetText => text()();
  TextColumn get nativeText => text()();
  TextColumn get targetKey => text()();
  TextColumn get nativeKey => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK(length(trim(target_text)) > 0)',
    'CHECK(length(trim(native_text)) > 0)',
    'UNIQUE(collection_id, target_key, native_key)',
  ];
}

class LearningItems extends Table {
  IntColumn get id => integer()();
  TextColumn get entryId =>
      text().references(VocabularyEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get direction => text()();
  IntColumn get formatVersion => integer()();
  TextColumn get cardJson => text()();
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
    LearningItems,
    LearningIdentitySequence,
    VocabularyOrderSequence,
  ],
)
class PikoDatabase extends _$PikoDatabase {
  PikoDatabase(super.executor, {this.clock = const SystemPikoClock()});
  final PikoClock clock;

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _initializeLearningSequence();
      await _initializeVocabularyOrder();
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
          final entries =
              await (select(vocabularyEntries)..orderBy([
                    (_) => OrderingTerm(
                      expression: const CustomExpression<int>('rowid'),
                    ),
                  ]))
                  .get();
          for (final entry in entries) {
            await createLearningItems(entry.id, at: instant);
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
      });
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
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
          final card = fsrs.Card(cardId: id, due: instant);
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
