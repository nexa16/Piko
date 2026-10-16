import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/data/settings_repository.dart';
import 'package:piko/features/settings/preferred_direction_controller.dart';

class HeldDirectionSettings implements SettingsRepository {
  HeldDirectionSettings(this.stored);
  String? stored;
  Completer<void>? readGate, writeGate;
  bool failRead = false, failWrite = false;
  final writes = <(String, String)>[];
  @override
  Future<String?> read(String key) async {
    expect(key, PreferredDirection.settingKey);
    await readGate?.future;
    if (failRead) throw StateError('read failed');
    return stored;
  }

  @override
  Future<void> write(String key, String value) async {
    writes.add((key, value));
    await writeGate?.future;
    if (failWrite) throw StateError('write failed');
    stored = value;
  }

  @override
  Future<void> remove(String key) async {
    stored = null;
  }
}

void main() {
  for (final stored in [
    null,
    'targetToNative',
    'nativeToTarget',
    'both',
    'unknown',
  ]) {
    test('hydrates $stored without a preference write', () async {
      final repository = HeldDirectionSettings(stored);
      final pending = <Future<void>>[];
      final controller = PreferredDirectionController(
        repository: repository,
        registerPending: pending.add,
      );
      addTearDown(controller.dispose);
      expect(controller.canSelect, isFalse);
      await controller.load();
      expect(controller.ready, isTrue);
      expect(controller.value, PreferredDirection.fromStored(stored));
      expect(repository.writes, isEmpty);
      expect(pending, hasLength(1));
    });
  }

  test(
    'registration precedes optimistic selection; one pending write; failure rolls back and retries',
    () async {
      final repository = HeldDirectionSettings('targetToNative');
      final pending = <Future<void>>[];
      late PreferredDirectionController controller;
      controller = PreferredDirectionController(
        repository: repository,
        registerPending: (work) {
          expect(
            controller.value,
            controller.ready
                ? PreferredDirection.targetToNative
                : PreferredDirection.nativeToTarget,
          );
          pending.add(work);
        },
      );
      addTearDown(controller.dispose);
      await controller.load();
      repository.writeGate = Completer<void>();
      repository.failWrite = true;
      final work = controller.select(PreferredDirection.both);
      expect(controller.value, PreferredDirection.both);
      expect(controller.pending, isTrue);
      await controller.select(PreferredDirection.nativeToTarget);
      expect(repository.writes, [(PreferredDirection.settingKey, 'both')]);
      var drained = false;
      controller.awaitPending.then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      repository.writeGate!.complete();
      await work;
      expect(controller.error, isNotNull);
      expect(controller.value, PreferredDirection.targetToNative);
      expect(repository.stored, 'targetToNative');
      repository.failWrite = false;
      await controller.retry();
      expect(controller.value, PreferredDirection.both);
      expect(repository.stored, 'both');
      expect(controller.error, isNull);
      await Future.wait(pending);
    },
  );

  test(
    'failed hydration retries; disposed hydration cannot select or notify',
    () async {
      final repository = HeldDirectionSettings('both')..failRead = true;
      final controller = PreferredDirectionController(
        repository: repository,
        registerPending: (_) {},
      );
      await controller.load();
      expect(controller.ready, isFalse);
      expect(controller.error, isNotNull);
      repository.failRead = false;
      repository.readGate = Completer<void>();
      final retry = controller.retry();
      controller.dispose();
      repository.readGate!.complete();
      await retry;
      await controller.select(PreferredDirection.targetToNative);
      expect(repository.writes, isEmpty);
      expect(controller.ready, isFalse);
    },
  );

  test(
    'failed pending registration has no optimistic or storage side effect',
    () async {
      final repository = HeldDirectionSettings('both');
      var failRegistration = false;
      final controller = PreferredDirectionController(
        repository: repository,
        registerPending: (_) {
          if (failRegistration) throw StateError('owner closed');
        },
      );
      addTearDown(controller.dispose);
      await controller.load();
      failRegistration = true;
      await controller.select(PreferredDirection.nativeToTarget);
      expect(controller.value, PreferredDirection.both);
      expect(repository.writes, isEmpty);
      expect(controller.error, isNotNull);
    },
  );
}
