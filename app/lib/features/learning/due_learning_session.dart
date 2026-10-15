import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/clock.dart';
import '../../data/learning_item.dart';
import '../../data/regular_review.dart';
import '../../data/retry_answer.dart';
import '../../data/retry_obligation.dart';
import '../../data/review_correction.dart';
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
  GradingCoordinator<LearningAnswerReceipt>? _correction;
  LearningAnswerReceipt? _correctionExpected;
  List<RetryWaitMutation> _correctionWaits = const [];
  int _lastAnswerWaitIndex = 0;
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
  bool get isCorrecting => _correction != null;
  // Exhausting regular membership does not imply retries or learning are complete.
  bool get regularItemsExhausted => _index == members.length;
  @override
  GradingCardHandle? get current =>
      _stopped ? null : _correction?.current ?? _grading.current;
  @override
  bool get hard => _correction?.hard ?? _grading.hard;
  Object? get error => _selectionError ?? _correction?.error ?? _grading.error;
  bool get selectionFailed => _selectionError != null;

  /// Earliest persisted retry deadline while no question is displayed.
  /// This presentation view never arms or extends a wait.
  DateTime? get retryWaitDeadline {
    if (_stopped || _disposed || selectionFailed || current != null) {
      return null;
    }
    DateTime? earliest;
    for (final round in _rounds.values) {
      final wait = round.waitEligibleAt;
      if (wait != null && (earliest == null || wait.isBefore(earliest))) {
        earliest = wait;
      }
    }
    return earliest;
  }

  /// Remaining whole seconds, rounded up from the actual stored UTC instant.
  int? get retryWaitSeconds {
    final deadline = retryWaitDeadline;
    if (deadline == null) return null;
    final remaining = deadline.difference(_clock.now().toUtc()).inMicroseconds;
    return remaining <= 0 ? 0 : (remaining + 999999) ~/ 1000000;
  }

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
      !_stopped &&
      !_disposed &&
      !isSubmitting &&
      (_correction?.canSetHard(handle) ?? _grading.canSetHard(handle));

  @override
  bool setHard(GradingCardHandle handle, bool selected) =>
      canSetHard(handle) &&
      (_correction?.setHard(handle, selected) ??
          _grading.setHard(handle, selected));

  LearningRating? get previousRating {
    final answer = _correctionExpected;
    return switch (answer) {
      RegularReviewReceipt() => answer.event.rating,
      RetryAnswerReceipt() => answer.rating,
      _ => null,
    };
  }

  bool canCorrectPrevious(GradingCardHandle handle) =>
      !_stopped &&
      !_disposed &&
      !isSubmitting &&
      _correction == null &&
      identical(_grading.current, handle) &&
      _lastAnswer != null &&
      _lastProgressChange?.receipt == _lastAnswer &&
      _source is ReviewCorrectionSource;

  /// Presents only the latest accepted answer. The unanswered current card is
  /// retained privately and resumes after an accepted replacement.
  bool beginCorrection(GradingCardHandle handle) {
    if (!canCorrectPrevious(handle)) return false;
    _cancelWake();
    final expected = _lastAnswer!;
    final waits = List<RetryWaitMutation>.unmodifiable(
      _waitMutations.skip(_lastAnswerWaitIndex),
    );
    final source = _source as ReviewCorrectionSource;
    final correction = GradingCoordinator<LearningAnswerReceipt>(
      record: (_, rating, at) => source.replaceAnswer(
        expected: expected,
        expectedWaits: waits,
        rating: rating,
        executionAt: at,
      ),
      // Runtime drainage includes applying the replacement to session state.
      onPendingWrites: (_) => _register?.call(awaitPending()),
    );
    correction.addListener(_changed);
    final correctionHandle = correction.activate(expected.prior);
    if (correctionHandle == null) {
      correction.removeListener(_changed);
      correction.dispose();
      return false;
    }
    final priorRating = switch (expected) {
      RegularReviewReceipt() => expected.event.rating,
      RetryAnswerReceipt() => expected.rating,
      _ => LearningRating.good,
    };
    if (priorRating == LearningRating.hard) {
      correction.setHard(correctionHandle, true);
    }
    _correctionExpected = expected;
    _correctionWaits = waits;
    _correction = correction;
    _emit();
    return true;
  }

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
      _correction == null &&
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
      final refreshAt = earliest!;
      final remaining = retryWaitSeconds;
      if (current == null && remaining != null && remaining > 0) {
        // Wake only the presentation at the next whole-second boundary. The
        // original persisted wait/expiry still controls the next storage read.
        consider(retryWaitDeadline!.subtract(Duration(seconds: remaining - 1)));
      }
      final identity = _wakeIdentity;
      _wakeTimer = _timerFactory(
        earliest!.isAfter(now) ? earliest!.difference(now) : Duration.zero,
        () {
          if (identity == _wakeIdentity && _canWake) {
            unawaited(_wake(countdownBefore: refreshAt));
          }
        },
      );
    } catch (error) {
      _selectionError = error;
      _changed();
    }
  }

  Future<void> _wake({DateTime? countdownBefore}) async {
    if (!_canWake || isSubmitting) return;
    try {
      final now = _clock.now().toUtc();
      if (current == null &&
          countdownBefore != null &&
          now.isBefore(countdownBefore)) {
        _changed();
        _scheduleWake();
        return;
      }
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
    final correction = _correction;
    if (correction != null && identical(correction.current, handle)) {
      unawaited(
        _submitCorrection(correction, handle, grade, reviewedAt, result),
      );
    } else {
      unawaited(_submit(handle, grade, reviewedAt, result));
    }
    return result.future;
  }

  Future<void> _submitCorrection(
    GradingCoordinator<LearningAnswerReceipt> correction,
    GradingCardHandle handle,
    AnswerGrade grade,
    DateTime at,
    Completer<LearningAnswerReceipt?> result,
  ) async {
    final expected = _correctionExpected;
    final progressChange = _lastProgressChange;
    final waits = _correctionWaits;
    try {
      if (expected == null ||
          progressChange == null ||
          !identical(progressChange.receipt, expected)) {
        throw StateError('Correction context is no longer current');
      }
      final regularIndex = expected is RegularReviewReceipt
          ? _receipts.lastIndexWhere(
              (receipt) => receipt.event.id == expected.event.id,
            )
          : null;
      if (regularIndex != null &&
          (regularIndex < 0 || regularIndex != _receipts.length - 1)) {
        throw StateError('Corrected review is no longer latest');
      }
      final replacement = await correction.submit(
        handle,
        grade,
        reviewedAt: at,
      );
      if (replacement != null) {
        final sameKind =
            expected is RegularReviewReceipt &&
                replacement is RegularReviewReceipt ||
            expected is RetryAnswerReceipt && replacement is RetryAnswerReceipt;
        if (!sameKind ||
            replacement.prior.id != expected.prior.id ||
            replacement.prior.generation != expected.prior.generation) {
          throw StateError('Correction returned an unrelated answer');
        }
        final correctedProgress = progressChange.prior.accepting(replacement);
        _lastAnswer = replacement;
        _progress = correctedProgress;
        _lastProgressChange = SessionProgressChange(
          receipt: replacement,
          prior: progressChange.prior,
          next: correctedProgress,
        );
        if (expected is RegularReviewReceipt &&
            replacement is RegularReviewReceipt) {
          _receipts[regularIndex!] = replacement;
        }
        final retiredCurrent = _applyCorrectedQueue(
          expected,
          replacement,
          waits,
        );
        _scopeState = switch (replacement) {
          RegularReviewReceipt() => replacement.scopeNext,
          RetryAnswerReceipt() => replacement.scopeNext,
          _ => _scopeState,
        };
        _lastAnswerWaitIndex = _waitMutations.length;
        correction.completeAdvance(handle);
        correction.removeListener(_changed);
        correction.dispose();
        if (identical(_correction, correction)) {
          _correction = null;
          _correctionExpected = null;
          _correctionWaits = const [];
        }
        if (retiredCurrent && !_stopped && !_disposed) {
          try {
            await _refreshAndSelect(at);
            _selectionError = null;
          } catch (error) {
            if (!_stopped && !_disposed) _selectionError = error;
          }
        }
      }
      result.complete(replacement);
    } catch (error, stack) {
      result.completeError(error, stack);
    } finally {
      if (identical(_pending, result.future)) _pending = null;
      _changed();
      _scheduleWake();
    }
  }

  bool _applyCorrectedQueue(
    LearningAnswerReceipt expected,
    LearningAnswerReceipt replacement,
    List<RetryWaitMutation> waits,
  ) {
    final correctedRoundId = switch (expected) {
      RegularReviewReceipt() => expected.retryNext?.id,
      RetryAnswerReceipt() => expected.retryPrior.id,
      _ => null,
    };
    final ids = <String>{};
    if (correctedRoundId != null) ids.add(correctedRoundId);
    ids.addAll(
      waits
          .where((mutation) => mutation.prior.id == correctedRoundId)
          .map((mutation) => mutation.prior.id),
    );
    for (final id in ids) {
      _rounds.remove(id);
    }
    final next = switch (replacement) {
      RegularReviewReceipt() => replacement.retryNext,
      RetryAnswerReceipt() => replacement.retryNext,
      _ => null,
    };
    if (next != null) _rounds[next.id] = next;
    if (correctedRoundId == null || _currentRetry?.id != correctedRoundId) {
      return false;
    }
    if (next != null) {
      _currentRetry = next;
      return false;
    }
    final unanswered = _grading.current;
    _currentRetry = null;
    return unanswered != null && _grading.retireUnanswered(unanswered);
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
        _lastAnswerWaitIndex = _waitMutations.length;
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
      _correction?.removeListener(_changed);
      // Stop may be called by a listener inside the coordinator's notification.
      // Remove forwarding now, but never dispose a notifier on its own stack.
      scheduleMicrotask(_grading.dispose);
      final correction = _correction;
      if (correction != null) scheduleMicrotask(correction.dispose);
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
