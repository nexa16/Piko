import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/ai/ai_contract.dart';
import '../../data/local/sqlite_ai_service.dart';
import '../../data/vocabulary_repository.dart';

/// One explicit request/review/apply owner. No typing listener, retry loop or
/// background work can start an operation. An exit invalidates late replies.
final class AiOperationController extends ChangeNotifier {
  AiOperationController({
    required this.service,
    required this.provider,
    required this.collectionId,
    this.registerPending,
  });
  final SqliteAiService service;
  final AiProvider provider;
  final String collectionId;
  final void Function(Future<void>)? registerPending;
  AiPlan? plan;
  AiFailure? error;
  bool requesting = false, applying = false, applied = false, disposed = false;
  final selected = <String>{};
  bool allowPartial = false;
  int _revision = 0;
  Future<void> start({
    required AiAction action,
    String goal = '',
    bool comprehensiveLevel = false,
    bool allowGroups = true,
    bool allowValues = true,
    AiEntry? anchor,
    Set<String>? targets,
  }) async {
    if (disposed || requesting || applying) return;
    final owner = ++_revision;
    requesting = true;
    error = null;
    plan = null;
    applied = false;
    selected.clear();
    allowPartial = false;
    notifyListeners();
    try {
      final request = await service.request(
        collectionId: collectionId,
        action: action,
        goal: goal,
        comprehensiveLevel: comprehensiveLevel,
        allowGroups: allowGroups,
        allowValues: allowValues,
        anchor: anchor,
        targets: targets,
      );
      if (disposed || owner != _revision) return;
      final received = AiPlan.parse(request, await provider.generate(request));
      if (disposed || owner != _revision) return;
      plan = received;
      final stillApplicable = await service.applicable(request, currentDraft: anchor);
      if (disposed || owner != _revision) return;
      if (!stillApplicable) error = AiFailure.stale;
    } catch (failure) {
      if (disposed || owner != _revision) return;
      error = failure is AiFailure ? failure : AiFailure.unavailable;
    } finally {
      if (!disposed && owner == _revision) {
        requesting = false;
        notifyListeners();
      }
    }
  }

  void invalidate() {
    if (disposed || applying) return;
    ++_revision; requesting=false;
    if (plan != null) error=AiFailure.stale;
    notifyListeners();
  }

  void cancel() {
    if (disposed || applying) return;
    ++_revision;
    requesting = false;
    plan = null;
    selected.clear();
    error = null;
    notifyListeners();
  }

  void choose(String id, bool value) {
    if (disposed || applying || applied) return;
    value ? selected.add(id) : selected.remove(id);
    notifyListeners();
  }

  bool get canApply =>
      !disposed &&
      !requesting &&
      !applying &&
      !applied &&
      plan != null &&
      selected.isNotEmpty &&
      error != AiFailure.stale &&
      (plan!.complete || allowPartial);
  Future<VocabularyRecord?> apply({
    AiEntry? newAnchor,
    bool makeHintVisibilityDefault = false,
  }) async {
    if (!canApply) throw error ?? AiFailure.dependency;
    final current = plan!, choices = Set<String>.of(selected);
    applying = true;
    error = null;
    notifyListeners();
    final operation = service.apply(
      current,
      choices,
      allowPartial: allowPartial,
      newAnchor: newAnchor,
      makeHintVisibilityDefault: makeHintVisibilityDefault,
    );
    registerPending?.call(operation.then<void>((_) {}));
    try {
      final saved = await operation;
      applied = true;
      return saved;
    } catch (failure) {
      error = failure is AiFailure ? failure : AiFailure.unavailable;
      rethrow;
    } finally {
      applying = false;
      if (!disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    disposed = true;
    ++_revision;
    super.dispose();
  }
}
