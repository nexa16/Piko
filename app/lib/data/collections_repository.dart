enum VocabularyLanguage {
  korean('ko'),
  french('fr'),
  english('en'),
  german('de');

  const VocabularyLanguage(this.code);
  final String code;
  String get copyKey => 'language.$name';
}

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

enum CollectionValidation { requiredName, sameLanguage }

abstract interface class CollectionsRepository {
  Stream<List<CollectionRecord>> watchAll();
  Stream<CollectionRecord?> watchById(String id);
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  });
}
