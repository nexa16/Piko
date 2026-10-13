import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Lazily opens the private application database on first use.
QueryExecutor openPikoDatabase() => driftDatabase(
  name: 'piko',
  native: const DriftNativeOptions(
    databaseDirectory: getApplicationSupportDirectory,
  ),
);
