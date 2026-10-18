import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/platform/device_clock_changes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'idle clock stream cancels its Android subscription without waiting for another broadcast',
    () async {
      final calls = <String>[];
      const channel = MethodChannel('piko/clock_changes');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      try {
        final stream = deviceClockChanges().listen((_) {});
        await Future<void>.delayed(Duration.zero);
        expect(calls, ['listen']);
        await stream.cancel().timeout(const Duration(seconds: 2));
        expect(calls, ['listen', 'cancel']);
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );
}
