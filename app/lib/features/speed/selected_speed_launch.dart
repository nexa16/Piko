import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/categories_repository.dart';
import '../../data/collection_query.dart';
import '../../data/collections_repository.dart';
import '../../data/learning_item.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/piko_theme.dart';
import '../collections/collection_view_preferences.dart';
import '../learning/review_launch.dart' show reviewDirectionLabel;
import '../learning/learning_direction_choice.dart';
import '../vocabulary/vocabulary_selection.dart';
import 'speed_learning_session.dart';
import 'speed_session_route.dart';
import 'speed_setup_dialog.dart';

/// Counts and order come from one authoritative Collection snapshot, including
/// hidden selections. Group occurrences and selection click order are irrelevant.
final class SelectedSpeedScope {
  SelectedSpeedScope(
    CollectionQuerySnapshot snapshot,
    Set<String> selected,
    VocabularySort sort,
  ) : collection = snapshot.collection {
    final owned = {
      for (final entry in snapshot.allEntries)
        if (entry.collectionId == collection.id && selected.contains(entry.id))
          entry.id: entry,
    };
    inactive = owned.values.where((entry) => !entry.active).length;
    missing = selected.length - owned.length;
    orderedIds = List.unmodifiable(
      sortVocabulary(
        owned.values.toList(),
        sort,
      ).where((entry) => entry.active).map((entry) => entry.id),
    );
    final visible = snapshot.entries.map((entry) => entry.id).toSet();
    hidden = orderedIds.where((id) => !visible.contains(id)).length;
  }
  final CollectionRecord collection;
  late final List<String> orderedIds;
  late final int inactive, missing, hidden;
  bool sameMembership(SelectedSpeedScope other) =>
      listEquals(orderedIds, other.orderedIds) &&
      inactive == other.inactive &&
      missing == other.missing &&
      hidden == other.hidden;
}

class SelectedSpeedLaunch extends StatefulWidget {
  const SelectedSpeedLaunch({
    super.key,
    required this.collection,
    required this.selection,
    required this.directions,
    required this.factory,
    required this.loadScope,
    required this.beforeLaunch,
    required this.onBusyChanged,
    required this.vocabularyRepository,
    this.categoriesRepository,
    this.onPendingWrites,
    this.onCompleted,
    this.onSessionClosed,
    this.enabled = true,
    this.recheckCounts = false,
    this.actionBuilder,
    this.eligibleCount = 0,
    this.availabilityChanges,
    this.scopeIdentity,
  });
  final CollectionRecord collection;
  final VocabularySelection selection;
  final Set<LearningDirection> directions;
  final SelectedSpeedSessionFactory factory;
  final Future<SelectedSpeedScope> Function(Set<String>) loadScope;
  final Future<void> Function() beforeLaunch;
  final ValueChanged<bool> onBusyChanged;
  final VocabularyRepository vocabularyRepository;
  final CategoriesRepository? categoriesRepository;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<int>? onCompleted;
  final VoidCallback? onSessionClosed;
  final bool enabled;
  final bool recheckCounts;
  final int eligibleCount;
  final Listenable? availabilityChanges;
  final Object? scopeIdentity;
  final Widget Function(BuildContext, void Function(LearningDirection?)?)?
  actionBuilder;
  @override
  SelectedSpeedLaunchState createState() => SelectedSpeedLaunchState();
}

