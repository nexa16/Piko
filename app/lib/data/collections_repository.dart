import 'vocabulary_language.dart';
export 'vocabulary_language.dart';

final class CollectionRecord {
  const CollectionRecord({
    required this.id,
    required this.name,
    required this.targetLanguage,
    required this.nativeLanguage,
  });
  final String id;
  final String name;
  final VocabularyLanguage targetLanguage;
  final VocabularyLanguage nativeLanguage;
}

enum CollectionValidation { requiredName, sameLanguage, collectionNotFound }

abstract interface class CollectionsRepository {
  /// Permanently removes only this Collection and its dependent vocabulary/progress.
  Future<void> delete(String id);

  /// Changes only the existing Collection's name; storage remains caller-owned.
  Future<CollectionRecord> rename({required String id, required String name});
  Stream<List<CollectionRecord>> watchAll();
  Stream<CollectionRecord?> watchById(String id);
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  });
}
