import 'package:flutter/material.dart';
import '../piko_theme.dart';

class PikoCard extends StatelessWidget {
  const PikoCard({
    super.key,
    required this.child,
    this.padding,
    this.selected = false,
    this.focused = false,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool selected;
  final bool focused;
  @override
  Widget build(BuildContext context) => Container(
    padding:
        padding ??
        EdgeInsets.all(pikoDesign.dimension('components.cards.padding')),
    decoration: BoxDecoration(
      color: pikoDesign.color('surface'),
      borderRadius: BorderRadius.circular(pikoDesign.dimension('radii.card')),
      border: Border.all(
        color: selected || focused
            ? pikoDesign.color('primary')
            : PikoTheme.border,
        width: pikoDesign.dimension(
          focused ? 'states.focusWidth' : 'states.borderWidth',
        ),
      ),
    ),
    child: child,
  );
}
