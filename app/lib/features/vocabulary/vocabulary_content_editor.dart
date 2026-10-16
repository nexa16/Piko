import 'package:flutter/material.dart';
import '../../data/vocabulary_content.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_checkbox.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/piko_theme.dart';

String? vocabularyContentErrorKey(Object? error) => switch (error) {
  VocabularyContentValidation.examplePairRequired =>
    'vocab.examplePairRequired',
  VocabularyContentValidation.exampleTooLong => 'vocab.exampleTooLong',
  VocabularyContentValidation.hintTooLong => 'vocab.hintTooLong',
  _ => null,
};

/// One optional pair and one Hint. Text buffers stay raw while repository
/// validation/normalization runs independently; no maxLength silently truncates.
class VocabularyContentEditor extends StatefulWidget {
  const VocabularyContentEditor({
    required this.value,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.makeDefault,
    required this.onChanged,
    this.enabled = true,
    this.onFocus,
    super.key,
  });
  final VocabularyContent value;
  final String targetLanguage, nativeLanguage;
  final bool makeDefault, enabled;
  final void Function(VocabularyContent, bool) onChanged;
  final VoidCallback? onFocus;
  @override
  State<VocabularyContentEditor> createState() =>
      _VocabularyContentEditorState();
}

class _VocabularyContentEditorState extends State<VocabularyContentEditor> {
  late final target = TextEditingController(
    text: widget.value.exampleTargetText ?? '',
  );
  late final native = TextEditingController(
    text: widget.value.exampleNativeText ?? '',
  );
  late final hint = TextEditingController(text: widget.value.hintText ?? '');
  @override
  void didUpdateWidget(VocabularyContentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final pair in [
      (target, widget.value.exampleTargetText ?? ''),
      (native, widget.value.exampleNativeText ?? ''),
      (hint, widget.value.hintText ?? ''),
    ]) {
      if (pair.$1.text != pair.$2) pair.$1.text = pair.$2;
    }
  }

  void publish({HintVisibility? visibility, bool? makeDefault}) {
    if (!mounted ||
        !widget.enabled ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    widget.onChanged(
      VocabularyContent(
        exampleTargetText: target.text,
        exampleNativeText: native.text,
        hintText: hint.text,
        hintVisibility: visibility ?? widget.value.hintVisibility,
      ),
      makeDefault ?? widget.makeDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final gap = pikoDesign.dimension('spacing.3');
    Widget field(String key, String label, TextEditingController controller) =>
        PikoField(
          label: label,
          child: Semantics(
            label: label,
            child: TextField(
              key: ValueKey(key),
              controller: controller,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 4,
              style: Theme.of(context).textTheme.bodyMedium,
              textInputAction: TextInputAction.newline,
              decoration: pikoInputDecoration(),
              onTap: widget.onFocus,
              onChanged: (_) => publish(),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: gap),
        Text(
          copy.text('vocab.examplePair'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: gap),
        field(
          'content-example-target',
          copy.text('vocab.exampleTarget', {'language': widget.targetLanguage}),
          target,
        ),
        SizedBox(height: gap),
        field(
          'content-example-native',
          copy.text('vocab.exampleTarget', {'language': widget.nativeLanguage}),
          native,
        ),
        SizedBox(height: gap),
        field('content-hint', copy.text('vocab.hint'), hint),
        SizedBox(height: gap),
        Text(copy.text('vocab.hintVisibility')),
        RadioGroup<HintVisibility>(
          groupValue: widget.value.hintVisibility,
          onChanged: (value) {
            if (value != null) publish(visibility: value);
          },
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final value in HintVisibility.values)
                  RadioListTile<HintVisibility>(
                    key: ValueKey('content-hint-visibility-${value.name}'),
                    value: value,
                    enabled: widget.enabled,
                    contentPadding: EdgeInsets.zero,
                    selected: widget.value.hintVisibility == value,
                    selectedTileColor: pikoDesign.color('tint'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        pikoDesign.dimension('components.buttons.radius'),
                      ),
                    ),
                    title: Text(
                      copy.text(
                        value == HintVisibility.always
                            ? 'vocab.hintAlways'
                            : 'vocab.hintHidden',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        PikoCheckbox(
          label: copy.text('vocab.makeHintDefault'),
          value: widget.makeDefault,
          onChanged: widget.enabled
              ? (value) => publish(makeDefault: value)
              : null,
        ),
      ],
    );
  }

  @override
  void dispose() {
    target.dispose();
    native.dispose();
    hint.dispose();
    super.dispose();
  }
}
