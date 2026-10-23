import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Removes only empty schema24 operational artifacts from a synthetic database
/// before a legacy fixture is frozen. Never merely relabel a current schema.
/// Refuse populated state so this helper cannot hide lost job/adoption evidence.
void freezePre24(sqlite.Database raw) {
  final tables = raw
      .select("SELECT name FROM sqlite_master WHERE type='table'")
      .map((r) => r['name'] as String)
      .toSet();
  for (final table in ['ai_review_jobs', 'ai_adoption_receipts']) {
    if (tables.contains(table) &&
        raw.select('SELECT COUNT(*) AS n FROM $table').single['n'] != 0) {
      throw StateError('Legacy fixture contains nonempty $table');
    }
  }
  final triggers = raw
      .select(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'ai_lock_%'",
      )
      .map((r) => r['name'] as String)
      .toList();
  for (final trigger in triggers) {
    if (!RegExp(r'^ai_lock_[a-z_]+$').hasMatch(trigger))
      throw StateError('Unexpected synthetic trigger name');
    raw.execute('DROP TRIGGER "$trigger"');
  }
  for (final table in ['ai_adoption_receipts', 'ai_review_jobs']) {
    if (tables.contains(table)) raw.execute('DROP TABLE $table');
  }
}
