import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/collection_query.dart';
import '../../data/learning_item.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';
import '../learning/review_launch.dart' show reviewDirectionLabel;
import 'speed_learning_session.dart';
import 'speed_session_route.dart';
import 'speed_setup_dialog.dart';

/// Directional launch actions for an authoritative filtered Collection snapshot.
class SpeedLaunch extends StatefulWidget {
  const SpeedLaunch({
    required this.snapshot,
    required this.factory,
    required this.vocabularyRepository,
    required this.beforeLaunch,
    required this.onBusyChanged,
    this.snapshotLoader,
    this.onPendingWrites,
    this.onSessionClosed,
    this.enabled = true,
    this.scopeIdentity,
    super.key,
  });

  final CollectionQuerySnapshot snapshot;
  final SpeedSessionFactory factory;
  final VocabularyRepository vocabularyRepository;
  final Future<void> Function() beforeLaunch;
  final ValueChanged<bool> onBusyChanged;
  final Future<CollectionQuerySnapshot> Function()? snapshotLoader;
  final ValueChanged<Future<void>>? onPendingWrites;
  final VoidCallback? onSessionClosed;
  final bool enabled;

  /// Stable query intent, independent of passive result refreshes. A Detail
  /// owner can pass (binding, search, immutableFilters) even while holding its
  /// admitted launch snapshot. Without this token, snapshot identity is used.
  final Object? scopeIdentity;

  @override
  State<SpeedLaunch> createState() => _SpeedLaunchState();
}

class _SpeedLaunchState extends State<SpeedLaunch> {
  bool _opening = false;
  bool _launched = false;
  int _identity = 0;
  ModalRoute<int>? _setup;
  Object? _error;
  LearningDirection? _failedDirection;
  int? _failedPoolSize;

