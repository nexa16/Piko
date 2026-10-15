import 'core/clock.dart';
import 'data/learning_item.dart';
import 'data/local/sqlite_learning_repository.dart';
import 'features/speed/speed_learning_session.dart';
import 'features/speed/speed_session.dart';

enum SpeedLaunchFailure { noNewVocabulary }

/// Runtime composition between the pure round and its per-item transaction.
final class PikoSpeedRuntime {
  const PikoSpeedRuntime({
    required this.learning,
    required this.clock,
    this.onPendingWrites,
  });
  final SqliteLearningRepository learning;
  final PikoClock clock;
  final void Function(Future<void>)? onPendingWrites;

  Future<SpeedLearningSession> prepare({
    required String collectionId,
    required LearningDirection direction,
    required Set<String> visibleEntryIds,
    required int poolSize,
  }) {
    final selected = Set<String>.unmodifiable(visibleEntryIds);
    final future = _prepare(collectionId, direction, selected, poolSize);
    onPendingWrites?.call(
      future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    return future;
  }

  Future<SpeedLearningSession> _prepare(
    String collectionId,
    LearningDirection direction,
    Set<String> selected,
    int poolSize,
  ) async {
    final source = await learning.forCollection(
      collectionId: collectionId,
      direction: direction,
      entryIds: selected,
    );
    final eligible = await source.newSpeedItems();
    if (eligible.isEmpty) throw SpeedLaunchFailure.noNewVocabulary;
    final originals = {for (final item in eligible) item.entryId: item};
    final completedAt = <String, DateTime>{};
    return SpeedLearningSession(
      initial: SpeedSession.start(
        collectionId: collectionId,
        direction: direction,
        eligibleEntryIds: eligible.map((item) => item.entryId),
        poolSize: poolSize,
      ),
      presentationActive: false,
      onPendingWrites: onPendingWrites,
      commitCompletion: (completion) async {
        final prior = originals[completion.entryId]!;
        final instant = completedAt.putIfAbsent(
          completion.entryId,
          () => clock.now().toUtc(),
        );
        await source.completeSpeedItem(
          expectedPrior: prior,
          errors: completion.errors,
          completedAt: instant,
        );
      },
    );
  }
}
