import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/vocabulary_normalization.dart';
import '../../data/vocabulary_repository.dart';

@immutable
final class InlineVocabularyDraft {
  const InlineVocabularyDraft({
    required this.targetText,
    required this.nativeText,
  });
  final String targetText, nativeText;
}

/// One existing entry's raw edit lifetime, independent of entry-session routing.
/// Widgets own text/focus controllers; callers own repository/storage lifetime.
final class InlineVocabularyEditController extends ChangeNotifier {
  InlineVocabularyEditController._({
    required VocabularyRecord entry,
    required VocabularyRepository repository,
    required VocabularyOpeningSnapshot opening,
  }) : entryId = entry.id,
       collectionId = entry.collectionId,
       _draft = InlineVocabularyDraft(
         targetText: entry.targetText,
         nativeText: entry.nativeText,
       ),
       _committed = entry,
       // Keep the public dependency name separate from its private field.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // The public factory receives this value under its domain name.
       // ignore: prefer_initializing_formals
       _opening = opening;

  static Future<InlineVocabularyEditController> open({
    required String entryId,
    required String collectionId,
    required VocabularyRepository repository,
  }) async {
    final opening = await repository.captureOpeningSnapshot(
      entryId: entryId,
      collectionId: collectionId,
    );
    if (opening.entry.id != entryId ||
        opening.entry.collectionId != collectionId) {
      throw StateError('Opening capture returned a different identity.');
    }
    return InlineVocabularyEditController._(
      entry: opening.entry,
      repository: repository,
      opening: opening,
    );
  }

  final String entryId, collectionId;
  final VocabularyRepository _repository;
  VocabularyOpeningSnapshot? _opening;
  Future<VocabularyRecord>? _discarding;
  Object? _discardError;
  Object? get discardError => _discardError;
  bool get isDiscarding => _discarding != null;
  VocabularyRecord get opening {
    _ensureActive();
    return _opening!.entry;
  }

  bool get changedSinceOpening {
    _ensureActive();
    return _worker != null ||
        _discarding != null ||
        _draft.targetText != opening.targetText ||
        _draft.nativeText != opening.nativeText ||
        _committed!.targetText != opening.targetText ||
        _committed!.nativeText != opening.nativeText;
  }

  InlineVocabularyDraft _draft;
  VocabularyRecord? _committed;
  Object? _error;
  int _revision = 0;
  bool _disposed = false;
  (int, InlineVocabularyDraft)? _pending;
  Future<void>? _worker;

  InlineVocabularyDraft get draft => _draft;
  VocabularyRecord get committed {
    _ensureActive();
    return _committed!;
  }

  Object? get error => _error;
  int get revision => _revision;
  bool get isSaving => !_disposed && _worker != null;

  /// Canonical-equivalent raw input is not an unpersisted change. Raw display
  /// buffers deliberately retain spaces/decomposition for stable text selection.
  bool get hasUncommittedChanges {
    _ensureActive();
    return normalizeVocabularyText(_draft.targetText) !=
            normalizeVocabularyText(_committed!.targetText) ||
        normalizeVocabularyText(_draft.nativeText) !=
            normalizeVocabularyText(_committed!.nativeText);
  }

  void setTargetText(String value) => edit(targetText: value);
  void setNativeText(String value) => edit(nativeText: value);

  void edit({String? targetText, String? nativeText}) {
    _ensureActive();
    if (isDiscarding) throw StateError('Discard is in progress.');
    _discardError = null;
    final next = InlineVocabularyDraft(
      targetText: targetText ?? _draft.targetText,
      nativeText: nativeText ?? _draft.nativeText,
    );
    if (next.targetText == _draft.targetText &&
        next.nativeText == _draft.nativeText) {
      return;
    }
    _draft = next;
    _revision++;
    _error = _requiredError(next);
    if (_error == null) {
      _pending = (_revision, next);
      _startWorker();
    }
    notifyListeners();
  }

  VocabularyValidation? _requiredError(InlineVocabularyDraft value) {
    if (normalizeVocabularyText(value.targetText).isEmpty) {
      return VocabularyValidation.requiredTarget;
    }
    if (normalizeVocabularyText(value.nativeText).isEmpty) {
      return VocabularyValidation.requiredNative;
    }
    return null;
  }

  /// Explicit retry is single-flight and never writes an invalid raw pair.
  void retry() {
    _ensureActive();
    if (isDiscarding) return;
    if (_worker != null) return;
    _error = _requiredError(_draft);
    if (_error == null) {
      _revision++;
      _pending = (_revision, _draft);
      _startWorker();
    }
    notifyListeners();
  }

  void _startWorker() {
    if (_worker != null) return;
    final done = Completer<void>();
    _worker = done.future;
    unawaited(_save(done));
  }

  Future<void> _save(Completer<void> done) async {
    while (_pending != null) {
      final (revision, snapshot) = _pending!;
      _pending = null;
      try {
        final saved = await _repository.update(
          id: entryId,
          targetText: snapshot.targetText,
          nativeText: snapshot.nativeText,
        );
        if (saved.id != entryId || saved.collectionId != collectionId) {
          throw StateError('Inline edit returned a different entry identity.');
        }
        if (!_disposed) {
          _committed = saved;
          if (_revision == revision) _error = null;
        }
      } catch (error) {
        if (!_disposed && _revision == revision) _error = error;
      }
      if (!_disposed) notifyListeners();
    }
    _worker = null;
    if (!_disposed) notifyListeners();
    done.complete();
  }

  /// Drains accepted/coalesced writes, including additions while waiting. May
  /// be awaited after disposal before the caller closes its repository.
  Future<void> awaitSavedEdits() async {
    while (_worker != null || _discarding != null) {
      if (_worker != null) await _worker;
      final discard = _discarding;
      if (discard != null) {
        try {
          await discard;
        } catch (_) {
          /* Initiating caller owns the error. */
        }
      }
    }
  }

  Future<VocabularyRecord> discard() {
    _ensureActive();
    if (_discarding != null) return _discarding!;
    final opening = _opening!;
    final done = Completer<VocabularyRecord>();
    _discarding = done.future;
    _discardError = null;
    notifyListeners();
    unawaited(_restore(done, opening));
    return done.future;
  }

  Future<void> _restore(
    Completer<VocabularyRecord> done,
    VocabularyOpeningSnapshot opening,
  ) async {
    try {
      while (_worker != null) {
        await _worker;
      }
      final restored = await _repository.restoreOpeningSnapshot(opening);
      if (restored.id != entryId || restored.collectionId != collectionId) {
        throw StateError('Discard returned a different identity.');
      }
      if (!_disposed) {
        _committed = restored;
        _draft = InlineVocabularyDraft(
          targetText: restored.targetText,
          nativeText: restored.nativeText,
        );
        _error = null;
        _revision++;
      }
      done.complete(restored);
    } catch (error, stack) {
      if (!_disposed) _discardError = error;
      done.completeError(error, stack);
    } finally {
      _discarding = null;
      if (!_disposed) notifyListeners();
    }
  }

  void _ensureActive() {
    if (_disposed) throw StateError('The inline edit lifetime has ended.');
  }

  @override
  void dispose() {
    _disposed = true;
    _draft = const InlineVocabularyDraft(targetText: '', nativeText: '');
    _committed = null;
    _error = null;
    _opening = null;
    _discardError = null;
    // Already accepted snapshots finish; they never publish late state.
    super.dispose();
  }
}
