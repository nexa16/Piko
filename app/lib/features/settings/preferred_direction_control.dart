import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/preferred_direction.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_preference_picker.dart';
import '../../ui/components/piko_form.dart';
import 'preferred_direction_controller.dart';

class PreferredDirectionControl extends StatelessWidget {
  const PreferredDirectionControl({required this.binding, super.key});
  final ValueListenable<PreferredDirectionController?> binding;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: binding,
    builder: (context, controller, _) {
      if (controller == null) return const SizedBox.shrink();
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final copy = PikoCopyScope.of(context);
          bool current() =>
              context.mounted &&
              ModalRoute.of(context)?.isCurrent == true &&
              identical(binding.value, controller) &&
              controller.canSelect;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!controller.ready)
                PikoFormFieldRow(
                  child: Text(
                    copy.text(
                      controller.error == null
                          ? 'settings.loading'
                          : 'settings.directionLoadFailed',
                    ),
                  ),
                ),
              if (controller.ready)
                PikoPreferencePicker<PreferredDirection>(
                  key: const ValueKey('settings-preferred-direction'),
                  label: copy.text('settings.preferredDirection'),
                  value: controller.value,
                  choices: [
                    for (final direction in PreferredDirection.values)
                      (
                        direction,
                        copy.text(switch (direction) {
                          PreferredDirection.targetToNative =>
                            'settings.directionTargetToNative',
                          PreferredDirection.nativeToTarget =>
                            'settings.directionNativeToTarget',
                          PreferredDirection.both => 'settings.directionBoth',
                        }),
                      ),
                  ],
                  onChanged: controller.canSelect
                      ? (selected) {
                          if (current()) controller.select(selected);
                        }
                      : null,
                ),
              if (controller.pending || controller.error != null)
                PikoFormFieldRow(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controller.pending)
                        Text(copy.text('settings.saving')),
                      if (controller.error != null) ...[
                        if (controller.ready)
                          Text(copy.text('settings.directionSaveFailed')),
                        PikoButton(
                          label: copy.text('action.retry'),
                          onPressed: controller.pending
                              ? null
                              : () {
                                  if (context.mounted &&
                                      ModalRoute.of(context)?.isCurrent ==
                                          true &&
                                      identical(binding.value, controller) &&
                                      !controller.pending) {
                                    controller.retry();
                                  }
                                },
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}
