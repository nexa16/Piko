import 'package:uuid/uuid.dart';
import '../collections_repository.dart';
import 'piko_database.dart';

final class SqliteCollectionsRepository implements CollectionsRepository {
  SqliteCollectionsRepository(this.database);
  final PikoDatabase database;

  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw CollectionValidation.requiredName;
    if (targetLanguage == nativeLanguage) {
      throw CollectionValidation.sameLanguage;
    }
    final id = const Uuid().v4();
    await database
        .into(database.collections)
        .insert(
          CollectionsCompanion.insert(
            id: id,
            name: trimmed,
            targetLanguage: targetLanguage.code,
            nativeLanguage: nativeLanguage.code,
          ),
        );
    return CollectionRecord(
      id: id,
      name: trimmed,
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
    );
  }
}
