import 'dart:math';

import '../../data/learning_item.dart' show LearningDirection;
import 'speed_numbers_game.dart';

enum SpeedAnswer { correct, incorrect }

/// Current-round counters, never an attempt history or long-term grade.
final class SpeedItemProgress {
  const SpeedItemProgress({this.errors = 0, this.correctStreak = 0});

  final int errors;
  final int correctStreak;
  int get requiredCorrectStreak => errors >= 3 ? 4 : errors + 1;
  bool get isComplete => correctStreak >= requiredCorrectStreak;

  SpeedItemProgress _answer(SpeedAnswer answer) => switch (answer) {
    SpeedAnswer.incorrect => SpeedItemProgress(errors: errors + 1),
    SpeedAnswer.correct => SpeedItemProgress(
      errors: errors,
      correctStreak: correctStreak + 1,
    ),
  };
}

/// An item just completed in memory; its learning effects still need committing.
final class SpeedCompletion {
  const SpeedCompletion({required this.entryId, required this.errors});

  final String entryId;
  final int errors;
}

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
    required Map<String, SpeedItemProgress> itemProgress,
    this.completion,
    this.needsBreak = false,
    this.numberGame,
  }) : entryIds = List.unmodifiable(entryIds),
       pool = List.unmodifiable(pool),
       waiting = List.unmodifiable(waiting),
       pass = List.unmodifiable(pass),
       completedEntryIds = Set.unmodifiable(completedEntryIds),
       itemProgress = Map.unmodifiable(itemProgress);

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
      itemProgress: {for (final id in entries) id: const SpeedItemProgress()},
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
  final Map<String, SpeedItemProgress> itemProgress;

  /// Set only by the answer that reaches an item's required streak.
  /// This intent does not itself write a marker, reset FSRS or record a review.
  final SpeedCompletion? completion;

  /// A short pool has exhausted its pass and needs one completed minigame.
  final bool needsBreak;
  final SpeedNumbersGame? numberGame;

  String? get currentEntryId =>
      turnIndex < pass.length ? pass[turnIndex] : null;
  bool get isComplete => pool.isEmpty && waiting.isEmpty;

  /// Creates the shuffled game once for this exact pending break.
  SpeedSession beginBreak({Random? random}) {
    if (!needsBreak) {
      throw StateError('No Speed break is awaiting a numbers game');
    }
    if (numberGame != null) return this;
    return _withGame(SpeedNumbersGame.start(random: random));
  }

  /// Finishing 10 automatically unlocks every remaining word's next pass.
  SpeedSession tapNumber(int number) {
    final game = numberGame;
    if (!needsBreak || game == null) {
      throw StateError('No Speed numbers game is active');
    }
    final next = game.tap(number);
    if (identical(next, game)) return this;
    return next.isComplete ? _completeBreak() : _withGame(next);
  }

  SpeedSession _withGame(SpeedNumbersGame game) => SpeedSession._(
    collectionId: collectionId,
    direction: direction,
    poolSize: poolSize,
    entryIds: entryIds,
    pool: pool,
    waiting: waiting,
    pass: pass,
    turnIndex: turnIndex,
    rotation: rotation,
    completedEntryIds: completedEntryIds,
    itemProgress: itemProgress,
    needsBreak: true,
    numberGame: game,
  );

  SpeedSession _completeBreak() {
    return SpeedSession._(
      collectionId: collectionId,
      direction: direction,
      poolSize: poolSize,
      entryIds: entryIds,
      pool: pool,
      waiting: waiting,
      pass: pool,
      turnIndex: 0,
      rotation: rotation + 1,
      completedEntryIds: completedEntryIds,
      itemProgress: itemProgress,
    );
  }

  /// Remove unfinished inactive work without recording an attempt or starting a game.
  SpeedSession excluding(Set<String> excluded) {
    final remove = excluded
        .difference(completedEntryIds)
        .intersection(entryIds.toSet());
    if (remove.isEmpty) return this;
    final nextWaiting = waiting.where((id) => !remove.contains(id)).toList();
    final nextPool = <String>[];
    for (final id in pool) {
      if (!remove.contains(id)) {
        nextPool.add(id);
      } else if (nextWaiting.isNotEmpty) {
        nextPool.add(nextWaiting.removeAt(0));
      }
    }
    final remainingPass = pass
        .skip(turnIndex)
        .where((id) => !remove.contains(id))
        .toList();
    final keepBreak = needsBreak && nextPool.isNotEmpty;
    final nextPass = remainingPass.isNotEmpty
        ? remainingPass
        : keepBreak
        ? <String>[]
        : nextPool;
    return SpeedSession._(
      collectionId: collectionId,
      direction: direction,
      poolSize: poolSize,
      entryIds: entryIds.where((id) => !remove.contains(id)),
      pool: nextPool,
      waiting: nextWaiting,
      pass: nextPass,
      turnIndex: 0,
      rotation: rotation,
      completedEntryIds: completedEntryIds,
      itemProgress: {
        for (final pair in itemProgress.entries)
          if (!remove.contains(pair.key)) pair.key: pair.value,
      },
      needsBreak: keepBreak,
      numberGame: keepBreak ? numberGame : null,
    );
  }

  /// Only an explicit Correct/Incorrect advances the pass or changes counters.
  SpeedSession answer({required String entryId, required SpeedAnswer answer}) {
    if (entryId != currentEntryId || isComplete) {
      throw StateError('Only the current Speed turn can advance');
    }
    final progress = itemProgress[entryId]!._answer(answer);
    return _advance(entryId: entryId, progress: progress);
  }

  SpeedSession _advance({
    required String entryId,
    required SpeedItemProgress progress,
  }) {
    final completed = progress.isComplete;
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
    final endedPass = nextTurn == pass.length;
    final nextProgress = {...itemProgress, entryId: progress};
    final needsBreak =
        endedPass &&
        nextPool.isNotEmpty &&
        poolSize > 1 &&
        nextPool.length < poolSize &&
        nextWaiting.isEmpty &&
        // Refilled slots join the next pass before any game. Either counter
        // proves an answered attempt; Incorrect leaves the streak at zero.
        nextPool.every((id) {
          final item = nextProgress[id]!;
          return item.errors > 0 || item.correctStreak > 0;
        });
    final startsNextRotation = endedPass && nextPool.isNotEmpty && !needsBreak;
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
      itemProgress: nextProgress,
      completion: completed
          ? SpeedCompletion(entryId: entryId, errors: progress.errors)
          : null,
      needsBreak: needsBreak,
    );
  }
}
