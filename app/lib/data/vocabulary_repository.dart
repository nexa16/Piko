final class VocabularyRecord {
  const VocabularyRecord({
    required this.id,
    required this.collectionId,
    required this.targetText,
    required this.nativeText,
  });
  final String id;
  final String collectionId;
  final String targetText;
  final String nativeText;
}

enum VocabularyValidation {
  requiredTarget,
  requiredNative,
  collectionNotFound,
  entryNotFound,
  duplicatePair,
}

abstract interface class VocabularyOpeningSnapshot {
  VocabularyRecord get entry;
}

abstract interface class VocabularyRepository {
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  });
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  );
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  });
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  });
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId);
  Stream<VocabularyRecord?> watchById(String id);
}
