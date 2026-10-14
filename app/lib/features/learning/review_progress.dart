import 'dart:ui' show SemanticsRole;
import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/piko_theme.dart';
import 'learning_session_progress.dart';

/// Binding context and determinate unique-item success, independent of attempts.
class ReviewProgress extends StatelessWidget {
  const ReviewProgress({
    super.key,
    required this.direction,
    required this.progress,
  });
  final String direction;
  final LearningSessionProgress progress;
  @override
  Widget build(BuildContext context) {
    final d = pikoDesign, copy = PikoCopyScope.of(context);
    final compact =
        MediaQuery.sizeOf(context).width <=
        d.dimension('components.reviewContext.compactBreakpoint');
    final description = copy.text('learn.progress', {
      'completed': progress.completed,
      'total': progress.total,
      'correct': progress.firstTryCorrect,
    });
    return Padding(
      padding: EdgeInsets.only(
        top: d.dimension('components.reviewContext.topMargin'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            key: const ValueKey('review-context'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  direction,
                  key: const ValueKey('review-fixed-direction'),
                ),
              ),
              SizedBox(
                width: compact
                    ? d.dimension('spacing.2')
                    : d.dimension('components.reviewContext.gap'),
              ),
              Expanded(
                child: Text(
                  description,
                  key: const ValueKey('review-counters'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: d.color('muted'),
                    fontSize: compact
                        ? d.dimension('components.reviewContext.compactSize')
                        : d.dimension('typography.small'),
                    height: d.dimension('components.reviewContext.lineHeight'),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: d.dimension('components.progress.marginY'),
            ),
            child: Semantics(
              key: const ValueKey('review-progress'),
              role: SemanticsRole.progressBar,
              label: '${copy.text('learn.progressLabel')} · $description',
              value: '${progress.completed}',
              minValue: '0',
              maxValue: '${progress.total}',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    d.dimension('components.progress.radius'),
                  ),
                  child: SizedBox(
                    height: d.dimension('components.progress.height'),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: d.color('tint')),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.fraction,
                          child: ColoredBox(
                            key: const ValueKey('review-progress-fill'),
                            color: d.color('ink'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
