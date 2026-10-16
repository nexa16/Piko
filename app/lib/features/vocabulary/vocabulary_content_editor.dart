import '../../ui/components/piko_button.dart';
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

/// Ordered optional pairs and one Hint. Text buffers stay raw while repository
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
  final pairs = <(TextEditingController, TextEditingController)>[];
  late final hint = TextEditingController(text: widget.value.hintText ?? '');
  @override
  void initState() {
    super.initState();
    syncPairs();
  }

  void syncPairs() {
    final values = widget.value.examples.isEmpty
        ? [const ExamplePair(targetText: '', nativeText: '')]
        : widget.value.examples;
    while (pairs.length < values.length) {
      pairs.add((TextEditingController(), TextEditingController()));
    }
    while (pairs.length > values.length) {
      final removed = pairs.removeLast();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        removed.$1.dispose();
        removed.$2.dispose();
      });
    }
    for (var i = 0; i < values.length; i++) {
      for (final field in [
        (pairs[i].$1, values[i].targetText),
        (pairs[i].$2, values[i].nativeText),
      ]) {
        if (field.$1.text != field.$2) field.$1.text = field.$2;
      }
    }
  }

  @override
  void didUpdateWidget(VocabularyContentEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncPairs();
    if (hint.text != (widget.value.hintText ?? '')) {
      hint.text = widget.value.hintText ?? '';
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
        examples: [
          for (final pair in pairs)
            ExamplePair(targetText: pair.$1.text, nativeText: pair.$2.text),
        ],
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
          copy.text('vocab.examples'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: gap),
        for (var i = 0; i < pairs.length; i++) ...[
          field(
            i == 0 ? 'content-example-target' : 'content-example-target-$i',
            copy.text('vocab.exampleTarget', {
              'language': widget.targetLanguage,
            }),
            pairs[i].$1,
          ),
          SizedBox(height: gap),
          field(
            i == 0 ? 'content-example-native' : 'content-example-native-$i',
            copy.text('vocab.exampleTarget', {
              'language': widget.nativeLanguage,
            }),
            pairs[i].$2,
          ),
          PikoButton(
            label: copy.text('vocab.removeExample', {'number': i + 1}),
            variant: PikoButtonVariant.ghost,
            onPressed: widget.enabled
                ? () {
                    final removed = pairs.removeAt(i);
                    if (pairs.isEmpty) {
                      pairs.add((
                        TextEditingController(),
                        TextEditingController(),
                      ));
                    }
                    publish();
                    setState(() {});
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      removed.$1.dispose();
                      removed.$2.dispose();
                    });
                  }
                : null,
          ),
          SizedBox(height: gap),
        ],
        PikoButton(
          label: copy.text('vocab.addExample'),
          onPressed: widget.enabled
              ? () {
                  setState(
                    () => pairs.add((
                      TextEditingController(),
                      TextEditingController(),
                    )),
                  );
                  publish();
                }
              : null,
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
    for (final pair in pairs) {
      pair.$1.dispose();
      pair.$2.dispose();
    }
    hint.dispose();
    super.dispose();
  }
}
