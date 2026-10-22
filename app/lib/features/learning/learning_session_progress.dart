import '../../data/regular_review.dart';
import '../../data/retry_answer.dart';
import 'learning_scheduler.dart';

typedef SessionItemIdentity = ({int itemId, int generation});

/// Per-launch unique membership and accepted success, never daily aggregates.
final class LearningSessionProgress {
  LearningSessionProgress({
    required Set<SessionItemIdentity> members,
    Set<SessionItemIdentity> completed = const {},
    Set<SessionItemIdentity> firstTry = const {},
    Map<SessionItemIdentity, int> attempts = const {},
  }) : members = Set.unmodifiable(members),
       completedItems = Set.unmodifiable(completed),
       firstTryItems = Set.unmodifiable(firstTry),
       attempts = Map.unmodifiable(attempts);

  final Set<SessionItemIdentity> members;
  final Set<SessionItemIdentity> completedItems;
  final Set<SessionItemIdentity> firstTryItems;
  final Map<SessionItemIdentity, int> attempts;
  int get totalRetries =>
      attempts.values.fold(0, (sum, count) => sum + count - 1);
  int get total => members.length;
  int get completed => completedItems.length;
  int get firstTryCorrect => firstTryItems.length;
  double get fraction => total == 0 ? 0 : completed / total;

  LearningSessionProgress excludingUncompleted(
    Set<SessionItemIdentity> excluded,
  ) {
    final remove = members.intersection(excluded).difference(completedItems);
    if (remove.isEmpty) return this;
    return LearningSessionProgress(
      members: members.difference(remove),
      completed: completedItems,
      firstTry: firstTryItems,
      attempts: attempts,
    );
  }

  LearningSessionProgress accepting(LearningAnswerReceipt receipt) {
    final identity = (
      itemId: receipt.prior.id,
      generation: receipt.prior.generation,
    );
    if (!members.contains(identity)) {
      throw StateError('Answer outside captured progress membership');
    }
    final rating = switch (receipt) {
      RegularReviewReceipt() => receipt.event.rating,
      RetryAnswerReceipt() => receipt.rating,
      _ => throw StateError('Unsupported learning answer receipt'),
    };
    return LearningSessionProgress(
      members: members,
      attempts: {...attempts, identity: (attempts[identity] ?? 0) + 1},
      completed: {
        ...completedItems,
        if (rating != LearningRating.again) identity,
      },
      firstTry: {
        ...firstTryItems,
        if (receipt is RegularReviewReceipt && rating != LearningRating.again)
          identity,
      },
    );
  }
}

/// Latest accepted answer's reversible counter context for later correction.
/// This is not a retry-attempt history or persisted daily accounting.
final class SessionProgressChange {
  const SessionProgressChange({
    required this.receipt,
    required this.prior,
    required this.next,
  });
  final LearningAnswerReceipt receipt;
  final LearningSessionProgress prior;
  final LearningSessionProgress next;
}
