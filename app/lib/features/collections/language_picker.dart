import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/piko_theme.dart';

class LanguagePickerDialog extends StatefulWidget {
  const LanguagePickerDialog({required this.target, super.key});
  final bool target;
  @override
  State<LanguagePickerDialog> createState() => _LanguagePickerDialogState();
}

class _LanguagePickerDialogState extends State<LanguagePickerDialog> {
  final search = TextEditingController(), custom = TextEditingController();
  bool enteringCustom = false;
  String? error;
  @override
  void dispose() {
    search.dispose();
    custom.dispose();
    super.dispose();
  }

  void saveCustom() {
    try {
      final language = VocabularyLanguage.fromName(
        custom.text,
        PikoCopyScope.of(context).locale,
      );
      Navigator.of(context).pop(language);
    } on FormatException {
      setState(
        () => error = languageNameKey(custom.text).isEmpty
            ? 'language.customRequired'
            : 'language.ambiguous',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final all = VocabularyLanguage.values;
    final rest = all.skip(10).toList()
      ..sort(
        (a, b) => a
            .label(copy.locale)
            .toLowerCase()
            .compareTo(b.label(copy.locale).toLowerCase()),
      );
    final sorted = [...all.take(10), ...rest];
    final needle = search.text.trim().toLowerCase();
    final matches = sorted.where(
      (language) =>
          language.label(copy.locale).toLowerCase().contains(needle) ||
          language.code.toLowerCase().contains(needle),
    );
    return PikoDialog(
      key: const ValueKey('language-picker'),
      title: copy.text(
        enteringCustom
            ? 'language.customTitle'
            : widget.target
            ? 'language.chooseTarget'
            : 'language.chooseNative',
      ),
      presentation: PikoDialogPresentation.groupedForm,
      purpose: enteringCustom
          ? PikoDialogPurpose.form
          : PikoDialogPurpose.directChoice,
      onBack: enteringCustom
          ? () => setState(() {
              enteringCustom = false;
              error = null;
            })
          : () => Navigator.of(context).pop(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (enteringCustom) ...[
            PikoFormGroup(
              children: [
                PikoFormFieldRow(
                  child: PikoTextField(
                    label: copy.text('language.customPrompt'),
                    controller: custom,
                    onChanged: (_) => setState(() => error = null),
                    error: error == null ? null : copy.text(error!),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => saveCustom(),
                  ),
                ),
              ],
            ),
          ] else ...[
            PikoFormGroup(
              children: [
                PikoFormFieldRow(
                  child: PikoTextField(
                    label: copy.text('language.search'),
                    controller: search,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            SizedBox(height: pikoDesign.dimension('spacing.4')),
            PikoFormGroup(
              children: [
                PikoNavigationRow(
                  title: copy.text('language.custom'),
                  subtitle: copy.text('language.customDescription'),
                  onTap: () => setState(() {
                    enteringCustom = true;
                    error = null;
                  }),
                ),
              ],
            ),
            SizedBox(height: pikoDesign.dimension('spacing.4')),
            if (matches.isEmpty) Text(copy.text('language.noResults')),
            if (matches.isNotEmpty)
              PikoFormGroup(
                children: [
                  for (final language in matches)
                    PikoNavigationRow(
                      key: ValueKey('language-${language.code}'),
                      title: language.label(copy.locale),
                      onTap: () => Navigator.of(context).pop(language),
                    ),
                ],
              ),
          ],
        ],
      ),
      actions: [
        if (enteringCustom)
          PikoDialogAction(
            label: copy.text('language.customSave'),
            onPressed: saveCustom,
          ),
      ],
    );
  }
}
