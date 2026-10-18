import 'dart:convert';
import 'package:drift/drift.dart';
import '../../core/learning_day.dart';
import '../learning_item.dart';
import '../statistics_repository.dart';
import 'piko_database.dart';

final class SqliteStatisticsRepository implements StatisticsRepository {
  SqliteStatisticsRepository(this.database);
  final PikoDatabase database;

  @override
  Stream<void> get changes => database
      .tableUpdates()
      .where(
        (updates) => updates.any(
          (update) =>
              update.table == 'statistics_origins' ||
              update.table == 'statistics_activity',
        ),
      )
      .map((_) {});

  Future<StatisticsOrigin> _initialize() async {
    final existing = await database
        .select(database.statisticsOrigins)
        .getSingleOrNull();
    if (existing != null) return existing;
    final at = database.clock.now().toUtc();
    await database
        .into(database.statisticsOrigins)
        .insert(
          StatisticsOriginsCompanion.insert(
            singleton: const Value(1),
            startedAt: at.toIso8601String(),
            learningDate: LearningDay.dateFor(
              at,
              calendar: database.learningDayCalendar,
            ).key,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return database.select(database.statisticsOrigins).getSingle();
  }

  @override
  Future<StatisticsSnapshot> snapshot({required DateTime at}) =>
      database.transaction(() async {
        return _read(at, await _initialize());
      });

  /// Export must not initialize coverage or invent history as a read side effect.
  Future<StatisticsSnapshot?> recordedSnapshot({required DateTime at}) =>
      database.transaction(() async {
        final origin = await database
            .select(database.statisticsOrigins)
            .getSingleOrNull();
        return origin == null ? null : _read(at, origin);
      });

  Future<StatisticsSnapshot> _read(DateTime at, StatisticsOrigin origin) async {
    final today = LearningDay.dateFor(
      at,
      calendar: database.learningDayCalendar,
    );
    final rows = await database
        .customSelect(
          'SELECT learning_date, '
          "SUM(CASE WHEN mode = 'regular' THEN 1 ELSE 0 END) AS regular_count, "
          "SUM(CASE WHEN mode = 'speed' THEN 1 ELSE 0 END) AS speed_count "
          'FROM statistics_activity GROUP BY learning_date ORDER BY learning_date',
          readsFrom: {database.statisticsActivity},
        )
        .get();
    return StatisticsSnapshot(
      asOf: at,
      startedAt: DateTime.parse(origin.startedAt),
      startDate: LearningDate.parse(origin.learningDate),
      today: today,
      activity: {
        for (final row in rows)
          LearningDate.parse(row.read<String>('learning_date')): ActivityCounts(
            regular: row.read<int>('regular_count'),
            speed: row.read<int>('speed_count'),
          ),
      },
    );
  }

  /// Called inside the learning write transaction; nested writes share rollback.
  Future<void> recordRegular(String eventId, DateTime at) =>
      database.transaction(() async {
        if (eventId.isEmpty || !at.isUtc) {
          throw ArgumentError('Invalid regular credit');
        }
        await _initialize();
        final key = jsonEncode(['regular', eventId]);
        final existing = await (database.select(
          database.statisticsActivity,
        )..where((row) => row.creditKey.equals(key))).getSingleOrNull();
        if (existing != null) {
          if (existing.mode != 'regular' ||
              existing.occurredAt != at.toIso8601String()) {
            throw StateError('Conflicting regular credit');
          }
          return;
        }
        await database
            .into(database.statisticsActivity)
            .insert(
              StatisticsActivityCompanion.insert(
                creditKey: key,
                mode: 'regular',
                occurredAt: at.toIso8601String(),
                learningDate: LearningDay.dateFor(
                  at,
                  calendar: database.learningDayCalendar,
                ).key,
              ),
            );
      });

  /// True is a newly admitted completion request, even when its daily credit
  /// already exists. Replaying the frozen identity/instant retains its date.
  Future<bool> recordSpeed(
    String entryId,
    LearningDirection direction,
    DateTime at,
  ) => database.transaction(() async {
    if (entryId.isEmpty || !at.isUtc) {
      throw ArgumentError('Invalid Speed credit');
    }
    await _initialize();
    final instant = at.toIso8601String();
    final existing =
        await (database.select(database.speedCompletionReceipts)..where(
              (row) =>
                  row.entryId.equals(entryId) &
                  row.direction.equals(direction.name) &
                  row.completedAt.equals(instant),
            ))
            .getSingleOrNull();
    if (existing != null) return false;
    final date = LearningDay.dateFor(
      at,
      calendar: database.learningDayCalendar,
    ).key;
    await database
        .into(database.statisticsActivity)
        .insert(
          StatisticsActivityCompanion.insert(
            creditKey: jsonEncode(['speed', entryId, direction.name, date]),
            mode: 'speed',
            occurredAt: instant,
            learningDate: date,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.speedCompletionReceipts)
        .insert(
          SpeedCompletionReceiptsCompanion.insert(
            entryId: entryId,
            direction: direction.name,
            completedAt: instant,
            learningDate: date,
          ),
        );
    return true;
  });
}
