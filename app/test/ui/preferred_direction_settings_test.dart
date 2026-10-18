import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/settings/preferred_direction_control.dart';
import 'package:piko/features/settings/preferred_direction_controller.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_preference_picker.dart';
import '../features/preferred_direction_controller_test.dart'
    show HeldDirectionSettings;

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language preference hydrates, disables during saving, rolls back, and retries',
      (tester) async {
        final repository = HeldDirectionSettings('targetToNative');
        final controller = PreferredDirectionController(
          repository: repository,
          registerPending: (_) {},
        );
        final binding = ValueNotifier<PreferredDirectionController?>(
          controller,
        );
        addTearDown(() {
          binding.dispose();
          controller.dispose();
        });
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(language),
            home: Scaffold(body: PreferredDirectionControl(binding: binding)),
          ),
        );
        expect(
          find.byType(PikoPreferencePicker<PreferredDirection>),
          findsNothing,
        );
        await controller.load();
        await tester.pumpAndSettle();
        final copy = PikoCopy(language);
        final field = find.byType(PikoPreferencePicker<PreferredDirection>);
        expect(
          tester.widget<PikoPreferencePicker<PreferredDirection>>(field).value,
          PreferredDirection.targetToNative,
        );
        repository.writeGate = Completer<void>();
        repository.failWrite = true;
        final callback = tester
            .widget<PikoPreferencePicker<PreferredDirection>>(field)
            .onChanged!;
        callback(PreferredDirection.both);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<PikoPreferencePicker<PreferredDirection>>(field)
              .onChanged,
          isNull,
        );
        callback(PreferredDirection.nativeToTarget);
        expect(repository.writes, hasLength(1));
        repository.writeGate!.complete();
        await controller.awaitPending;
        await tester.pumpAndSettle();
        expect(
          find.text(copy.text('settings.directionSaveFailed')),
          findsOneWidget,
        );
        expect(
          tester.widget<PikoPreferencePicker<PreferredDirection>>(field).value,
          PreferredDirection.targetToNative,
        );
        repository.failWrite = false;
        await tester.tap(find.text(copy.text('action.retry')));
        await tester.pumpAndSettle();
        expect(controller.value, PreferredDirection.both);
        expect(repository.stored, 'both');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('replaced controller rejects a retained settings callback', (
    tester,
  ) async {
    final firstRepository = HeldDirectionSettings('both');
    final secondRepository = HeldDirectionSettings('targetToNative');
    final first = PreferredDirectionController(
      repository: firstRepository,
      registerPending: (_) {},
    );
    final second = PreferredDirectionController(
      repository: secondRepository,
      registerPending: (_) {},
    );
    final binding = ValueNotifier<PreferredDirectionController?>(first);
    addTearDown(() {
      binding.dispose();
      first.dispose();
      second.dispose();
    });
    await first.load();
    await second.load();
    await tester.pumpWidget(
      PikoApp(
        home: Scaffold(body: PreferredDirectionControl(binding: binding)),
      ),
    );
    final stale = tester
        .widget<PikoPreferencePicker<PreferredDirection>>(
          find.byType(PikoPreferencePicker<PreferredDirection>),
        )
        .onChanged!;
    binding.value = second;
    await tester.pumpAndSettle();
    stale(PreferredDirection.nativeToTarget);
    await tester.pumpAndSettle();
    expect(firstRepository.writes, isEmpty);
    expect(secondRepository.writes, isEmpty);
    expect(second.value, PreferredDirection.targetToNative);
  });
}
