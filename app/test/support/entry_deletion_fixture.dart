import 'dart:async';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'mutable_clock.dart';

class GatedDeletion implements VocabularyDeletionService {
  GatedDeletion(this.real);
  final VocabularyDeletionService real;
  Completer<void>? deleteGate, restoreGate, afterRestoreGate, afterDeleteGate;
  bool failDelete = false, failRestore = false;
  int deletes = 0, restores = 0, disposals = 0;
  final receipts = <VocabularyDeletionReceipt>[];
  @override
  Future<VocabularyDeletionReceipt> delete(String id) async {
    deletes++;
    await deleteGate?.future;
    if (failDelete) throw StateError('Delete unavailable');
    final receipt = await real.delete(id);
    receipts.add(receipt);
    await afterDeleteGate?.future;
    return receipt;
  }

  @override
  Future<VocabularyRecord> restore(VocabularyDeletionReceipt receipt) async {
    restores++;
    await restoreGate?.future;
    if (failRestore) throw StateError('Restore unavailable');
    final restored = await real.restore(receipt);
    await afterRestoreGate?.future;
    return restored;
  }

  @override
  bool canUndo(VocabularyDeletionReceipt receipt) => real.canUndo(receipt);
  @override
  void expireUndo() => real.expireUndo();
  @override
  void forget(VocabularyDeletionReceipt receipt) => real.forget(receipt);
  @override
  void dispose() {
    disposals++;
    real.dispose();
  }
}

class GatedEntryRepository implements VocabularyRepository {
  GatedEntryRepository(this.real);
  final VocabularyRepository real;
  final updateGates = <String, Completer<void>>{};
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) => real.create(
    collectionId: collectionId,
    targetText: targetText,
    nativeText: nativeText,
  );
  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) async {
    await updateGates[id]?.future;
    return real.update(id: id, targetText: targetText, nativeText: nativeText);
  }

  @override
  Stream<List<VocabularyRecord>> watchByCollection(String id) =>
      real.watchByCollection(id);
  @override
  Stream<VocabularyRecord?> watchById(String id) => real.watchById(id);
}

class EntryDeletionFixture {
  final clock = MutablePikoClock(DateTime.utc(2026, 10, 14));
  late final PikoDatabase db = PikoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    clock: clock,
  );
  late CollectionRecord owner;
  late GatedEntryRepository repository;
  late GatedDeletion deletion;
  late EntrySessionController session;
  final sessions = <EntrySessionController>[];
  Future<void> initialize() async {
    owner = await SqliteCollectionsRepository(db).create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    repository = GatedEntryRepository(SqliteVocabularyRepository(db));
    deletion = GatedDeletion(SqliteVocabularyDeletionService(db));
    session = newSession();
  }

  EntrySessionController newSession() {
    final value = EntrySessionController(
      collectionId: owner.id,
      repository: repository,
      deletionService: deletion,
      clock: clock,
    );
    sessions.add(value);
    return value;
  }

  Future<VocabularyRecord> confirm(String target, String native) {
    session.setTargetText(target);
    session.setNativeText(native);
    return session.confirmAndNext();
  }

  Future<void> dispose() async {
    for (final value in sessions) {
      value.dispose();
    }
    deletion.dispose();
    await db.close();
  }
}
