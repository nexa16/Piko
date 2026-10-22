import 'core/clock.dart';
import 'data/learning_item.dart';
import 'data/local/sqlite_learning_repository.dart';
import 'features/speed/speed_learning_session.dart';
import 'features/speed/speed_session.dart';

enum SpeedLaunchFailure { noNewVocabulary, noSelectedVocabulary }

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
    return _session(source, eligible, poolSize);
  }

  /// Explicit practice preserves the caller's current display order and admits
  /// reviewed/completed words. Activity and ownership remain authoritative.
  Future<SpeedLearningSession> prepareSelected({
    required String collectionId,
    required LearningDirection direction,
    required List<String> orderedEntryIds,
    required int poolSize,
  }) {
    final ordered = List<String>.unmodifiable(orderedEntryIds.toSet());
    final future = () async {
      final source = await learning.forCollection(
        collectionId: collectionId,
        direction: direction,
        entryIds: ordered.toSet(),
      );
      final items = {
        for (final item in await source.items()) item.entryId: item,
      };
      final active = await source.activeEntryIds(
        expectedEntryIds: ordered.toSet(),
      );
      final eligible = [
        for (final id in ordered)
          if (active.contains(id)) items[id]!,
      ];
      if (eligible.isEmpty) throw SpeedLaunchFailure.noSelectedVocabulary;
      final session = await _session(source, eligible, poolSize);
      if (session.error != null || session.state!.entryIds.isEmpty) {
        final error = session.error ?? SpeedLaunchFailure.noSelectedVocabulary;
        await session.stop();
        session.dispose();
        throw error;
      }
      return session;
    }();
    onPendingWrites?.call(
      future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    return future;
  }

  Future<SpeedLearningSession> _session(
    CollectionReviewGateway source,
    List<LearningItemRecord> eligible,
    int poolSize,
  ) async {
    final originals = {for (final item in eligible) item.entryId: item};
    final completedAt = <String, DateTime>{};
    final session = SpeedLearningSession(
      initial: SpeedSession.start(
        collectionId: source.collectionId,
        direction: source.direction,
        eligibleEntryIds: eligible.map((item) => item.entryId),
        poolSize: poolSize,
      ),
      presentationActive: false,
      activeEntryIds: () =>
          source.activeEntryIds(expectedEntryIds: originals.keys.toSet()),
      onPendingWrites: onPendingWrites,
      commitCompletion: (_) async {},
      retireCompletion: source.retireSpeedCompletion,
      reverseCompletion: (receipt) async {
        await source.reverseSpeedCompletion(expected: receipt);
        completedAt.remove(receipt.prior.entryId);
      },
      commitCorrectableCompletion: (completion) async {
        final prior = originals[completion.entryId]!;
        final instant = completedAt.putIfAbsent(
          completion.entryId,
          () => clock.now().toUtc(),
        );
        return source.completeSpeedItem(
          expectedPrior: prior,
          errors: completion.errors,
          completedAt: instant,
        );
      },
    );
    await session.revalidateActivity();
    return session;
  }
}
