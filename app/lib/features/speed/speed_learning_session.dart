import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'speed_session.dart';
import '../../data/speed_completion.dart';

/// A single presentation, distinct even when the same word appears next pass.
final class SpeedTurnHandle {
  const SpeedTurnHandle._(this.entryId);

  final String entryId;
}

/// Stable for one numbers game; callbacks from an earlier break are rejected.
final class SpeedBreakHandle {
  const SpeedBreakHandle._();
}

/// Owns an in-process round and drains accepted completion writes on exit.
///
/// Unfinished attempts are never passed to storage. The injected callback must
/// commit an item's completion atomically or fail without a partial result.
final class SpeedLearningSession extends ChangeNotifier {
  SpeedLearningSession({
    required SpeedSession initial,
    required Future<void> Function(SpeedCompletion) commitCompletion,
    void Function(Future<void>)? onPendingWrites,
    bool presentationActive = true,
    this.activeEntryIds,
    bool Function()? isPresentationCurrent,
    this.commitCorrectableCompletion,
    this.reverseCompletion,
    this.retireCompletion,
  }) : _state = initial,
       // Preserve public callback names while keeping owned fields private,
       // matching the existing GradingCoordinator constructor boundary.
       // ignore: prefer_initializing_formals
       _commitCompletion = commitCompletion,
       _register = onPendingWrites,
       // The public option initializes state changed only through its guard.
       // ignore: prefer_initializing_formals
       _presentationActive = presentationActive,
       // Keep the injected route guard private, with a public dependency name.
       // ignore: prefer_initializing_formals
       _isPresentationCurrent = isPresentationCurrent {
    _activate();
  }

  final Future<Set<String>> Function()? activeEntryIds;
  bool endedByExclusion = false;
  final Future<void> Function(SpeedCompletion) _commitCompletion;
  final Future<SpeedCompletionResult> Function(SpeedCompletion)?
  commitCorrectableCompletion;
  final Future<void> Function(SpeedCompletionResult)? reverseCompletion;
  final void Function(SpeedCompletionResult)? retireCompletion;
  SpeedSession? _previousBefore;
  SpeedAnswer? _previousAnswer;
  SpeedCompletionResult? _previousCompletion;
  SpeedTurnHandle? _correctionHandle;
  SpeedAnswer? get previousAnswer => _previousAnswer;
  bool get isCorrecting => _correctionHandle != null;
  bool get canCorrectPrevious =>
      _canInteract &&
      !isSubmitting &&
      !isComplete &&
      !isCorrecting &&
      !_revealed &&
      _previousBefore != null &&
      commitCorrectableCompletion != null &&
      reverseCompletion != null;

  bool beginCorrection() {
    if (!canCorrectPrevious) return false;
    _correctionHandle = SpeedTurnHandle._(_previousBefore!.currentEntryId!);
    // A hidden game's cached callbacks must not operate during correction or
    // revive when that game is presented again after replacement.
    _currentBreak = null;
    _revealed = true;
    notifyListeners();
    return true;
  }

  Future<SpeedCompletionResult?> _commitAnswer(SpeedSession next) async {
    if (next.completion == null) return null;
    final correctable = commitCorrectableCompletion;
    if (correctable != null) {
      final result = await correctable(next.completion!);
      if (_stopped || _disposed) retireCompletion?.call(result);
      return result;
    }
    await _commitCompletion(next.completion!);
    return null;
  }

  void _remember(
    SpeedSession before,
    SpeedAnswer answer,
    SpeedCompletionResult? receipt,
  ) {
    if (_stopped || _disposed) {
      if (receipt != null) retireCompletion?.call(receipt);
      return;
    }
    if (_previousCompletion case final old?) {
      if (!identical(old, receipt)) retireCompletion?.call(old);
    }
    _previousBefore = before;
    _previousAnswer = answer;
    _previousCompletion = receipt;
  }

