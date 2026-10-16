import 'dart:convert';
import '../../data/settings_repository.dart';
import 'collection_view_preferences.dart';
import 'package:flutter/foundation.dart';

/// Persistent presentation preferences with session-only search, filters and expansion.
final class CollectionViewScope extends ChangeNotifier {
  CollectionViewScope({
    this.repository,
    this.collectionId,
    this.registerPending,
  }) {
    if (repository != null) {
      loadView();
    } else {
      viewReady = true;
    }
  }
  final SettingsRepository? repository;
  final String? collectionId;
  final void Function(Future<void>)? registerPending;
  CollectionViewPreferences view = const CollectionViewPreferences();
  final expandedGroups = <String>{};
  bool viewPending = false, viewReady = false, _disposed = false;
  Object? viewError;
  String get _viewKey => 'collectionView:$collectionId';
  Future<void> loadView() async {
    if (repository == null || viewPending) return;
    viewPending = true;
    try {
      final raw = await repository!.read(_viewKey);
      if (_disposed) return;
      if (raw != null) {
        view = CollectionViewPreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
      viewReady = true;
      viewError = null;
    } catch (e) {
      if (!_disposed) viewError = e;
    } finally {
      if (!_disposed) {
        viewPending = false;
        notifyListeners();
      }
    }
  }

  Future<void> saveView(CollectionViewPreferences next) {
    if (viewPending || _disposed) return Future.value();
    viewPending = true;
    viewError = null;
    notifyListeners();
    final work = _saveView(next);
    registerPending?.call(work);
    return work;
  }

  Future<void> _saveView(CollectionViewPreferences next) async {
    try {
      if (repository != null) {
        await repository!.write(_viewKey, jsonEncode(next.toJson()));
      }
      if (_disposed) return;
      if (view.grouping != next.grouping) expandedGroups.clear();
      view = next;
      viewReady = true;
    } catch (e) {
      if (!_disposed) viewError = e;
    } finally {
      if (!_disposed) {
        viewPending = false;
        notifyListeners();
      }
    }
  }

  void expandGroups(Iterable<String> ids, bool expand) {
    if (expand) {
      expandedGroups.addAll(ids);
    } else {
      expandedGroups.removeAll(ids);
    }
    notifyListeners();
  }

  void resetExpansion() {
    expandedGroups.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _search = '';
  Map<String, Set<String>> _filters = const {};
  String get search => _search;
  Map<String, Set<String>> get filters => _filters;
  bool get restricted => _search.trim().isNotEmpty || _filters.isNotEmpty;

  void setSearch(String value) {
    if (value == _search) return;
    _search = value;
    notifyListeners();
  }

  void setFilters(Map<String, Set<String>> value) {
    final next = <String, Set<String>>{
      for (final entry in value.entries)
        if (entry.value.isNotEmpty) entry.key: Set.unmodifiable(entry.value),
    };
    if (next.length == _filters.length &&
        next.entries.every(
          (entry) => setEquals(entry.value, _filters[entry.key]),
        )) {
      return;
    }
    _filters = Map.unmodifiable(next);
    notifyListeners();
  }
}

/// The runtime owns one store. Navigation reuses a collection's scope; a new
/// runtime starts empty. Overview must not consult these Detail preferences.
final class CollectionViewScopes {
  CollectionViewScopes({this.repository, this.registerPending});
  final SettingsRepository? repository;
  final void Function(Future<void>)? registerPending;
  final _scopes = <String, CollectionViewScope>{};
  CollectionViewScope forCollection(String id) => _scopes.putIfAbsent(
    id,
    () => CollectionViewScope(
      repository: repository,
      collectionId: id,
      registerPending: registerPending,
    ),
  );

  void dispose() {
    for (final scope in _scopes.values) {
      scope.dispose();
    }
    _scopes.clear();
  }
}
