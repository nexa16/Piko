import 'package:flutter/material.dart';

import '../../data/collections_repository.dart';
import '../piko_theme.dart';

/// Collection data, independent of interface locale. The parent action names
/// the full language pair, so this visual abbreviation is decorative.
class PikoLanguageBadge extends StatelessWidget {
  const PikoLanguageBadge(this.language, {super.key});
  final VocabularyLanguage language;

  @override
  Widget build(BuildContext context) {
    final d = pikoDesign;
    final fontSize = d.dimension('components.languageBadge.fontSize');
    return ExcludeSemantics(
      child: Container(
        constraints: BoxConstraints(
          minWidth: d.dimension('components.languageBadge.size'),
          minHeight: d.dimension('components.languageBadge.size'),
        ),
        decoration: BoxDecoration(
          color: d.color('tint'),
          borderRadius: BorderRadius.circular(
            d.dimension('components.languageBadge.radius'),
          ),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            language.badge,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: d.weight('components.languageBadge.weight'),
              letterSpacing:
                  fontSize *
                  d.dimension('components.languageBadge.letterSpacingEm'),
              color: d.color('primary'),
            ),
          ),
        ),
      ),
    );
  }
}