  void _closeSetup() {
    final setup = _setup;
    _setup = null;
    if (setup == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (setup.isActive) setup.navigator?.removeRoute(setup);
    });
  }

  @override
  void didUpdateWidget(SpeedLaunch oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ownerChanged =
        oldWidget.snapshot.collection.id != widget.snapshot.collection.id ||
        oldWidget.factory != widget.factory ||
        !identical(oldWidget.vocabularyRepository, widget.vocabularyRepository);
    final scopeChanged =
        oldWidget.scopeIdentity != null || widget.scopeIdentity != null
        ? oldWidget.scopeIdentity != widget.scopeIdentity
        : !identical(oldWidget.snapshot, widget.snapshot);
    final pendingScopeChanged =
        !_launched && (scopeChanged || (oldWidget.enabled && !widget.enabled));
    if (ownerChanged || pendingScopeChanged) {
      _identity++;
      _closeSetup();
      final wasOpening = _opening;
      _opening = false;
      _launched = false;
      _error = null;
      _failedDirection = null;
      _failedPoolSize = null;
      if (wasOpening) {
        final busy = oldWidget.onBusyChanged;
        WidgetsBinding.instance.addPostFrameCallback((_) => busy(false));
      }
    }
  }

  /// Register only admitted preparation, never the time spent in a popup/round.
  Future<T> _prepare<T>(
    Future<T> Function() operation,
    ValueChanged<Future<void>>? register,
  ) async {
    final done = Completer<void>();
    try {
      register?.call(done.future);
      return await operation();
    } finally {
      done.complete();
    }
  }

  Future<void> _open(LearningDirection direction, {int? retryPoolSize}) async {
    final ownerRoute = ModalRoute.of(context);
    if (_opening ||
        !widget.enabled ||
        ownerRoute?.isCurrent != true ||
        (widget.snapshot.directions[direction]?.newSpeedItems.length ?? 0) ==
            0) {
      return;
    }
    final identity = _identity;
    final collectionId = widget.snapshot.collection.id;
    final factory = widget.factory;
    final repository = widget.vocabularyRepository;
    final register = widget.onPendingWrites;
    final busy = widget.onBusyChanged;
    final beforeLaunch = widget.beforeLaunch;
    final loader = widget.snapshotLoader;
    bool current() =>
        mounted &&
        identity == _identity &&
        widget.snapshot.collection.id == collectionId &&
        widget.factory == factory &&
        identical(widget.vocabularyRepository, repository);
    bool canLaunch() =>
        current() && widget.enabled && ownerRoute?.isCurrent == true;
    setState(() {
      _opening = true;
      _error = null;
    });
    busy(true);
    SpeedLearningSession? prepared;
    int? poolSize = retryPoolSize;
    try {
      final initialSnapshot = await _prepare(() async {
        await beforeLaunch();
        if (!canLaunch()) return null;
        return await loader?.call() ?? widget.snapshot;
      }, register);
      if (!mounted ||
          !canLaunch() ||
          initialSnapshot == null ||
          initialSnapshot.collection.id != collectionId) {
        return;
      }
      final count =
          initialSnapshot.directions[direction]?.newSpeedItems.length ?? 0;
      if (count == 0) return;
      ModalRoute<int>? openedSetup;
      poolSize ??= await showSpeedSetup(
        context,
        collection: initialSnapshot.collection,
        direction: direction,
        eligibleCount: count,
        canRestoreFocus: canLaunch,
        onRouteCreated: (route) {
          openedSetup = route;
          if (current()) _setup = route;
        },
      );
      if (identical(_setup, openedSetup)) _setup = null;
      if (poolSize == null || !canLaunch()) return;
      final configuredPool = poolSize;
      var launchSnapshot = initialSnapshot;
      prepared = await _prepare(() async {
        await beforeLaunch();
        if (!canLaunch()) return null;
        final refreshed = await loader?.call() ?? widget.snapshot;
        if (!canLaunch() ||
            refreshed.collection.id != collectionId ||
            (refreshed.directions[direction]?.newSpeedItems.length ?? 0) == 0) {
          return null;
        }
        launchSnapshot = refreshed;
        final visible = Set<String>.unmodifiable(
          refreshed.entries.map((entry) => entry.id),
        );
        final result = await factory(
          collectionId: collectionId,
          direction: direction,
          visibleEntryIds: visible,
          poolSize: configuredPool,
        );
        final state = result.state;
        if (state == null ||
            state.collectionId != collectionId ||
            state.direction != direction ||
            !state.entryIds.every(visible.contains)) {
          await result.stop();
          result.dispose();
          throw StateError('Speed preparation returned another scope');
        }
        return result;
      }, register);
      if (!mounted || !canLaunch() || prepared == null) return;
      final session = prepared;
      _launched = true;
      final closed = Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SpeedSessionRoute(
            collection: launchSnapshot.collection,
            session: session,
            vocabularyRepository: repository,
          ),
        ),
      );
      prepared = null;
      await closed;
      if (current()) widget.onSessionClosed?.call();
    } catch (error) {
      if (current() && ownerRoute?.isCurrent == true) {
        setState(() {
          _error = error;
          _failedDirection = direction;
          _failedPoolSize = poolSize;
        });
      }
    } finally {
      if (prepared != null) {
        await prepared.stop();
        prepared.dispose();
      }
      if (current()) {
        setState(() {
          _opening = false;
          _launched = false;
        });
        busy(false);
      }
    }
  }

  @override
  void dispose() {
    _identity++;
    _closeSetup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final available = LearningDirection.values
        .where(
          (direction) =>
              (widget.snapshot.directions[direction]?.newSpeedItems.length ??
                  0) >
              0,
        )
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    Widget action(LearningDirection direction) {
      final count = widget.snapshot.directions[direction]!.newSpeedItems.length;
      final label = reviewDirectionLabel(widget.snapshot.collection, direction);
      final activate = widget.enabled && !_opening
          ? () => _open(direction)
          : null;
      return Semantics(
        button: true,
        enabled: activate != null,
        label: count == 1
            ? copy.text('r2.speedDirectionOne', {'direction': label})
            : copy.text('r2.speedDirectionAction', {
                'direction': label,
                'count': count,
              }),
        onTap: activate,
        child: ExcludeSemantics(
          child: PikoButton(
            key: ValueKey('collection-speed-${direction.name}'),
            label:
                '${copy.text('action.speed')}\n${copy.text('r2.speedDirectionCount', {'direction': label, 'count': count})}',
            variant: PikoButtonVariant.tint,
            icon: const PikoIcon(PikoIconName.zap),
            onPressed: activate,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            key: const ValueKey('collection-speed-actions'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: action(available.first)),
              SizedBox(width: d.dimension('spacing.2')),
              Expanded(
                child: available.length > 1
                    ? action(available[1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        if (_opening && !_launched) Text(copy.text('learn.preparing')),
        if (_error != null) ...[
          Text(
            copy.text('learn.prepareFailed'),
            style: TextStyle(color: d.color('danger')),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: PikoButton(
              label: copy.text('action.retry'),
              onPressed: widget.enabled && !_opening && _failedDirection != null
                  ? () =>
                        _open(_failedDirection!, retryPoolSize: _failedPoolSize)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}
