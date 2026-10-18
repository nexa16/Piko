import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/vocabulary_content.dart';
import '../entry/entry_session_controller.dart';
import 'ai_content.dart';

/// Ephemeral suggestions belong to one manual draft and never own its save.
final class EntryAiController extends ChangeNotifier {
  EntryAiController({
    required this.session,
    required this.access,
    required this.targetLanguage,
    required this.nativeLanguage,
  }) {
    session.addListener(_sessionChanged);
    access.addListener(_accessChanged);
  }
  final EntrySessionController session;
  final AiAccess access;
  final String targetLanguage, nativeLanguage;
  bool _disposed = false;
  Object? _token;
  EntryDraft? _source;
  int? _advancement;
  AiTask? task;
  AiContentSuggestion? suggestion;
  AiFailure? error;
  bool pending = false;
  bool get eligible =>
      !_disposed &&
      !session.isBusy &&
      !session.isCompleted &&
      session.activeEntryId == null &&
      session.draft.targetText.trim().isNotEmpty &&
      session.draft.nativeText.trim().isNotEmpty;

  bool _sameSource() {
    final source = _source;
    if (!eligible ||
        source == null ||
        session.advancementRevision != _advancement) {
      return false;
    }
    final now = session.draft;
    if (source.targetText != now.targetText ||
        source.nativeText != now.nativeText) {
      return false;
    }
    return task == AiTask.example
        ? listEquals(source.content.examples, now.content.examples)
        : source.content.hintText == now.content.hintText &&
              source.content.hintVisibility == now.content.hintVisibility;
  }

  void _sessionChanged() {
    if (_token != null && !_sameSource()) {
      cancel();
    } else if (!_disposed) {
      notifyListeners();
    }
  }

  void _accessChanged() {
    if (!access.enabled && _token != null) {
      cancel();
    } else if (!_disposed) {
      notifyListeners();
    }
  }

  void cancel() {
    _token = null;
    _source = null;
    suggestion = null;
    error = null;
    pending = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> request(AiTask requested) async {
    if (!eligible) return;
    if (pending || access.busy) {
      if (_token != null && requested != task) {
        cancel();
        task = requested;
        error = AiFailure.busy;
        notifyListeners();
      }
      return;
    }
    cancel();
    final token = Object();
    _token = token;
    task = requested;
    _source = session.draft;
    _advancement = session.advancementRevision;
    pending = true;
    notifyListeners();
    try {
      final result = await access.generate(
        AiContentRequest(
          requestId: const Uuid().v7(),
          task: requested,
          targetLanguage: targetLanguage,
          nativeLanguage: nativeLanguage,
          targetText: _source!.targetText,
          nativeText: _source!.nativeText,
        ),
      );
      if (!_disposed && identical(_token, token) && _sameSource()) {
        suggestion = result;
      }
    } on AiFailure catch (failure) {
      if (!_disposed && identical(_token, token) && _sameSource()) {
        error = failure;
      }
    } finally {
      if (!_disposed && identical(_token, token)) {
        pending = false;
        notifyListeners();
      }
    }
  }

  void use() {
    if (_disposed || pending || !_sameSource()) return;
    final result = suggestion;
    if (result == null) return;
    final old = session.draft.content;
    // Invalidate synchronously before calling the ordinary editor boundary.
    cancel();
    session.setContent(
      VocabularyContent(
        examples: result is AiExample && !old.examples.contains(result.pair)
            ? [...old.examples, result.pair]
            : old.examples,
        hintText: result is AiHint ? result.text : old.hintText,
        hintVisibility: old.hintVisibility,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _token = null;
    session.removeListener(_sessionChanged);
    access.removeListener(_accessChanged);
    super.dispose();
  }
}
