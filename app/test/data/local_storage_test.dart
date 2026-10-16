import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';

void main() {
  late PikoDatabase database;
  late SqliteSettingsRepository settings;

  setUp(() {
    database = PikoDatabase(NativeDatabase.memory());
    settings = SqliteSettingsRepository(database);
  });

  tearDown(() => database.close());

  test(
    'fresh schema seeds only its direction preference and enables foreign keys',
    () async {
      final seeded = await database.select(database.appSettings).get();
      expect(seeded, hasLength(1));
      expect(seeded.single.key, PreferredDirection.settingKey);
      expect(seeded.single.value, PreferredDirection.targetToNative.name);
      expect(await settings.read('missing'), isNull);
      final pragma = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(pragma.read<int>('foreign_keys'), 1);
    },
  );

  test('settings can be updated and removed without duplicate rows', () async {
    await settings.write('test.setting', 'first');
    await settings.write('test.setting', 'second');
    expect(await settings.read('test.setting'), 'second');
    expect(await database.select(database.appSettings).get(), hasLength(2));
    await settings.remove('test.setting');
    expect(await settings.read('test.setting'), isNull);
  });

  test('failure rolls back all writes in a transaction', () async {
    await settings.write('existing', 'before');
    await expectLater(
      database.transaction(() async {
        await settings.write('existing', 'after');
        await settings.write('new', 'value');
        throw StateError('Injected failure');
      }),
      throwsStateError,
    );
    expect(await settings.read('existing'), 'before');
    expect(await settings.read('new'), isNull);
  });

  test('file database preserves committed data across reopen', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'piko-storage-test-',
    );
    final file = File('${directory.path}/piko.sqlite');
    PikoDatabase? diskDatabase;
    try {
      diskDatabase = PikoDatabase(NativeDatabase(file));
      await SqliteSettingsRepository(
        diskDatabase,
      ).write('test.setting', 'saved');
      await diskDatabase.close();
      diskDatabase = PikoDatabase(NativeDatabase(file));
      expect(
        await SqliteSettingsRepository(diskDatabase).read('test.setting'),
        'saved',
      );
    } finally {
      await diskDatabase?.close();
      await directory.delete(recursive: true);
    }
  });
}
