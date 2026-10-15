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
    required Iterable<String> pass,
    required this.turnIndex,
    required this.rotation,
    required Iterable<String> completedEntryIds,
  }) : entryIds = List.unmodifiable(entryIds),
       pool = List.unmodifiable(pool),
       waiting = List.unmodifiable(waiting),
       pass = List.unmodifiable(pass),
       completedEntryIds = Set.unmodifiable(completedEntryIds);

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
      pass: entries.take(poolSize),
      turnIndex: 0,
      rotation: 1,
      completedEntryIds: const [],
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

  /// The pool captured at this rotation's start; replacements cannot join it.
  final List<String> pass;
  final int turnIndex;
  final int rotation;
  final Set<String> completedEntryIds;

  String? get currentEntryId =>
      turnIndex < pass.length ? pass[turnIndex] : null;
  bool get isComplete => pool.isEmpty && waiting.isEmpty;

  /// Advances an explicitly answered current turn using its completion verdict.
  ///
  /// This pool transition does not calculate streaks or durable learning effects.
  SpeedSession advance({required String entryId, required bool completed}) {
    if (entryId != currentEntryId || isComplete) {
      throw StateError('Only the current Speed turn can advance');
    }
    final nextPool = List<String>.of(pool);
    final nextWaiting = List<String>.of(waiting);
    if (completed) {
      final slot = nextPool.indexOf(entryId);
      if (nextWaiting.isEmpty) {
        nextPool.removeAt(slot);
      } else {
        nextPool[slot] = nextWaiting.removeAt(0);
      }
    }
    final nextTurn = turnIndex + 1;
    final startsNextRotation = nextTurn == pass.length && nextPool.isNotEmpty;
    return SpeedSession._(
      collectionId: collectionId,
      direction: direction,
      poolSize: poolSize,
      entryIds: entryIds,
      pool: nextPool,
      waiting: nextWaiting,
      pass: startsNextRotation ? nextPool : pass,
      turnIndex: startsNextRotation ? 0 : nextTurn,
      rotation: rotation + (startsNextRotation ? 1 : 0),
      completedEntryIds: {...completedEntryIds, if (completed) entryId},
    );
  }
}
