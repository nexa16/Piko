import 'vocabulary_language.dart';
export 'vocabulary_language.dart';

final class CollectionRecord {
  const CollectionRecord({
    required this.id,
    required this.name,
    required this.targetLanguage,
    required this.nativeLanguage,
    this.level = 'A1',
  });
  final String id;
  final String name;
  final VocabularyLanguage targetLanguage;
  final VocabularyLanguage nativeLanguage;
  final String level;
  static const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
}

enum CollectionValidation {
  requiredName,
  sameLanguage,
  collectionNotFound,
  invalidLevel,
}

abstract interface class CollectionLevelRepository {
  Future<CollectionRecord> setLevel({
    required String id,
    required String level,
  });
  Future<CollectionRecord> createWithLevel({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
    required String level,
  });
}

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
