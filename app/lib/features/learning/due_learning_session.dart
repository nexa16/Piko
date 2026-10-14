import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/learning_item.dart';
import '../../data/regular_review.dart';
import 'regular_grading_coordinator.dart';

/// Owns the captured all-due regular-review membership, not reinforcement retries.
final class DueLearningSession extends ChangeNotifier {
  DueLearningSession._(
    ScopedReviewSource source,
    this.cutoff,
    this.members,
    void Function(Future<void>)? register,
  ) : collectionId = source.collectionId,
      direction = source.direction {
    _grading = RegularGradingCoordinator(
      repository: source,
      // Drain includes session receipt bookkeeping, not just the database write.
      onPendingWrites: (_) => register?.call(awaitPending()),
    );
    _grading.addListener(_changed);
    if (members.isNotEmpty) _grading.activate(members.first);
  }

  static Future<DueLearningSession> start({
    required ScopedReviewSource source,
    required DateTime cutoff,
    void Function(Future<void>)? onPendingWrites,
  }) async {
    if (!cutoff.isUtc) {
      throw ArgumentError.value(cutoff, 'cutoff', 'Must be UTC');
    }
    final members = List<LearningItemRecord>.unmodifiable(
      await source.dueItems(cutoff: cutoff),
    );
    return DueLearningSession._(source, cutoff, members, onPendingWrites);
  }

  final String collectionId;
  final LearningDirection direction;
  final DateTime cutoff;
  final List<LearningItemRecord> members;
  late final RegularGradingCoordinator _grading;
  final List<RegularReviewReceipt> _receipts = [];
  int _index = 0;
  int _notificationDepth = 0;
  bool _stopped = false, _disposed = false;
  Future<RegularReviewReceipt?>? _pending;

  bool get isStopped => _stopped;
  bool get isSubmitting => _pending != null;
  // Exhausting regular membership does not imply retries or learning are complete.
  bool get regularItemsExhausted => _index == members.length;
  GradingCardHandle? get current => _stopped ? null : _grading.current;
  bool get hard => _grading.hard;
  Object? get error => _grading.error;
  List<RegularReviewReceipt> get acceptedReviews =>
      List.unmodifiable(_receipts);
  List<LearningItemRecord> get unreviewedMembers =>
      List.unmodifiable(members.skip(_index));

  void _changed() {
    if (!_stopped && !_disposed) _emit();
  }

  void _emit() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      notifyListeners();
    } finally {
      _notificationDepth--;
    }
  }

  bool setHard(GradingCardHandle handle, bool selected) =>
      !_stopped && !_disposed && _grading.setHard(handle, selected);

  Future<RegularReviewReceipt?> submit(
    GradingCardHandle handle,
    AnswerGrade grade, {
    required DateTime reviewedAt,
  }) {
    if (_stopped || _disposed || isSubmitting || !identical(current, handle)) {
      return Future.value(null);
    }
    // Install the session drain before coordinator registration can reenter stop.
    final result = Completer<RegularReviewReceipt?>();
    _pending = result.future;
    unawaited(_submit(handle, grade, reviewedAt, result));
    return result.future;
  }

  Future<void> _submit(
    GradingCardHandle handle,
    AnswerGrade grade,
    DateTime at,
    Completer<RegularReviewReceipt?> result,
  ) async {
    try {
      final receipt = await _grading.submit(handle, grade, reviewedAt: at);
      if (receipt != null) {
        // Retain accepted writes even after stop/disposal, without late UI changes.
        _receipts.add(receipt);
        _index++;
        if (!_stopped && !_disposed) {
          _grading.completeAdvance(handle);
          if (!_stopped && !_disposed && !regularItemsExhausted) {
            _grading.activate(members[_index]);
          }
        }
      }
      result.complete(receipt);
    } catch (error, stack) {
      result.completeError(error, stack);
    } finally {
      if (identical(_pending, result.future)) _pending = null;
      _changed();
    }
  }

  /// Freeze immediately; drain the admitted operation including its exact receipt.
  Future<void> stop() {
    if (!_stopped) {
      _stopped = true;
      _grading.removeListener(_changed);
      // Stop may be called by a listener inside the coordinator's notification.
      // Remove forwarding now, but never dispose a notifier on its own stack.
      scheduleMicrotask(_grading.dispose);
      _emit();
    }
    return awaitPending();
  }

  Future<void> awaitPending() =>
      _pending?.then<void>((_) {}, onError: (Object _, StackTrace _) {}) ??
      Future.value();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
    if (_notificationDepth > 0) {
      scheduleMicrotask(super.dispose);
    } else {
      super.dispose();
    }
  }
}
