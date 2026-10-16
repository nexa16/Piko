import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_field.dart';
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
      name.text = PikoCopyScope.of(context).text(target.copyKey);
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
    Widget language(
      String key,
      VocabularyLanguage value,
      ValueChanged<VocabularyLanguage> changed, {
      List<VocabularyLanguage> options = VocabularyLanguage.values,
    }) => PikoDropdown<VocabularyLanguage>(
      label: copy.text(key),
      value: value,
      items: options
          .map(
            (language) => DropdownMenuItem(
              value: language,
              child: Text(copy.text(language.copyKey)),
            ),
          )
          .toList(),
      onChanged: submitting
          ? null
          : (value) {
              if (value != null) setState(() => changed(value));
            },
    );
    return PikoDialog(
      title: copy.text('dialog.newCollection'),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          language('collection.targetLanguage', target, (value) {
            if (value == target) return;
            target = value;
            if (automaticName) name.text = copy.text(target.copyKey);
          }),
          SizedBox(height: pikoDesign.dimension('spacing.4')),
          language(
            'collection.nativeLanguage',
            native,
            (value) => native = value,
            options: const [
              VocabularyLanguage.german,
              VocabularyLanguage.english,
              VocabularyLanguage.french,
              VocabularyLanguage.korean,
            ],
          ),
          SizedBox(height: pikoDesign.dimension('spacing.4')),
          PikoTextField(
            label: copy.text('collection.name'),
            controller: name,
            onChanged: (_) => automaticName = false,
            enabled: !submitting,
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
