import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Collections/vocabulary DDL was unchanged from 16 through 19. Retain original
// rowids while freezing those tables so this is an actual old-schema upgrade.
void freezePre20(sqlite.Database raw) {
  // Recovery storage did not exist before schema23; never merely relabel it old.
  raw.execute('DROP TABLE IF EXISTS vocabulary_trash');
  if (raw
      .select('PRAGMA table_info(category_group_preferences)')
      .any((r) => r['name'] == 'acquisition_source')) {
    raw.execute(
      'ALTER TABLE category_group_preferences DROP COLUMN acquisition_source',
    );
  }
  if (raw
      .select('PRAGMA table_info(category_group_preferences)')
      .any((r) => r['name'] == 'tag_color_role')) {
    raw.execute(
      'ALTER TABLE category_group_preferences DROP COLUMN tag_color_role',
    );
  }
  final schema =
      jsonDecode(File('drift_schemas/drift_schema_v16.json').readAsStringSync())
          as Map;
  for (final table in ['collections', 'vocabulary_entries']) {
    final spec = (schema['fixed_sql'] as List).singleWhere(
      (x) => x['name'] == table,
    );
    final ddl = ((spec['sql'] as List).single['sql'] as String).replaceFirst(
      'CREATE TABLE IF NOT EXISTS "$table"',
      'CREATE TABLE "${table}_legacy"',
    );
    raw.execute(ddl);
    final columns = raw
        .select('PRAGMA table_info(${table}_legacy)')
        .map((r) => r['name'] as String)
        .join(',');
    raw.execute(
      'INSERT INTO ${table}_legacy(rowid,$columns) SELECT rowid,$columns FROM $table',
    );
    raw.execute('DROP TABLE $table');
    raw.execute('ALTER TABLE ${table}_legacy RENAME TO $table');
  }
  raw.execute(
    'CREATE UNIQUE INDEX vocabulary_entry_ownership ON vocabulary_entries(id,collection_id)',
  );
}
