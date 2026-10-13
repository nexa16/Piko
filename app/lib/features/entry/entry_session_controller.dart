import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../data/vocabulary_repository.dart';
import '../../data/vocabulary_normalization.dart';

/// Raw editing values; persistence normalization never rewrites this buffer.
@immutable
final class EntryDraft {
  const EntryDraft({this.targetText = '', this.nativeText = ''});
  final String targetText;
  final String nativeText;
}

@immutable
final class SavedEntryEditState {
  const SavedEntryEditState({
    required this.draft,
    required this.committed,
    required this.isSaving,
    this.error,
  });
  final EntryDraft draft;
  final VocabularyRecord committed;
  final bool isSaving;
  final Object? error;
}

final class _SavedEntryBuffer {
  _SavedEntryBuffer(this.committed)
    : draft = EntryDraft(
        targetText: committed.targetText,
        nativeText: committed.nativeText,
      );
  VocabularyRecord committed;
  EntryDraft draft;
  int revision = 0;
  Object? error;
  (int, EntryDraft)? pending;
}

/// One Collection's ephemeral session: new drafts require confirmation, while
/// valid edits of this session's confirmed records save automatically.
/// Text, focus and scroll controllers belong to the consuming widgets.
final class EntrySessionController extends ChangeNotifier {
  EntrySessionController({
    required this.collectionId,
    required VocabularyRepository repository,
    // Public injection name with a private dependency; not a UI-facing property.
    // ignore: prefer_initializing_formals
  }) : _repository = repository;
  final String collectionId;
  final VocabularyRepository _repository;
  EntryDraft _draft = const EntryDraft();
  bool _disposed = false;
  final List<VocabularyRecord> _confirmedEntries = [];
  String? _activeEntryId;
  Future<VocabularyRecord>? _pendingConfirmation;
  final Map<String, _SavedEntryBuffer> _savedBuffers = {};
  final Map<String, Future<void>> _savedWorkers = {};
  bool get isConfirming => !_disposed && _pendingConfirmation != null;

  EntryDraft get draft => _draft;
  List<VocabularyRecord> get confirmedEntries =>
      List.unmodifiable(_confirmedEntries);

  /// Null identifies the in-progress draft; a UUID identifies a saved card.
  String? get activeEntryId => _activeEntryId;

  _SavedEntryBuffer _savedBuffer(String id) {
    _ensureActive();
    final record = _confirmedEntries
        .where((entry) => entry.id == id)
        .firstOrNull;
    if (record == null) {
      throw ArgumentError('Unknown entry in this entry session.');
    }
    return _savedBuffers.putIfAbsent(id, () => _SavedEntryBuffer(record));
  }

  SavedEntryEditState savedEntryState(String id) {
    final buffer = _savedBuffer(id);
    return SavedEntryEditState(
      draft: buffer.draft,
      committed: buffer.committed,
      error: buffer.error,
      isSaving: _savedWorkers.containsKey(id),
    );
  }

  void editSavedEntry(String id, {String? targetText, String? nativeText}) {
    _ensureEditable();
    final buffer = _savedBuffer(id);
    final target = targetText ?? buffer.draft.targetText;
    final native = nativeText ?? buffer.draft.nativeText;
    if (target == buffer.draft.targetText &&
        native == buffer.draft.nativeText) {
      return;
    }
    buffer.draft = EntryDraft(targetText: target, nativeText: native);
    buffer.revision++;
    if (normalizeVocabularyText(target).isEmpty) {
      buffer.error = VocabularyValidation.requiredTarget;
    } else if (normalizeVocabularyText(native).isEmpty) {
      buffer.error = VocabularyValidation.requiredNative;
    } else {
      buffer.error = null;
      buffer.pending = (buffer.revision, buffer.draft);
      _startSavedWorker(id, buffer);
    }
    notifyListeners();
  }

  void _startSavedWorker(String id, _SavedEntryBuffer buffer) {
    if (_savedWorkers.containsKey(id)) return;
    final done = Completer<void>();
    _savedWorkers[id] = done.future;
    unawaited(_saveEntry(id, buffer, done));
  }

  /// Retries the current valid saved edit after a storage failure. This does
  /// not confirm a new entry or duplicate an already running saved edit.
  void retrySavedEntry(String id) {
    _ensureEditable();
    final buffer = _savedBuffer(id);
    if (_savedWorkers.containsKey(id)) return;
    if (normalizeVocabularyText(buffer.draft.targetText).isEmpty) {
      buffer.error = VocabularyValidation.requiredTarget;
    } else if (normalizeVocabularyText(buffer.draft.nativeText).isEmpty) {
      buffer.error = VocabularyValidation.requiredNative;
    } else {
      buffer.revision++;
      buffer.error = null;
      buffer.pending = (buffer.revision, buffer.draft);
      _startSavedWorker(id, buffer);
    }
    notifyListeners();
  }

