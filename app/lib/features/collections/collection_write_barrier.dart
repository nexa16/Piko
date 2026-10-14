import 'dart:async';
import 'package:flutter/foundation.dart';

/// Narrow route coordination: freeze new edits and drain accepted child work.
/// It owns neither repositories nor editor buffers and does not discard drafts.
final class CollectionWriteBarrier extends ChangeNotifier {
  bool _frozen = false;
  bool get frozen => _frozen;
  final _drainers = <Future<void> Function()>{};
  final _accepted = <Future<void>>{};
  void attach(Future<void> Function() drain) => _drainers.add(drain);
  void detach(Future<void> Function() drain) => _drainers.remove(drain);
  void freeze() {
    if (!_frozen) {
      _frozen = true;
      notifyListeners();
    }
  }

  void release() {
    if (_frozen) {
      _frozen = false;
      notifyListeners();
    }
  }

  void track(Future<void> work) {
    final tracked = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _accepted.add(tracked);
    unawaited(tracked.whenComplete(() => _accepted.remove(tracked)));
  }

  Future<void> drain() async {
    // Capture drains before child removal/replacement can detach participants.
    await Future.wait([for (final drain in _drainers.toList()) drain()]);
    while (_accepted.isNotEmpty) {
      await Future.wait(_accepted.toList());
    }
  }

  @override
  void dispose() {
    _drainers.clear();
    super.dispose();
  }
}
