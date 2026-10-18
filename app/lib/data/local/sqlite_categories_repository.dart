import '../vocabulary_normalization.dart' show compareVocabularyLabels;
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

  CategoryDimensionRecord _dimension(QueryRow result) {
    final row = database.categoryDimensions.map(result.data);
    return CategoryDimensionRecord(
      id: row.id,
      collectionId: row.collectionId,
      name: row.name,
      mode: CategoryMode.values.byName(row.mode),
      position: row.position,
      carryOver: result.read<int>('carry_over') != 0,
      tagColorRole: result.readNullable<String>('tag_color_role'),
    );
  }

  CategoryValueRecord _value(StoredCategoryValue row) => CategoryValueRecord(
    id: row.id,
    dimensionId: row.dimensionId,
    name: row.name,
    position: row.position,
  );

  Selectable<QueryRow> _dimensions(String owner, {bool byId = false}) =>
      database.customSelect(
        'SELECT d.*, COALESCE(p.carry_over, 0) AS carry_over, p.tag_color_role '
        'FROM category_dimensions d LEFT JOIN category_group_preferences p '
        'ON p.dimension_id = d.id WHERE d.${byId ? 'id' : 'collection_id'} = ? '
        'ORDER BY d.position, d.id',
        variables: [Variable(owner)],
        readsFrom: {
          database.categoryDimensions,
          database.categoryGroupPreferences,
        },
      );
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
    final row = await _dimensions(id, byId: true).getSingleOrNull();
    return row == null ? null : _dimension(row);
  }

  Selectable<QueryRow> _orderedValues(String dimensionId) =>
      database.customSelect(
        'SELECT v.*, COALESCE(p.custom_value_order, 0) AS custom_order '
        'FROM category_values v LEFT JOIN category_group_preferences p '
        'ON p.dimension_id = v.dimension_id WHERE v.dimension_id = ? '
        'ORDER BY v.position, v.id',
        variables: [Variable(dimensionId)],
        readsFrom: {database.categoryValues, database.categoryGroupPreferences},
      );

  List<CategoryValueRecord> _sortedValues(List<QueryRow> rows) {
    final values = rows
        .map((row) => _value(database.categoryValues.map(row.data)))
        .toList();
    if (rows.isNotEmpty && rows.first.read<int>('custom_order') == 0) {
      values.sort((a, b) {
        final order = compareVocabularyLabels(a.name, b.name);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    }
    return values;
  }

  @override
  Future<List<CategoryValueRecord>> values(String dimensionId) async =>
      _sortedValues(await _orderedValues(dimensionId).get());
  @override
  Stream<List<CategoryValueRecord>> watchValues(String dimensionId) =>
      _orderedValues(dimensionId).watch().map(_sortedValues);

  @override
  Future<List<CategoryValueRecord>> reorderValues({
    required String dimensionId,
    required List<String> expectedOrder,
    required List<String> orderedIds,
  }) {
    final expected = List<String>.of(expectedOrder);
    final requested = List<String>.of(orderedIds);
    return _write(() async {
      if (await dimensionById(dimensionId) == null) {
        throw CategoryValidation.dimensionNotFound;
      }
      final current = await values(dimensionId);
      final ids = current.map((value) => value.id).toList();
      if (expected.length != ids.length ||
          Iterable<int>.generate(
            ids.length,
          ).any((i) => expected[i] != ids[i])) {
        throw CategoryValidation.staleOrder;
      }
      if (requested.length != ids.length ||
          requested.toSet().length != ids.length ||
          !requested.toSet().containsAll(ids)) {
        throw CategoryValidation.invalidOwnership;
      }
      if (Iterable<int>.generate(
        ids.length,
      ).every((i) => requested[i] == ids[i])) {
        return current;
      }
      await database
          .into(database.categoryGroupPreferences)
          .insertOnConflictUpdate(
            CategoryGroupPreferencesCompanion.insert(
              dimensionId: dimensionId,
              customValueOrder: const Value(true),
            ),
          );
      await _rankValues(requested);
      return values(dimensionId);
    });
  }

  Future<void> _rankValues(List<String> ids) async {
    for (var index = 0; index < ids.length; index++) {
      await (database.update(database.categoryValues)
            ..where((row) => row.id.equals(ids[index])))
          .write(CategoryValuesCompanion(position: Value(index)));
    }
  }

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
    bool carryOver = false,
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
      await database.assignCategoryTagColor(identity, collectionId);
      if (carryOver) await _saveCarryOver(identity, true);
      return (await dimensionById(identity))!;
    });
  }

  @override
  Future<CategoryDimensionRecord> renameDimension({
    required String id,
    required String name,
  }) async {
    _name(name);
    return _write(() async {
      final existing = await dimensionById(id);
      if (existing == null) throw CategoryValidation.dimensionNotFound;
      return updateDimension(id: id, name: name, mode: existing.mode);
    });
  }

  @override
  Future<CategoryDimensionRecord> updateDimension({
    required String id,
    required String name,
    required CategoryMode mode,
    bool? carryOver,
  }) async {
    final trimmed = _name(name);
    return _write(() async {
      final existing = await dimensionById(id);
      if (existing == null) throw CategoryValidation.dimensionNotFound;
      if (mode == CategoryMode.single) {
        final conflicts = await database
            .customSelect(
              'SELECT entry_id FROM vocabulary_category_assignments '
              'WHERE dimension_id = ? GROUP BY entry_id HAVING COUNT(*) > 1 LIMIT 1',
              variables: [Variable(id)],
            )
            .get();
        if (conflicts.isNotEmpty) throw CategoryValidation.cardinalityViolation;
      }
      final count =
          await (database.update(
            database.categoryDimensions,
          )..where((row) => row.id.equals(id))).write(
            CategoryDimensionsCompanion(
              name: Value(trimmed),
              nameKey: Value(trimmed.toLowerCase()),
              mode: Value(mode.name),
            ),
          );
      if (count != 1) throw CategoryValidation.dimensionNotFound;
      if (carryOver != null && carryOver != existing.carryOver) {
        await _saveCarryOver(id, carryOver);
      }
      return (await dimensionById(id))!;
    });
  }

  Future<void> _saveCarryOver(String id, bool enabled) => database
      .into(database.categoryGroupPreferences)
      .insertOnConflictUpdate(
        CategoryGroupPreferencesCompanion.insert(
          dimensionId: id,
          carryOver: Value(enabled),
        ),
      )
      .then((_) {});

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
      final existing = await _values(dimensionId).get();
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
    final value = await valueById(id);
    if (value == null) throw CategoryValidation.valueNotFound;
    final count = await (database.delete(
      database.categoryValues,
    )..where((row) => row.id.equals(id))).go();
    if (count != 1) throw CategoryValidation.valueNotFound;
    final preference =
        await (database.select(database.categoryGroupPreferences)
              ..where((row) => row.dimensionId.equals(value.dimensionId)))
            .getSingleOrNull();
    if (preference?.customValueOrder == true) {
      await _rankValues(
        (await values(value.dimensionId)).map((value) => value.id).toList(),
      );
    }
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
  Future<void> setValueSelected({
    required String entryId,
    required String valueId,
    required bool selected,
  }) => _write(() async {
    final value = await valueById(valueId);
    if (value == null) throw CategoryValidation.valueNotFound;
    final dimension = await dimensionById(value.dimensionId);
    if (dimension == null) throw CategoryValidation.dimensionNotFound;
    final current = {
      for (final group in await assignments(entryId))
        group.dimensionId: Set<String>.of(group.valueIds),
    };
    final values = current.putIfAbsent(dimension.id, () => <String>{});
    if (selected) {
      if (dimension.mode == CategoryMode.single) values.clear();
      values.add(valueId);
    } else {
      values.remove(valueId);
    }
    // Retain the touched dimension even when empty so reference/owner validation
    // still runs for deselection, then reuse the full replacement boundary.
    await replaceAssignments(entryId: entryId, assignments: current);
  });

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
      await validateAssignments(
        collectionId: entry.collectionId,
        assignments: requested,
      );
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

  /// Shared preflight inside the caller's transaction, including for a new
  /// vocabulary UUID that must not be allocated until category validation passes.
  Future<void> validateAssignments({
    required String collectionId,
    required Map<String, Set<String>> assignments,
  }) async {
    for (final group in assignments.entries) {
      final dimension = await dimensionById(group.key);
      if (dimension == null) throw CategoryValidation.dimensionNotFound;
      if (dimension.collectionId != collectionId) {
        throw CategoryValidation.invalidOwnership;
      }
      if (dimension.mode == CategoryMode.single && group.value.length > 1) {
        throw CategoryValidation.cardinalityViolation;
      }
      for (final id in group.value) {
        final value = await valueById(id);
        if (value == null) throw CategoryValidation.valueNotFound;
        if (value.dimensionId != dimension.id) {
          throw CategoryValidation.invalidOwnership;
        }
      }
    }
  }
}
