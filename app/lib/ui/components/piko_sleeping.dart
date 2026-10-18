import 'package:flutter/material.dart';

import '../piko_theme.dart';

/// Decoration for a resolved Collection scope with no current learning work.
class PikoSleeping extends StatelessWidget {
  const PikoSleeping({super.key});

  @override
  Widget build(BuildContext context) {
    final size = pikoDesign.dimension('components.collectionReview.mascotSize');
    return ExcludeSemantics(
      child: Image.asset(
        'assets/brand/piko-sleeping.png',
        key: const ValueKey('piko-sleeping'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        excludeFromSemantics: true,
      ),
    );
  }
}
