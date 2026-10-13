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

enum VocabularyValidation { requiredTarget, requiredNative, collectionNotFound }

abstract interface class VocabularyRepository {
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  });
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId);
  Stream<VocabularyRecord?> watchById(String id);
}
