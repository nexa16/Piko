import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/learning/learning_scheduler.dart';

import 'regular_reviews_test.dart' show Fixture;
import 'speed_eligibility_test.dart' show completeSnapshot;

void main() {
  test('stored choices map to immutable directional presentation scopes', () {
    for (final choice in PreferredDirection.values) {
      expect(PreferredDirection.fromStored(choice.name), choice);
      expect(() => choice.directions.clear(), throwsUnsupportedError);
    }
    expect(PreferredDirection.targetToNative.directions, {
      LearningDirection.targetToNative,
    });
    expect(PreferredDirection.nativeToTarget.directions, {
      LearningDirection.nativeToTarget,
    });
    expect(
      PreferredDirection.both.directions,
      LearningDirection.values.toSet(),
    );
    for (final unsupported in [null, '', 'future-value']) {
      expect(
        PreferredDirection.fromStored(unsupported),
        PreferredDirection.nativeToTarget,
      );
    }
  });

  test(
    'fresh installation persists its Target to Native default across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-direction-new-',
      );
      final file = File('${directory.path}/new.sqlite');
      var db = PikoDatabase(NativeDatabase(file));
      try {
        expect(
          await SqliteSettingsRepository(
            db,
          ).read(PreferredDirection.settingKey),
          PreferredDirection.targetToNative.name,
        );
        await db.close();
        db = PikoDatabase(NativeDatabase(file));
        expect(
          await SqliteSettingsRepository(
            db,
          ).read(PreferredDirection.settingKey),
          PreferredDirection.targetToNative.name,
        );
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
            'user_version',
          ),
          db.schemaVersion,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  for (final saved in <PreferredDirection?>[
    null,
    ...PreferredDirection.values,
  ]) {
    test(
      'schema12 migration preserves data and explicit direction=$saved',
      () async {
        final f = Fixture();
        final directory = await Directory.systemTemp.createTemp(
          'piko-direction-upgrade-',
        );
        final file = File('${directory.path}/legacy.sqlite');
        PikoDatabase? migrated;
        var sourceClosed = false;
        try {
          await f.initialize();
          await f.review(rating: LearningRating.again);
          await f.review(reverse: true, rating: LearningRating.good);
          final settings = SqliteSettingsRepository(f.db);
          await settings.write('locale', 'de');
          await settings.write('unrelated', 'keep exactly');
          if (saved == null) {
            await settings.remove(PreferredDirection.settingKey);
          } else {
            await settings.write(PreferredDirection.settingKey, saved.name);
          }
          // Legacy schemas used automatic hints; preserve that historical state.
          await f.db.customStatement(
            "UPDATE vocabulary_entries SET hint_visibility = 'always'",
          );
          final before = await completeSnapshot(f.db);
          // Recreate the historical schema, where addition dates were unknown.
          for (final row in before['vocabulary_entries'] as List) {
            (row as Map)['added_at'] = null;
          }
          final legacy = sqlite.sqlite3.open(file.path);
          try {
            final schema =
                jsonDecode(
                      await File(
                        'drift_schemas/drift_schema_v12.json',
                      ).readAsString(),
                    )
                    as Map<String, dynamic>;
            for (final group in schema['fixed_sql'] as List) {
              legacy.execute((group['sql'] as List).single['sql'] as String);
            }
            for (final table in before.entries) {
              for (final stored in table.value! as List) {
                final row = Map<String, Object?>.of(
                  stored as Map<String, Object?>,
                );
                if (table.key == 'collections') {
                  row.remove('automatic_hint_default');
                  row.remove('hint_default_offer_handled');
                }
                if (table.key == 'vocabulary_entries') {
                  row.remove('active');
                  for (final column in [
                    'added_at',
                    'example_target_text',
                    'example_native_text',
                    'hint_text',
                    'hint_visibility',
                  ]) {
                    row.remove(column);
                  }
                }
                final columns = row.keys
                    .map((key) => key == 'stored_rowid' ? 'rowid' : key)
                    .join(',');
                legacy.execute(
                  'INSERT INTO ${table.key} ($columns) VALUES (${List.filled(row.length, '?').join(',')})',
                  row.values.toList(),
                );
              }
            }
            legacy.execute('PRAGMA user_version = 12');
          } finally {
            legacy.close();
          }
          final settingsRows = before['app_settings']! as List;
          final lastSettingRowId = settingsRows.fold<int>(0, (last, row) {
            final id = (row as Map<String, Object?>)['stored_rowid']! as int;
            return id > last ? id : last;
          });
          final expected = <String, Object?>{
            ...before,
            if (saved == null)
              'app_settings': [
                ...settingsRows,
                {
                  'stored_rowid': lastSettingRowId + 1,
                  'key': PreferredDirection.settingKey,
                  'value': PreferredDirection.nativeToTarget.name,
                },
              ],
          };
          await f.db.close();
          sourceClosed = true;
          migrated = PikoDatabase(NativeDatabase(file));
          expect(await completeSnapshot(migrated), expected);
          expect(
            await SqliteSettingsRepository(
              migrated,
            ).read(PreferredDirection.settingKey),
            (saved ?? PreferredDirection.nativeToTarget).name,
          );
          expect(
            await migrated.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          await migrated.close();
          migrated = PikoDatabase(NativeDatabase(file));
          expect(await completeSnapshot(migrated), expected);
        } finally {
          await migrated?.close();
          if (!sourceClosed) await f.db.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
