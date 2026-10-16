import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/preferred_direction.dart';
import '../../data/settings_repository.dart';

/// Runtime owns hydration, pending-write registration and disposal. Selecting a
/// preference writes settings only; launch directions and learning are separate.
final class PreferredDirectionController extends ChangeNotifier
    implements ValueListenable<PreferredDirection> {
  PreferredDirectionController({
    required this.repository,
    required this.registerPending,
  });
  final SettingsRepository repository;
  final ValueChanged<Future<void>> registerPending;
  @override
  PreferredDirection get value => _value;
  PreferredDirection _value = PreferredDirection.nativeToTarget;
  PreferredDirection _committed = PreferredDirection.nativeToTarget;
  PreferredDirection? _retry;
  bool ready = false, pending = false, _disposed = false;
  int _notifying = 0;
  Object? error;
  Future<void> _drain = Future<void>.value();
  Future<void> get awaitPending => _drain;
  bool get canSelect => !_disposed && ready && !pending;

  void _changed() {
    if (_disposed) return;
    _notifying++;
    try {
      notifyListeners();
    } finally {
      _notifying--;
    }
  }

  Future<void> load({Future<void>? after}) => _run(() async {
    await after;
    final stored = await repository.read(PreferredDirection.settingKey);
    if (_disposed) return;
    _committed = PreferredDirection.fromStored(stored);
    _value = _committed;
    ready = true;
    _retry = null;
  });

  Future<void> select(PreferredDirection requested) {
    if (!canSelect) return Future<void>.value();
    if (requested == _committed && requested == _value && error == null) {
      return Future<void>.value();
    }
    _retry = requested;
    return _run(() async {
      if (!_disposed) {
        _value = requested;
        _changed();
      }
      await repository.write(PreferredDirection.settingKey, requested.name);
      _committed = requested;
      _retry = null;
    }, rollback: true);
  }

  Future<void> retry() => ready && _retry != null ? select(_retry!) : load();

  Future<void> _run(
    Future<void> Function() operation, {
    bool rollback = false,
  }) {
    if (_disposed || pending) return Future<void>.value();
    final done = Completer<void>();
    _drain = done.future;
    pending = true;
    error = null;
    try {
      registerPending(done.future);
    } catch (failure) {
      pending = false;
      error = failure;
      done.complete();
      _changed();
      return done.future;
    }
    _changed();
    unawaited(() async {
      try {
        await operation();
      } catch (failure) {
        if (!_disposed) {
          error = failure;
          if (rollback) _value = _committed;
        }
      } finally {
        pending = false;
        _changed();
        done.complete();
      }
    }());
    return done.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_notifying > 0) {
      scheduleMicrotask(super.dispose);
    } else {
      super.dispose();
    }
  }
}
