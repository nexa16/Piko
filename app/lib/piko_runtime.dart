import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'data/local/database_connection.dart';
import 'data/local/piko_database.dart';
import 'data/local/sqlite_collections_repository.dart';
import 'data/local/sqlite_vocabulary_repository.dart';
import 'data/local/sqlite_vocabulary_deletion.dart';
import 'data/local/sqlite_learning_repository.dart';
import 'data/learning_item.dart';
import 'features/learning/due_learning_session.dart';
import 'features/collections/collections_home.dart';
import 'features/entry/entry_session_controller.dart';
import 'features/entry/entry_session_route.dart';
import 'features/vocabulary/collection_vocabulary_mutations.dart';

/// Owns private runtime storage. Injected feature repositories remain caller-owned.
class PikoRuntime extends StatefulWidget {
  const PikoRuntime({super.key, this.databaseFactory});

  /// Test/composition injection; the runtime owns the returned database.
  final PikoDatabase Function()? databaseFactory;
  @override
  State<PikoRuntime> createState() => _PikoRuntimeState();
}

class _PikoRuntimeState extends State<PikoRuntime> {
  late final database =
      widget.databaseFactory?.call() ??
      PikoDatabase(LazyDatabase(() async => openPikoDatabase()));
  late final collections = SqliteCollectionsRepository(database);
  late final vocabulary = SqliteVocabularyRepository(database);
  late final learning = SqliteLearningRepository(database);
  final pendingVocabularyWrites = <Future<void>>{};
  void trackWrites(Future<void> future) {
    final tracked = future.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    pendingVocabularyWrites.add(tracked);
    unawaited(
      tracked.whenComplete(() => pendingVocabularyWrites.remove(tracked)),
    );
  }

  Future<void> closeDatabase() async {
    // Sibling route disposal registers its accepted editor queues synchronously
    // during the same unmount traversal, before this microtask continues.
    await Future<void>.value();
    while (pendingVocabularyWrites.isNotEmpty) {
      await Future.wait(pendingVocabularyWrites.toList());
    }
    await database.close();
  }

  EntrySessionResources _entrySession(String collectionId) {
    final deletion = SqliteVocabularyDeletionService(database);
    return EntrySessionResources(
      session: EntrySessionController(
        collectionId: collectionId,
        repository: vocabulary,
        deletionService: deletion,
        clock: database.clock,
      ),
      deletionService: deletion,
    );
  }

  Future<DueLearningSession> _reviewSession(
    String collectionId,
    LearningDirection direction,
  ) async {
    final source = await learning.forCollection(
      collectionId: collectionId,
      direction: direction,
    );
    return DueLearningSession.start(
      source: source,
      cutoff: database.clock.now().toUtc(),
      clock: database.clock,
      onPendingWrites: trackWrites,
    );
  }

  CollectionVocabularyMutations _collectionMutations(String id) =>
      CollectionVocabularyMutations(
        collectionId: id,
        service: SqliteVocabularyDeletionService(database),
        clock: database.clock,
      );

  @override
  void dispose() {
    unawaited(closeDatabase());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CollectionsHome(
    repository: collections,
    entrySessionFactory: _entrySession,
    vocabularyRepository: vocabulary,
    onPendingVocabularyWrites: trackWrites,
    vocabularyMutationsFactory: _collectionMutations,
    reviewSessionFactory: _reviewSession,
  );
}
