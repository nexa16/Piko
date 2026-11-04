import 'package:flutter/material.dart';
import '../../ui/piko_theme.dart';

/// Compact list language text wraps completely; recovery previews stay bounded.
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
        maxLines: _preview ? 1 : null,
        overflow: _preview ? TextOverflow.ellipsis : TextOverflow.visible,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: secondary ? pikoDesign.color('muted') : null,
        ),
      );
      // Editable rows own tap-to-edit and long-press-to-select. A tooltip's
      // recognizer here would steal selection when pressing either language.
      return _preview ? Tooltip(message: value, child: label) : label;
    }

    if (_preview) {
      return Row(
        children: [
          Expanded(child: text(first)),
          SizedBox(width: pikoDesign.dimension('spacing.3')),
          Expanded(child: text(second, secondary: true)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [text(first), text(second, secondary: true)],
    );
  }
}
