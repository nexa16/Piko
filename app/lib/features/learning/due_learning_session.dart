import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/clock.dart';
import '../../data/learning_item.dart';
import '../../data/regular_review.dart';
import '../../data/retry_answer.dart';
import '../../data/retry_obligation.dart';
import 'learning_scheduler.dart';
import 'regular_grading_coordinator.dart';
import 'learning_session_progress.dart';

/// Owns captured regular membership and its actual scope-bound reinforcement.
final class DueLearningSession extends ChangeNotifier implements HardSelection {
  DueLearningSession._(
    ScopedReviewSource source,
    this.cutoff,
    this.members,
    this._clock,
    void Function(Future<void>)? register,
    RetrySelection? selection,
    this._timerFactory,
    this._presentationActive,
  ) : collectionId = source.collectionId,
      direction = source.direction,
      _source = source,
      _register = register,
      hasInitialWork =
          members.isNotEmpty ||
          (selection?.retries.rounds.isNotEmpty ?? false) {
    _progress = LearningSessionProgress(
      members: {
        for (final item in members)
          (itemId: item.id, generation: item.generation),
        for (final round in selection?.retries.rounds ?? <RetryObligation>[])
          (itemId: round.itemId, generation: round.generation),
      },
    );
    _grading = GradingCoordinator<LearningAnswerReceipt>(
      record: _recordAnswer,
      // Drain includes session receipt bookkeeping, not just the database write.
      onPendingWrites: (_) => register?.call(awaitPending()),
    );
    _grading.addListener(_changed);
    if (selection != null) {
      _scopeState = selection.retries.scope;
      for (final round in selection.retries.rounds) {
        _rounds[round.id] = round;
      }
      _select(selection.retries.items, cutoff);
    } else if (members.isNotEmpty) {
      _grading.activate(members.first);
    }
  }

  static Future<DueLearningSession> start({
    required ScopedReviewSource source,
    required DateTime cutoff,
    PikoClock clock = const SystemPikoClock(),
    void Function(Future<void>)? onPendingWrites,
    Timer Function(Duration, void Function()) timerFactory = Timer.new,
    bool presentationActive = true,
    Random? orderRandom,
  }) async {
    if (!cutoff.isUtc) {
      throw ArgumentError.value(cutoff, 'cutoff', 'Must be UTC');
    }
    final selection = source is RetryReviewSource
        ? await source.initialSelection(cutoff: cutoff)
        : null;
    final ordered = List<LearningItemRecord>.of(
      selection?.regular ?? await source.dueItems(cutoff: cutoff),
    );
    // Rebuild a resumed question order, never restore a persisted sequence.
    // Eligible captured retries still take priority independently of this order.
    if (selection?.retries.rounds.isNotEmpty ?? false) {
      ordered.shuffle(orderRandom);
    }
    final members = List<LearningItemRecord>.unmodifiable(ordered);
    final session = DueLearningSession._(
      source,
      cutoff,
      members,
      clock,
      onPendingWrites,
      selection,
      timerFactory,
      presentationActive,
    );
    if (session.current == null && session.hasPendingRetryWork) {
      await session.refreshRetries();
    } else {
      session._scheduleWake();
    }
    return session;
  }

