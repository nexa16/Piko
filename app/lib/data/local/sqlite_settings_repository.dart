import '../settings_repository.dart';
import 'piko_database.dart';

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._database);

  final PikoDatabase _database;

  @override
  Future<String?> read(String key) async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) async {
    await _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<void> remove(String key) async {
    await (_database.delete(
      _database.appSettings,
    )..where((row) => row.key.equals(key))).go();
  }
}
