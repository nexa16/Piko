import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_celebration.dart';
import '../../ui/piko_theme.dart';
import 'learning_session_progress.dart';
import 'metric_label_wrapping.dart';

/// Presentation only: caller owns completion, navigation and immutable counts.
class ReviewSummaryDialog extends StatelessWidget {
  const ReviewSummaryDialog({super.key, required this.progress, this.onClose});
  final LearningSessionProgress progress;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final gap = d.dimension('spacing.6');
    Widget metric(String key, int value, String label) => Semantics(
      key: ValueKey('summary-$key'),
      label: '$value $label',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: d.dimension('components.reviewSummary.metricSize'),
                height: d.dimension(
                  'components.reviewSummary.metricLineHeight',
                ),
                fontWeight: d.weight('typography.titleWeight'),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: d.dimension('spacing.2')),
            Text(
              key == 'first-try' ? keepMetricTailTogether(label) : label,
              style: TextStyle(
                fontSize: d.dimension('typography.label'),
                height: d.dimension('components.reviewSummary.labelLineHeight'),
                color: d.color('muted'),
              ),
            ),
          ],
        ),
      ),
    );
    return PikoDialog(
      purpose: PikoDialogPurpose.summary,
      title: copy.text('summary.title'),
      onClose: onClose,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(copy.text('learn.summaryEncouragement'))),
              SizedBox(
                width: d.dimension('components.collectionReview.mascotGap'),
              ),
              const PikoCelebration(),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: gap),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minimum =
                    MediaQuery.textScalerOf(context).scale(
                      d.dimension('components.reviewSummary.metricSize'),
                    ) *
                    3;
                final width = constraints.maxWidth >= minimum * 2 + gap
                    ? (constraints.maxWidth - gap) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: metric(
                        'completed',
                        progress.completed,
                        copy.text('summary.completed'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: metric(
                        'first-try',
                        progress.firstTryCorrect,
                        copy.text('summary.firstTryCorrect'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
