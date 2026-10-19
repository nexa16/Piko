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
  AiPlan? plan, replacement;
  AiFailure? error;
  bool requesting = false, applying = false, applied = false, disposed = false;
  final selected = <String>{};
  bool allowPartial = false;
  int _revision = 0;
  String? _requestId, _rootRequestId;
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
    replacement = null;
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
      _rootRequestId = request.id;
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
      replacement == null &&
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
        followUp: original.followUp,
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

  bool get canReplace =>
      !disposed &&
      !requesting &&
      !applying &&
      !applied &&
      replacement == null &&
      plan != null &&
      error != AiFailure.stale &&
      (plan!.request.action == AiAction.generate ||
          plan!.request.action == AiAction.gaps);

  /// Separate replacement review; the current preview is never consumed here.
  Future<void> replaceGeneration({String? instruction}) async {
    if (!canReplace || (instruction != null && instruction.trim().isEmpty)) {
      return;
    }
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
        followUp: {
          'kind': instruction == null ? 'regenerate' : 'refine',
          'parentRequestId': original.id,
          'rootRequestId': _rootRequestId ?? original.id,
          if (instruction != null) 'instruction': instruction.trim(),
          if (instruction != null) 'result': previous.toJson(),
        },
      );
      _requestId = request.id;
      final candidate = AiPlan.parse(request, await provider.generate(request));
      if (disposed || owner != _revision) return;
      if (!await service.applicable(request)) throw AiFailure.stale;
      if (disposed || owner != _revision) return;
      replacement = candidate;
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

  Future<void> acceptReplacement() async {
    if (disposed ||
        requesting ||
        applying ||
        replacement == null ||
        error == AiFailure.stale) {
      return;
    }
    final candidate = replacement!, owner = _revision;
    try {
      if (!await service.applicable(candidate.request)) throw AiFailure.stale;
      if (disposed || owner != _revision || replacement != candidate) return;
      plan = candidate;
      replacement = null;
      selected.clear();
      allowPartial = false;
      error = null;
    } catch (failure) {
      if (!disposed && owner == _revision) {
        error = failure is AiFailure ? failure : AiFailure.unavailable;
      }
    }
    if (!disposed && owner == _revision) notifyListeners();
  }

  void keepPrevious() {
    if (disposed || applying || requesting) return;
    replacement = null;
    notifyListeners();
  }

  void stopWaiting() {
    if (disposed || applying || !requesting) return;
    _stopWaiting();
    ++_revision;
    requesting = false;
    notifyListeners();
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
    replacement = null;
    selected.clear();
    error = null;
    notifyListeners();
  }

  void choose(String id, bool value) {
    if (disposed || requesting || applying || applied || replacement != null) {
      return;
    }
    value ? selected.add(id) : selected.remove(id);
    notifyListeners();
  }

  bool get canApply =>
      !disposed &&
      !requesting &&
      !applying &&
      !applied &&
      plan != null &&
      replacement == null &&
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
      // Telemetry cannot roll back a successful local commit or invite a retry.
      if (provider is AiPilotAccess) {
        try {
          await (provider as AiPilotAccess).pilot('adoption', {
            'requestId': current.request.id,
            'selected': choices.toList()..sort(),
          });
        } catch (_) {
          /* No content retry, no false failure of the saved adoption. */
        }
      }
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
