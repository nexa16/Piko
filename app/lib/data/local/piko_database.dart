import 'package:drift/drift.dart';
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

@DriftDatabase(tables: [AppSettings, Collections, VocabularyEntries])
class PikoDatabase extends _$PikoDatabase {
  PikoDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      await transaction(() async {
        if (from < 2) await m.createTable(collections);
        if (from < 3) {
          await m.createTable(vocabularyEntries);
        } else if (from < 4) {
          await _upgradeVocabularyKeys(m);
        }
      });
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
