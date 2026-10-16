import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Never mount PikoRuntime or openPikoDatabase here: the installed file is only
// read as bytes. The migrated clone remains private; there is no cleanup/export.
const _sourceName = 'piko.sqlite';
const _sentinelName = 'release-final-sentinel.txt';

void _require(bool condition, String code) {
  if (!condition) throw StateError(code);
}

final class _ProtectedBytes {
  _ProtectedBytes(this.file, this.bytes) : contentHash = Object.hashAll(bytes);
  final File file;
  final Uint8List bytes;
  // This in-memory checksum is not a cryptographic claim. Exact byte equality
  // below is authoritative, so checksum collisions cannot mask a changed file.
  final int contentHash;
  static Future<_ProtectedBytes> read(File file) async {
    _require(
      await FileSystemEntity.type(file.path, followLinks: false) ==
          FileSystemEntityType.file,
      'protected-file-missing-or-link',
    );
    return _ProtectedBytes(file, await file.readAsBytes());
  }

  Future<void> verify() async {
    final current = await _ProtectedBytes.read(file);
    _require(
      contentHash == current.contentHash && listEquals(bytes, current.bytes),
      'protected-file-changed',
    );
  }
}

Future<void> _requireQuiescent(File file) async {
  // Fail closed even for empty sidecars; never checkpoint/open the source.
  for (final suffix in ['-wal', '-shm', '-journal']) {
    _require(
      await FileSystemEntity.type('${file.path}$suffix', followLinks: false) ==
          FileSystemEntityType.notFound,
      'source-sidecar-present',
    );
  }
}

String _quote(String identifier) => '"${identifier.replaceAll('"', '""')}"';

Object? _cell(Object? value) {
  if (value == null) return null;
  if (value is Uint8List) return ['blob', base64Encode(value)];
  if (value is int) return ['integer', value.toString()];
  if (value is double) {
    final bytes = ByteData(8)..setFloat64(0, value);
    return ['real', base64Encode(bytes.buffer.asUint8List())];
  }
  if (value is String) return ['text', value];
  throw StateError('unsupported-sqlite-value');
}

Map<String, String> _columns(sqlite.Database db, String table) => {
  for (final column in db.select('PRAGMA table_xinfo(${_quote(table)})'))
    column['name'] as String: jsonEncode([
      for (final key in [
        'cid',
        'name',
        'type',
        'notnull',
        'dflt_value',
        'pk',
        'hidden',
      ])
        _cell(column[key]),
    ]),
};

List<String> _rows(
  sqlite.Database db,
  String table,
  List<String> columns,
  String? rowId,
) {
  var alias = '__piko_upgrade_rowid__';
  while (columns.any((column) => column.toLowerCase() == alias)) {
    alias = '_$alias';
  }
  final projection = [
    if (rowId != null) '${_quote(rowId)} AS ${_quote(alias)}',
    ...columns.map(_quote),
  ].join(', ');
  final result = db.select('SELECT $projection FROM ${_quote(table)}');
  // Compare multisets without depending on query order; an accessible rowid is
  // included separately so logical/physical vocabulary ordering is preserved.
  final rows = [
    for (final row in result)
      jsonEncode([
        for (var i = 0; i < result.columnNames.length; i++)
          _cell(row.values.elementAt(i)),
      ]),
  ];
  rows.sort();
  return rows;
}

final class _OldTable {
  _OldTable(this.name, this.columns, this.rowId, this.rows);
  final String name;
  final Map<String, String> columns;
  final String? rowId;
  final List<String> rows;
}

final class _Baseline {
  _Baseline(this.version, this.tables);
  final int version;
  final List<_OldTable> tables;
}