  final String collectionId;
  final LearningDirection direction;
  final DateTime cutoff;
  final PikoClock _clock;
  final List<LearningItemRecord> members;
  final ScopedReviewSource _source;
  final void Function(Future<void>)? _register;
  final bool hasInitialWork;
  final Timer Function(Duration, void Function()) _timerFactory;
  bool _presentationActive;
  bool Function()? _presentationGuard;
  Timer? _wakeTimer;
  int _wakeIdentity = 0;
  final List<RetryWaitMutation> _waitMutations = [];
  List<RetryWaitMutation> get waitMutations =>
      List.unmodifiable(_waitMutations);
  late final GradingCoordinator<LearningAnswerReceipt> _grading;
  final Map<String, RetryObligation> _rounds = {};
  ScopeAnswerState? _scopeState;
  RetryObligation? _currentRetry;
  Object? _selectionError;
  LearningAnswerReceipt? _lastAnswer;
  LearningAnswerReceipt? get lastAnswer => _lastAnswer;
  late LearningSessionProgress _progress;
  LearningSessionProgress get progress => _progress;
  SessionProgressChange? _lastProgressChange;
  SessionProgressChange? get lastProgressChange => _lastProgressChange;
  int get pendingItemCount => {
    for (final item in unreviewedMembers)
      (itemId: item.id, generation: item.generation),
    for (final round in _rounds.values)
      (itemId: round.itemId, generation: round.generation),
  }.length;
  bool get currentIsRetry => _currentRetry != null;
  bool get hasPendingRetryWork => _rounds.isNotEmpty;
  final List<RegularReviewReceipt> _receipts = [];
  int _index = 0;
  int _notificationDepth = 0;
  bool _stopped = false, _disposed = false;
  Future<LearningAnswerReceipt?>? _pending;

  bool get isStopped => _stopped;
  bool get isSubmitting => _pending != null;
  // Exhausting regular membership does not imply retries or learning are complete.
  bool get regularItemsExhausted => _index == members.length;
  @override
  GradingCardHandle? get current => _stopped ? null : _grading.current;
  @override
  bool get hard => _grading.hard;
  Object? get error => _selectionError ?? _grading.error;
  bool get selectionFailed => _selectionError != null;
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

  @override
  bool canSetHard(GradingCardHandle handle) =>
      !_stopped && !_disposed && !isSubmitting && _grading.canSetHard(handle);

  @override
  bool setHard(GradingCardHandle handle, bool selected) =>
      canSetHard(handle) && _grading.setHard(handle, selected);

  Future<LearningAnswerReceipt> _recordAnswer(
    LearningItemRecord item,
    LearningRating rating,
    DateTime at,
  ) {
    final round = _currentRetry;
    if (round != null) {
      final source = _source;
      if (source is! RetryReviewSource || round.itemId != item.id) {
        throw RetryFailure.staleState;
      }
      return source.answerRetry(
        expectedPrior: item,
        expectedRetry: round,
        rating: rating,
        answeredAt: at,
      );
    }
    return _source.review(
      kind: ReviewKind.regular,
      expectedPrior: item,
      rating: rating,
      reviewedAt: at,
    );
  }

  void _select(List<LearningItemRecord> items, DateTime at) {
    if (_stopped || _disposed) return;
    _currentRetry = null;
    final eligible =
        _rounds.values
            .where(
              (round) =>
                  _scopeState != null && round.eligibleAt(_scopeState!, at),
            )
            .toList()
          ..sort((a, b) {
            final order = a.dueOrdinal.compareTo(b.dueOrdinal);
            return order != 0 ? order : a.itemId.compareTo(b.itemId);
          });
    if (eligible.isNotEmpty && _source is RetryReviewSource) {
      final round = eligible.first;
      final item = items
          .where(
            (item) =>
                item.id == round.itemId && item.generation == round.generation,
          )
          .firstOrNull;
      if (item == null) throw RetryFailure.staleState;
      _currentRetry = round;
      _grading.activate(item);
    } else if (!regularItemsExhausted) {
      _grading.activate(members[_index]);
    }
  }

  Future<void> _refreshAndSelect(DateTime at) async {
    final source = _source;
    if (source is RetryReviewSource) {
      var state = await source.retryState(at: at);
      if (_stopped || _disposed) return;
      _scopeState = state.scope;
      final observed = {for (final round in state.rounds) round.id: round};
      // Never expand captured work to a new externally created retry round.
      for (final id in _rounds.keys.toList()) {
        final round = observed[id];
        if (round == null) {
          _rounds.remove(id);
        } else {
          _rounds[id] = round;
        }
      }
      if (regularItemsExhausted &&
          _rounds.isNotEmpty &&
          !_rounds.values.any((round) => round.eligibleAt(state.scope, at))) {
        final armed = await source.armBlockedWaits(
          expectedRounds: List.unmodifiable(_rounds.values),
          remainingRegular: unreviewedMembers,
          at: at,
        );
        // Accepted wait mutations must survive exit, just like grade receipts.
        _waitMutations.addAll(armed.mutations);
        if (_stopped || _disposed) return;
        state = armed.state;
        _scopeState = state.scope;
        final armedRounds = {for (final round in state.rounds) round.id: round};
        for (final id in _rounds.keys.toList()) {
          final round = armedRounds[id];
          if (round == null) {
            _rounds.remove(id);
          } else {
            _rounds[id] = round;
          }
        }
      }
      _select(state.items, at);
    } else {
      _select(members, at);
    }
  }

