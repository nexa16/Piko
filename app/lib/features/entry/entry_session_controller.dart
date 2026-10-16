import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../core/clock.dart';
import '../../data/vocabulary_deletion.dart';
import '../../data/vocabulary_repository.dart';
import '../../data/vocabulary_normalization.dart';
import '../../data/categories_repository.dart';
import '../../data/vocabulary_content.dart';

/// Raw editing values; persistence normalization never rewrites this buffer.
@immutable
final class EntryDraft {
  const EntryDraft({
    this.targetText = '',
    this.nativeText = '',
    this.content = const VocabularyContent(),
    this.makeHintVisibilityDefault = false,
  }) : assignments = const {};
  EntryDraft.categorized({
    this.targetText = '',
    this.nativeText = '',
    Map<String, Set<String>> assignments = const {},
    this.content = const VocabularyContent(),
    this.makeHintVisibilityDefault = false,
  }) : assignments = _freezeEntryAssignments(assignments);
  final String targetText;
  final String nativeText;
  final Map<String, Set<String>> assignments;
  final VocabularyContent content;
  final bool makeHintVisibilityDefault;
  bool get hasOptionalText =>
      content.examples.any(
        (pair) =>
            pair.targetText.trim().isNotEmpty ||
            pair.nativeText.trim().isNotEmpty,
      ) ||
      (content.hintText?.trim().isNotEmpty ?? false);
}

Map<String, Set<String>> _freezeEntryAssignments(
  Map<String, Set<String>> values,
) => Map.unmodifiable({
  for (final group in values.entries)
    if (group.value.isNotEmpty)
      group.key: Set<String>.unmodifiable(group.value),
});
bool _sameEntryAssignments(
  Map<String, Set<String>> first,
  Map<String, Set<String>> second,
) =>
    first.length == second.length &&
    first.entries.every((group) => setEquals(group.value, second[group.key]));

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
  _SavedEntryBuffer(
    this.committed, [
    Map<String, Set<String>> assignments = const {},
  ]) : draft = EntryDraft.categorized(
         targetText: committed.targetText,
         nativeText: committed.nativeText,
         assignments: assignments,
         content: committed.content,
       );
  VocabularyRecord committed;
  EntryDraft draft;
  int revision = 0;
  Object? error;
  (int, EntryDraft)? pending;
}

/// Completion preserves and activates a saved buffer that needs attention.
final class SavedEntryCompletionBlocked implements Exception {
  const SavedEntryCompletionBlocked(this.entryId, this.error);
  final String entryId;
  final Object error;
}

@immutable
final class EntryUndoState {
  const EntryUndoState(this.entry, this.expiresAt, this.error);
  final VocabularyRecord entry;
  final DateTime expiresAt;
  final Object? error;
}

final class _SessionDeletion {
  _SessionDeletion(this.receipt, this.assignments);
  final VocabularyDeletionReceipt receipt;
  final Map<String, Set<String>> assignments;
  Timer? timer;
  Object? error;
}

