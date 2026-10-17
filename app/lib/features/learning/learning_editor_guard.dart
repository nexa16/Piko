/// The route drains the currently attached answer editor before leaving.
final class LearningEditorGuard {
  Object? _owner;
  Future<bool> Function()? _close;
  bool get isEditing => _close != null;
  void attach(Object owner, Future<bool> Function() close) {
    _owner = owner;
    _close = close;
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _close = null;
  }

  Future<bool> close() => _close?.call() ?? Future.value(true);
}
