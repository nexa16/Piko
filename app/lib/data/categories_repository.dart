enum CategoryMode { single, multiple }

final class CategoryDimensionRecord {
  const CategoryDimensionRecord({
    required this.id,
    required this.collectionId,
    required this.name,
    required this.mode,
    required this.position,
  });
  final String id;
  final String collectionId;
  final String name;
  final CategoryMode mode;
  final int position;
}

final class CategoryValueRecord {
  const CategoryValueRecord({
    required this.id,
    required this.dimensionId,
    required this.name,
    required this.position,
  });
  final String id;
  final String dimensionId;
  final String name;
  final int position;
}

/// An immutable set of assigned value UUIDs in one dimension.
final class CategoryAssignmentRecord {
  CategoryAssignmentRecord({
    required this.dimensionId,
    required Set<String> valueIds,
  }) : valueIds = Set.unmodifiable(valueIds);
  final String dimensionId;
  final Set<String> valueIds;
}

enum CategoryValidation {
  requiredName,
  duplicateName,
  collectionNotFound,
  dimensionNotFound,
  valueNotFound,
  entryNotFound,
  invalidOwnership,
  invalidId,
  identityConflict,
  cardinalityViolation,
  staleOrder,
}

abstract interface class CategoriesRepository {
  Future<List<CategoryDimensionRecord>> dimensions(String collectionId);
  Future<CategoryDimensionRecord?> dimensionById(String id);
  Future<List<CategoryValueRecord>> values(String dimensionId);
  Future<CategoryValueRecord?> valueById(String id);
  Stream<List<CategoryDimensionRecord>> watchDimensions(String collectionId);
  Stream<List<CategoryValueRecord>> watchValues(String dimensionId);
  Future<CategoryDimensionRecord> createDimension({
    required String collectionId,
    required String name,
    required CategoryMode mode,
    String? id,
  });
  Future<CategoryDimensionRecord> renameDimension({
    required String id,
    required String name,
  });

  /// Confirms both editable fields together. Switching to Single never drops
  /// existing assignments; conflicting entries must be resolved first.
  Future<CategoryDimensionRecord> updateDimension({
    required String id,
    required String name,
    required CategoryMode mode,
  });
  Future<void> deleteDimension(String id);
  Future<CategoryValueRecord> createValue({
    required String dimensionId,
    required String name,
    String? id,
  });
  Future<CategoryValueRecord> renameValue({
    required String id,
    required String name,
  });
  Future<void> deleteValue(String id);

  /// Commits a complete group permutation only if its observed sequence is still
  /// current. Inputs are captured on admission; no-op moves keep default A–Z.
  Future<List<CategoryValueRecord>> reorderValues({
    required String dimensionId,
    required List<String> expectedOrder,
    required List<String> orderedIds,
  });
  Future<List<CategoryAssignmentRecord>> assignments(String entryId);
  Stream<List<CategoryAssignmentRecord>> watchAssignments(String entryId);

  /// Explicit picker action: selecting replaces the old Single selection, or
  /// adds to Multiple. Deselecting removes only this value in either mode.
  Future<void> setValueSelected({
    required String entryId,
    required String valueId,
    required bool selected,
  });

  /// Replaces all assignments atomically, after validating every reference.
  /// Empty input explicitly clears assignments. Definitions are never changed.
  /// Unlike a picker selection, a Single group containing several values fails
  /// rather than choosing one. JSON uses this same validated write boundary.
  Future<void> replaceAssignments({
    required String entryId,
    required Map<String, Set<String>> assignments,
  });
}
