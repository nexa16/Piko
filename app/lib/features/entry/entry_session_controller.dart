import 'package:flutter/foundation.dart';

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

  EntryDraft get draft => _draft;

  void setTargetText(String text) => _setDraft(text, _draft.nativeText);
  void setNativeText(String text) => _setDraft(_draft.targetText, text);

  void _setDraft(String target, String native) {
    if (_disposed) throw StateError('The entry session has ended.');
    if (target == _draft.targetText && native == _draft.nativeText) return;
    _draft = EntryDraft(targetText: target, nativeText: native);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _draft = const EntryDraft();
    super.dispose();
  }
}
