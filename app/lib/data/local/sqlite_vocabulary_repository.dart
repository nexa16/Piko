import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../vocabulary_repository.dart';
import 'piko_database.dart';

final class SqliteVocabularyRepository implements VocabularyRepository {
  SqliteVocabularyRepository(this.database);
  final PikoDatabase database;

  VocabularyRecord _record(VocabularyEntry row) => VocabularyRecord(
    id: row.id,
    collectionId: row.collectionId,
    targetText: row.targetText,
    nativeText: row.nativeText,
  );

  @override
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) =>
      (database.select(database.vocabularyEntries)
            ..where((row) => row.collectionId.equals(collectionId))
            ..orderBy([
              (_) => OrderingTerm(
                expression: const CustomExpression<int>('rowid'),
              ),
            ]))
          .watch()
          .map((rows) => rows.map(_record).toList(growable: false));

  @override
  Stream<VocabularyRecord?> watchById(String id) =>
      (database.select(database.vocabularyEntries)
            ..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _record(row));

  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) async {
    if (targetText.trim().isEmpty) throw VocabularyValidation.requiredTarget;
    if (nativeText.trim().isEmpty) throw VocabularyValidation.requiredNative;
    return database.transaction(() async {
      final collection = await (database.select(
        database.collections,
      )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
      if (collection == null) throw VocabularyValidation.collectionNotFound;
      final id = const Uuid().v4();
      await database
          .into(database.vocabularyEntries)
          .insert(
            VocabularyEntriesCompanion.insert(
              id: id,
              collectionId: collectionId,
              targetText: targetText,
              nativeText: nativeText,
            ),
          );
      return VocabularyRecord(
        id: id,
        collectionId: collectionId,
        targetText: targetText,
        nativeText: nativeText,
      );
    });
  }
}
