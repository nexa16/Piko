import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/ai/ai_contract.dart';

/// One explicit request/review/apply owner. No typing listener, retry loop or
/// background work can start an operation. An exit invalidates late replies.
final class AiOperationController extends ChangeNotifier {
  AiOperationController({
    required this.service,
    required this.provider,
    required this.collectionId,
    this.registerPending,
  });
  final AiContentService service;
  final AiProvider provider;
  final String collectionId;
  final void Function(Future<void>)? registerPending;
  AiPlan? plan;
  AiFailure? error;
  bool requesting = false, applying = false, applied = false, disposed = false;
  final selected = <String>{};
  bool allowPartial = false;
  int _revision = 0;
  String? _requestId;
  void _stopWaiting() {
    final id = _requestId;
    if (id != null && provider is CancelableAiProvider) {
      (provider as CancelableAiProvider).cancel(id);
    }
    _requestId = null;
  }

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
      _requestId = request.id;
      final received = AiPlan.parse(request, await provider.generate(request));
      if (disposed || owner != _revision) return;
      plan = received;
      final stillApplicable = await service.applicable(
        request,
        currentDraft: anchor,
      );
      if (disposed || owner != _revision) return;
      if (!stillApplicable) error = AiFailure.stale;
    } catch (failure) {
      if (disposed || owner != _revision) return;
      error = failure is AiFailure ? failure : AiFailure.unavailable;
    } finally {
      if (!disposed && owner == _revision) {
        requesting = false;
        _requestId = null;
        notifyListeners();
      }
    }
  }

  bool get canContinue =>
      !disposed &&
      !requesting &&
      !applying &&
      !applied &&
      plan != null &&
      !plan!.complete &&
      error != AiFailure.stale &&
      (plan!.request.action == AiAction.generate ||
          plan!.request.action == AiAction.gaps) &&
      plan!.cards.length < plan!.request.cardCeiling;

  /// A new explicitly requested paid portion, on the original immutable snapshot.
  /// The prior preview and choices survive errors. There is no automatic retry.
  Future<void> continueGeneration() async {
    if (!canContinue) return;
    final previous = plan!, original = previous.request, owner = ++_revision;
    requesting = true;
    error = null;
    notifyListeners();
    try {
      if (!await service.applicable(original)) throw AiFailure.stale;
      if (disposed || owner != _revision) return;
      final request = AiRequest(
        id: const Uuid().v4(),
        action: original.action,
        snapshot: original.snapshot,
        goal: original.goal,
        comprehensiveLevel: original.comprehensiveLevel,
        allowGroups: original.allowGroups,
        allowValues: original.allowValues,
        previous: previous.toJson(),
      );
      _requestId = request.id;
      final combined = AiPlan.accumulate(
        request,
        await provider.generate(request),
      );
      if (disposed || owner != _revision) return;
      if (!await service.applicable(request)) throw AiFailure.stale;
      if (disposed || owner != _revision) return;
      plan = combined;
      allowPartial = false;
    } catch (failure) {
      if (!disposed && owner == _revision) {
        error = failure is AiFailure ? failure : AiFailure.unavailable;
      }
    } finally {
      if (!disposed && owner == _revision) {
        requesting = false;
        _requestId = null;
        notifyListeners();
      }
    }
  }

  void invalidate() {
    if (disposed || applying) return;
    if (requesting) _stopWaiting();
    ++_revision;
    requesting = false;
    if (plan != null) error = AiFailure.stale;
    notifyListeners();
  }

  void cancel() {
    if (disposed || applying) return;
    if (requesting) _stopWaiting();
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
  Future<AiAdoption> apply({
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
    if (requesting) _stopWaiting();
    disposed = true;
    ++_revision;
    super.dispose();
  }
}
