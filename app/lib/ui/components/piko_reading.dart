import 'package:flutter/material.dart';

import '../piko_theme.dart';

/// The decorative reading pose used beside an available normal review action.
class PikoReading extends StatelessWidget {
  const PikoReading({super.key});

  @override
  Widget build(BuildContext context) {
    final size = pikoDesign.dimension('components.collectionReview.mascotSize');
    return ExcludeSemantics(
      child: Image.asset(
        'assets/brand/piko-reading.png',
        key: const ValueKey('piko-reading'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        excludeFromSemantics: true,
      ),
    );
  }
}
