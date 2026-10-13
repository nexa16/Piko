import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'data/local/database_connection.dart';
import 'data/local/piko_database.dart';
import 'data/local/sqlite_collections_repository.dart';
import 'features/collections/collections_home.dart';

/// Owns private runtime storage. Injected feature repositories remain caller-owned.
class PikoRuntime extends StatefulWidget {
  const PikoRuntime({super.key});
  @override
  State<PikoRuntime> createState() => _PikoRuntimeState();
}

class _PikoRuntimeState extends State<PikoRuntime> {
  late final database = PikoDatabase(
    LazyDatabase(() async => openPikoDatabase()),
  );
  late final collections = SqliteCollectionsRepository(database);
  @override
  void dispose() {
    unawaited(database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CollectionsHome(repository: collections);
}
