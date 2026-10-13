import 'package:flutter/foundation.dart';
import '../../data/vocabulary_repository.dart';

/// Raw editing values. Persistence normalization happens only on confirmation.
@immutable
final class EntryDraft {
  const EntryDraft({this.targetText = '', this.nativeText = ''});
  final String targetText;
  final String nativeText;
}

/// One Collection's ephemeral entry session. No storage or restoration boundary.
/// Text, focus and scroll controllers belong to the consuming widgets.
final class EntrySessionController extends ChangeNotifier {
  EntrySessionController({required this.collectionId});
  final String collectionId;
  EntryDraft _draft = const EntryDraft();
  bool _disposed = false;
  final List<VocabularyRecord> _confirmedEntries = [];
  String? _activeEntryId;

  EntryDraft get draft => _draft;
  List<VocabularyRecord> get confirmedEntries =>
      List.unmodifiable(_confirmedEntries);

  /// Null identifies the in-progress draft; a UUID identifies a saved card.
  String? get activeEntryId => _activeEntryId;

  /// Called after a successful confirmation within this session, not to import
  /// the Collection's existing vocabulary history.
  void registerConfirmedEntry(VocabularyRecord record) {
    _ensureActive();
    if (record.collectionId != collectionId) {
      throw ArgumentError('The confirmed entry belongs to another Collection.');
    }
    if (_confirmedEntries.any((entry) => entry.id == record.id)) return;
    _confirmedEntries.add(record);
    notifyListeners();
  }

  void selectSavedEntry(String id) {
    _ensureActive();
    if (!_confirmedEntries.any((entry) => entry.id == id)) {
      throw ArgumentError('Unknown entry in this entry session.');
    }
    if (_activeEntryId == id) return;
    _activeEntryId = id;
    notifyListeners();
  }

  void selectDraft() {
    _ensureActive();
    if (_activeEntryId == null) return;
    _activeEntryId = null;
    notifyListeners();
  }

  void _ensureActive() {
    if (_disposed) throw StateError('The entry session has ended.');
  }

  void setTargetText(String text) => _setDraft(text, _draft.nativeText);
  void setNativeText(String text) => _setDraft(_draft.targetText, text);

  void _setDraft(String target, String native) {
    _ensureActive();
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
