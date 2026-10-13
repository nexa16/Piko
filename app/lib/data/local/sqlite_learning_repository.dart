import 'package:drift/drift.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../learning_item.dart';
import 'piko_database.dart';

final class SqliteLearningRepository {
  SqliteLearningRepository(this.database);
  final PikoDatabase database;
  Future<List<LearningItemRecord>> forEntry(String entryId) async {
    final rows =
        await (database.select(database.learningItems)
              ..where((row) => row.entryId.equals(entryId))
              ..orderBy([(row) => OrderingTerm(expression: row.id)]))
            .get();
    return rows
        .map((row) {
          final record = LearningItemRecord(
            id: row.id,
            entryId: row.entryId,
            direction: LearningDirection.values.byName(row.direction),
            cardJson: row.cardJson,
            formatVersion: row.formatVersion,
          );
          record.card; // Fail closed on corrupt or unsupported persisted state.
          return record;
        })
        .toList(growable: false);
  }

  /// Stores a complete state for one identified direction; scheduling lives elsewhere.
  Future<void> saveCard(int id, fsrs.Card card) async {
    if (card.cardId != id) {
      throw const FormatException('Learning identity mismatch');
    }
    final encoded = LearningCardCodec.encode(card);
    final count =
        await (database.update(database.learningItems)
              ..where((row) => row.id.equals(id)))
            .write(LearningItemsCompanion(cardJson: Value(encoded)));
    if (count != 1) throw StateError('Learning item does not exist');
  }
}
