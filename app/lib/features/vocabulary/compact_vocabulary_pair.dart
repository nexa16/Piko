import 'package:flutter/material.dart';
import '../../ui/piko_theme.dart';

/// The flat two-language role shared by Compact lists and trash previews.
class CompactVocabularyPair extends StatelessWidget {
  const CompactVocabularyPair({
    required this.first,
    required this.second,
    super.key,
  });
  final String first, second;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Tooltip(
          message: first,
          child: Text(
            first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
      SizedBox(width: pikoDesign.dimension('spacing.3')),
      Expanded(
        child: Tooltip(
          message: second,
          child: Text(
            second,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: pikoDesign.color('muted')),
          ),
        ),
      ),
    ],
  );
}
