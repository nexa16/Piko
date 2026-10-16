import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/piko_theme.dart';
import 'learning_session_progress.dart';
import 'learning_progress_bar.dart';

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
          Column(
            key: const ValueKey('review-context'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(direction, key: const ValueKey('review-fixed-direction')),
              SizedBox(height: d.dimension('spacing.2')),
              Semantics(
                key: const ValueKey('review-counters'),
                label: description,
                excludeSemantics: true,
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodySmall!,
                  child: Wrap(
                    spacing: d.dimension('spacing.4'),
                    runSpacing: d.dimension('spacing.2'),
                    children: [
                      Text(
                        copy.text('learn.completedGroup', {
                          'completed': progress.completed,
                          'total': progress.total,
                        }),
                        key: const ValueKey('review-completed-group'),
                      ),
                      Text(
                        copy.text('learn.firstTryGroup', {
                          'correct': progress.firstTryCorrect,
                        }),
                        key: const ValueKey('review-first-try-group'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: d.dimension('components.progress.marginY'),
            ),
            child: LearningProgressBar(
              key: const ValueKey('review-progress'),
              fillKey: const ValueKey('review-progress-fill'),
              label: '${copy.text('learn.progressLabel')} · $description',
              completed: progress.completed,
              total: progress.total,
            ),
          ),
        ],
      ),
    );
  }
}