_Baseline _capture(File clone) {
  final db = sqlite.sqlite3.open(clone.path, mode: sqlite.OpenMode.readOnly);
  try {
    final version =
        db.select('PRAGMA user_version').single.values.single as int;
    final tables = <_OldTable>[];
    for (final table in db.select(
      "SELECT name, sql FROM sqlite_schema WHERE type = 'table' ORDER BY name",
    )) {
      final name = table['name'] as String;
      final columns = _columns(db, name);
      _require(columns.isNotEmpty, 'empty-column-schema');
      final withoutRowId = RegExp(
        r'\bWITHOUT\s+ROWID\b',
        caseSensitive: false,
      ).hasMatch(table['sql'] as String? ?? '');
      final rowId = withoutRowId
          ? null
          : ['rowid', '_rowid_', 'oid']
                .where(
                  (candidate) => !columns.keys.any(
                    (name) => name.toLowerCase() == candidate,
                  ),
                )
                .firstOrNull;
      tables.add(
        _OldTable(
          name,
          columns,
          rowId,
          _rows(db, name, columns.keys.toList(), rowId),
        ),
      );
    }
    _require(tables.isNotEmpty, 'empty-installed-database');
    return _Baseline(version, tables);
  } finally {
    db.close();
  }
}

void _verifyOldTables(File clone, _Baseline baseline, int targetSchema) {
  final db = sqlite.sqlite3.open(clone.path, mode: sqlite.OpenMode.readOnly);
  try {
    _require(
      db.select('PRAGMA user_version').single.values.single == targetSchema,
      'target-schema-mismatch',
    );
    final names = {
      for (final row in db.select(
        "SELECT name FROM sqlite_schema WHERE type = 'table'",
      ))
        row['name'],
    };
    for (final table in baseline.tables) {
      _require(names.contains(table.name), 'old-table-missing');
      final columns = _columns(db, table.name);
      for (final column in table.columns.entries) {
        _require(
          columns[column.key] == column.value,
          'old-column-schema-changed',
        );
      }
      _require(
        listEquals(
          _rows(db, table.name, table.columns.keys.toList(), table.rowId),
          table.rows,
        ),
        'old-rows-changed',
      );
    }
    _require(
      db.select('PRAGMA foreign_key_check').isEmpty,
      'foreign-key-check-failed',
    );
    _require(
      db.select('PRAGMA integrity_check').single.values.single == 'ok',
      'integrity-check-failed',
    );
  } finally {
    db.close();
  }
}

final class _UpgradeDatabase extends PikoDatabase {
  _UpgradeDatabase(File file) : super(NativeDatabase(file)) {
    _closed.future.ignore();
  }
  final _closed = Completer<void>();
  bool _closing = false;
  @override
  Future<void> close() async {
    if (_closing) return _closed.future;
    _closing = true;
    try {
      await super.close();
      _closed.complete();
    } catch (error, stack) {
      _closed.completeError(error, stack);
      rethrow;
    }
  }
}

