import '../../ui/components/piko_switch.dart';
import '../../ui/components/piko_button.dart';
import 'package:flutter/material.dart';
import '../../data/vocabulary_content.dart';
import '../../shared/copy_scope.dart';
import '../../data/vocabulary_repository.dart';
import 'vocabulary_disclosure.dart';
import 'hint_default_offer.dart';
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
    this.preferences,
    this.collectionId,
    this.error,
    this.onPendingWrites,
    super.key,
  });
  final VocabularyContent value;
  final String targetLanguage, nativeLanguage;
  final bool makeDefault, enabled;
  final void Function(VocabularyContent, bool) onChanged;
  final VoidCallback? onFocus;
  final CollectionHintPreferences? preferences;
  final String? collectionId;
  final Object? error;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<VocabularyContentEditor> createState() =>
      _VocabularyContentEditorState();
}

class _VocabularyContentEditorState extends State<VocabularyContentEditor> {
  bool offerPending = false, offerFailed = false;
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
        VocabularyDisclosure(
          controlKey: const ValueKey('content-examples-toggle'),
          label:
              widget.value.examples
                  .where(
                    (p) => p.targetText.isNotEmpty || p.nativeText.isNotEmpty,
                  )
                  .isEmpty
              ? copy.text('vocab.addExamples')
              : copy.text(
                  widget.value.examples.length == 1
                      ? 'vocab.oneExample'
                      : 'vocab.examplesCount',
                  {'count': widget.value.examples.length},
                ),
          error:
              widget.error == VocabularyContentValidation.examplePairRequired ||
              widget.error == VocabularyContentValidation.exampleTooLong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < pairs.length; i++) ...[
                field(
                  i == 0
                      ? 'content-example-target'
                      : 'content-example-target-$i',
                  copy.text('vocab.exampleTarget', {
                    'language': widget.targetLanguage,
                  }),
                  pairs[i].$1,
                ),
                SizedBox(height: gap),
                field(
                  i == 0
                      ? 'content-example-native'
                      : 'content-example-native-$i',
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
            ],
          ),
        ),
        VocabularyDisclosure(
          controlKey: const ValueKey('content-hint-toggle'),
          label: (widget.value.hintText?.isNotEmpty ?? false)
              ? '${copy.text('vocab.hint')}: ${widget.value.hintText!.replaceAll('\n', ' ').characters.take(48)} · ${copy.text(widget.value.hintVisibility == HintVisibility.always ? 'vocab.hintAlways' : 'vocab.hintHidden')}'
              : copy.text('vocab.addHint'),
          error: widget.error == VocabularyContentValidation.hintTooLong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field('content-hint', copy.text('vocab.hint'), hint),
              SizedBox(height: gap),
              PikoSwitch(
                key: const ValueKey('content-hint-automatic'),

                title: Text(copy.text('vocab.hintAutomatic')),
                subtitle: Text(copy.text('vocab.hintTapHelper')),
                value: widget.value.hintVisibility == HintVisibility.always,
                onChanged: widget.enabled
                    ? (value) {
                        final wasHidden =
                            widget.value.hintVisibility ==
                            HintVisibility.hidden;
                        publish(
                          visibility: value
                              ? HintVisibility.always
                              : HintVisibility.hidden,
                          makeDefault: false,
                        );
                        if (value && wasHidden) offer();
                      }
                    : null,
              ),
              if (offerFailed) ...[
                Text(copy.text('vocab.hintDefaultFailed')),
                PikoButton(
                  label: copy.text('action.retry'),
                  onPressed: offerPending ? null : retryDismissal,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> offer() async {
    if (offerPending ||
        widget.preferences == null ||
        widget.collectionId == null) {
      return;
    }
    offerPending = true;
    final operation = offerCollectionHintDefault(
      context,
      widget.preferences!,
      widget.collectionId!,
    );
    widget.onPendingWrites?.call(operation);
    try {
      await operation;
    } catch (_) {
      if (mounted) setState(() => offerFailed = true);
    } finally {
      offerPending = false;
    }
  }

  Future<void> retryDismissal() async {
    if (offerPending) return;
    offerPending = true;
    final operation = widget.preferences!.completeHintDefaultOffer(
      widget.collectionId!,
      accept: false,
    );
    widget.onPendingWrites?.call(operation);
    try {
      await operation;
      if (mounted) setState(() => offerFailed = false);
    } catch (_) {
      /* Keep the visible retry. */
    } finally {
      offerPending = false;
    }
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
