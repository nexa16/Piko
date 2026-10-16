import 'collection_view_preferences.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../core/clock.dart';
import '../../data/collection_query.dart';
import 'collection_view_scope.dart';

/// Runtime-owned, session-scoped Detail projection. One successful snapshot
/// supplies rows, category labels, Review, Speed and decorative availability.
final class CollectionQueryBinding extends ChangeNotifier
    with WidgetsBindingObserver {
  CollectionQueryBinding({
    required this.collectionId,
    required this.service,
    required this.scope,
    required Stream<void> invalidations,
    this.clock = const SystemPikoClock(),
    this.onPendingWrites,
  }) {
    scope.addListener(_scopeChanged);
    _subscription = invalidations.listen(
      (_) => refresh(),
      onError: (Object failure) {
        if (_disposed) return;
        _generation++;
        _timer?.cancel();
        error = failure;
        loading = false;
        notifyListeners();
      },
    );
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }
  final String collectionId;
  final CollectionQueryService service;
  final CollectionViewScope scope;
  final PikoClock clock;
  final void Function(Future<void>)? onPendingWrites;
  late final StreamSubscription<void> _subscription;
  CollectionQuerySnapshot? snapshot;
  Object? error;
  bool loading = false, _disposed = false, _active = true;
  int _generation = 0;
  Timer? _timer;
  bool get ready => !loading && error == null && snapshot != null;

  String _lastSearch = '';
  Map<String, Set<String>>? _lastFilters;
  void _scopeChanged() {
    if (_lastSearch != scope.search ||
        !identical(_lastFilters, scope.filters)) {
      refresh();
    } else if (!_disposed) {
      final view = scope.view;
      if (ready &&
          scope.viewReady &&
          !scope.viewPending &&
          view.grouping != null &&
          !snapshot!.categoryDimensions.any((d) => d.id == view.grouping)) {
        unawaited(
          scope.saveView(
            CollectionViewPreferences(
              mode: view.mode,
              targetFirst: view.targetFirst,
              sort: view.sort,
            ),
          ),
        );
      }
      notifyListeners();
    }
  }

  void refresh() {
    _lastSearch = scope.search;
    _lastFilters = scope.filters;
    if (_disposed || !_active) return;
    _timer?.cancel();
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    final work = _load(generation);
    onPendingWrites?.call(work);
  }

  Future<void> _load(int generation) async {
    try {
      final value = await service.query(
        collectionId: collectionId,
        at: clock.now().toUtc(),
        search: scope.search,
        filters: scope.filters,
      );
      if (!_current(generation)) return;
      snapshot = value;
      final view = scope.view;
      if (view.grouping != null &&
          !value.categoryDimensions.any((d) => d.id == view.grouping) &&
          !scope.viewPending) {
        unawaited(
          scope.saveView(
            CollectionViewPreferences(
              mode: view.mode,
              targetFirst: view.targetFirst,
              sort: view.sort,
            ),
          ),
        );
      }
      final boundary = value.nextChangeAt;
      if (boundary != null) {
        final delay = boundary.difference(clock.now().toUtc());
        _timer = Timer(delay.isNegative ? Duration.zero : delay, refresh);
      }
    } catch (failure) {
      if (!_current(generation)) return;
      if (failure == CollectionQueryFailure.invalidFilter) {
        try {
          final all = await service.query(
            collectionId: collectionId,
            at: clock.now().toUtc(),
          );
          if (!_current(generation)) return;
          final valid = {
            for (final group in scope.filters.entries)
              if (all.categoryValues.containsKey(group.key))
                group.key: group.value.intersection(
                  all.categoryValues[group.key]!
                      .map((value) => value.id)
                      .toSet(),
                ),
          };
          final before = scope.filters;
          scope.setFilters(valid);
          if (!identical(before, scope.filters)) return;
        } catch (reloadFailure) {
          if (!_current(generation)) return;
          error = reloadFailure;
        }
      }
      error ??= failure;
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _current(int generation) =>
      !_disposed && _active && generation == _generation;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      refresh();
    } else {
      _generation++;
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    scope.removeListener(_scopeChanged);
    _subscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
