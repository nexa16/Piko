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
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tooltip(
            message: backLabel,
            excludeFromSemantics: true,
            child: PikoButton(
              label: backLabel,
              icon: const PikoIcon(PikoIconName.arrowLeft),
              labelSize: compact
                  ? d.dimension('typography.small')
                  : d.dimension('typography.body'),
              labelWeight: d.weight('components.entryHeader.backWeight'),
              padding: EdgeInsets.zero,
              variant: PikoButtonVariant.ghost,
              onPressed: onBack,
            ),
          ),
          SizedBox(width: d.dimension('components.entryHeader.gap')),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: d.dimension('components.headings.titleMargin'),
              ),
              child: Semantics(
                header: true,
                headingLevel: 1,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    letterSpacing: d.dimension(
                      'components.entryHeader.titleLetterSpacing',
                    ),
                    fontSize: d.dimension(
                      compact
                          ? 'components.entryHeader.compactTitleSize'
                          : 'components.entryHeader.titleSize',
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: d.dimension('components.entryHeader.gap')),
          PikoIconButton(
            icon: const PikoIcon(PikoIconName.check),
            semanticLabel: completionLabel,
            variant: PikoButtonVariant.primary,
            large: true,
            padding: EdgeInsets.all(
              d.dimension('components.entryHeader.actionPadding'),
            ),
            onPressed: onComplete,
          ),
        ],
      );
    },
  );
}
