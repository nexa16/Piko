import '../../data/learning_reset.dart';
import '../../data/categories_repository.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../data/collection_query.dart';
import '../../data/learning_item.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import 'speed_direction_actions.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/piko_theme.dart';
import '../learning/review_launch.dart' show reviewDirectionLabel;
import '../learning/learning_direction_choice.dart';
import 'speed_learning_session.dart';
import 'speed_session_route.dart';
import 'speed_setup_dialog.dart';

/// Directional launch actions for an authoritative filtered Collection snapshot.
class SpeedLaunch extends StatefulWidget {
  const SpeedLaunch({
    required this.snapshot,
    required this.factory,
    required this.vocabularyRepository,
    this.categoriesRepository,
    this.learningReset,
    required this.beforeLaunch,
    required this.onBusyChanged,
    this.snapshotLoader,
    this.onPendingWrites,
    this.onSessionClosed,
    this.onCompleted,
    this.onResult,
    this.enabled = true,
    this.countsUnknown = false,
    this.recheckCounts = false,
    this.scopeIdentity,
    this.availabilityChanges,
    this.allowedDirections = const {
      LearningDirection.targetToNative,
      LearningDirection.nativeToTarget,
    },
    super.key,
  });

  final CollectionQuerySnapshot snapshot;
  final SpeedSessionFactory factory;
  final VocabularyRepository vocabularyRepository;
  final CategoriesRepository? categoriesRepository;
  final LearningResetRepository? learningReset;
  final Future<void> Function() beforeLaunch;
  final ValueChanged<bool> onBusyChanged;
  final Future<CollectionQuerySnapshot> Function()? snapshotLoader;
  final ValueChanged<Future<void>>? onPendingWrites;
  final VoidCallback? onSessionClosed;
  final ValueChanged<int>? onCompleted;
  final ValueChanged<SpeedSessionResult>? onResult;
  final bool enabled;
  final bool countsUnknown, recheckCounts;
  final Set<LearningDirection> allowedDirections;

  /// Stable query intent, independent of passive result refreshes. A Detail
  /// owner can pass (binding, search, immutableFilters) even while holding its
  /// admitted launch snapshot. Without this token, snapshot identity is used.
  final Object? scopeIdentity;
  final Listenable? availabilityChanges;

  @override
  SpeedLaunchState createState() => SpeedLaunchState();
}

class SpeedLaunchState extends State<SpeedLaunch> {
  /// Resolve only Speed's eligible directions; retain this launch/setup owner.
  void openMerged() => unawaited(_open(null));
  bool get hasLaunchError => _error != null;
  bool _opening = false;
  bool _launched = false;
  int _identity = 0;
  ModalRoute<dynamic>? _setup;
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
        !_launched &&
        (scopeChanged ||
            !setEquals(oldWidget.allowedDirections, widget.allowedDirections) ||
            (oldWidget.enabled && !widget.enabled));
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

  Future<void> _open(LearningDirection? direction, {int? retryPoolSize}) async {
    final ownerRoute = ModalRoute.of(context);
    if (_opening ||
        (direction != null && !widget.allowedDirections.contains(direction)) ||
        !widget.enabled ||
        ownerRoute?.isCurrent != true ||
        (direction != null &&
            !widget.countsUnknown &&
            !widget.recheckCounts &&
            (widget.snapshot.directions[direction]?.newSpeedItems.length ??
                    0) ==
                0)) {
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
        current() &&
        widget.enabled &&
        (direction == null || widget.allowedDirections.contains(direction)) &&
        ownerRoute?.isCurrent == true;
    setState(() {
      _opening = true;
      _error = null;
    });
    busy(true);
    SpeedLearningSession? prepared;
    int? poolSize = retryPoolSize;
    try {
      var initialSnapshot = await _prepare(() async {
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
      if (direction == null) {
        final available = LearningDirection.values
            .where(
              (value) =>
                  widget.allowedDirections.contains(value) &&
                  (initialSnapshot!.directions[value]?.newSpeedItems.length ??
                          0) >
                      0,
            )
            .toList();
        if (available.isEmpty) return;
        direction = available.length == 1
            ? available.single
            : await showPikoDialog<LearningDirection>(
                context,
                canRestoreFocus: canLaunch,
                onRouteCreated: (route) => _setup = route,
                builder: (dialogContext) => LearningDirectionChoice(
                  title: PikoCopyScope.of(
                    dialogContext,
                  ).text('selectedSpeed.direction'),
                  initial: {
                    for (final value in available)
                      value: initialSnapshot!
                          .directions[value]!
                          .newSpeedItems
                          .length,
                  },
                  changes: widget.availabilityChanges,
                  canChoose: () => current() && widget.enabled,
                  load: () => _prepare(() async {
                    await beforeLaunch();
                    if (!current() || !widget.enabled) {
                      return <LearningDirection, int>{};
                    }
                    final fresh = await loader?.call() ?? widget.snapshot;
                    if (fresh.collection.id != collectionId) {
                      return <LearningDirection, int>{};
                    }
                    return {
                      for (final value in widget.allowedDirections)
                        value:
                            fresh.directions[value]?.newSpeedItems.length ?? 0,
                    };
                  }, register),
                  label: (value, count) => PikoCopyScope.of(dialogContext)
                      .text('r2.speedDirectionCount', {
                        'direction': reviewDirectionLabel(
                          widget.snapshot.collection,
                          value,
                        ),
                        'count': count,
                      }),
                ),
              );
        _setup = null;
        if (direction == null || !canLaunch()) return;
        final rechecked = await _prepare<CollectionQuerySnapshot?>(() async {
          await beforeLaunch();
          if (!canLaunch()) return null;
          return await loader?.call() ?? widget.snapshot;
        }, register);
        if (!mounted ||
            !canLaunch() ||
            rechecked == null ||
            rechecked.collection.id != collectionId) {
          return;
        }
        initialSnapshot = rechecked;
      }
      if (!mounted || !canLaunch()) return;
      final chosenDirection = direction;
      final count =
          initialSnapshot.directions[direction]?.newSpeedItems.length ?? 0;
      if (count == 0) return;
      ModalRoute<int>? openedSetup;
      poolSize ??= await showSpeedSetup(
        context,
        collection: initialSnapshot.collection,
        direction: chosenDirection,
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
          direction: chosenDirection,
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
      final closed = Navigator.of(context).push<SpeedSessionResult>(
        MaterialPageRoute<SpeedSessionResult>(
          builder: (_) => SpeedSessionRoute(
            collection: launchSnapshot.collection,
            session: session,
            vocabularyRepository: repository,
            categoriesRepository: widget.categoriesRepository,
            learningReset: widget.learningReset,
            onPendingWrites: widget.onPendingWrites,
          ),
        ),
      );
      prepared = null;
      final result = await closed;
      if (current()) {
        if (result != null) {
          widget.onCompleted?.call(result.completedCount);
          widget.onResult?.call(result);
        }
        widget.onSessionClosed?.call();
      }
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
              widget.allowedDirections.contains(direction) &&
              (widget.countsUnknown ||
                  (widget
                              .snapshot
                              .directions[direction]
                              ?.newSpeedItems
                              .length ??
                          0) >
                      0),
        )
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SpeedDirectionActions(
          collection: widget.snapshot.collection,
          countsUnknown: widget.countsUnknown,
          recheckCounts: widget.recheckCounts,
          counts: {
            for (final direction in available)
              direction:
                  widget.snapshot.directions[direction]?.newSpeedItems.length ??
                  0,
          },
          onPressed: widget.enabled && !_opening
              ? (direction) => _open(direction)
              : null,
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
