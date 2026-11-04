import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Android system broadcasts, with resume/boundary refresh on other platforms.
Stream<void> deviceClockChanges({bool? android}) =>
    !(android ?? Platform.isAndroid)
    ? const Stream<void>.empty()
    : const EventChannel(
        'piko/clock_changes',
      ).receiveBroadcastStream().transform<void>(
        StreamTransformer<dynamic, void>.fromHandlers(
          handleData: (_, sink) => sink.add(null),
          handleError: (Object error, StackTrace stack, EventSink<void> sink) {
            if (error is! MissingPluginException) sink.addError(error, stack);
          },
        ),
      );
