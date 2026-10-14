import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_checkbox.dart';
import 'regular_grading_coordinator.dart';

class HardModifier extends StatelessWidget {
  const HardModifier({
    required this.coordinator,
    required this.handle,
    this.focusNode,
    super.key,
  });
  final RegularGradingCoordinator coordinator;
  final GradingCardHandle handle;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: coordinator,
    builder: (context, _) {
      final current = identical(coordinator.current, handle);
      return PikoCheckbox(
        label: PikoCopyScope.of(context).text('learn.hard'),
        value: current && coordinator.hard,
        selectedColorRole: 'success',
        focusNode: focusNode,
        onChanged:
            current && !coordinator.isSubmitting && coordinator.accepted == null
            ? (selected) => coordinator.setHard(handle, selected)
            : null,
      );
    },
  );
}
