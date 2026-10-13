import 'package:drift/drift.dart';

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

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK(length(trim(target_text)) > 0)',
    'CHECK(length(trim(native_text)) > 0)',
  ];
}

@DriftDatabase(tables: [AppSettings, Collections, VocabularyEntries])
class PikoDatabase extends _$PikoDatabase {
  PikoDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(collections);
      if (from < 3) await m.createTable(vocabularyEntries);
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
