import 'package:flutter/material.dart';
import '../piko_theme.dart';

enum PikoButtonVariant {
  primary,
  ghost,
  dangerGhost,
  dangerOutline,
  gradeIncorrect,
  gradeCorrect,
}

class PikoButton extends StatelessWidget {
  const PikoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = PikoButtonVariant.primary,
    this.focusNode,
    this.minimumSize,
    this.padding,
    this.labelSize,
    this.labelWeight,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final PikoButtonVariant variant;
  final FocusNode? focusNode;
  final Size? minimumSize;
  final EdgeInsetsGeometry? padding;
  final double? labelSize;
  final FontWeight? labelWeight;

  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    final primaryStyle = d.text('components.buttons.variant');
    final primary = variant == PikoButtonVariant.primary;
    final grade =
        variant == PikoButtonVariant.gradeCorrect ||
        variant == PikoButtonVariant.gradeIncorrect;
    final danger =
        variant == PikoButtonVariant.dangerGhost ||
        variant == PikoButtonVariant.dangerOutline ||
        variant == PikoButtonVariant.gradeIncorrect;
    final color = grade || (primary && primaryStyle == 'flat')
        ? d.color('onPrimary')
        : d.color(danger ? 'danger' : 'primary');
    final background = grade
        ? d.color(danger ? 'danger' : 'success')
        : primary
        ? d.color(
            primaryStyle == 'flat'
                ? 'primary'
                : primaryStyle == 'outline'
                ? 'surface'
                : 'tint',
          )
        : Colors.transparent;
    return TextButton(
      onPressed: onPressed,
      focusNode: focusNode,
      style: ButtonStyle(
        animationDuration: PikoTheme.motion(context),
        minimumSize: WidgetStatePropertyAll(
          minimumSize ??
              Size(
                d.dimension('components.buttons.height'),
                d.dimension(
                  grade ? 'controls.largeHeight' : 'components.buttons.height',
                ),
              ),
        ),
        padding: WidgetStatePropertyAll(
          padding ??
              EdgeInsets.symmetric(
                horizontal: d.dimension('components.buttons.padding'),
                vertical: d.dimension('spacing.2'),
              ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              d.dimension('components.buttons.radius'),
            ),
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: labelSize ?? d.dimension('typography.label'),
            fontWeight: labelWeight ?? d.weight('components.buttons.weight'),
          ),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? color.withValues(alpha: d.dimension('states.disabledOpacity'))
              : color,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? background.withValues(
                  alpha: background.a * d.dimension('states.disabledOpacity'),
                )
              : background,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.focused)
                ? d.color('primary')
                : variant == PikoButtonVariant.dangerOutline ||
                      (primary && primaryStyle == 'outline')
                ? color
                : Colors.transparent,
            width: d.dimension(
              s.contains(WidgetState.focused)
                  ? 'states.focusWidth'
                  : 'states.borderWidth',
            ),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            ExcludeSemantics(
              child: IconTheme.merge(
                data: IconThemeData(size: d.dimension('components.icons.size')),
                child: icon!,
              ),
            ),
          if (icon != null && label.isNotEmpty)
            SizedBox(width: d.dimension('spacing.2')),
          if (label.isNotEmpty)
            Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class PikoIconButton extends StatelessWidget {
  const PikoIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.variant = PikoButtonVariant.ghost,
    this.large = false,
    this.padding,
    this.focusNode,
  });
  final Widget icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final PikoButtonVariant variant;
  final bool large;
  final EdgeInsetsGeometry? padding;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    child: Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: ExcludeSemantics(
        child: PikoButton(
          label: '',
          icon: icon,
          onPressed: onPressed,
          focusNode: focusNode,
          variant: variant,
          padding: padding,
          minimumSize: large
              ? Size.square(pikoDesign.dimension('controls.largeHeight'))
              : null,
        ),
      ),
    ),
  );
}
