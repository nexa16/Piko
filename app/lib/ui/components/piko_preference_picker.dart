import 'package:flutter/material.dart';
import 'piko_dialog.dart';
import 'piko_form.dart';

/// Immediate preferences choose once and return; no staged Apply semantics.
class PikoPreferencePicker<T extends Object> extends StatelessWidget {
  const PikoPreferencePicker({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    super.key,
  });
  final String label;
  final T value;
  final List<(T, String)> choices;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) => PikoNavigationRow(
    title: label,
    subtitle: choices.where((choice) => choice.$1 == value).firstOrNull?.$2,
    onTap: onChanged == null
        ? null
        : () async {
            if (ModalRoute.of(context)?.isCurrent != true) return;
            final selected = await showPikoDialog<T>(
              context,
              builder: (context) => PikoDialog(
                title: label,
                purpose: PikoDialogPurpose.directChoice,
                body: RadioGroup<T>(
                  groupValue: value,
                  onChanged: (choice) {
                    if (choice != null) Navigator.of(context).pop(choice);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final choice in choices)
                        RadioListTile<T>(
                          value: choice.$1,
                          title: Text(choice.$2),
                        ),
                    ],
                  ),
                ),
              ),
            );
            if (context.mounted &&
                ModalRoute.of(context)?.isCurrent == true &&
                selected != null &&
                selected != value) {
              onChanged?.call(selected);
            }
          },
  );
}
