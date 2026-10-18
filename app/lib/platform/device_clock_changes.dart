import 'package:flutter/services.dart';

/// Android system broadcasts, with resume/boundary refresh on other platforms.
Stream<void> deviceClockChanges() async* {
  try {
    await for (final _ in const EventChannel(
      'piko/clock_changes',
    ).receiveBroadcastStream()) {
      yield null;
    }
  } on MissingPluginException {
    // Host tests and platforms without the Android broadcast bridge.
  }
}
