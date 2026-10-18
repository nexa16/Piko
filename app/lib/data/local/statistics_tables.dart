import 'package:drift/drift.dart';

/// Independent of vocabulary/Collection cascades; no historical reconstruction.
class StatisticsOrigins extends Table {
  IntColumn get singleton =>
      integer().check(const CustomExpression<bool>('singleton = 1'))();
  TextColumn get startedAt => text().check(
    const CustomExpression<bool>("substr(started_at, -1) = 'Z'"),
  )();
  TextColumn get learningDate => text().check(
    const CustomExpression<bool>('length(learning_date) = 10'),
  )();
  @override
  Set<Column<Object>> get primaryKey => {singleton};
}

@TableIndex.sql(
  'CREATE INDEX statistics_activity_date ON statistics_activity(learning_date, mode)',
)
class StatisticsActivity extends Table {
  TextColumn get creditKey => text()();
  TextColumn get mode => text().check(
    const CustomExpression<bool>("mode IN ('regular', 'speed')"),
  )();
  TextColumn get occurredAt => text().check(
    const CustomExpression<bool>("substr(occurred_at, -1) = 'Z'"),
  )();
  TextColumn get learningDate => text().check(
    const CustomExpression<bool>('length(learning_date) = 10'),
  )();
  @override
  Set<Column<Object>> get primaryKey => {creditKey};
}

/// The caller freezes completion time across retries. This receipt preserves
/// its assigned date even if the device timezone changes before acknowledgement.
class SpeedCompletionReceipts extends Table {
  TextColumn get entryId => text()();
  TextColumn get direction => text().check(
    const CustomExpression<bool>(
      "direction IN ('targetToNative', 'nativeToTarget')",
    ),
  )();
  TextColumn get completedAt => text().check(
    const CustomExpression<bool>("substr(completed_at, -1) = 'Z'"),
  )();
  TextColumn get learningDate => text().check(
    const CustomExpression<bool>('length(learning_date) = 10'),
  )();
  @override
  Set<Column<Object>> get primaryKey => {entryId, direction, completedAt};
}