  /// Owned retry-state refresh only; never discovers new regular membership.
  Future<void> refreshRetries() async {
    if (_stopped || _disposed || isSubmitting || current != null) return;
    final result = Completer<LearningAnswerReceipt?>();
    _pending = result.future;
    try {
      _register?.call(awaitPending());
    } catch (error) {
      _pending = null;
      _selectionError = error;
      result.complete(null);
      _changed();
      return;
    }
    _changed();
    try {
      await _refreshAndSelect(_clock.now().toUtc());
      if (!_stopped && !_disposed) _selectionError = null;
    } catch (error) {
      if (!_stopped && !_disposed) _selectionError = error;
    } finally {
      _pending = null;
      result.complete(null);
      _changed();
      _scheduleWake();
    }
  }

  /// Presentation owns wake-ups; storage and a fresh clock own eligibility.
  /// Covering/backgrounding cancels wake-ups without cancelling admitted work.
  void setPresentationActive(bool active, {bool Function()? isCurrent}) {
    if (_stopped || _disposed) return;
    _presentationGuard = isCurrent;
    final resumed = active && !_presentationActive;
    _presentationActive = active;
    _cancelWake();
    if (resumed) {
      unawaited(_wake());
    } else {
      _scheduleWake();
    }
  }

  bool get _canWake =>
      !_stopped &&
      !_disposed &&
      _presentationActive &&
      (_presentationGuard?.call() ?? true);

  void _cancelWake() {
    _wakeIdentity++;
    _wakeTimer?.cancel();
    _wakeTimer = null;
  }

  void _scheduleWake() {
    _cancelWake();
    if (!_canWake || isSubmitting || selectionFailed || _rounds.isEmpty) return;
    try {
      final now = _clock.now().toUtc();
      DateTime? earliest;
      void consider(DateTime at) {
        if (earliest == null || at.isBefore(earliest!)) earliest = at;
      }

      if (_currentRetry case final round?) {
        consider(round.expiresAt);
      } else if (current == null) {
        for (final round in _rounds.values) {
          consider(round.expiresAt);
          if (round.waitEligibleAt case final wait?) consider(wait);
        }
      }
      if (earliest == null) return;
      final identity = _wakeIdentity;
      _wakeTimer = _timerFactory(
        earliest!.isAfter(now) ? earliest!.difference(now) : Duration.zero,
        () {
          if (identity == _wakeIdentity && _canWake) unawaited(_wake());
        },
      );
    } catch (error) {
      _selectionError = error;
      _changed();
    }
  }

  Future<void> _wake() async {
    if (!_canWake || isSubmitting) return;
    try {
      final now = _clock.now().toUtc();
      // Never replace a displayed unanswered card merely because a wait elapsed.
      if (current != null) {
        final round = _currentRetry;
        if (round == null || now.isBefore(round.expiresAt)) {
          _scheduleWake();
          return;
        }
        final handle = current!;
        _currentRetry = null;
        _grading.retireExpired(handle);
      }
      await refreshRetries();
    } catch (error) {
      if (_canWake) {
        _selectionError = error;
        _changed();
      }
    }
  }

