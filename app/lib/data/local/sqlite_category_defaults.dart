import '../../shared/catalogs.dart';
import '../categories_repository.dart';
import '../vocabulary_normalization.dart';
import 'piko_database.dart';
import 'sqlite_categories_repository.dart';

/// Only called inside creation of a new Collection. Never repairs or backfills a
/// saved catalog, so removal/renaming remains an ordinary supported operation.
final class SqliteCategoryDefaults {
  SqliteCategoryDefaults(this.database);
  final PikoDatabase database;
  Future<void> initialize(String collectionId, String locale) async {
    final copy = PikoCopy(locale), cats = SqliteCategoriesRepository(database);
    for (final spec in [
      ('level', CategoryMode.single, ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']),
      ('topic', CategoryMode.multiple, ['food', 'home', 'time']),
      (
        'wordType',
        CategoryMode.single,
        ['noun', 'verb', 'adjective', 'expression'],
      ),
      ('source', CategoryMode.multiple, ['manual', 'ai']),
    ]) {
      final group = await cats.createDimension(
        collectionId: collectionId,
        name: copy.text('category.default.${spec.$1}'),
        mode: spec.$2,
      );
      for (final value in spec.$3) {
        await cats.createValue(
          dimensionId: group.id,
          name: value.startsWith(RegExp('[ABC]'))
              ? value
              : copy.text('category.default.$value'),
        );
      }
    }
  }

  /// Acquisition is known at the manual confirmation boundary. Imports and old
  /// entries do not pass through this function and never receive guessed labels.
  Future<Map<String, Set<String>>> manualAssignments(
    String collectionId,
    Map<String, Set<String>> supplied,
  ) async {
    final result = {
      for (final e in supplied.entries) e.key: Set<String>.of(e.value),
    };
    final cats = SqliteCategoriesRepository(database);
    final groups = (await cats.dimensions(collectionId))
        .where(
          (g) =>
              {'source', 'quelle'}.contains(vocabularyIdentityKey(g.name)) &&
              g.mode == CategoryMode.multiple,
        )
        .toList();
    if (groups.length != 1) return result;
    final group = groups.single;
    if (result[group.id]?.isNotEmpty ?? false) return result;
    final values = (await cats.values(group.id))
        .where(
          (v) => {
            'manually entered',
            'manuell erfasst',
          }.contains(vocabularyIdentityKey(v.name)),
        )
        .toList();
    if (values.length == 1) result[group.id] = {values.single.id};
    return result;
  }
}
