import 'package:flutter/foundation.dart';

/// Transient UUID ownership only. Never writes vocabulary, preferences or learning.
class VocabularySelection extends ChangeNotifier {
  final _ids = <String>{};
  bool _active = false;
  bool get active => _active;
  Set<String> get ids => Set.unmodifiable(_ids);
  bool contains(String id) => _ids.contains(id);
  void toggle(String id) {
    _active = true;
    if (!_ids.add(id)) _ids.remove(id);
    notifyListeners();
  }

  void selectAll(Iterable<String> matching) {
    _active = true;
    _ids.addAll(matching);
    notifyListeners();
  }

  void clear() {
    if (!active && _ids.isEmpty) return;
    _active = false;
    _ids.clear();
    notifyListeners();
  }

  int hidden(Iterable<String> matching) =>
      _ids.difference(matching.toSet()).length;
}
