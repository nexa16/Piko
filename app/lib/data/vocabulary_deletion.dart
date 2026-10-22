import 'vocabulary_repository.dart';

/// Opaque, temporary Undo capability issued by one deletion service instance.
abstract interface class VocabularyDeletionReceipt {
  VocabularyRecord get entry;
  DateTime get expiresAt;
}

enum VocabularyUndoFailure {
  invalidReceipt,
  expired,
  alreadyUsed,
  collectionNotFound,
  duplicatePair,
  identityConflict,
  categoryConflict,
}

abstract interface class VocabularyDeletionService {
  Future<VocabularyDeletionReceipt> delete(String id);
  Future<VocabularyRecord> restore(VocabularyDeletionReceipt receipt);
  bool canUndo(VocabularyDeletionReceipt receipt);

  /// Caller schedules this at receipt deadlines; operations also sweep lazily.
  /// Disposal/forget release snapshots when the owning UI lifetime ends.
  void expireUndo();
  void forget(VocabularyDeletionReceipt receipt);
  void dispose();
}

/// Atomic Collection-owned batch; duplicate identities are deleted once.
abstract interface class VocabularyBatchDeletionService {
  Future<List<VocabularyDeletionReceipt>> deleteMany({
    required String collectionId,
    required Set<String> ids,
  });
}

final class VocabularyTrashGroup {
  const VocabularyTrashGroup({
    required this.id,
    required this.collectionId,
    required this.deletedAt,
    required this.expiresAt,
    required this.entries,
  });
  final String id, collectionId;
  final DateTime deletedAt, expiresAt;
  final List<VocabularyRecord> entries;
}

final class VocabularyTrashRestoreResult {
  VocabularyTrashRestoreResult({
    required Iterable<String> restoredIds,
    Map<String, VocabularyUndoFailure> conflicts = const {},
    Iterable<String> omittedCategoryEntryIds = const [],
  }) : restoredIds = Set.unmodifiable(restoredIds),
       conflicts = Map.unmodifiable(conflicts),
       omittedCategoryEntryIds = Set.unmodifiable(omittedCategoryEntryIds);
  final Set<String> restoredIds, omittedCategoryEntryIds;
  final Map<String, VocabularyUndoFailure> conflicts;
}

abstract interface class VocabularyTrashService {
  Future<List<VocabularyTrashGroup>> trashGroups({
    required String collectionId,
  });
  Future<VocabularyTrashRestoreResult> restoreTrashEntry(String entryId);
  Future<VocabularyTrashRestoreResult> restoreTrashGroup(String groupId);
  Future<void> clearTrash(String collectionId);
  Future<void> purgeExpiredTrash();
}
