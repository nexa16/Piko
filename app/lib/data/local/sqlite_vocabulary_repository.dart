import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import '../vocabulary_repository.dart';
import '../vocabulary_normalization.dart';
import 'piko_database.dart';
import 'sqlite_categories_repository.dart';

final class _OpeningSnapshot implements CategorizedVocabularyOpeningSnapshot {
  const _OpeningSnapshot(this.entry, this.issuer, this.assignments);
  @override
  final VocabularyRecord entry;
  final Object issuer;
  @override
  final Map<String, Set<String>> assignments;
}

final class SqliteVocabularyRepository
    implements CategorizedVocabularyRepository {
  SqliteVocabularyRepository(this.database);
  final PikoDatabase database;
  final _issuer = Object();

  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) => database.transaction(() async {
    final row =
        await (database.select(database.vocabularyEntries)..where(
              (row) =>
                  row.id.equals(entryId) &
                  row.collectionId.equals(collectionId),
            ))
            .getSingleOrNull();
    if (row == null) throw VocabularyValidation.entryNotFound;
    return _OpeningSnapshot(
      _record(row),
      _issuer,
      await categorizedAssignments(entryId),
    );
  });

  @override
  Future<Map<String, Set<String>>> categorizedAssignments(
    String entryId,
  ) async => Map.unmodifiable({
    for (final group in await SqliteCategoriesRepository(
      database,
    ).assignments(entryId))
      group.dimensionId: Set<String>.unmodifiable(group.valueIds),
  });

  @override
  Future<VocabularyRecord> createCategorized({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) {
    final requested = {
      for (final group in assignments.entries)
        group.key: Set<String>.of(group.value),
    };
    return _write(() async {
      final categories = SqliteCategoriesRepository(database);
      await categories.validateAssignments(
        collectionId: collectionId,
        assignments: requested,
      );
      final saved = await create(
        collectionId: collectionId,
        targetText: targetText,
        nativeText: nativeText,
      );
      await categories.replaceAssignments(
        entryId: saved.id,
        assignments: requested,
      );
      return saved;
    });
  }

  @override
  Future<VocabularyRecord> updateCategorized({
    required String id,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  }) {
    final requested = {
      for (final group in assignments.entries)
        group.key: Set<String>.of(group.value),
    };
    return _write(() async {
      final saved = await update(
        id: id,
        targetText: targetText,
        nativeText: nativeText,
      );
      await SqliteCategoriesRepository(
        database,
      ).replaceAssignments(entryId: id, assignments: requested);
      return saved;
    });
  }

  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) {
    if (snapshot is! _OpeningSnapshot || !identical(snapshot.issuer, _issuer)) {
      throw StateError('Opening snapshot belongs to a different repository.');
    }
    final original = snapshot.entry;
    return _write(() async {
      final row =
          await (database.select(database.vocabularyEntries)..where(
                (row) =>
                    row.id.equals(original.id) &
                    row.collectionId.equals(original.collectionId),
              ))
              .getSingleOrNull();
      if (row == null) throw VocabularyValidation.entryNotFound;
      final owner =
          await (database.select(database.collections)
                ..where((row) => row.id.equals(original.collectionId)))
              .getSingleOrNull();
      if (owner == null) throw VocabularyValidation.collectionNotFound;
      final count =
          await (database.update(database.vocabularyEntries)..where(
                (row) =>
                    row.id.equals(original.id) &
                    row.collectionId.equals(original.collectionId),
              ))
              .write(
                VocabularyEntriesCompanion(
                  targetText: Value(original.targetText),
                  nativeText: Value(original.nativeText),
                  targetKey: Value(
                    vocabularyComparisonKey(original.targetText),
                  ),
                  nativeKey: Value(
                    vocabularyComparisonKey(original.nativeText),
                  ),
                ),
              );
      if (count != 1) throw VocabularyValidation.entryNotFound;
      // Explicit deletion of definitions remains effective: Discard restores
      // surviving assignments, never recreates a deleted category or value.
      final categories = SqliteCategoriesRepository(database);
      final assignments = <String, Set<String>>{};
      for (final group in snapshot.assignments.entries) {
        final dimension = await categories.dimensionById(group.key);
        if (dimension == null ||
            dimension.collectionId != original.collectionId)
          continue;
        final surviving = <String>{};
        for (final id in group.value) {
          final value = await categories.valueById(id);
          if (value?.dimensionId == group.key) surviving.add(id);
        }
        if (surviving.isNotEmpty) assignments[group.key] = surviving;
      }
      await categories.replaceAssignments(
        entryId: original.id,
        assignments: assignments,
      );
      return original;
    });
  }

  Future<VocabularyRecord> _write(
    Future<VocabularyRecord> Function() action,
  ) async {
    try {
      return await database.transaction(action);
    } on SqliteException catch (error) {
      // Other tables also have unique keys; only translate this exact constraint.
      if (error.extendedResultCode == 2067 &&
          error.message.contains(
            'vocabulary_entries.collection_id, vocabulary_entries.target_key, vocabulary_entries.native_key',
          )) {
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
      final rowId = await database.allocateVocabularyRowId();
      await database.customInsert(
        'INSERT INTO vocabulary_entries (rowid, id, collection_id, target_text, native_text, target_key, native_key) VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable(rowId),
          Variable(id),
          Variable(collectionId),
          Variable(target),
          Variable(native),
          Variable(vocabularyComparisonKey(target)),
          Variable(vocabularyComparisonKey(native)),
        ],
        updates: {database.vocabularyEntries},
      );
      await database.createLearningItems(id);
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
