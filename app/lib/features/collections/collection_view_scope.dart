import 'package:flutter/foundation.dart';

/// Session-only view preferences, never persisted as vocabulary/learning data.
final class CollectionViewScope extends ChangeNotifier {
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
        ))
      return;
    _filters = Map.unmodifiable(next);
    notifyListeners();
  }
}

/// The runtime owns one store. Navigation reuses a collection's scope; a new
/// runtime starts empty. Overview must not consult these Detail preferences.
final class CollectionViewScopes {
  final _scopes = <String, CollectionViewScope>{};
  CollectionViewScope forCollection(String id) =>
      _scopes.putIfAbsent(id, CollectionViewScope.new);

  void dispose() {
    for (final scope in _scopes.values) {
      scope.dispose();
    }
    _scopes.clear();
  }
}
