import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../data/settings_repository.dart';
import '../../shared/interface_locale.dart';

/// Runtime-owned persistence binding; the interface controller stays app-owned.
final class AppLanguageController extends ChangeNotifier {
  AppLanguageController({
    required this.repository,
    required this.locale,
    required this.registerPending,
  });
  final SettingsRepository repository;
  final InterfaceLocaleController locale;
  final ValueChanged<Future<void>> registerPending;
  bool ready = false;
  bool pending = false;
  bool _disposed = false;
  int _notifying = 0;
  Object? error;
  Locale _committed = const Locale('en');
  Locale? _retry;
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
    final stored = await repository.read('locale');
    if (_disposed) return;
    _committed = stored == 'de' ? const Locale('de') : const Locale('en');
    locale.value = _committed;
    ready = true;
    _retry = null;
  });

  Future<void> select(Locale requested) {
    if (!canSelect) return Future<void>.value();
    final selected = InterfaceLocaleController.resolve(requested);
    if (selected == _committed && selected == locale.value && error == null) {
      return Future<void>.value();
    }
    _retry = selected;
    return _run(() async {
      // Lifetime registration has succeeded before optimistic UI or storage.
      if (!_disposed) locale.value = selected;
      await repository.write('locale', selected.languageCode);
      _committed = selected;
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
          if (rollback) locale.value = _committed;
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
