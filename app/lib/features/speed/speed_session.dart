import '../../data/learning_item.dart' show LearningDirection;

/// Immutable, memory-only membership for one fixed-direction Speed launch.
///
/// The caller supplies the eligible IDs in Collection display order. Eligibility
/// and durable learning effects belong to the data boundary, not this model.
final class SpeedSession {
  SpeedSession._({
    required this.collectionId,
    required this.direction,
    required this.poolSize,
    required Iterable<String> entryIds,
    required Iterable<String> pool,
    required Iterable<String> waiting,
  }) : entryIds = List.unmodifiable(entryIds),
       pool = List.unmodifiable(pool),
       waiting = List.unmodifiable(waiting);

  factory SpeedSession.start({
    required String collectionId,
    required LearningDirection direction,
    required Iterable<String> eligibleEntryIds,
    int poolSize = defaultPoolSize,
  }) {
    if (collectionId.isEmpty) {
      throw ArgumentError.value(collectionId, 'collectionId', 'Required');
    }
    if (poolSize < 1 || poolSize > maxPoolSize) {
      throw ArgumentError.value(
        poolSize,
        'poolSize',
        'Must be a positive safe integer',
      );
    }
    final entries = List<String>.of(eligibleEntryIds);
    if (entries.isEmpty ||
        entries.any((id) => id.isEmpty) ||
        entries.toSet().length != entries.length) {
      throw ArgumentError.value(
        entries,
        'eligibleEntryIds',
        'Must contain nonempty, unique eligible entry IDs',
      );
    }
    return SpeedSession._(
      collectionId: collectionId,
      direction: direction,
      poolSize: poolSize,
      entryIds: entries,
      pool: entries.take(poolSize),
      waiting: entries.skip(poolSize),
    );
  }

  static const defaultPoolSize = 5;
  static const maxPoolSize = 9007199254740991;

  final String collectionId;
  final LearningDirection direction;
  final int poolSize;

  /// Captured membership; subsequent Collection/filter changes do not add work.
  final List<String> entryIds;

  /// Active slots in rotation order, never larger than [poolSize].
  final List<String> pool;

  /// Selected work not yet admitted into an active slot, in original order.
  final List<String> waiting;
}
