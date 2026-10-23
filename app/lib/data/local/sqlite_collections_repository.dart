import 'sqlite_category_defaults.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../collections_repository.dart';
import 'piko_database.dart';

final class SqliteCollectionsRepository
    implements CollectionsRepository, CollectionLevelRepository {
  SqliteCollectionsRepository(this.database, {this.interfaceLanguage});
  final String Function()? interfaceLanguage;
  final PikoDatabase database;

  @override
  Future<CollectionRecord> createWithLevel({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
    required String level,
  }) => database.transaction(() async {
    if (!CollectionRecord.levels.contains(level)) {
      throw CollectionValidation.invalidLevel;
    }
    final created = await create(
      name: name,
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
    );
    return setLevel(id: created.id, level: level);
  });

  @override
  Future<CollectionRecord> setLevel({
    required String id,
    required String level,
  }) => database.transaction(() async {
    if (!CollectionRecord.levels.contains(level)) {
      throw CollectionValidation.invalidLevel;
    }
    final count =
        await (database.update(database.collections)
              ..where((row) => row.id.equals(id)))
            .write(CollectionsCompanion(level: Value(level)));
    if (count != 1) throw CollectionValidation.collectionNotFound;
    return _record(
      await (database.select(
        database.collections,
      )..where((row) => row.id.equals(id))).getSingle(),
    );
  });

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
      TableUpdate.onTable(database.categoryDimensions, kind: UpdateKind.delete),
      TableUpdate.onTable(database.categoryValues, kind: UpdateKind.delete),
      TableUpdate.onTable(
        database.vocabularyCategoryAssignments,
        kind: UpdateKind.delete,
      ),
      TableUpdate.onTable(
        database.scopeAnswerOrdinals,
        kind: UpdateKind.delete,
      ),
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
    level: row.level,
    targetLanguage: VocabularyLanguage.stored(
      row.targetLanguage,
      row.targetLanguageName,
    ),
    nativeLanguage: VocabularyLanguage.stored(
      row.nativeLanguage,
      row.nativeLanguageName,
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
    if (targetLanguage.matches(nativeLanguage)) {
      throw CollectionValidation.sameLanguage;
    }
    final id = const Uuid().v4();
    return database.transaction(() async {
      await database
          .into(database.collections)
          .insert(
            CollectionsCompanion.insert(
              id: id,
              name: trimmed,
              targetLanguage: targetLanguage.code,
              nativeLanguage: nativeLanguage.code,
              targetLanguageName: Value(targetLanguage.customName),
              nativeLanguageName: Value(nativeLanguage.customName),
            ),
          );
      if (interfaceLanguage != null) {
        await SqliteCategoryDefaults(
          database,
        ).initialize(id, interfaceLanguage!());
      }
      return CollectionRecord(
        id: id,
        name: trimmed,
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
      );
    });
  }
}
