import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../collections_repository.dart';
import 'piko_database.dart';

final class SqliteCollectionsRepository implements CollectionsRepository {
  SqliteCollectionsRepository(this.database);
  final PikoDatabase database;

  @override
  Future<void> delete(String id) => database.transaction(() async {
    final count = await (database.delete(
      database.collections,
    )..where((row) => row.id.equals(id))).go();
    if (count != 1) throw CollectionValidation.collectionNotFound;
    // SQLite performs the FK cascade; dependent observers must also requery.
    database.notifyUpdates({
      TableUpdate.onTable(database.vocabularyEntries, kind: UpdateKind.delete),
      TableUpdate.onTable(database.learningItems, kind: UpdateKind.delete),
      TableUpdate.onTable(database.regularReviews, kind: UpdateKind.delete),
      TableUpdate.onTable(database.retryObligations, kind: UpdateKind.delete),
    });
  });

  @override
  Future<CollectionRecord> rename({
    required String id,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw CollectionValidation.requiredName;
    return database.transaction(() async {
      final count =
          await (database.update(database.collections)
                ..where((row) => row.id.equals(id)))
              .write(CollectionsCompanion(name: Value(trimmed)));
      if (count != 1) throw CollectionValidation.collectionNotFound;
      final row = await (database.select(
        database.collections,
      )..where((row) => row.id.equals(id))).getSingle();
      return _record(row);
    });
  }

  CollectionRecord _record(Collection row) => CollectionRecord(
    id: row.id,
    name: row.name,
    targetLanguage: VocabularyLanguage.values.singleWhere(
      (v) => v.code == row.targetLanguage,
    ),
    nativeLanguage: VocabularyLanguage.values.singleWhere(
      (v) => v.code == row.nativeLanguage,
    ),
  );

  @override
  Stream<List<CollectionRecord>> watchAll() =>
      (database.select(database.collections)..orderBy([
            (_) =>
                OrderingTerm(expression: const CustomExpression<int>('rowid')),
          ]))
          .watch()
          .map((rows) => rows.map(_record).toList(growable: false));

  @override
  Stream<CollectionRecord?> watchById(String id) =>
      (database.select(database.collections)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _record(row));

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
