import 'package:flutter/material.dart';
import '../../ui/piko_theme.dart';

/// The flat two-language role shared by Compact lists and trash previews.
class CompactVocabularyPair extends StatelessWidget {
  const CompactVocabularyPair({
    required this.first,
    required this.second,
    super.key,
  }) : _preview = false;

  /// Read-only recovery previews have no editor or selection gesture owner.
  const CompactVocabularyPair.preview({
    required this.first,
    required this.second,
    super.key,
  }) : _preview = true;
  final String first, second;
  final bool _preview;

  @override
  Widget build(BuildContext context) {
    Widget text(String value, {bool secondary = false}) {
      final label = Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: secondary ? pikoDesign.color('muted') : null,
        ),
      );
      // Editable rows own tap-to-edit and long-press-to-select. A tooltip's
      // recognizer here would steal selection when pressing either language.
      return _preview ? Tooltip(message: value, child: label) : label;
    }

    return Row(
      children: [
        Expanded(child: text(first)),
        SizedBox(width: pikoDesign.dimension('spacing.3')),
        Expanded(child: text(second, secondary: true)),
      ],
    );
  }
}
