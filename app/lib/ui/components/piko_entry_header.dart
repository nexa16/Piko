import 'package:flutter/material.dart';
import '../piko_theme.dart';
import 'piko_button.dart';
import 'piko_icon.dart';

/// Binding entry header: intrinsic Back, centered middle track, final action.
/// Responsive CSS and Flutter consume the same canonical viewport threshold.
class PikoEntryHeader extends StatelessWidget {
  const PikoEntryHeader({
    super.key,
    required this.title,
    required this.backLabel,
    required this.completionLabel,
    required this.onBack,
    required this.onComplete,
  });
  final String title, backLabel, completionLabel;
  final VoidCallback? onBack, onComplete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // CSS responds to the viewport, not the narrower padded content track.
      final d = pikoDesign;
      final compact =
          MediaQuery.sizeOf(context).width <=
          d.dimension('components.entryHeader.compactBreakpoint');
      final titleStyle = Theme.of(context).textTheme.titleLarge!.copyWith(
        letterSpacing: d.dimension('components.entryHeader.titleLetterSpacing'),
        fontSize: d.dimension(
          compact
              ? 'components.entryHeader.compactTitleSize'
              : 'components.entryHeader.titleSize',
        ),
      );
      final backSize = compact
          ? d.dimension('typography.small')
          : d.dimension('typography.body');
      final backPainter = TextPainter(
        text: TextSpan(
          text: backLabel,
          style: TextStyle(
            fontSize: backSize,
            fontWeight: d.weight('components.entryHeader.backWeight'),
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final available =
          constraints.maxWidth -
          backPainter.width -
          d.dimension('components.icons.size') -
          d.dimension('spacing.2') -
          d.dimension('controls.largeHeight') -
          2 * d.dimension('components.entryHeader.gap');
      backPainter.dispose();
      final titlePainter = TextPainter(
        text: TextSpan(text: title, style: titleStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: available > 0 ? available : 1);
      final stacked =
          titlePainter.computeLineMetrics().length >
          d.dimension('components.entryHeader.maxTitleLines');
      titlePainter.dispose();
      final back = Tooltip(
        message: backLabel,
        excludeFromSemantics: true,
        child: PikoButton(
          label: backLabel,
          icon: const PikoIcon(PikoIconName.arrowLeft),
          labelSize: backSize,
          labelWeight: d.weight('components.entryHeader.backWeight'),
          padding: EdgeInsets.zero,
          variant: PikoButtonVariant.ghost,
          onPressed: onBack,
        ),
      );
      final heading = Padding(
        padding: EdgeInsets.symmetric(
          vertical: d.dimension('components.headings.titleMargin'),
        ),
        child: Semantics(
          header: true,
          headingLevel: 1,
          child: Text(title, textAlign: TextAlign.center, style: titleStyle),
        ),
      );
      final completion = PikoIconButton(
        icon: const PikoIcon(PikoIconName.check),
        semanticLabel: completionLabel,
        variant: PikoButtonVariant.primary,
        large: true,
        padding: EdgeInsets.all(
          d.dimension('components.entryHeader.actionPadding'),
        ),
        onPressed: onComplete,
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [back, const Spacer(), completion]),
            heading,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          back,
          SizedBox(width: d.dimension('components.entryHeader.gap')),
          Expanded(child: heading),
          SizedBox(width: d.dimension('components.entryHeader.gap')),
          completion,
        ],
      );
    },
  );
}
