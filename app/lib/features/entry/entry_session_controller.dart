import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../data/vocabulary_repository.dart';
import '../../data/vocabulary_normalization.dart';

/// Raw editing values. Persistence normalization happens only on confirmation.
@immutable
final class EntryDraft {
  const EntryDraft({this.targetText = '', this.nativeText = ''});
  final String targetText;
  final String nativeText;
}

/// One Collection's ephemeral entry session. Only explicit confirmation writes.
/// Text, focus and scroll controllers belong to the consuming widgets.
final class EntrySessionController extends ChangeNotifier {
  EntrySessionController({
    required this.collectionId,
    required this.repository,
  });
  final String collectionId;
  final VocabularyRepository repository;
  EntryDraft _draft = const EntryDraft();
  bool _disposed = false;
  final List<VocabularyRecord> _confirmedEntries = [];
  String? _activeEntryId;
  Future<VocabularyRecord>? _pendingConfirmation;
  bool get isConfirming => !_disposed && _pendingConfirmation != null;

  EntryDraft get draft => _draft;
  List<VocabularyRecord> get confirmedEntries =>
      List.unmodifiable(_confirmedEntries);

  /// Null identifies the in-progress draft; a UUID identifies a saved card.
  String? get activeEntryId => _activeEntryId;

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
      final record = await repository.create(
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
    _activeEntryId = null;
    super.dispose();
  }
}
