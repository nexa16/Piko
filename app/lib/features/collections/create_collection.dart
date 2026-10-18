import 'language_picker.dart';
import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/piko_theme.dart';

class CreateCollectionDialog extends StatefulWidget {
  const CreateCollectionDialog({required this.repository, super.key});
  final CollectionsRepository repository;
  @override
  State<CreateCollectionDialog> createState() => _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<CreateCollectionDialog> {
  final name = TextEditingController();
  var target = VocabularyLanguage.korean;
  var native = VocabularyLanguage.german;
  var submitting = false;
  var nameInitialized = false;
  var automaticName = true;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!nameInitialized) {
      name.text = target.label(PikoCopyScope.of(context).locale);
      nameInitialized = true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (submitting) return;
    final route = ModalRoute.of(context);
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final created = await widget.repository.create(
        name: name.text,
        targetLanguage: target,
        nativeLanguage: native,
      );
      if (mounted && route?.isCurrent == true) {
        Navigator.of(context).pop(created);
      }
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        error = switch (failure) {
          CollectionValidation.requiredName => 'collection.requiredName',
          CollectionValidation.sameLanguage => 'collection.sameLanguage',
          _ => 'collection.saveFailed',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    Widget language(String key, VocabularyLanguage value, bool isTarget) =>
        PikoNavigationRow(
          key: ValueKey(key),
          title: copy.text(key),
          subtitle: value.label(copy.locale),
          onTap: submitting
              ? null
              : () async {
                  final selected = await showPikoDialog<VocabularyLanguage>(
                    context,
                    builder: (_) => LanguagePickerDialog(target: isTarget),
                  );
                  if (!mounted || selected == null || submitting) return;
                  setState(() {
                    if (isTarget) {
                      if (target == selected) return;
                      target = selected;
                      if (automaticName) name.text = target.label(copy.locale);
                    } else {
                      native = selected;
                    }
                    error = null;
                  });
                },
        );
    return PikoDialog(
      presentation: PikoDialogPresentation.groupedForm,
      title: copy.text('dialog.newCollection'),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PikoFormGroup(
            children: [
              language('collection.targetLanguage', target, true),
              language('collection.nativeLanguage', native, false),
              PikoFormFieldRow(
                child: PikoTextField(
                  label: copy.text('collection.name'),
                  controller: name,
                  onChanged: (_) => automaticName = false,
                  enabled: !submitting,
                ),
              ),
            ],
          ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                copy.text(error!),
                style: TextStyle(color: pikoDesign.color('danger')),
              ),
            ),
        ],
      ),
      actions: [
        PikoDialogAction(
          label: copy.text('action.create'),
          onPressed: submitting ? null : submit,
        ),
      ],
    );
  }
}