  Future<void> _saveEntry(
    String id,
    _SavedEntryBuffer buffer,
    Completer<void> done,
  ) async {
    while (buffer.pending != null) {
      final (revision, snapshot) = buffer.pending!;
      buffer.pending = null;
      try {
        final saved = await _repository.update(
          id: id,
          targetText: snapshot.targetText,
          nativeText: snapshot.nativeText,
        );
        if (saved.id != id || saved.collectionId != collectionId) {
          throw StateError('Saved edit returned a different entry identity.');
        }
        buffer.committed = saved;
        if (buffer.revision == revision) buffer.error = null;
        if (!_disposed) {
          final index = _confirmedEntries.indexWhere((entry) => entry.id == id);
          if (index >= 0) _confirmedEntries[index] = saved;
        }
      } catch (error) {
        if (buffer.revision == revision) buffer.error = error;
      }
      if (!_disposed) notifyListeners();
    }
    _savedWorkers.remove(id);
    if (!_disposed) notifyListeners();
    done.complete();
  }

  /// Resolves when all accepted saved-edit queues are idle, including additions
  /// made while draining. Errors remain on each saved-entry state.
  Future<void> awaitSavedEdits() async {
    while (_savedWorkers.isNotEmpty) {
      await Future.wait(_savedWorkers.values.toList(growable: false));
    }
  }

  /// Pending writes freeze editing/navigation; widgets disable those controls
  /// while [isConfirming]. Repeated confirmation shares one result.
  Future<VocabularyRecord> confirmAndNext() {
    _ensureActive();
    final pending = _pendingConfirmation;
    if (pending != null) return pending;
    final snapshot = _draft;
    if (normalizeVocabularyText(snapshot.targetText).isEmpty) {
      return Future.error(VocabularyValidation.requiredTarget);
    }
    if (normalizeVocabularyText(snapshot.nativeText).isEmpty) {
      return Future.error(VocabularyValidation.requiredNative);
    }
    final result = Completer<VocabularyRecord>();
    _pendingConfirmation = result.future;
    notifyListeners();
    unawaited(_confirm(snapshot, result));
    return result.future;
  }

  Future<void> _confirm(
    EntryDraft snapshot,
    Completer<VocabularyRecord> result,
  ) async {
    try {
      final record = await _repository.create(
        collectionId: collectionId,
        targetText: snapshot.targetText,
        nativeText: snapshot.nativeText,
      );
      if (record.collectionId != collectionId) {
        throw StateError(
          'Confirmation returned an entry from another Collection.',
        );
      }
      _pendingConfirmation = null;
      if (!_disposed) {
        _confirmedEntries.add(record);
        _draft = const EntryDraft();
        _activeEntryId = null;
        notifyListeners();
      }
      result.complete(record);
    } catch (error, stack) {
      _pendingConfirmation = null;
      if (!_disposed) notifyListeners();
      result.completeError(error, stack);
    }
  }

  void selectSavedEntry(String id) {
    _ensureEditable();
    if (!_confirmedEntries.any((entry) => entry.id == id)) {
      throw ArgumentError('Unknown entry in this entry session.');
    }
    if (_activeEntryId == id) return;
    _activeEntryId = id;
    notifyListeners();
  }

  void selectDraft() {
    _ensureEditable();
    if (_activeEntryId == null) return;
    _activeEntryId = null;
    notifyListeners();
  }

  void _ensureActive() {
    if (_disposed) throw StateError('The entry session has ended.');
  }

  void _ensureEditable() {
    _ensureActive();
    if (isConfirming) throw StateError('Confirmation is in progress.');
  }

  void setTargetText(String text) => _setDraft(text, _draft.nativeText);
  void setNativeText(String text) => _setDraft(_draft.targetText, text);

  void _setDraft(String target, String native) {
    _ensureEditable();
    if (target == _draft.targetText && native == _draft.nativeText) return;
    _draft = EntryDraft(targetText: target, nativeText: native);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _draft = const EntryDraft();
    _confirmedEntries.clear();
    _savedBuffers.clear();
    _activeEntryId = null;
    super.dispose();
  }
}