Future<int> _openAndClose(File clone) async {
  final db = _UpgradeDatabase(clone);
  try {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    final version = row.read<int>('user_version');
    _require(version == db.schemaVersion, 'current-schema-not-opened');
    return version;
  } finally {
    await db.close();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'private installed-database clone preserves all old rows through current-schema upgrade and offline reopen',
    (tester) async {
      // Required inputs identify the exact candidate/run, never private records.
      const run = String.fromEnvironment('PIKO_UPGRADE_RUN');
      const commit = String.fromEnvironment('PIKO_UPGRADE_COMMIT');
      const sentinel = String.fromEnvironment('PIKO_UPGRADE_SENTINEL');
      const appFilename = String.fromEnvironment('PIKO_UPGRADE_APP_FILENAME');
      _require(Platform.isAndroid, 'android-required');
      _require(
        RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{7,79}$').hasMatch(run),
        'unique-run-id-required',
      );
      _require(
        RegExp(r'^[0-9a-f]{40}$').hasMatch(commit),
        'full-commit-required',
      );
      _require(sentinel == _sentinelName, 'expected-sentinel-required');
      _require(appFilename == _sourceName, 'unexpected-app-database-filename');
      final support = await getApplicationSupportDirectory();
      final source = File('${support.path}/$_sourceName');
      final marker = File('${support.path}/$sentinel');
      _ProtectedBytes? original, originalSentinel;
      Directory? directory;
      int? sourceSchema, targetSchema, oldTableCount;
      var stage = 'source-preflight';
      try {
        await _requireQuiescent(source);
        original = await _ProtectedBytes.read(source);
        originalSentinel = await _ProtectedBytes.read(marker);
        _require(
          originalSentinel.bytes.length == 71,
          'unexpected-sentinel-size',
        );
        _require(
          original.bytes.length >= 100 &&
              listEquals(
                original.bytes.sublist(0, 16),
                ascii.encode('SQLite format 3\u0000'),
              ),
          'unexpected-app-database-file',
        );
        directory = Directory('${support.path}/round2-upgrade-$run');
        _require(
          await FileSystemEntity.type(directory.path, followLinks: false) ==
              FileSystemEntityType.notFound,
          'run-already-exists',
        );
        await directory.create();
        final clone = File('${directory.path}/clone.sqlite');
        await clone.create(exclusive: true);
        await clone.writeAsBytes(original.bytes, flush: true);
        await _requireQuiescent(source);
        await original.verify();
        stage = 'clone-baseline';
        final baseline = _capture(clone);
        sourceSchema = baseline.version;
        oldTableCount = baseline.tables.length;
        _require(
          sourceSchema >= 10 && sourceSchema <= 12,
          'unsupported-installed-schema',
        );
        stage = 'clone-migration';
        var networkAttempts = 0;
        await HttpOverrides.runZoned<Future<void>>(
          () async {
            targetSchema = await _openAndClose(clone);
            stage = 'clone-preservation';
            _verifyOldTables(clone, baseline, targetSchema!);
            stage = 'offline-reopen';
            _require(
              await _openAndClose(clone) == targetSchema,
              'reopen-schema-changed',
            );
            _verifyOldTables(clone, baseline, targetSchema!);
          },
          createHttpClient: (_) {
            networkAttempts++;
            throw StateError('network-disabled');
          },
        );
        _require(networkAttempts == 0, 'network-attempted');
        stage = 'original-preservation';
        await _requireQuiescent(source);
        await original.verify();
        await originalSentinel.verify();
        final metadata = <String, Object?>{
          'status': 'passed',
          'runId': run,
          'commit': commit,
          'sourceSchema': sourceSchema,
          'targetSchema': targetSchema,
          'oldTableCount': oldTableCount,
          'schema10UpgradeVerified': sourceSchema == 10 && targetSchema == 12,
          'sameSchemaOnly': sourceSchema == targetSchema,
          'sourceAndSentinelUnchanged': true,
        };
        // Only this safe summary may leave app-private storage. In particular,
        // never print caught errors, SQL, table names, rows, identifiers or hashes.
        await File(
          '${directory.path}/manifest.json',
        ).writeAsString(jsonEncode(metadata), flush: true);
        binding.reportData = metadata;
        debugPrint(jsonEncode(metadata));
      } catch (_) {
        // Raw SQLite/file failures can contain private values or paths. Redact
        // those details, but still verify originals even after a failed migration.
        var protected = true;
        try {
          await _requireQuiescent(source);
          await original?.verify();
          await originalSentinel?.verify();
        } catch (_) {
          protected = false;
        }
        binding.reportData = {
          'status': 'failed',
          'runId': run,
          'commit': commit,
          'sourceSchema': sourceSchema,
          'targetSchema': targetSchema,
          'oldTableCount': oldTableCount,
          'sourceAndSentinelUnchanged':
              protected && original != null && originalSentinel != null,
        };
        throw TestFailure(
          'Private upgrade verification failed at $stage; private details suppressed.',
        );
      }
    },
  );
}
