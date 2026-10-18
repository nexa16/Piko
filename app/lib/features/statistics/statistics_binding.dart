import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../core/clock.dart';
import '../../core/learning_day.dart';
import '../../data/statistics_repository.dart';

/// One committed projection shared by Home and Statistics. View choices remain
/// in the page; invalidation never replaces its focus, mode or calendar month.
final class StatisticsBinding extends ChangeNotifier
    with WidgetsBindingObserver {
  StatisticsBinding({
    required this.repository,
    this.clock = const SystemPikoClock(),
    this.calendar = const DeviceLearningDayCalendar(),
    Stream<void>? clockChanges,
    this.onPendingWrites,
  }) {
    _activity = repository.changes.listen((_) => refresh(), onError: _failed);
    _clockChanges = clockChanges?.listen((_) => refresh(), onError: _failed);
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  final StatisticsRepository repository;
  final PikoClock clock;
  final LearningDayCalendar calendar;
  final void Function(Future<void>)? onPendingWrites;
  late final StreamSubscription<void> _activity;
  StreamSubscription<void>? _clockChanges;
  Timer? _boundary;
  int _generation = 0;
  bool _disposed = false, _active = true;
  bool loading = false;
  Object? error;
  StatisticsSnapshot? snapshot;
  bool get ready => snapshot != null && !loading && error == null;

  void refresh() {
    if (_disposed || !_active) return;
    _boundary?.cancel();
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    final work = _load(generation);
    onPendingWrites?.call(work);
  }

  Future<void> _load(int generation) async {
    try {
      final value = await repository.snapshot(at: clock.now().toUtc());
      if (_disposed || generation != _generation) return;
      if (value.today !=
          LearningDay.dateFor(clock.now().toUtc(), calendar: calendar)) {
        // A slow query may straddle 04:00 even without a broadcast. Never publish
        // yesterday as the fresh current snapshot for another whole day.
        refresh();
        return;
      }
      snapshot = value;
      error = null;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
    }
    if (_disposed || generation != _generation) return;
    loading = false;
    // A failed read still retries at the next day boundary.
    final now = clock.now().toUtc();
    final next = LearningDay.nextBoundaryUtc(now, calendar: calendar);
    _boundary = Timer(next.difference(now), refresh);
    notifyListeners();
  }

  void _failed(Object failure) {
    if (_disposed) return;
    _generation++;
    error = failure;
    loading = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      refresh();
    } else {
      _generation++;
      _boundary?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _boundary?.cancel();
    unawaited(_activity.cancel());
    unawaited(_clockChanges?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