  /// UI admission uses the current runtime instant, never the launch cutoff.
  Future<RegularReviewReceipt?> submitNow(
    GradingCardHandle handle,
    AnswerGrade grade,
  ) {
    if (_stopped || _disposed || isSubmitting || !identical(current, handle)) {
      return Future.value(null);
    }
    return submit(handle, grade, reviewedAt: _clock.now().toUtc());
  }

  Future<RegularReviewReceipt?> submit(
    GradingCardHandle handle,
    AnswerGrade grade, {
    required DateTime reviewedAt,
  }) {
    if (_stopped || _disposed || isSubmitting || !identical(current, handle)) {
      return Future.value(null);
    }
    if (_currentRetry != null) {
      return Future.error(StateError('Use reinforcement answer admission'));
    }
    return submitAnswer(
      handle,
      grade,
      reviewedAt: reviewedAt,
    ).then((receipt) => receipt as RegularReviewReceipt?);
  }

  Future<LearningAnswerReceipt?> submitAnswerNow(
    GradingCardHandle handle,
    AnswerGrade grade,
  ) {
    if (_stopped || _disposed || isSubmitting || !identical(current, handle)) {
      return Future.value(null);
    }
    return submitAnswer(handle, grade, reviewedAt: _clock.now().toUtc());
  }

  Future<LearningAnswerReceipt?> submitAnswer(
    GradingCardHandle handle,
    AnswerGrade grade, {
    required DateTime reviewedAt,
  }) {
    if (_stopped || _disposed || isSubmitting || !identical(current, handle)) {
      return Future.value(null);
    }
    // Install the session drain before coordinator registration can reenter stop.
    final result = Completer<LearningAnswerReceipt?>();
    _pending = result.future;
    _cancelWake();
    unawaited(_submit(handle, grade, reviewedAt, result));
    return result.future;
  }

  Future<void> _submit(
    GradingCardHandle handle,
    AnswerGrade grade,
    DateTime at,
    Completer<LearningAnswerReceipt?> result,
  ) async {
    final submittedRetry = _currentRetry;
    try {
      final receipt = await _grading.submit(handle, grade, reviewedAt: at);
      if (receipt != null) {
        // Retain accepted writes even after stop/disposal, without late UI changes.
        _lastAnswer = receipt;
        final priorProgress = _progress;
        _progress = _progress.accepting(receipt);
        _lastProgressChange = SessionProgressChange(
          receipt: receipt,
          prior: priorProgress,
          next: _progress,
        );
        if (receipt is RegularReviewReceipt) {
          _receipts.add(receipt);
          _index++;
          _scopeState = receipt.scopeNext;
          if (receipt.retryNext case final round?) _rounds[round.id] = round;
        } else if (receipt is RetryAnswerReceipt) {
          _scopeState = receipt.scopeNext;
          _rounds.remove(receipt.retryPrior.id);
          if (receipt.retryNext case final round?) _rounds[round.id] = round;
        }
        if (!_stopped && !_disposed) {
          _currentRetry = null;
          _grading.completeAdvance(handle);
          if (!_stopped && !_disposed) {
            try {
              await _refreshAndSelect(_clock.now().toUtc());
              _selectionError = null;
            } catch (error) {
              if (!_stopped && !_disposed) _selectionError = error;
            }
          }
        }
      }
      result.complete(receipt);
    } catch (error, stack) {
      if (error == RetryFailure.expired && submittedRetry != null) {
        _rounds.remove(submittedRetry.id);
        if (!_stopped && !_disposed) {
          _currentRetry = null;
          _grading.retireExpired(handle);
          if (!_stopped && !_disposed) {
            try {
              await _refreshAndSelect(_clock.now().toUtc());
            } catch (failure) {
              if (!_stopped && !_disposed) _selectionError = failure;
            }
          }
        }
        result.complete(null);
      } else {
        result.completeError(error, stack);
      }
    } finally {
      if (identical(_pending, result.future)) _pending = null;
      _changed();
      _scheduleWake();
    }
  }

  /// Freeze immediately; drain the admitted operation including its exact receipt.
  Future<void> stop() {
    if (!_stopped) {
      _stopped = true;
      _cancelWake();
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
