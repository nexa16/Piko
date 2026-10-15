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
