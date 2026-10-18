import 'package:flutter/material.dart';
import '../piko_theme.dart';

/// Static original artwork. Completion owners decide whether it is truthful;
/// the image contributes no focus target, announcement or learning outcome.
class PikoCelebration extends StatelessWidget {
  const PikoCelebration({super.key});
  @override
  Widget build(BuildContext context) {
    final size = pikoDesign.dimension('components.collectionReview.mascotSize');
    return ExcludeSemantics(
      child: Image.asset(
        'assets/brand/piko-celebration.png',
        key: const ValueKey('piko-celebration'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        excludeFromSemantics: true,
      ),
    );
  }
}
