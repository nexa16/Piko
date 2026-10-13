import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import '../vocabulary_repository.dart';
import '../vocabulary_normalization.dart';
import 'piko_database.dart';

final class SqliteVocabularyRepository implements VocabularyRepository {
  SqliteVocabularyRepository(this.database);
  final PikoDatabase database;

  Future<VocabularyRecord> _write(
    Future<VocabularyRecord> Function() action,
  ) async {
    try {
      return await database.transaction(action);
    } on SqliteException catch (error) {
      // SQLITE_CONSTRAINT_UNIQUE: only the normalized pair is a UNIQUE key.
      if (error.extendedResultCode == 2067) {
        throw VocabularyValidation.duplicatePair;
      }
      rethrow;
    }
  }

  (String, String) _texts(String targetText, String nativeText) {
    final target = normalizeVocabularyText(targetText);
    final native = normalizeVocabularyText(nativeText);
    if (target.isEmpty) throw VocabularyValidation.requiredTarget;
    if (native.isEmpty) throw VocabularyValidation.requiredNative;
    return (target, native);
  }

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
    final (target, native) = _texts(targetText, nativeText);
    return _write(() async {
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
              targetText: target,
              nativeText: native,
              targetKey: vocabularyComparisonKey(target),
              nativeKey: vocabularyComparisonKey(native),
            ),
          );
      return VocabularyRecord(
        id: id,
        collectionId: collectionId,
        targetText: target,
        nativeText: native,
      );
    });
  }

  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) async {
    final (target, native) = _texts(targetText, nativeText);
    return _write(() async {
      final existing = await (database.select(
        database.vocabularyEntries,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing == null) throw VocabularyValidation.entryNotFound;
      await (database.update(
        database.vocabularyEntries,
      )..where((row) => row.id.equals(id))).write(
        VocabularyEntriesCompanion(
          targetText: Value(target),
          nativeText: Value(native),
          targetKey: Value(vocabularyComparisonKey(target)),
          nativeKey: Value(vocabularyComparisonKey(native)),
        ),
      );
      return VocabularyRecord(
        id: existing.id,
        collectionId: existing.collectionId,
        targetText: target,
        nativeText: native,
      );
    });
  }
}
