import 'package:flutter/material.dart';
import '../piko_theme.dart';
import 'piko_focus_highlight.dart';

enum PikoButtonVariant {
  primary,
  primaryOutline,
  tint,
  speed,
  reviewPrimary,
  reviewSecondary,
  ghost,
  dangerGhost,
  dangerOutline,
  dangerFilled,
  neutral,
  gradeIncorrect,
  gradeCorrect,
}

class PikoButton extends StatelessWidget {
  const PikoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailing,
    this.variant = PikoButtonVariant.primary,
    this.focusNode,
    this.minimumSize,
    this.padding,
    this.labelSize,
    this.labelWeight,
    this.iconLabelSpacing,
    this.trailingSpacing,
    this.autofocus = false,
    this.expandLabel = false,
    this.labelAlignment = TextAlign.center,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? trailing;
  final PikoButtonVariant variant;
  final FocusNode? focusNode;
  final Size? minimumSize;
  final EdgeInsetsGeometry? padding;
  final double? labelSize;
  final FontWeight? labelWeight;
  final double? iconLabelSpacing;
  final double? trailingSpacing;
  final bool autofocus;
  final bool expandLabel;
  final TextAlign labelAlignment;

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
        variant == PikoButtonVariant.dangerFilled ||
        variant == PikoButtonVariant.gradeIncorrect;
    final color = variant == PikoButtonVariant.speed
        ? d.color('ink')
        : variant == PikoButtonVariant.reviewPrimary
        ? d.color('onPrimary')
        : variant == PikoButtonVariant.reviewSecondary
        ? d.color('onReviewSecondary')
        : grade || variant == PikoButtonVariant.dangerFilled
        ? d.color(danger ? 'onDanger' : 'onSuccess')
        : primary && primaryStyle == 'flat'
        ? d.color('onPrimary')
        : d.color(
            variant == PikoButtonVariant.neutral
                ? 'muted'
                : danger
                ? 'danger'
                : 'primary',
          );
    final background = variant == PikoButtonVariant.speed
        ? d.color('gold')
        : variant == PikoButtonVariant.tint
        ? d.color('tint')
        : variant == PikoButtonVariant.reviewPrimary
        ? d.color('primary')
        : variant == PikoButtonVariant.reviewSecondary
        ? d.color('reviewSecondary')
        : grade || variant == PikoButtonVariant.dangerFilled
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
    return PikoFocusHighlight(
      builder: (context, showFocus) => TextButton(
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        style: ButtonStyle(
          animationDuration: PikoTheme.motion(context),
          minimumSize: WidgetStatePropertyAll(
            minimumSize == null
                ? Size(
                    d.dimension('components.buttons.height'),
                    d.dimension(
                      grade
                          ? 'controls.largeHeight'
                          : 'components.buttons.height',
                    ),
                  )
                : Size(
                    minimumSize!.width
                        .clamp(
                          d.dimension('controls.largeHeight'),
                          double.infinity,
                        )
                        .toDouble(),
                    minimumSize!.height
                        .clamp(
                          d.dimension('controls.largeHeight'),
                          double.infinity,
                        )
                        .toDouble(),
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
            Theme.of(context).textTheme.labelLarge!.copyWith(
              fontSize: labelSize ?? d.dimension('typography.label'),
              fontWeight: labelWeight ?? d.weight('components.buttons.weight'),
            ),
          ),
          // State layers are palette alpha blends; disabled actions have no
          // interactive layer. Keyboard focus also retains its explicit border.
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.transparent;
            }
            final opacity = states.contains(WidgetState.pressed)
                ? d.dimension('states.pressedOpacity')
                : states.contains(WidgetState.focused)
                ? d.dimension('states.focusOpacity')
                : states.contains(WidgetState.hovered)
                ? d.dimension('states.hoverOpacity')
                : 0.0;
            return color.withValues(alpha: opacity);
          }),
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
              color: showFocus && s.contains(WidgetState.focused)
                  ? d.color('primary')
                  : variant == PikoButtonVariant.dangerOutline ||
                        variant == PikoButtonVariant.primaryOutline ||
                        (primary && primaryStyle == 'outline')
                  ? color
                  : Colors.transparent,
              width: d.dimension(
                showFocus && s.contains(WidgetState.focused)
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
                  data: IconThemeData(
                    size: d.dimension('components.icons.size'),
                  ),
                  child: icon!,
                ),
              ),
            if (icon != null && label.isNotEmpty)
              SizedBox(width: iconLabelSpacing ?? d.dimension('spacing.2')),
            if (label.isNotEmpty)
              Flexible(
                fit: expandLabel ? FlexFit.tight : FlexFit.loose,
                child: Text(label, textAlign: labelAlignment),
              ),
            if (trailing != null)
              SizedBox(width: trailingSpacing ?? d.dimension('spacing.2')),
            ?trailing,
          ],
        ),
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