  Future<bool> _replace(SpeedTurnHandle handle, SpeedAnswer answer) async {
    final result = Completer<bool>();
    _pending = result.future;
    _error = null;
    try {
      _register?.call(awaitPending());
      notifyListeners();
      await _refreshActivity();
      if (activeEntryIds case final read?) {
        if (!(await read()).contains(handle.entryId)) {
          throw SpeedCompletionFailure.inactive;
        }
      }
      if (_stopped || _disposed || !identical(_correctionHandle, handle)) {
        return false;
      }
      if (answer != _previousAnswer) {
        final before = _previousBefore!;
        final next = before.answer(entryId: handle.entryId, answer: answer);
        final priorReceipt = _previousCompletion;
        if (priorReceipt != null) await reverseCompletion!(priorReceipt);
        final receipt = await _commitAnswer(next);
        _remember(before, answer, receipt);
        if (!_stopped && !_disposed) _state = next;
      }
      if (!_stopped && !_disposed) {
        _correctionHandle = null;
        _activate();
      }
      return true;
    } catch (error) {
      if (!_stopped && !_disposed) _error = error;
      rethrow;
    } finally {
      _pending = null;
      result.complete(false);
      if (!_stopped && !_disposed) notifyListeners();
    }
  }

  void _exclude(Set<String> inactive) {
    final state = _state;
    if (state == null) return;
    final next = state.excluding(inactive);
    if (identical(next, state)) return;
    if (_previousBefore case final before?) {
      if (inactive.contains(before.currentEntryId)) {
        if (_previousCompletion case final receipt?) {
          retireCompletion?.call(receipt);
        }
        _previousBefore = null;
        _previousCompletion = null;
        _previousAnswer = null;
        _correctionHandle = null;
      } else {
        _previousBefore = before.excluding(inactive);
      }
    }
    final currentId = _current?.entryId;
    _state = next;
    endedByExclusion = next.isComplete;
    if (next.currentEntryId != currentId) _activate();
  }

  Future<void> _refreshActivity() async {
    final read = activeEntryIds;
    if (read == null) return;
    final active = await read();
    if (!_stopped && !_disposed) {
      _exclude(_state!.entryIds.toSet().difference(active));
    }
  }

  Future<void> revalidateActivity() async {
    if (_stopped || _disposed || isSubmitting || activeEntryIds == null) return;
    final result = Completer<bool>();
    _pending = result.future;
    try {
      _register?.call(awaitPending());
      await _refreshActivity();
      _error = null;
    } catch (error) {
      _error = error;
    } finally {
      _pending = null;
      result.complete(false);
      if (!_stopped && !_disposed) notifyListeners();
    }
  }

  Future<bool> _submitChecked(SpeedTurnHandle handle, SpeedAnswer answer) {
    final result = Completer<bool>();
    _pending = result.future;
    _error = null;
    Future<void> run() async {
      try {
        _register?.call(awaitPending());
        await _refreshActivity();
        if (_stopped || _disposed || !identical(_current, handle)) {
          result.complete(false);
          return;
        }
        final before = _state!;
        final next = before.answer(entryId: handle.entryId, answer: answer);
        final receipt = await _commitAnswer(next);
        if (!_stopped && !_disposed && identical(_current, handle)) {
          _remember(before, answer, receipt);
          _accept(next);
          await _refreshActivity();
        }
        result.complete(true);
      } catch (error, stack) {
        if (error == SpeedCompletionFailure.inactive) {
          _exclude({handle.entryId});
          result.complete(false);
        } else {
          if (!_stopped && !_disposed) _error = error;
          result.completeError(error, stack);
        }
      } finally {
        if (identical(_pending, result.future)) _pending = null;
        if (!_stopped && !_disposed) notifyListeners();
      }
    }

    unawaited(run());
    if (!_stopped && !_disposed) notifyListeners();
    return result.future;
  }

  final void Function(Future<void>)? _register;
  bool Function()? _isPresentationCurrent;
  SpeedSession? _state;
  SpeedTurnHandle? _current;
  SpeedBreakHandle? _currentBreak;
  Future<bool>? _pending;
  Object? _error;
  bool _revealed = false;
  bool _presentationActive;
  bool _stopped = false;
  bool _disposed = false;

  SpeedSession? get state => _state;
  SpeedTurnHandle? get current => _correctionHandle ?? _current;
  SpeedBreakHandle? get currentBreak => _currentBreak;
  bool get revealed => _revealed;
  bool get isSubmitting => _pending != null;
  bool get isStopped => _stopped;
  bool get isComplete => _state?.isComplete ?? false;
  bool get needsBreak => !isCorrecting && (_state?.needsBreak ?? false);
  Object? get error => _error;

  bool get _canInteract =>
      !_disposed &&
      !_stopped &&
      _presentationActive &&
      (_isPresentationCurrent?.call() ?? true);

