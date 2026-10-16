import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/vocabulary_normalization.dart';
import '../../data/vocabulary_repository.dart';
import '../../data/categories_repository.dart';
import '../../data/vocabulary_content.dart';

@immutable
final class InlineVocabularyDraft {
  InlineVocabularyDraft({
    required this.targetText,
    required this.nativeText,
    Map<String, Set<String>> assignments = const {},
    this.content = const VocabularyContent(),
    this.makeHintVisibilityDefault = false,
  }) : assignments = _freezeAssignments(assignments);
  final String targetText, nativeText;
  final Map<String, Set<String>> assignments;
  final VocabularyContent content;
  final bool makeHintVisibilityDefault;
}

Map<String, Set<String>> _freezeAssignments(Map<String, Set<String>> values) =>
    Map.unmodifiable({
      for (final entry in values.entries)
        if (entry.value.isNotEmpty)
          entry.key: Set<String>.unmodifiable(entry.value),
    });

bool _sameAssignments(
  Map<String, Set<String>> first,
  Map<String, Set<String>> second,
) =>
    first.length == second.length &&
    first.entries.every((entry) => setEquals(entry.value, second[entry.key]));

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
         content: entry.content,
         assignments: opening is CategorizedVocabularyOpeningSnapshot
             ? opening.assignments
             : const {},
       ),
       _committedAssignments = _freezeAssignments(
         opening is CategorizedVocabularyOpeningSnapshot
             ? opening.assignments
             : const {},
       ),
       _openingAssignments = _freezeAssignments(
         opening is CategorizedVocabularyOpeningSnapshot
             ? opening.assignments
             : const {},
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
  Map<String, Set<String>> _committedAssignments, _openingAssignments;
  bool get supportsCategories => _repository is CategorizedVocabularyRepository;
  bool get supportsContent => _repository is VocabularyContentRepository;
  bool _committedMakeHintDefault = false;
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
        _committed!.nativeText != opening.nativeText ||
        _draft.content != opening.content ||
        _committed!.content != opening.content ||
        _draft.makeHintVisibilityDefault ||
        !_sameAssignments(_draft.assignments, _openingAssignments) ||
        !_sameAssignments(_committedAssignments, _openingAssignments);
  }

  InlineVocabularyDraft _draft;
  VocabularyRecord? _committed;
  Object? _error;
  int _revision = 0;
  bool _disposed = false;
  (int, InlineVocabularyDraft)? _pending;
  Future<void>? _worker;
  Future<void>? _metadataWorker;
  bool _metadataRequested = false;
  int _lastPruneRevision = -1;
  Map<String, Set<String>> _validCategoryValues = const {};

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
            normalizeVocabularyText(_committed!.nativeText) ||
        !_sameNormalizedContent(_draft.content, _committed!.content) ||
        _draft.makeHintVisibilityDefault != _committedMakeHintDefault ||
        !_sameAssignments(_draft.assignments, _committedAssignments);
  }

  void setTargetText(String value) => edit(targetText: value);
  void setNativeText(String value) => edit(nativeText: value);
  void setContent(
    VocabularyContent content, {
    bool? makeHintVisibilityDefault,
  }) => edit(
    content: content,
    makeHintVisibilityDefault: makeHintVisibilityDefault,
  );

  bool _sameNormalizedContent(
    VocabularyContent first,
    VocabularyContent second,
  ) {
    try {
      return first.normalized() == second;
    } on VocabularyContentValidation {
      return false;
    }
  }

  void setCategoryValues(String dimensionId, Set<String> valueIds) {
    if (!supportsCategories) {
      throw StateError('Category editing is unavailable.');
    }
    edit(assignments: {..._draft.assignments, dimensionId: valueIds});
  }

  /// Explicit definition deletion remains effective in every open buffer. Only
  /// a fresh repository read can remove UUIDs; an older query projection cannot
  /// erase a value just created/confirmed in the picker. Mode conflicts remain.
  Future<void> refreshCategoryReferences(CategoriesRepository repository) {
    _ensureActive();
    _metadataRequested = true;
    if (_metadataWorker != null) return _metadataWorker!;
    final done = Completer<void>();
    _metadataWorker = done.future;
    unawaited(() async {
      try {
        while (_metadataRequested && !_disposed && !isDiscarding) {
          _metadataRequested = false;
          final revision = _revision;
          final dimensions = await repository.dimensions(collectionId);
          if (_disposed || isDiscarding) return;
          final allowed = <String, Set<String>>{};
          for (final dimension in dimensions) {
            if (dimension.collectionId != collectionId) continue;
            final values = await repository.values(dimension.id);
            if (_disposed || isDiscarding) return;
            allowed[dimension.id] = values
                .where((value) => value.dimensionId == dimension.id)
                .map((value) => value.id)
                .toSet();
          }
          if (_revision != revision) {
            _metadataRequested = true;
            continue;
          }
          Map<String, Set<String>> prune(Map<String, Set<String>> map) =>
              _freezeAssignments({
                for (final group in map.entries)
                  if (allowed.containsKey(group.key))
                    group.key: group.value.intersection(allowed[group.key]!),
              });
          final next = prune(_draft.assignments);
          final committed = prune(_committedAssignments);
          final opening = prune(_openingAssignments);
          if (_sameAssignments(next, _draft.assignments) &&
              _sameAssignments(committed, _committedAssignments) &&
              _sameAssignments(opening, _openingAssignments)) {
            continue;
          }
          _revision++;
          _lastPruneRevision = _revision;
          _validCategoryValues = allowed;
          _draft = InlineVocabularyDraft(
            targetText: _draft.targetText,
            nativeText: _draft.nativeText,
            assignments: next,
            content: _draft.content,
            makeHintVisibilityDefault: _draft.makeHintVisibilityDefault,
          );
          _committedAssignments = committed;
          _openingAssignments = opening;
          final pending = _pending;
          if (pending != null) {
            _pending = (
              pending.$1,
              InlineVocabularyDraft(
                targetText: pending.$2.targetText,
                nativeText: pending.$2.nativeText,
                assignments: prune(pending.$2.assignments),
                content: pending.$2.content,
                makeHintVisibilityDefault: pending.$2.makeHintVisibilityDefault,
              ),
            );
          }
          if (_error is CategoryValidation &&
              _error != CategoryValidation.cardinalityViolation) {
            _error = _requiredError(_draft);
          }
          if (_error == null &&
              _requiredError(_draft) == null &&
              hasUncommittedChanges) {
            _pending = (_revision, _draft);
            _startWorker();
          }
          notifyListeners();
        }
      } catch (_) {
        // A failed metadata read is never evidence that definitions disappeared.
      } finally {
        _metadataWorker = null;
        done.complete();
      }
    }());
    return done.future;
  }

  void edit({
    String? targetText,
    String? nativeText,
    Map<String, Set<String>>? assignments,
    VocabularyContent? content,
    bool? makeHintVisibilityDefault,
  }) {
    _ensureActive();
    if (assignments != null && !supportsCategories) {
      throw StateError('Category editing is unavailable.');
    }
    if (isDiscarding) throw StateError('Discard is in progress.');
    _discardError = null;
    final next = InlineVocabularyDraft(
      targetText: targetText ?? _draft.targetText,
      nativeText: nativeText ?? _draft.nativeText,
      assignments: assignments ?? _draft.assignments,
      content: content ?? _draft.content,
      makeHintVisibilityDefault:
          makeHintVisibilityDefault ?? _draft.makeHintVisibilityDefault,
    );
    if (next.targetText == _draft.targetText &&
        next.nativeText == _draft.nativeText &&
        next.content == _draft.content &&
        next.makeHintVisibilityDefault == _draft.makeHintVisibilityDefault &&
        _sameAssignments(next.assignments, _draft.assignments)) {
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

  Object? _requiredError(InlineVocabularyDraft value) {
    if (normalizeVocabularyText(value.targetText).isEmpty) {
      return VocabularyValidation.requiredTarget;
    }
    if (normalizeVocabularyText(value.nativeText).isEmpty) {
      return VocabularyValidation.requiredNative;
    }
    try {
      value.content.normalized();
      return null;
    } on VocabularyContentValidation catch (error) {
      return error;
    }
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
        final repository = _repository;
        final saved = repository is VocabularyContentRepository
            ? await repository.updateWithContent(
                id: entryId,
                targetText: snapshot.targetText,
                nativeText: snapshot.nativeText,
                assignments: snapshot.assignments,
                content: snapshot.content,
                makeHintVisibilityDefault: snapshot.makeHintVisibilityDefault,
              )
            : repository is CategorizedVocabularyRepository
            ? await repository.updateCategorized(
                id: entryId,
                targetText: snapshot.targetText,
                nativeText: snapshot.nativeText,
                assignments: snapshot.assignments,
              )
            : await repository.update(
                id: entryId,
                targetText: snapshot.targetText,
                nativeText: snapshot.nativeText,
              );
        if (saved.id != entryId || saved.collectionId != collectionId) {
          throw StateError('Inline edit returned a different entry identity.');
        }
        if (!_disposed) {
          _committed = saved;
          _committedMakeHintDefault = snapshot.makeHintVisibilityDefault;
          _committedAssignments = revision < _lastPruneRevision
              ? _freezeAssignments({
                  for (final group in snapshot.assignments.entries)
                    if (_validCategoryValues.containsKey(group.key))
                      group.key: group.value.intersection(
                        _validCategoryValues[group.key]!,
                      ),
                })
              : snapshot.assignments;
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
    while (_worker != null || _discarding != null || _metadataWorker != null) {
      if (_worker != null) await _worker;
      if (_metadataWorker != null) await _metadataWorker;
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
      final repository = _repository;
      final restoredAssignments = repository is CategorizedVocabularyRepository
          ? _freezeAssignments(await repository.categorizedAssignments(entryId))
          : const <String, Set<String>>{};
      if (!_disposed) {
        _committed = restored;
        _draft = InlineVocabularyDraft(
          targetText: restored.targetText,
          nativeText: restored.nativeText,
          assignments: restoredAssignments,
          content: restored.content,
        );
        _committedAssignments = restoredAssignments;
        _committedMakeHintDefault = false;
        _openingAssignments = restoredAssignments;
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
    _draft = InlineVocabularyDraft(targetText: '', nativeText: '');
    _committedAssignments = const {};
    _openingAssignments = const {};
    _committed = null;
    _error = null;
    _opening = null;
    _discardError = null;
    // Already accepted snapshots finish; they never publish late state.
    super.dispose();
  }
}