/// One Collection's ephemeral session: new drafts require confirmation, while
/// valid edits of this session's confirmed records save automatically.
/// Text, focus and scroll controllers belong to the consuming widgets.
final class EntrySessionController extends ChangeNotifier {
  EntrySessionController({
    required this.collectionId,
    required VocabularyRepository repository,
    VocabularyDeletionService? deletionService,
    PikoClock? clock,
    // Public injection name with a private dependency; not a UI-facing property.
    // ignore: prefer_initializing_formals
  }) : _repository = repository,
       // Keep the public dependency name distinct from its private field.
       // ignore: prefer_initializing_formals
       _deletionService = deletionService,
       _clock = clock ?? const SystemPikoClock();
  final String collectionId;
  final VocabularyRepository _repository;
  final VocabularyDeletionService? _deletionService;
  final PikoClock _clock;
  final Map<String, int> _ordinals = {};
  int _nextOrdinal = 0, _advancementRevision = 0;
  final Map<String, _SessionDeletion> _deletions = {};
  int _undoLifetime = 0;
  Future<VocabularyDeletionReceipt>? _deleting;
  Future<VocabularyRecord>? _restoring;
  String? _deletingId, _restoringId;
  bool get supportsDeletion => _deletionService != null;
  bool get supportsCategories => _repository is CategorizedVocabularyRepository;
  bool get supportsContent => _repository is VocabularyContentRepository;
  bool _contentDefaultReady = false, _draftContentEdited = false;
  HintVisibility _newHintVisibility = HintVisibility.always;
  Future<void>? _contentDefaultLoad;
  Object? contentDefaultError;
  bool get contentReady => !supportsContent || _contentDefaultReady;
  Future<void> initializeContentDefault() {
    _ensureActive();
    if (!supportsContent || _contentDefaultReady) return Future.value();
    if (_contentDefaultLoad != null) return _contentDefaultLoad!;
    final done = Completer<void>();
    _contentDefaultLoad = done.future;
    contentDefaultError = null;
    if (!_disposed && !isConfirming && !isCompleting) notifyListeners();
    unawaited(() async {
      try {
        final visibility = await (_repository as VocabularyContentRepository)
            .readHintVisibilityDefault();
        if (!_disposed) {
          _newHintVisibility = visibility;
          _contentDefaultReady = true;
          if (!_draftContentEdited &&
              _draft.content.hintVisibility != visibility) {
            _draft = EntryDraft.categorized(
              targetText: _draft.targetText,
              nativeText: _draft.nativeText,
              assignments: _draft.assignments,
              content: VocabularyContent(
                examples: _draft.content.examples,
                hintText: _draft.content.hintText,
                hintVisibility: visibility,
              ),
              makeHintVisibilityDefault: _draft.makeHintVisibilityDefault,
            );
          }
        }
        done.complete();
      } catch (error, stack) {
        if (!_disposed) contentDefaultError = error;
        done.completeError(error, stack);
      } finally {
        _contentDefaultLoad = null;
        if (!_disposed && !isConfirming && !isCompleting) notifyListeners();
      }
    }());
    return done.future;
  }

  int get advancementRevision => _advancementRevision;
  bool get isMutating =>
      !_disposed && (_deleting != null || _restoring != null);
  List<EntryUndoState> get undoEntries => List.unmodifiable(
    _deletions.values.map(
      (value) => EntryUndoState(
        value.receipt.entry,
        value.receipt.expiresAt,
        value.error,
      ),
    ),
  );
  EntryDraft _draft = const EntryDraft();
  Object? _draftError;
  int _draftRevision = 0, _activationRevision = 0;
  final Map<String, Future<void>> _rechecks = {};
  bool _disposed = false;
  final List<VocabularyRecord> _confirmedEntries = [];
  String? _activeEntryId;
  Future<VocabularyRecord>? _pendingConfirmation;
  Future<void>? _completion;
  bool _completed = false, _completing = false;
  final Map<String, _SavedEntryBuffer> _savedBuffers = {};
  final Map<String, Future<void>> _savedWorkers = {};
  Future<void>? _categoryMetadata;
  bool _categoryMetadataRequested = false;
  bool get isConfirming => !_disposed && _pendingConfirmation != null;
  bool get isCompleting => !_disposed && _completing;
  bool get isBusy =>
      isConfirming || isCompleting || isMutating || _contentDefaultLoad != null;
  bool get isCompleted => !_disposed && _completed;

  EntryDraft get draft => _draft;
  Object? get draftError => _draftError;
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

