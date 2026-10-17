import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    ),
  );
}
