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

@DriftDatabase(tables: [AppSettings, Collections])
class PikoDatabase extends _$PikoDatabase {
  PikoDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(collections);
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
