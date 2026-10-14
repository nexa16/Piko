import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/learning_item.dart';
import '../../data/regular_review.dart';
import 'learning_scheduler.dart';

enum AnswerGrade { incorrect, correct }

/// A captured presentation, distinct even when the same item is activated again.
final class GradingCardHandle {
  const GradingCardHandle._(this.item);
  final LearningItemRecord item;
}

/// Owns a regular card's modifier and one accepted write; storage stays caller-owned.
final class RegularGradingCoordinator extends ChangeNotifier {
  RegularGradingCoordinator({
    required RegularReviewWriter repository,
    void Function(Future<void>)? onPendingWrites,
  }) : // Preserve the public dependency name while keeping ownership private.
       // ignore: prefer_initializing_formals
       _repository = repository,
       _register = onPendingWrites;
  final RegularReviewWriter _repository;
  final void Function(Future<void>)? _register;
  GradingCardHandle? _current;
  bool _hard = false, _disposed = false;
  Object? _error;
  RegularReviewReceipt? _accepted;
  Future<RegularReviewReceipt?>? _pending;
  GradingCardHandle? get current => _current;
  bool get hard => _hard;
  bool get isSubmitting => _pending != null;
  Object? get error => _error;
  RegularReviewReceipt? get accepted => _accepted;

  /// Busy activation is refused, so an accepted grade cannot be superseded.
  GradingCardHandle? activate(LearningItemRecord item) {
    if (_disposed || isSubmitting) return null;
    item.card;
    final handle = GradingCardHandle._(item);
    _current = handle;
    _hard = false;
    _error = null;
    _accepted = null;
    notifyListeners();
    return handle;
  }

  bool setHard(GradingCardHandle handle, bool selected) {
    if (_disposed ||
        !identical(_current, handle) ||
        isSubmitting ||
        _accepted != null) {
      return false;
    }
    if (_hard != selected) {
      _hard = selected;
      notifyListeners();
    }
    return true;
  }

  /// Only an accepted presentation may explicitly retire and reset its modifier.
  bool completeAdvance(GradingCardHandle handle) {
    if (_disposed ||
        !identical(_current, handle) ||
        isSubmitting ||
        _accepted == null) {
      return false;
    }
    _current = null;
    _hard = false;
    _accepted = null;
    _error = null;
    notifyListeners();
    return true;
  }

  Future<RegularReviewReceipt?> submit(
    GradingCardHandle handle,
    AnswerGrade grade, {
    required DateTime reviewedAt,
  }) {
    if (_disposed ||
        !identical(_current, handle) ||
        isSubmitting ||
        _accepted != null) {
      return Future.value(null);
    }
    final rating = grade == AnswerGrade.incorrect
        ? LearningRating.again
        : _hard
        ? LearningRating.hard
        : LearningRating.good;
    final result = Completer<RegularReviewReceipt?>();
    _pending = result.future;
    _error = null;
    final drain = result.future.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    // Registration must precede storage so runtime close can always drain it.
    try {
      _register?.call(drain);
    } catch (error, stack) {
      if (!_disposed) _error = error;
      _pending = null;
      result.completeError(error, stack);
      if (!_disposed) notifyListeners();
      return result.future;
    }
    unawaited(_record(handle, rating, reviewedAt, result));
    if (!_disposed) notifyListeners();
    return result.future;
  }

  Future<void> _record(
    GradingCardHandle handle,
    LearningRating rating,
    DateTime at,
    Completer<RegularReviewReceipt?> result,
  ) async {
    try {
      final receipt = await _repository.review(
        kind: ReviewKind.regular,
        expectedPrior: handle.item,
        rating: rating,
        reviewedAt: at,
      );
      if (!_disposed && identical(_current, handle)) _accepted = receipt;
      // Return the original accepted receipt even after disposal; session owners
      // may still need its captured identity or await it before closing storage.
      result.complete(receipt);
    } catch (error, stack) {
      if (!_disposed && identical(_current, handle)) _error = error;
      result.completeError(error, stack);
    } finally {
      if (identical(_pending, result.future)) _pending = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> awaitPending() =>
      _pending?.then<void>((_) {}, onError: (Object _, StackTrace _) {}) ??
      Future.value();

  @override
  void dispose() {
    _disposed = true;
    _current = null;
    _hard = false;
    _error = null;
    _accepted = null;
    super.dispose();
  }
}
