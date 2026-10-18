import 'package:flutter/material.dart';
import 'piko_interaction_anchor.dart';
import '../piko_theme.dart';

/// A labeled switch also paints correctly inside a decorated PikoCard.
class PikoSwitch extends StatelessWidget {
  const PikoSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => PikoAnchorAction(
    builder: (context) => Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontWeight: pikoDesign.weight('typography.controlWeight'),
          ),
          child: title,
        ),
        subtitle: subtitle == null
            ? null
            : DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.bodySmall,
                child: subtitle!,
              ),
        value: value,
        onChanged: onChanged == null
            ? null
            : (value) {
                PikoAnchorRegion.capture(context);
                onChanged!(value);
              },
      ),
    ),
  );
}
