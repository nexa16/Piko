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
      final d = pikoDesign;
      final titleStyle = Theme.of(context).textTheme.titleLarge!;
      final controlStyle = Theme.of(context).textTheme.labelLarge!;
      final backPainter = TextPainter(
        text: TextSpan(text: backLabel, style: controlStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final completionPainter = TextPainter(
        text: TextSpan(text: completionLabel, style: controlStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final available =
          constraints.maxWidth -
          backPainter.width -
          d.dimension('components.icons.size') -
          d.dimension('spacing.2') -
          completionPainter.width -
          d.dimension('components.buttons.padding') * 2 -
          2 * d.dimension('components.entryHeader.gap');
      backPainter.dispose();
      completionPainter.dispose();
      final titlePainter = TextPainter(
        text: TextSpan(text: title, style: titleStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final stacked = titlePainter.width > available;
      titlePainter.dispose();
      final back = Tooltip(
        message: backLabel,
        excludeFromSemantics: true,
        child: PikoButton(
          label: backLabel,
          icon: const PikoIcon(PikoIconName.arrowLeft),
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
      final completion = Tooltip(
        message: completionLabel,
        excludeFromSemantics: true,
        child: PikoButton(
          label: completionLabel,
          variant: PikoButtonVariant.primary,
          onPressed: onComplete,
        ),
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Align(alignment: Alignment.centerLeft, child: back),
                ),
                SizedBox(width: d.dimension('spacing.2')),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: completion,
                  ),
                ),
              ],
            ),
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
