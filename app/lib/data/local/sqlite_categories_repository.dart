import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:uuid/uuid.dart';
import '../categories_repository.dart';
import 'piko_database.dart';

final class SqliteCategoriesRepository implements CategoriesRepository {
  SqliteCategoriesRepository(this.database);
  final PikoDatabase database;

  String _name(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw CategoryValidation.requiredName;
    return trimmed;
  }

  String _id(String? id) {
    if (id == null) return const Uuid().v4();
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw CategoryValidation.invalidId;
    }
    return id.toLowerCase();
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await database.transaction(action);
    } on SqliteException catch (error) {
      if (error.extendedResultCode == 2067 &&
          (error.message.contains(
                'category_dimensions.collection_id, category_dimensions.name_key',
              ) ||
              error.message.contains(
                'category_values.dimension_id, category_values.name_key',
              ))) {
        throw CategoryValidation.duplicateName;
      }
      rethrow;
    }
  }

  Future<void> _availableId(String id) async {
    if (await dimensionById(id) != null || await valueById(id) != null) {
      throw CategoryValidation.identityConflict;
    }
  }

  CategoryDimensionRecord _dimension(StoredCategoryDimension row) =>
      CategoryDimensionRecord(
        id: row.id,
        collectionId: row.collectionId,
        name: row.name,
        mode: CategoryMode.values.byName(row.mode),
        position: row.position,
      );
  CategoryValueRecord _value(StoredCategoryValue row) => CategoryValueRecord(
    id: row.id,
    dimensionId: row.dimensionId,
    name: row.name,
    position: row.position,
  );

  SimpleSelectStatement<$CategoryDimensionsTable, StoredCategoryDimension>
  _dimensions(String collectionId) =>
      database.select(database.categoryDimensions)
        ..where((row) => row.collectionId.equals(collectionId))
        ..orderBy([
          (row) => OrderingTerm(expression: row.position),
          (row) => OrderingTerm(expression: row.id),
        ]);
  SimpleSelectStatement<$CategoryValuesTable, StoredCategoryValue> _values(
    String dimensionId,
  ) => database.select(database.categoryValues)
    ..where((row) => row.dimensionId.equals(dimensionId))
    ..orderBy([
      (row) => OrderingTerm(expression: row.position),
      (row) => OrderingTerm(expression: row.id),
    ]);

  @override
  Future<List<CategoryDimensionRecord>> dimensions(String collectionId) async =>
      (await _dimensions(
        collectionId,
      ).get()).map(_dimension).toList(growable: false);
  @override
  Stream<List<CategoryDimensionRecord>> watchDimensions(String collectionId) =>
      _dimensions(
        collectionId,
      ).watch().map((rows) => rows.map(_dimension).toList(growable: false));
  @override
  Future<CategoryDimensionRecord?> dimensionById(String id) async {
    final row = await (database.select(
      database.categoryDimensions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _dimension(row);
  }

  @override
  Future<List<CategoryValueRecord>> values(String dimensionId) async =>
      (await _values(dimensionId).get()).map(_value).toList(growable: false);
  @override
  Stream<List<CategoryValueRecord>> watchValues(String dimensionId) => _values(
    dimensionId,
  ).watch().map((rows) => rows.map(_value).toList(growable: false));
  @override
  Future<CategoryValueRecord?> valueById(String id) async {
    final row = await (database.select(
      database.categoryValues,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row == null ? null : _value(row);
  }

  @override
  Future<CategoryDimensionRecord> createDimension({
    required String collectionId,
    required String name,
    required CategoryMode mode,
    String? id,
  }) async {
    final trimmed = _name(name), identity = _id(id);
    return _write(() async {
      if (await (database.select(
            database.collections,
          )..where((row) => row.id.equals(collectionId))).getSingleOrNull() ==
          null) {
        throw CategoryValidation.collectionNotFound;
      }
      await _availableId(identity);
      final existing = await dimensions(collectionId);
      final position = existing.isEmpty ? 0 : existing.last.position + 1;
      await database
          .into(database.categoryDimensions)
          .insert(
            CategoryDimensionsCompanion.insert(
              id: identity,
              collectionId: collectionId,
              name: trimmed,
              nameKey: trimmed.toLowerCase(),
              mode: mode.name,
              position: position,
            ),
          );
      return (await dimensionById(identity))!;
    });
  }

  @override
  Future<CategoryDimensionRecord> renameDimension({
    required String id,
    required String name,
  }) async {
    final trimmed = _name(name);
    return _write(() async {
      final count =
          await (database.update(
            database.categoryDimensions,
          )..where((row) => row.id.equals(id))).write(
            CategoryDimensionsCompanion(
              name: Value(trimmed),
              nameKey: Value(trimmed.toLowerCase()),
            ),
          );
      if (count != 1) throw CategoryValidation.dimensionNotFound;
      return (await dimensionById(id))!;
    });
  }

  @override
  Future<void> deleteDimension(String id) => _write(() async {
    final count = await (database.delete(
      database.categoryDimensions,
    )..where((row) => row.id.equals(id))).go();
    if (count != 1) throw CategoryValidation.dimensionNotFound;
    database.notifyUpdates({
      TableUpdate.onTable(database.categoryValues, kind: UpdateKind.delete),
      TableUpdate.onTable(
        database.vocabularyCategoryAssignments,
        kind: UpdateKind.delete,
      ),
    });
  });

  @override
  Future<CategoryValueRecord> createValue({
    required String dimensionId,
    required String name,
    String? id,
  }) async {
    final trimmed = _name(name), identity = _id(id);
    return _write(() async {
      if (await dimensionById(dimensionId) == null) {
        throw CategoryValidation.dimensionNotFound;
      }
      await _availableId(identity);
      final existing = await values(dimensionId);
      final position = existing.isEmpty ? 0 : existing.last.position + 1;
      await database
          .into(database.categoryValues)
          .insert(
            CategoryValuesCompanion.insert(
              id: identity,
              dimensionId: dimensionId,
              name: trimmed,
              nameKey: trimmed.toLowerCase(),
              position: position,
            ),
          );
      return (await valueById(identity))!;
    });
  }

  @override
  Future<CategoryValueRecord> renameValue({
    required String id,
    required String name,
  }) async {
    final trimmed = _name(name);
    return _write(() async {
      final count =
          await (database.update(
            database.categoryValues,
          )..where((row) => row.id.equals(id))).write(
            CategoryValuesCompanion(
              name: Value(trimmed),
              nameKey: Value(trimmed.toLowerCase()),
            ),
          );
      if (count != 1) throw CategoryValidation.valueNotFound;
      return (await valueById(id))!;
    });
  }

  @override
  Future<void> deleteValue(String id) => _write(() async {
    final count = await (database.delete(
      database.categoryValues,
    )..where((row) => row.id.equals(id))).go();
    if (count != 1) throw CategoryValidation.valueNotFound;
    database.notifyUpdates({
      TableUpdate.onTable(
        database.vocabularyCategoryAssignments,
        kind: UpdateKind.delete,
      ),
    });
  });

  Selectable<QueryRow> _assignments(String entryId) => database.customSelect(
    'SELECT a.dimension_id, a.value_id FROM vocabulary_category_assignments a '
    'JOIN category_dimensions d ON d.id = a.dimension_id JOIN category_values v ON v.id = a.value_id '
    'WHERE a.entry_id = ? ORDER BY d.position, d.id, v.position, v.id',
    variables: [Variable(entryId)],
    readsFrom: {
      database.vocabularyCategoryAssignments,
      database.categoryDimensions,
      database.categoryValues,
    },
  );

  List<CategoryAssignmentRecord> _assignmentRecords(List<QueryRow> rows) {
    final groups = <String, Set<String>>{};
    for (final row in rows) {
      groups
          .putIfAbsent(row.read<String>('dimension_id'), () => <String>{})
          .add(row.read<String>('value_id'));
    }
    return groups.entries
        .map(
          (group) => CategoryAssignmentRecord(
            dimensionId: group.key,
            valueIds: group.value,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CategoryAssignmentRecord>> assignments(String entryId) async =>
      _assignmentRecords(await _assignments(entryId).get());
  @override
  Stream<List<CategoryAssignmentRecord>> watchAssignments(String entryId) =>
      _assignments(entryId).watch().map(_assignmentRecords);

  @override
  Future<void> replaceAssignments({
    required String entryId,
    required Map<String, Set<String>> assignments,
  }) {
    // Capture caller-owned mutable collections before the first asynchronous read.
    final requested = {
      for (final group in assignments.entries)
        group.key: Set<String>.of(group.value),
    };
    return _write(() async {
      final entry = await (database.select(
        database.vocabularyEntries,
      )..where((row) => row.id.equals(entryId))).getSingleOrNull();
      if (entry == null) throw CategoryValidation.entryNotFound;
      for (final group in requested.entries) {
        final dimension = await dimensionById(group.key);
        if (dimension == null) throw CategoryValidation.dimensionNotFound;
        if (dimension.collectionId != entry.collectionId) {
          throw CategoryValidation.invalidOwnership;
        }
        for (final id in group.value) {
          final value = await valueById(id);
          if (value == null) throw CategoryValidation.valueNotFound;
          if (value.dimensionId != dimension.id) {
            throw CategoryValidation.invalidOwnership;
          }
        }
      }
      await (database.delete(
        database.vocabularyCategoryAssignments,
      )..where((row) => row.entryId.equals(entryId))).go();
      for (final group in requested.entries) {
        for (final id in group.value) {
          await database
              .into(database.vocabularyCategoryAssignments)
              .insert(
                VocabularyCategoryAssignmentsCompanion.insert(
                  entryId: entryId,
                  collectionId: entry.collectionId,
                  dimensionId: group.key,
                  valueId: id,
                ),
              );
        }
      }
    });
  }
}