  /// App switches and locks suspend interaction but retain the same live round.
  void setPresentationActive(bool active, {bool Function()? isCurrent}) {
    if (isCurrent != null) _isPresentationCurrent = isCurrent;
    if (_stopped || _disposed || active == _presentationActive) return;
    _presentationActive = active;
    notifyListeners();
  }

  bool canReveal(SpeedTurnHandle handle) =>
      _canInteract && !isSubmitting && identical(handle, current);

  bool reveal(SpeedTurnHandle handle) {
    if (!canReveal(handle)) return false;
    if (!_revealed) {
      _revealed = true;
      notifyListeners();
    }
    return true;
  }

  bool canAnswer(SpeedTurnHandle handle) => canReveal(handle) && _revealed;

  Future<bool> submitAnswer(SpeedTurnHandle handle, SpeedAnswer answer) {
    if (!canAnswer(handle)) return Future.value(false);
    if (isCorrecting) return _replace(handle, answer);
    if (activeEntryIds != null) return _submitChecked(handle, answer);
    final next = _state!.answer(entryId: handle.entryId, answer: answer);
    if (next.completion == null) {
      _remember(_state!, answer, null);
      _accept(next);
      notifyListeners();
      return Future.value(true);
    }

    final result = Completer<bool>();
    _pending = result.future;
    _error = null;
    // Registration precedes storage so the runtime can safely close afterward.
    try {
      _register?.call(awaitPending());
    } catch (error, stack) {
      _pending = null;
      if (!_stopped && !_disposed) _error = error;
      result.completeError(error, stack);
      if (!_stopped && !_disposed) notifyListeners();
      return result.future;
    }
    unawaited(_commit(handle, next, answer, result));
    if (!_stopped && !_disposed) notifyListeners();
    return result.future;
  }

  Future<void> _commit(
    SpeedTurnHandle handle,
    SpeedSession next,
    SpeedAnswer answer,
    Completer<bool> result,
  ) async {
    try {
      final receipt = await _commitAnswer(next);
      if (!_stopped && !_disposed && identical(handle, _current)) {
        _remember(_state!, answer, receipt);
        _accept(next);
      }
      result.complete(true);
    } catch (error, stack) {
      if (!_stopped && !_disposed && identical(handle, _current)) {
        _error = error;
      }
      result.completeError(error, stack);
    } finally {
      if (identical(_pending, result.future)) _pending = null;
      if (!_stopped && !_disposed) notifyListeners();
    }
  }

  void _activate() {
    final id = _state?.currentEntryId;
    _current = id == null ? null : SpeedTurnHandle._(id);
    if (_state?.numberGame == null) {
      _currentBreak = null;
    } else {
      _currentBreak ??= SpeedBreakHandle._();
    }
    _revealed = false;
  }

  void _accept(SpeedSession next) {
    _state = next;
    _error = null;
    _activate();
  }

  bool beginBreak({Random? random}) {
    if (!_canInteract || isSubmitting || !needsBreak) return false;
    final next = _state!.beginBreak(random: random);
    if (!identical(next, _state)) {
      _accept(next);
      notifyListeners();
    }
    return true;
  }

  bool tapNumber(SpeedBreakHandle handle, int number) {
    if (!_canInteract ||
        isSubmitting ||
        isCorrecting ||
        !needsBreak ||
        _state?.numberGame == null ||
        !identical(handle, _currentBreak)) {
      return false;
    }
    final next = _state!.tapNumber(number);
    if (identical(next, _state)) return false;
    _accept(next);
    notifyListeners();
    return true;
  }

  Future<void> awaitPending() =>
      _pending?.then<void>((_) {}, onError: (Object _, StackTrace _) {}) ??
      Future.value();

  /// Drops unfinished round state immediately; accepted storage work still drains.
  Future<void> stop() {
    if (!_stopped && !_disposed) {
      _discard();
      notifyListeners();
    }
    return awaitPending();
  }

  void _discard() {
    if (_previousCompletion case final receipt?) {
      retireCompletion?.call(receipt);
    }
    _stopped = true;
    _state = null;
    _previousBefore = null;
    _previousAnswer = null;
    _previousCompletion = null;
    _correctionHandle = null;
    _current = null;
    _currentBreak = null;
    _revealed = false;
    _error = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _discard();
    super.dispose();
  }
}
