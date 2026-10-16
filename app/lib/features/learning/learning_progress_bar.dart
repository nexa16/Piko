import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../ui/piko_theme.dart';

/// Shared painted and accessible determinate progress for learning modes.
class LearningProgressBar extends StatelessWidget {
  const LearningProgressBar({
    required this.completed,
    required this.total,
    required this.label,
    this.fillKey,
    super.key,
  });

  final int completed;
  final int total;
  final String label;
  final Key? fillKey;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Semantics(label: label, child: const SizedBox.shrink());
    }
    final d = pikoDesign;
    return Semantics(
      role: SemanticsRole.progressBar,
      label: label,
      value: '$completed',
      minValue: '0',
      maxValue: '$total',
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
                  widthFactor: total == 0 ? 0 : completed / total,
                  heightFactor: 1,
                  child: ColoredBox(key: fillKey, color: d.color('ink')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