class SelectedSpeedLaunchState extends State<SelectedSpeedLaunch> {
  final _focus = FocusNode();
  bool _opening = false, _launched = false, _launchFailed = false;
  int _generation = 0;
  ModalRoute<dynamic>? _dialog;
  void _closeDialog() {
    final route = _dialog;
    _dialog = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
    });
  }

  @override
  void didUpdateWidget(SelectedSpeedLaunch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.id != widget.collection.id ||
        oldWidget.factory != widget.factory ||
        oldWidget.vocabularyRepository != widget.vocabularyRepository ||
        (!_launched &&
            (oldWidget.scopeIdentity != widget.scopeIdentity ||
                oldWidget.enabled && !widget.enabled ||
                !setEquals(oldWidget.directions, widget.directions)))) {
      _generation++;
      _closeDialog();
      if (_opening) {
        _opening = false;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => oldWidget.onBusyChanged(false),
        );
      }
    }
  }

  void openMerged() => unawaited(_open());

  Future<void> _open([LearningDirection? chosen]) async {
    final owner = ModalRoute.of(context);
    if (_opening ||
        !widget.enabled ||
        widget.selection.ids.isEmpty ||
        widget.directions.isEmpty ||
        (chosen != null && !widget.directions.contains(chosen)) ||
        owner?.isCurrent != true) {
      return;
    }
    final generation = _generation;
    final busy = widget.onBusyChanged;
    bool current() => mounted && generation == _generation;
    setState(() {
      _opening = true;
      _launchFailed = false;
    });
    busy(true);
    SpeedLearningSession? prepared;
    try {
      int? checkedCount;
      if (widget.recheckCounts) {
        final checking = Completer<void>();
        widget.onPendingWrites?.call(checking.future);
        try {
          await widget.beforeLaunch();
          if (!mounted || !current() || !widget.enabled) return;
          final verified = await widget.loadScope(widget.selection.ids);
          if (!mounted ||
              !current() ||
              !widget.enabled ||
              verified.collection.id != widget.collection.id ||
              verified.orderedIds.isEmpty) {
            return;
          }
          checkedCount = verified.orderedIds.length;
        } finally {
          checking.complete();
        }
      }
      if (!mounted || !current() || owner?.isCurrent != true) return;
      var direction =
          chosen ??
          (widget.directions.length == 1 ? widget.directions.single : null);
      if (direction == null) {
        direction = await showPikoDialog<LearningDirection>(
          context,
          canRestoreFocus: () => current() && owner?.isCurrent == true,
          onRouteCreated: (route) => _dialog = route,
          builder: (dialogContext) => LearningDirectionChoice(
            title: PikoCopyScope.of(
              dialogContext,
            ).text('selectedSpeed.direction'),
            initial: {
              for (final d in widget.directions)
                d:
                    checkedCount ??
                    (widget.eligibleCount > 0
                        ? widget.eligibleCount
                        : widget.selection.ids.length),
            },
            changes: Listenable.merge([
              widget.selection,
              widget.availabilityChanges,
            ]),
            canChoose: () => current() && widget.enabled,
            load: () async {
              final done = Completer<void>();
              widget.onPendingWrites?.call(done.future);
              try {
                await widget.beforeLaunch();
                if (!current() || !widget.enabled) return {};
                final scope = await widget.loadScope(widget.selection.ids);
                if (scope.collection.id != widget.collection.id) {
                  throw StateError('Selection owner changed');
                }
                return {
                  for (final d in widget.directions) d: scope.orderedIds.length,
                };
              } finally {
                done.complete();
              }
            },
            label: (d, count) =>
                PikoCopyScope.of(dialogContext).text('r2.speedDirectionCount', {
                  'direction': reviewDirectionLabel(widget.collection, d),
                  'count': count,
                }),
          ),
        );
        _dialog = null;
      }
      if (!mounted ||
          !current() ||
          direction == null ||
          owner?.isCurrent != true) {
        return;
      }
      final chosenDirection = direction;
      final factory = widget.factory;
      final before = widget.beforeLaunch;
      final load = widget.loadScope;
      final register = widget.onPendingWrites;
      prepared = await showPikoDialog<SpeedLearningSession>(
        context,
        canRestoreFocus: () => current() && owner?.isCurrent == true,
        onRouteCreated: (route) => _dialog = route,
        builder: (_) => _SelectedSetup(
          collection: widget.collection,
          direction: chosenDirection,
          load: () async {
            await before();
            if (!current()) throw StateError('Selection owner changed');
            final scope = await load(widget.selection.ids);
            if (scope.collection.id != widget.collection.id) {
              throw StateError('Selection owner changed');
            }
            return scope;
          },
          prepare: (scope, size) => factory(
            collectionId: scope.collection.id,
            direction: chosenDirection,
            orderedEntryIds: scope.orderedIds,
            poolSize: size,
          ),
          register: register,
        ),
      );
      _dialog = null;
      if (!mounted ||
          !current() ||
          prepared == null ||
          owner?.isCurrent != true) {
        return;
      }
      final session = prepared;
      _launched = true;
      final closed = Navigator.of(context).push<SpeedSessionResult>(
        MaterialPageRoute(
          builder: (_) => SpeedSessionRoute(
            collection: widget.collection,
            session: session,
            vocabularyRepository: widget.vocabularyRepository,
            categoriesRepository: widget.categoriesRepository,
            onPendingWrites: register,
          ),
        ),
      );
      prepared = null; // The route now owns disposal.
      final result = await closed;
      if (current()) {
        if (result != null) widget.onCompleted?.call(result.completedCount);
        widget.onSessionClosed?.call();
      }
    } catch (_) {
      if (current()) setState(() => _launchFailed = true);
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (current() &&
              owner?.isCurrent == true &&
              widget.selection.active &&
              widget.selection.ids.isNotEmpty &&
              _focus.canRequestFocus) {
            _focus.requestFocus();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _closeDialog();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action =
        widget.actionBuilder?.call(
          context,
          widget.enabled &&
                  !_opening &&
                  widget.selection.ids.isNotEmpty &&
                  (widget.eligibleCount > 0 || widget.recheckCounts)
              ? (direction) => unawaited(_open(direction))
              : null,
        ) ??
        PikoButton(
          key: const ValueKey('selected-speed-launch'),
          focusNode: _focus,
          variant: PikoButtonVariant.speed,
          label: PikoCopyScope.of(context).text('selectedSpeed.action', {
            'count': widget.selection.ids.length,
          }),
          onPressed:
              widget.enabled &&
                  !_opening &&
                  widget.directions.isNotEmpty &&
                  widget.selection.ids.isNotEmpty
              ? _open
              : null,
        );
    final copy = PikoCopyScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        action,
        if (_launchFailed) ...[
          Text(copy.text('learn.prepareFailed')),
          PikoButton(
            key: const ValueKey('selected-speed-retry'),
            label: copy.text('action.retry'),
            onPressed: widget.enabled && !_opening
                ? () => unawaited(_open())
                : null,
          ),
        ],
      ],
    );
  }
}