  void editSavedEntry(
    String id, {
    String? targetText,
    String? nativeText,
    Map<String, Set<String>>? assignments,
    VocabularyContent? content,
    bool? makeHintVisibilityDefault,
  }) {
    _ensureEditable();
    if (assignments != null && !supportsCategories) {
      throw StateError('Category editing is unavailable.');
    }
    final buffer = _savedBuffer(id);
    final target = targetText ?? buffer.draft.targetText;
    final native = nativeText ?? buffer.draft.nativeText;
    if (target == buffer.draft.targetText &&
        native == buffer.draft.nativeText &&
        (content == null || content == buffer.draft.content) &&
        (makeHintVisibilityDefault == null ||
            makeHintVisibilityDefault ==
                buffer.draft.makeHintVisibilityDefault) &&
        (assignments == null ||
            _sameEntryAssignments(assignments, buffer.draft.assignments))) {
      return;
    }
    buffer.draft = EntryDraft.categorized(
      targetText: target,
      nativeText: native,
      assignments: assignments ?? buffer.draft.assignments,
      content: content ?? buffer.draft.content,
      makeHintVisibilityDefault:
          makeHintVisibilityDefault ?? buffer.draft.makeHintVisibilityDefault,
    );
    buffer.revision++;
    if (normalizeVocabularyText(target).isEmpty) {
      buffer.error = VocabularyValidation.requiredTarget;
    } else if (normalizeVocabularyText(native).isEmpty) {
      buffer.error = VocabularyValidation.requiredNative;
    } else {
      buffer.error = _contentError(buffer.draft);
      if (buffer.error == null) {
        buffer.pending = (buffer.revision, buffer.draft);
        _startSavedWorker(id, buffer);
      }
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
    if (buffer.error == null ||
        buffer.error is VocabularyValidation ||
        buffer.error is VocabularyContentValidation ||
        buffer.error is CategoryValidation) {
      return;
    }
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
        final repository = _repository;
        final saved = repository is VocabularyContentRepository
            ? await repository.updateWithContent(
                id: id,
                targetText: snapshot.targetText,
                nativeText: snapshot.nativeText,
                assignments: snapshot.assignments,
                content: snapshot.content,
                makeHintVisibilityDefault: snapshot.makeHintVisibilityDefault,
              )
            : repository is CategorizedVocabularyRepository
            ? await repository.updateCategorized(
                id: id,
                targetText: snapshot.targetText,
                nativeText: snapshot.nativeText,
                assignments: snapshot.assignments,
              )
            : await repository.update(
                id: id,
                targetText: snapshot.targetText,
                nativeText: snapshot.nativeText,
              );
        if (saved.id != id || saved.collectionId != collectionId) {
          throw StateError('Saved edit returned a different entry identity.');
        }
        buffer.committed = saved;
        if (snapshot.makeHintVisibilityDefault) {
          _newHintVisibility = snapshot.content.hintVisibility;
        }
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
    while (_savedWorkers.isNotEmpty ||
        _rechecks.isNotEmpty ||
        _categoryMetadata != null) {
      await Future.wait([
        ..._savedWorkers.values,
        ..._rechecks.values,
        ?_categoryMetadata,
      ]);
    }
  }

  /// Deleting one card must not wait for an unrelated entry's held write.
  /// Its own recheck may still accept a save, so drain again after each await.
  Future<void> _awaitSavedEntryEdits(String id) async {
    while (true) {
      final worker = _savedWorkers[id];
      final pending = <Future<void>>[
        ?worker,
        for (final recheck in _rechecks.entries)
          if (recheck.key.startsWith('$id:')) recheck.value,
      ];
      if (pending.isEmpty) return;
      await Future.wait(pending);
    }
  }

  /// Reconcile this session's saved cards after an external confirmed import.
  /// Unconfirmed/raw failed drafts remain owned by the editor, never re-saved
  /// simply because another route changed the stored vocabulary.
  Future<void> refreshSavedEntries() async {
    await awaitSavedEdits();
    if (_disposed) return;
    final revisions = {
      for (final e in _savedBuffers.entries) e.key: e.value.revision,
    };
    final rows = await _repository.watchByCollection(collectionId).first;
    if (_disposed) return;
    final categoryAssignments = <String, Map<String, Set<String>>>{};
    final repository = _repository;
    if (repository is CategorizedVocabularyRepository) {
      for (final entry in rows.where(
        (entry) => _confirmedEntries.any((saved) => saved.id == entry.id),
      )) {
        categoryAssignments[entry.id] = await repository.categorizedAssignments(
          entry.id,
        );
        if (_disposed) return;
      }
    }
    final byId = {for (final entry in rows) entry.id: entry};
    for (var index = 0; index < _confirmedEntries.length; index++) {
      final id = _confirmedEntries[index].id;
      final buffer = _savedBuffers[id];
      if (_savedWorkers.containsKey(id) ||
          (buffer != null && buffer.revision != revisions[id])) {
        continue;
      }
      final updated = byId[id];
      if (updated == null) {
        if (buffer != null) buffer.error = VocabularyValidation.entryNotFound;
        continue;
      }
      _confirmedEntries[index] = updated;
      if (buffer != null) {
        if (buffer.error == null) {
          buffer.draft = EntryDraft.categorized(
            targetText: updated.targetText,
            nativeText: updated.nativeText,
            assignments: categoryAssignments[id] ?? buffer.draft.assignments,
            content: updated.content,
          );
        }
        buffer.committed = updated;
      }
    }
    notifyListeners();
  }

  /// Read-only validation never rewrites the user's raw buffer. The subsequent
  /// update remains authoritative if another writer races this snapshot.
  Future<Object?> _pairError(EntryDraft value, {String? excludingId}) async {
    if (normalizeVocabularyText(value.targetText).isEmpty) {
      return VocabularyValidation.requiredTarget;
    }
    if (normalizeVocabularyText(value.nativeText).isEmpty) {
      return VocabularyValidation.requiredNative;
    }
    final contentError = _contentError(value);
    if (contentError != null) return contentError;
    final entries = await _repository.watchByCollection(collectionId).first;
    final target = vocabularyComparisonKey(value.targetText);
    final native = vocabularyComparisonKey(value.nativeText);
    return entries.any(
          (entry) =>
              entry.collectionId == collectionId &&
              entry.id != excludingId &&
              vocabularyComparisonKey(entry.targetText) == target &&
              vocabularyComparisonKey(entry.nativeText) == native,
        )
        ? VocabularyValidation.duplicatePair
        : null;
  }

  void _recheckSavedEntry(String id) {
    final buffer = _savedBuffers[id];
    if (buffer == null || buffer.error != VocabularyValidation.duplicatePair) {
      return;
    }
    final activation = _activationRevision;
    final revision = buffer.revision;
    final snapshot = buffer.draft;
    final key = '$id:$activation';
    final done = Completer<void>();
    _rechecks[key] = done.future;
    unawaited(() async {
      try {
        final error = await _pairError(snapshot, excludingId: id);
        if (_disposed ||
            _activationRevision != activation ||
            buffer.revision != revision ||
            !identical(_savedBuffers[id], buffer)) {
          return;
        }
        buffer.error = error;
        if (error == null) {
          buffer.pending = (revision, snapshot);
          _startSavedWorker(id, buffer);
        }
        notifyListeners();
      } catch (_) {
        // A failed read cannot establish that the retained conflict is gone.
      } finally {
        _rechecks.remove(key);
        done.complete();
      }
    }());
  }

  void _recheckDraft() {
    if (_draftError != VocabularyValidation.duplicatePair) return;
    final activation = _activationRevision;
    final revision = _draftRevision;
    final snapshot = _draft;
    final key = 'draft:$activation';
    final done = Completer<void>();
    _rechecks[key] = done.future;
    unawaited(() async {
      try {
        final error = await _pairError(snapshot);
        if (_disposed ||
            _activationRevision != activation ||
            _draftRevision != revision) {
          return;
        }
        _draftError = error;
        notifyListeners();
      } catch (_) {
        // Retain duplicate feedback until a successful current read.
      } finally {
        _rechecks.remove(key);
        done.complete();
      }
    }());
  }

  Future<VocabularyDeletionReceipt> deleteSavedEntry(String id) {
    _ensureActive();
    if (_deletingId == id && _deleting != null) return _deleting!;
    _ensureEditable();
    _savedBuffer(id); // Reject foreign/unknown IDs before any service mutation.
    if (_deletionService == null) {
      throw StateError('Deletion service is unavailable.');
    }
    final result = Completer<VocabularyDeletionReceipt>();
    _deletingId = id;
    _deleting = result.future;
    notifyListeners();
    unawaited(_deleteSavedEntry(id, _undoLifetime, result));
    return result.future;
  }

  Future<void> _deleteSavedEntry(
    String id,
    int undoLifetime,
    Completer<VocabularyDeletionReceipt> result,
  ) async {
    try {
      await _awaitSavedEntryEdits(id);
      if (_disposed) throw StateError('The entry session has ended.');
      final repository = _repository;
      final assignments = repository is CategorizedVocabularyRepository
          ? _freezeEntryAssignments(await repository.categorizedAssignments(id))
          : const <String, Set<String>>{};
      if (_disposed) throw StateError('The entry session has ended.');
      final startedAt = _clock.now().toUtc();
      final receipt = await _deletionService!.delete(id);
      if (receipt.entry.id != id ||
          receipt.entry.collectionId != collectionId) {
        _deletionService.forget(receipt);
        throw StateError('Deletion returned a different entry identity.');
      }
      if (_disposed) {
        _deletionService.forget(receipt);
      } else {
        final index = _confirmedEntries.indexWhere((entry) => entry.id == id);
        _confirmedEntries.removeAt(index);
        _savedBuffers.remove(id);
        if (_activeEntryId == id) {
          _activeEntryId = index < _confirmedEntries.length
              ? _confirmedEntries[index].id
              : null;
        }
        if (undoLifetime == _undoLifetime) {
          final deleted = _SessionDeletion(receipt, assignments);
          _deletions[id] = deleted;
          _scheduleUndo(deleted, fallbackNow: startedAt);
        } else {
          _deletionService.forget(receipt);
        }
      }
      result.complete(receipt);
    } catch (error, stack) {
      result.completeError(error, stack);
    } finally {
      _deleting = null;
      _deletingId = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<VocabularyRecord> undoDeletion(String id) {
    _ensureActive();
    if (_restoringId == id && _restoring != null) return _restoring!;
    _ensureEditable();
    final deleted = _deletions[id];
    if (deleted == null) throw VocabularyUndoFailure.invalidReceipt;
    final result = Completer<VocabularyRecord>();
    _restoringId = id;
    _restoring = result.future;
    deleted.error = null;
    notifyListeners();
    unawaited(_undoDeletion(id, deleted, result));
    return result.future;
  }

  Future<void> _undoDeletion(
    String id,
    _SessionDeletion deleted,
    Completer<VocabularyRecord> result,
  ) async {
    try {
      final entry = await _deletionService!.restore(deleted.receipt);
      if (entry.id != id || entry.collectionId != collectionId) {
        throw StateError('Undo returned a different entry identity.');
      }
      final repository = _repository;
      var assignments = deleted.assignments;
      if (repository is CategorizedVocabularyRepository) {
        try {
          assignments = _freezeEntryAssignments(
            await repository.categorizedAssignments(id),
          );
        } catch (_) {
          // The restore already committed. A fallible presentation read must
          // not report Undo failure or retain a consumed receipt.
        }
      }
      if (!_disposed) {
        if (!_confirmedEntries.any((value) => value.id == id)) {
          _confirmedEntries.add(entry);
        }
        _confirmedEntries.sort(
          (a, b) => _ordinals[a.id]!.compareTo(_ordinals[b.id]!),
        );
        _savedBuffers[id] = _SavedEntryBuffer(entry, assignments);
        if (identical(_deletions[id], deleted)) _forgetUndo(id);
      }
      result.complete(entry);
    } catch (error, stack) {
      if (!_disposed && identical(_deletions[id], deleted)) {
        deleted.error = error;
      }
      result.completeError(error, stack);
    } finally {
      _restoring = null;
      _restoringId = null;
      if (!_disposed) {
        _expireUndo();
        notifyListeners();
      }
    }
  }

  void _forgetUndo(String id) {
    final deleted = _deletions.remove(id);
    if (deleted == null) return;
    deleted.timer?.cancel();
    try {
      _deletionService?.forget(deleted.receipt);
    } catch (_) {
      // The caller may already have ended the injected service lifetime.
    }
  }

  void _expireUndo() {
    if (_disposed) return;
    try {
      _deletionService?.expireUndo();
      final now = _clock.now().toUtc();
      for (final item in _deletions.entries.toList()) {
        if (item.key != _restoringId) {
          if (!now.isBefore(item.value.receipt.expiresAt)) {
            _forgetUndo(item.key);
          } else {
            _scheduleUndo(item.value);
          }
        }
      }
    } catch (_) {
      for (final id in _deletions.keys.toList()) {
        if (id != _restoringId) _forgetUndo(id);
      }
    }
    notifyListeners();
  }

  void _scheduleUndo(_SessionDeletion deleted, {DateTime? fallbackNow}) {
    deleted.timer?.cancel();
    DateTime now;
    try {
      now = _clock.now().toUtc();
    } catch (_) {
      // A fallible clock after commit must not report a failed deletion.
      // Initial scheduling can use the captured pre-transaction instant;
      // later expiry fails closed and releases owned capabilities.
      if (fallbackNow == null) rethrow;
      now = fallbackNow;
    }
    final remaining = deleted.receipt.expiresAt.difference(now);
    deleted.timer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      _expireUndo,
    );
  }

  /// Releases only this session's transient capabilities, not the caller's service.
  void forgetUndo() {
    _undoLifetime++;
    for (final id in _deletions.keys.toList()) {
      _forgetUndo(id);
    }
    if (!_disposed) notifyListeners();
  }

  /// Pending writes freeze editing/navigation; widgets disable those controls
  /// while [isConfirming]. Repeated confirmation shares one result.
  Future<VocabularyRecord> confirmAndNext() {
    _ensureActive();
    final pending = _pendingConfirmation;
    if (pending != null) return pending;
    _ensureAdmission();
    final snapshot = _draft;
    if (normalizeVocabularyText(snapshot.targetText).isEmpty) {
      _draftError = VocabularyValidation.requiredTarget;
      notifyListeners();
      return Future.error(VocabularyValidation.requiredTarget);
    }
    if (normalizeVocabularyText(snapshot.nativeText).isEmpty) {
      _draftError = VocabularyValidation.requiredNative;
      notifyListeners();
      return Future.error(VocabularyValidation.requiredNative);
    }
    final contentError = _contentError(snapshot);
    if (contentError != null) {
      _draftError = contentError;
      notifyListeners();
      return Future.error(contentError);
    }
    final result = Completer<VocabularyRecord>();
    _draftError = null;
    _pendingConfirmation = result.future;
    notifyListeners();
    unawaited(_confirm(snapshot, result));
    return result.future;
  }

  /// Final confirmation ends this lifetime, without creating a fresh draft.
  /// A successful result remains reusable when a covered route resumes exit.
  Future<void> completeSession() {
    _ensureActive();
    if (_completion != null) return _completion!;
    _ensureAdmission();
    final result = Completer<void>();
    _completion = result.future;
    _completing = true;
    final snapshot = _draft;
    notifyListeners();
    unawaited(_completeSession(snapshot, result));
    return result.future;
  }

  Future<void> _completeSession(
    EntryDraft snapshot,
    Completer<void> result,
  ) async {
    try {
      if (!contentReady) await initializeContentDefault();
      if (_disposed) throw StateError('The entry session has ended.');
      snapshot = _draft;
      await awaitSavedEdits();
      // Disposal ends the lifetime; do not begin a new write after draining.
      if (_disposed) throw StateError('The entry session has ended.');
      for (final record in _confirmedEntries) {
        final error = _savedBuffers[record.id]?.error;
        if (error != null) {
          _activeEntryId = record.id;
          throw SavedEntryCompletionBlocked(record.id, error);
        }
      }
      final target = normalizeVocabularyText(snapshot.targetText);
      final native = normalizeVocabularyText(snapshot.nativeText);
      if (target.isNotEmpty ||
          native.isNotEmpty ||
          snapshot.assignments.isNotEmpty ||
          snapshot.hasOptionalText) {
        _activeEntryId = null;
        if (target.isEmpty) throw VocabularyValidation.requiredTarget;
        if (native.isEmpty) throw VocabularyValidation.requiredNative;
        final record = await _create(snapshot);
        if (record.collectionId != collectionId) {
          throw StateError(
            'Completion returned an entry from another Collection.',
          );
        }
        if (!_disposed) {
          _confirmedEntries.add(record);
          _savedBuffers[record.id] = _SavedEntryBuffer(
            record,
            snapshot.assignments,
          );
          _ordinals[record.id] = _nextOrdinal++;
          _activeEntryId = record.id;
        }
      }
      if (!_disposed) _completed = true;
      _completing = false;
      if (!_disposed) notifyListeners();
      result.complete();
    } catch (error, stack) {
      _completion = null;
      _completing = false;
      if (!_disposed && error is! SavedEntryCompletionBlocked) {
        _draftError = error;
      }
      if (!_disposed) notifyListeners();
      result.completeError(error, stack);
    }
  }

  Future<void> _confirm(
    EntryDraft snapshot,
    Completer<VocabularyRecord> result,
  ) async {
    try {
      if (!contentReady) await initializeContentDefault();
      if (_disposed) throw StateError('The entry session has ended.');
      snapshot = _draft;
      final record = await _create(snapshot);
      if (record.collectionId != collectionId) {
        throw StateError(
          'Confirmation returned an entry from another Collection.',
        );
      }
      _pendingConfirmation = null;
      if (!_disposed) {
        _confirmedEntries.add(record);
        _savedBuffers[record.id] = _SavedEntryBuffer(
          record,
          snapshot.assignments,
        );
        _ordinals[record.id] = _nextOrdinal++;
        _advancementRevision++;
        if (snapshot.makeHintVisibilityDefault) {
          _newHintVisibility = snapshot.content.hintVisibility;
        }
        _draft = EntryDraft(
          content: VocabularyContent(hintVisibility: _newHintVisibility),
        );
        _draftContentEdited = false;
        _draftRevision++;
        _draftError = null;
        _activationRevision++;
        _activeEntryId = null;
        notifyListeners();
      }
      result.complete(record);
    } catch (error, stack) {
      _pendingConfirmation = null;
      if (!_disposed) _draftError = error;
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
    _activationRevision++;
    _recheckSavedEntry(id);
    notifyListeners();
  }

  void selectDraft() {
    _ensureEditable();
    if (_activeEntryId == null) return;
    _activeEntryId = null;
    _activationRevision++;
    _recheckDraft();
    notifyListeners();
  }

  void _ensureActive() {
    if (_disposed) throw StateError('The entry session has ended.');
  }

  void _ensureEditable() {
    _ensureActive();
    if (isBusy) throw StateError('Confirmation is in progress.');
    if (_completed) throw StateError('The entry session has completed.');
  }

  // Admission owns the same synchronous lock as a write, even while its
  // prerequisite default read is pending. An existing read may be joined.
  void _ensureAdmission() {
    _ensureActive();
    if (isConfirming || isCompleting || isMutating) {
      throw StateError('Confirmation is in progress.');
    }
    if (_completed) throw StateError('The entry session has completed.');
  }

  void setTargetText(String text) => _setDraft(text, _draft.nativeText);
  void setNativeText(String text) => _setDraft(_draft.targetText, text);

  Object? _contentError(EntryDraft value) {
    try {
      value.content.normalized();
      return null;
    } on VocabularyContentValidation catch (error) {
      return error;
    }
  }

  void setContent(
    VocabularyContent content, {
    bool? makeHintVisibilityDefault,
  }) {
    _ensureEditable();
    if (!supportsContent) throw StateError('Optional content is unavailable.');
    _draftContentEdited = true;
    _draft = EntryDraft.categorized(
      targetText: _draft.targetText,
      nativeText: _draft.nativeText,
      assignments: _draft.assignments,
      content: content,
      makeHintVisibilityDefault:
          makeHintVisibilityDefault ?? _draft.makeHintVisibilityDefault,
    );
    _draftRevision++;
    _draftError = _contentError(_draft);
    notifyListeners();
  }

  void _setDraft(String target, String native) {
    _ensureEditable();
    if (target == _draft.targetText && native == _draft.nativeText) return;
    _draft = EntryDraft.categorized(
      targetText: target,
      nativeText: native,
      assignments: _draft.assignments,
      content: _draft.content,
      makeHintVisibilityDefault: _draft.makeHintVisibilityDefault,
    );
    _draftRevision++;
    _draftError = null;
    notifyListeners();
  }

  Future<VocabularyRecord> _create(EntryDraft snapshot) {
    final repository = _repository;
    if (repository is VocabularyContentRepository) {
      return repository.createWithContent(
        collectionId: collectionId,
        targetText: snapshot.targetText,
        nativeText: snapshot.nativeText,
        assignments: snapshot.assignments,
        content: snapshot.content,
        makeHintVisibilityDefault: snapshot.makeHintVisibilityDefault,
      );
    }
    if (repository is CategorizedVocabularyRepository) {
      return repository.createCategorized(
        collectionId: collectionId,
        targetText: snapshot.targetText,
        nativeText: snapshot.nativeText,
        assignments: snapshot.assignments,
      );
    }
    if (snapshot.assignments.isNotEmpty) {
      throw StateError('Category editing is unavailable.');
    }
    return repository.create(
      collectionId: collectionId,
      targetText: snapshot.targetText,
      nativeText: snapshot.nativeText,
    );
  }

  void setCategoryValues({
    String? entryId,
    required String dimensionId,
    required Set<String> valueIds,
  }) {
    _ensureEditable();
    if (!supportsCategories) {
      throw StateError('Category editing is unavailable.');
    }
    if (entryId != null) {
      final buffer = _savedBuffer(entryId);
      editSavedEntry(
        entryId,
        assignments: {...buffer.draft.assignments, dimensionId: valueIds},
      );
      return;
    }
    final next = _freezeEntryAssignments({
      ..._draft.assignments,
      dimensionId: valueIds,
    });
    if (_sameEntryAssignments(next, _draft.assignments)) return;
    _draft = EntryDraft.categorized(
      targetText: _draft.targetText,
      nativeText: _draft.nativeText,
      assignments: next,
      content: _draft.content,
      makeHintVisibilityDefault: _draft.makeHintVisibilityDefault,
    );
    _draftRevision++;
    _draftError = null;
    notifyListeners();
  }

  /// Definition deletions are authoritative only after fresh successful reads.
  /// Older projections and failed reads must not erase new picker selections.
  Future<void> refreshCategoryReferences(CategoriesRepository repository) {
    _ensureActive();
    if (isBusy || !supportsCategories) return Future.value();
    _categoryMetadataRequested = true;
    if (_categoryMetadata != null) return _categoryMetadata!;
    final done = Completer<void>();
    _categoryMetadata = done.future;
    unawaited(() async {
      try {
        while (_categoryMetadataRequested && !_disposed && !isBusy) {
          _categoryMetadataRequested = false;
          final draftRevision = _draftRevision;
          final revisions = {
            for (final entry in _savedBuffers.entries)
              entry.key: entry.value.revision,
          };
          final dimensions = await repository.dimensions(collectionId);
          if (_disposed || isBusy) return;
          final allowed = <String, Set<String>>{};
          for (final dimension in dimensions.where(
            (dimension) => dimension.collectionId == collectionId,
          )) {
            final values = await repository.values(dimension.id);
            if (_disposed || isBusy) return;
            allowed[dimension.id] = values
                .where((value) => value.dimensionId == dimension.id)
                .map((value) => value.id)
                .toSet();
          }
          if (_draftRevision != draftRevision ||
              _savedBuffers.entries.any(
                (entry) => revisions[entry.key] != entry.value.revision,
              )) {
            _categoryMetadataRequested = true;
            continue;
          }
          Map<String, Set<String>> prune(
            Map<String, Set<String>> assignments,
          ) => _freezeEntryAssignments({
            for (final group in assignments.entries)
              if (allowed.containsKey(group.key))
                group.key: group.value.intersection(allowed[group.key]!),
          });
          EntryDraft pruned(EntryDraft value) => EntryDraft.categorized(
            targetText: value.targetText,
            nativeText: value.nativeText,
            assignments: prune(value.assignments),
            content: value.content,
            makeHintVisibilityDefault: value.makeHintVisibilityDefault,
          );
          var changed = false;
          final next = pruned(_draft);
          if (!_sameEntryAssignments(next.assignments, _draft.assignments)) {
            _draft = next;
            _draftRevision++;
            if (_draftError is CategoryValidation &&
                _draftError != CategoryValidation.cardinalityViolation) {
              _draftError = null;
            }
            changed = true;
          }
          for (final entry in _savedBuffers.entries) {
            final buffer = entry.value;
            final next = pruned(buffer.draft);
            if (_sameEntryAssignments(
              next.assignments,
              buffer.draft.assignments,
            )) {
              continue;
            }
            buffer.draft = next;
            buffer.revision++;
            final pending = buffer.pending;
            if (pending != null) {
              buffer.pending = (pending.$1, pruned(pending.$2));
            }
            if (buffer.error is CategoryValidation &&
                buffer.error != CategoryValidation.cardinalityViolation) {
              buffer.error = null;
            }
            if (buffer.error == null &&
                normalizeVocabularyText(next.targetText).isNotEmpty &&
                normalizeVocabularyText(next.nativeText).isNotEmpty) {
              buffer.pending = (buffer.revision, next);
              _startSavedWorker(entry.key, buffer);
            }
            changed = true;
          }
          if (changed) notifyListeners();
        }
      } catch (_) {
        // No authoritative proof of deletion: preserve all raw assignments.
      } finally {
        _categoryMetadata = null;
        done.complete();
      }
    }());
    return done.future;
  }

  @override
  void dispose() {
    _disposed = true;
    forgetUndo();
    _draft = const EntryDraft();
    _confirmedEntries.clear();
    _ordinals.clear();
    _savedBuffers.clear();
    _activeEntryId = null;
    super.dispose();
  }
}
