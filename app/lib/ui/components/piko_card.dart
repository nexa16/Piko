import 'package:flutter/material.dart';
import '../piko_theme.dart';

class PikoCard extends StatelessWidget {
  const PikoCard({
    super.key,
    required this.child,
    this.padding,
    this.selected = false,
    this.focused = false,
    this.animationDuration,
    this.constraints,
  });
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool selected;
  final bool focused;
  final Duration? animationDuration;
  final BoxConstraints? constraints;
  @override
  Widget build(BuildContext context) {
    final contentPadding =
        padding ??
        EdgeInsets.all(pikoDesign.dimension('components.cards.padding'));
    final decoration = BoxDecoration(
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
    );
    if (animationDuration != null) {
      return AnimatedContainer(
        duration: animationDuration!,
        padding: contentPadding,
        constraints: constraints,
        decoration: decoration,
        child: child,
      );
    }
    return Container(
      padding: contentPadding,
      constraints: constraints,
      decoration: decoration,
      child: child,
    );
  }
}
