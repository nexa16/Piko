import 'package:drift/drift.dart';
import '../vocabulary_content.dart';
import '../vocabulary_repository.dart';
import 'piko_database.dart';

/// Ordered example persistence shared by edits, interchange and Undo.
final class SqliteVocabularyContent {
  SqliteVocabularyContent(this.database);
  final PikoDatabase database;

  Future<Map<String, List<ExamplePair>>> forCollection(
    String collectionId,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT e.* FROM vocabulary_examples e JOIN vocabulary_entries v ON v.id=e.entry_id WHERE v.collection_id=? ORDER BY e.entry_id,e.position',
          variables: [Variable(collectionId)],
          readsFrom: {database.vocabularyEntries, database.vocabularyExamples},
        )
        .get();
    final result = <String, List<ExamplePair>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row.read<String>('entry_id'), () => [])
          .add(
            ExamplePair(
              targetText: row.read<String>('target_text'),
              nativeText: row.read<String>('native_text'),
            ),
          );
    }
    return result;
  }

  Future<VocabularyContent> read(VocabularyEntry row) async {
    final examples =
        await (database.select(database.vocabularyExamples)
              ..where((e) => e.entryId.equals(row.id))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();
    return content(
      row,
      examples
          .map(
            (e) =>
                ExamplePair(targetText: e.targetText, nativeText: e.nativeText),
          )
          .toList(),
    );
  }

  VocabularyContent content(VocabularyEntry row, List<ExamplePair> pairs) =>
      VocabularyContent.fromStored(
        examples: pairs,
        hintText: row.hintText,
        hintVisibility: row.hintVisibility,
      );

  VocabularyRecord record(VocabularyEntry row, List<ExamplePair> pairs) =>
      VocabularyRecord(
        id: row.id,
        active: row.active,
        collectionId: row.collectionId,
        targetText: row.targetText,
        nativeText: row.nativeText,
        addedAt: row.addedAt == null
            ? null
            : DateTime.parse(row.addedAt!).toUtc(),
        content: content(row, pairs),
      );

  Future<void> replace(String entryId, VocabularyContent content) async {
    final normalized = content.normalized();
    await (database.delete(
      database.vocabularyExamples,
    )..where((e) => e.entryId.equals(entryId))).go();
    await database.batch((batch) {
      batch.insertAll(database.vocabularyExamples, [
        for (var i = 0; i < normalized.examples.length; i++)
          VocabularyExamplesCompanion.insert(
            entryId: entryId,
            position: i,
            targetText: normalized.examples[i].targetText,
            nativeText: normalized.examples[i].nativeText,
          ),
      ]);
    });
  }
}
