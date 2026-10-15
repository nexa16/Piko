/// Storage boundary; feature code owns setting keys and their valid values.
abstract interface class SettingsRepository {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}
