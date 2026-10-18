import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/ai/ai_contract.dart';
import '../../data/vocabulary_repository.dart';
import '../entry/entry_session_controller.dart';
import 'ai_page.dart';

/// Related saved Hints stay transient until either Add-next or Done successfully
/// confirms this exact new draft. A failed confirmation preserves the plan.
final class AiEntrySessionCoordinator extends ChangeNotifier {
  AiEntrySessionCoordinator({
    required this.support,
    required this.repository,
    required this.session,
  });
  final AiSupport support;
  final EntryConfirmationRepository repository;
  final EntrySessionController Function() session;
  String _draftId = 'draft-${const Uuid().v4()}';
  AiStagedHints? staged;
  bool _disposed = false;
  AiEntry anchor(EntryDraft draft) => AiEntry(
    VocabularyRecord(
      id: _draftId,
      collectionId: session().collectionId,
      targetText: draft.targetText,
      nativeText: draft.nativeText,
      content: draft.content,
      active: draft.active,
    ),
    draft.assignments,
  );
  bool get matchesDraft =>
      staged == null ||
      aiContentKey(anchor(session().draft).toJson()) ==
          aiContentKey(staged!.plan.request.anchor!.toJson());
  Future<void> stage(AiStagedHints selected) async {
    if (_disposed || selected.plan.request.anchor?.record.id != _draftId) {
      throw AiFailure.stale;
    }
    final applicable = await support.service.applicable(
      selected.plan.request,
      currentDraft: anchor(session().draft),
    );
    if (_disposed ||
        !applicable ||
        selected.plan.request.anchor?.record.id != _draftId ||
        aiContentKey(anchor(session().draft).toJson()) !=
            aiContentKey(selected.plan.request.anchor!.toJson())) {
      throw AiFailure.stale;
    }
    staged = selected;
    notifyListeners();
  }

  void discard() {
    staged = null;
    if (!_disposed) notifyListeners();
  }

  Future<EntryConfirmation> confirm(EntryDraft draft) async {
    final current = session(), pending = staged;
    EntryConfirmation result;
    if (pending == null) {
      result = await repository.confirmNewEntry(
        collectionId: current.collectionId,
        targetText: draft.targetText,
        nativeText: draft.nativeText,
        assignments: draft.assignments,
        content: draft.content,
        active: draft.active,
        makeHintVisibilityDefault: draft.makeHintVisibilityDefault,
      );
    } else {
      await current.awaitSavedEdits();
      final known = current.confirmedEntries.map((e) => e.id).toSet();
      for (final entry in pending.plan.request.snapshot.entries) {
        if (known.contains(entry.record.id) &&
            current.savedEntryState(entry.record.id).error != null) {
          throw AiFailure.dependency;
        }
      }
      if (!matchesDraft) throw AiFailure.stale;
      final saved = await support.service.apply(
        pending.plan,
        pending.selected,
        allowPartial: pending.allowPartial,
        newAnchor: anchor(draft),
        makeHintVisibilityDefault: draft.makeHintVisibilityDefault,
      );
      if (saved.confirmation == null) {
        throw StateError('New anchor confirmation missing');
      }
      result = saved.confirmation!;
    }
    staged = null;
    _draftId = 'draft-${const Uuid().v4()}';
    if (!_disposed) notifyListeners();
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