class _SelectedSetup extends StatefulWidget {
  const _SelectedSetup({
    required this.collection,
    required this.direction,
    required this.load,
    required this.prepare,
    this.register,
  });
  final CollectionRecord collection;
  final LearningDirection direction;
  final Future<SelectedSpeedScope> Function() load;
  final Future<SpeedLearningSession> Function(SelectedSpeedScope, int) prepare;
  final ValueChanged<Future<void>>? register;
  @override
  State<_SelectedSetup> createState() => _SelectedSetupState();
}

class _SelectedSetupState extends State<_SelectedSetup> {
  SelectedSpeedScope? _scope;
  bool _busy = false, _failed = false, _changed = false;
  @override
  void initState() {
    super.initState();
    // Draining editors can notify the underlying page; do not do that while
    // the popup route is building its first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _refresh([int? size]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _changed = false;
    });
    final done = Completer<void>();
    widget.register?.call(done.future);
    SpeedLearningSession? prepared;
    bool current() => mounted && ModalRoute.of(context)?.isCurrent == true;
    try {
      final next = await widget.load();
      if (!mounted || !current()) return;
      final changed = _scope != null && !_scope!.sameMembership(next);
      setState(() {
        _scope = next;
        _changed = changed;
      });
      if (size == null || changed || next.orderedIds.isEmpty) return;
      prepared = await widget.prepare(next, size);
      if (!mounted || !current()) return;
      final state = prepared.state;
      if (state == null ||
          state.collectionId != next.collection.id ||
          state.direction != widget.direction ||
          !listEquals(state.entryIds, next.orderedIds)) {
        throw StateError(
          'Selected Speed membership changed during preparation',
        );
      }
      Navigator.of(context).pop(prepared);
      prepared = null;
    } catch (_) {
      if (current()) setState(() => _failed = true);
    } finally {
      if (prepared != null) {
        await prepared.stop();
        prepared.dispose();
      }
      if (mounted) setState(() => _busy = false);
      done.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), scope = _scope;
    return SpeedSetupDialog(
      collection: widget.collection,
      direction: widget.direction,
      eligibleCount: _failed ? 0 : scope?.orderedIds.length ?? 0,
      busy: _busy,
      onStart: (size) => unawaited(_refresh(size)),
      selectionDetails: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy) Text(copy.text('selectedSpeed.checking')),
            if (scope != null) ...[
              Text(
                copy.text('selectedSpeed.included', {
                  'count': scope.orderedIds.length,
                }),
                key: const ValueKey('selected-speed-included'),
              ),
              Text(copy.text('selectedSpeed.hidden', {'count': scope.hidden})),
              Text(
                copy.text('selectedSpeed.inactive', {'count': scope.inactive}),
              ),
              if (scope.missing > 0)
                Text(
                  copy.text('selectedSpeed.missing', {'count': scope.missing}),
                ),
            ],
            if (_changed) Text(copy.text('selectedSpeed.changed')),
            if (_failed)
              Text(
                copy.text('selectedSpeed.failed'),
                style: TextStyle(color: pikoDesign.color('danger')),
              ),
            if (_failed || scope?.orderedIds.isEmpty == true)
              PikoButton(
                key: const ValueKey('selected-speed-retry'),
                label: copy.text('action.retry'),
                onPressed: _busy ? null : () => unawaited(_refresh()),
              ),
            Text(copy.text('selectedSpeed.independent')),
          ],
        ),
      ),
    );
  }
}
