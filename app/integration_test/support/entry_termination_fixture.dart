import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/local/database_connection.dart';
import 'package:piko/data/local/piko_database.dart';

/// Test-only protocol. Run identity must be supplied by the external coordinator.
const runId = String.fromEnvironment('PIKO_TERMINATION_RUN');
const tables = [
  'app_settings',
  'collections',
  'vocabulary_entries',
  'learning_items',
];
const sequences = ['learning_identity_sequence', 'vocabulary_order_sequence'];
String get collectionName => 'Termination verification $runId';
String get draftTarget => 'Unconfirmed-$runId';

Future<File> checkpointFile() async {
  if (!RegExp(r'^[a-zA-Z0-9-]{8,64}$').hasMatch(runId)) {
    throw StateError('A unique PIKO_TERMINATION_RUN is required.');
  }
  return File(
    '${(await getApplicationSupportDirectory()).path}/entry-termination-$runId.json',
  );
}

PikoDatabase productionObserver() => PikoDatabase(openPikoDatabase());

Future<Map<String, Object?>> snapshot(PikoDatabase db) async {
  final result = <String, Object?>{};
  for (final table in [...tables, ...sequences]) {
    result[table] = [
      for (final row
          in await db
              .customSelect(
                'SELECT rowid AS stored_rowid, * FROM $table ORDER BY rowid',
              )
              .get())
        row.data,
    ];
  }
  result['schema'] =
      (await db.customSelect('PRAGMA user_version').getSingle()).data;
  return result;
}

Future<void> writeCheckpoint(File file, Map<String, Object?> value) =>
    file.writeAsString(jsonEncode(value), flush: true);

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
  }
  throw StateError('Expected production UI did not become ready.');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await waitFor(tester, () => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Finder entryField(String key) => find.descendant(
  of: find.byKey(ValueKey('draft-$key')),
  matching: find.byType(TextField),
);

/// Preserve all prior domain rows exactly. Allocators may advance, never reset.
void expectBaseline(
  Map<String, dynamic> before,
  Map<String, Object?> after, {
  String? ownedCollection,
  String? ownedEntry,
}) {
  for (final table in tables) {
    final rows = (after[table] as List).where((row) {
      final data = row as Map;
      if (table == 'collections') return data['id'] != ownedCollection;
      if (table == 'vocabulary_entries') return data['id'] != ownedEntry;
      if (table == 'learning_items') return data['entry_id'] != ownedEntry;
      return true;
    }).toList();
    expect(
      rows,
      before[table],
      reason: 'Baseline $table must remain unchanged',
    );
  }
  expect(after['schema'], before['schema']);
  for (final table in sequences) {
    final old = (before[table] as List).single as Map;
    final current = (after[table] as List).single as Map;
    for (final key in old.keys) {
      if (key == 'next_id' || key == 'next_row_id') {
        expect(current[key], greaterThanOrEqualTo(old[key] as int));
      } else {
        expect(current[key], old[key]);
      }
    }
  }
}

void expectOwned(Map<String, dynamic> checkpoint, Map<String, Object?> state) {
  final owner = checkpoint['owner'] as Map;
  final entry = checkpoint['entry'] as Map;
  expect(
    (state['collections'] as List)
        .where((row) => (row as Map)['id'] == owner['id'])
        .toList(),
    [owner],
  );
  expect(
    (state['vocabulary_entries'] as List)
        .where((row) => (row as Map)['collection_id'] == owner['id'])
        .toList(),
    [entry],
  );
  expect(
    (state['learning_items'] as List)
        .where((row) => (row as Map)['entry_id'] == entry['id'])
        .toList(),
    checkpoint['learning'],
  );
}

Future<void> cleanupOwned(PikoDatabase db, Map<String, dynamic> checkpoint) =>
    db.transaction(() async {
      final owner = checkpoint['owner'] as Map;
      final entry = checkpoint['entry'] as Map;
      final current = await snapshot(db);
      expectOwned(checkpoint, current);
      expectBaseline(
        checkpoint['baseline'] as Map<String, dynamic>,
        current,
        ownedCollection: owner['id'] as String,
        ownedEntry: entry['id'] as String,
      );
      final deleted = await (db.delete(
        db.collections,
      )..where((row) => row.id.equals(owner['id'] as String))).go();
      expect(deleted, 1);
      expectBaseline(
        checkpoint['baseline'] as Map<String, dynamic>,
        await snapshot(db),
      );
    });
