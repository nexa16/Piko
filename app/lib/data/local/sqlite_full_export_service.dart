import 'dart:convert';
import 'package:drift/drift.dart';
import '../../core/learning_day.dart';
import '../full_export.dart';
import '../learning_item.dart';
import '../statistics_repository.dart';
import '../vocabulary_json.dart';
import 'piko_database.dart';
import 'sqlite_statistics_repository.dart';
import 'sqlite_vocabulary_json_service.dart';

final class SqliteFullExportService implements FullExportService {
  SqliteFullExportService(this.database);
  final PikoDatabase database;

  @override
  Future<String> exportAll() => database.transaction(() async {
    final at = database.clock.now().toUtc();
    final owners =
        await (database.select(database.collections)..orderBy([
              (_) => OrderingTerm(
                expression: const CustomExpression<int>('rowid'),
              ),
            ]))
            .get();
    final service = SqliteVocabularyJsonService(database);
    final collections = <Object?>[];
    for (final owner in owners) {
      final document = await service.exportCollectionDocument(owner.id);
      collections.addAll(document['collections']! as List);
    }
    final statistics = await SqliteStatisticsRepository(
      database,
    ).recordedSnapshot(at: at);
    return const JsonEncoder.withIndent('  ').convert({
      'format': FullExportFormat.format,
      'schemaVersion': FullExportFormat.schemaVersion,
      'collectionSchemaVersion': VocabularyJsonFormat.schemaVersion,
      'exportedAt': at.toIso8601String(),
      'scheduler': {
        'library': VocabularyJsonFormat.schedulerLibrary,
        'version': VocabularyJsonFormat.schedulerVersion,
        'cardFormatVersion': LearningCardCodec.version,
      },
      'collections': collections,
      'statistics': statistics == null ? null : _report(statistics),
    });
  });

  Map<String, Object?> _report(StatisticsSnapshot snapshot) {
    final start = snapshot.startDate, today = snapshot.today;
    // Whole dates only: the initialization date and the still-running day are
    // partial. Backward-clock buckets cannot establish coverage between dates.
    final complete = <Map<String, String>>[];
    if (today.civilUtc.difference(start.civilUtc).inDays > 1) {
      complete.add({
        'firstDate': start.shifted(1).key,
        'lastDate': today.shifted(-1).key,
      });
    }
    final partial = <LearningDate>{start};
    if (today.compareTo(start) >= 0) partial.add(today);
    for (final date in snapshot.activity.keys) {
      if (date.compareTo(start) <= 0 || date.compareTo(today) >= 0) {
        partial.add(date);
      }
    }
    final dates = snapshot.activity.keys.toList()..sort();
    final partialDates = partial.toList()..sort();
    return {
      'schemaVersion': 1,
      'recordedSinceUtc': snapshot.startedAt.toUtc().toIso8601String(),
      'recordedSinceLearningDate': start.key,
      'snapshotLearningDate': today.key,
      'boundaryLocalTime': '04:00',
      'dayAssignment': 'recordedLocalDate',
      'coverageRanges': complete,
      'partialLearningDates': [for (final date in partialDates) date.key],
      'dailyCounts': [
        for (final date in dates)
          {
            'learningDate': date.key,
            'longTermReviews': snapshot.activity[date]!.regular,
            'speedCompletions': snapshot.activity[date]!.speed,
          },
      ],
    };
  }
}
