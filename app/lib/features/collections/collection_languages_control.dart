import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/piko_theme.dart';
import 'language_picker.dart';

/// Staged metadata-only editing. The repository owns validation and admission;
/// leaving this dialog never swaps or translates existing vocabulary fields.
class CollectionLanguagesControl extends StatelessWidget {
  const CollectionLanguagesControl({
    required this.collection,
    required this.repository,
    required this.enabled,
    this.onPendingWrites,
    this.onBusyChanged,
    super.key,
  });
  final CollectionRecord collection;
  final CollectionLanguageRepository repository;
  final bool enabled;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool>? onBusyChanged;
  @override
  Widget build(BuildContext context) => PikoNavigationRow(
    key: const ValueKey('collection-change-languages'),
    title: PikoCopyScope.of(context).text('collection.editLanguages'),
    subtitle:
        '${collection.targetLanguage.label(PikoCopyScope.of(context).locale)} · ${collection.nativeLanguage.label(PikoCopyScope.of(context).locale)}',
    onTap: !enabled
        ? null
        : () => showPikoDialog<void>(
            context,
            builder: (_) => _LanguagesDialog(
              collection: collection,
              repository: repository,
              onPendingWrites: onPendingWrites,
              onBusyChanged: onBusyChanged,
            ),
          ),
  );
}

class _LanguagesDialog extends StatefulWidget {
  const _LanguagesDialog({
    required this.collection,
    required this.repository,
    this.onPendingWrites,
    this.onBusyChanged,
  });
  final CollectionRecord collection;
  final CollectionLanguageRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<_LanguagesDialog> createState() => _LanguagesDialogState();
}

class _LanguagesDialogState extends State<_LanguagesDialog> {
  late VocabularyLanguage target = widget.collection.targetLanguage;
  late VocabularyLanguage native = widget.collection.nativeLanguage;
  bool saving = false;
  String? error;
  Future<void> choose(bool isTarget) async {
    if (saving) return;
    final choice = await showPikoDialog<VocabularyLanguage>(
      context,
      builder: (_) => LanguagePickerDialog(target: isTarget),
    );
    if (!mounted || saving || choice == null) return;
    setState(() {
      if (isTarget) {
        target = choice;
      } else {
        native = choice;
      }
      error = null;
    });
  }

  Future<void> save() async {
    if (saving || target.matches(native)) return;
    setState(() {
      saving = true;
      error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final operation = widget.repository.setLanguages(
        id: widget.collection.id,
        targetLanguage: target,
        nativeLanguage: native,
      );
      widget.onPendingWrites?.call(
        operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      await operation;
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'collection.saveFailed');
    } finally {
      widget.onBusyChanged?.call(false);
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return PikoDialog(
      title: copy.text('collection.editLanguages'),
      dismissible: !saving,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(copy.text('collection.languagesPreserved')),
          SizedBox(height: pikoDesign.dimension('spacing.4')),
          PikoFormGroup(
            children: [
              PikoNavigationRow(
                title: copy.text('collection.targetLanguage'),
                subtitle: target.label(copy.locale),
                onTap: saving ? null : () => choose(true),
              ),
              PikoNavigationRow(
                title: copy.text('collection.nativeLanguage'),
                subtitle: native.label(copy.locale),
                onTap: saving ? null : () => choose(false),
              ),
            ],
          ),
          if (target.matches(native) || error != null)
            Text(
              copy.text(
                target.matches(native) ? 'collection.sameLanguage' : error!,
              ),
              style: TextStyle(color: pikoDesign.color('danger')),
            ),
        ],
      ),
      actions: [
        PikoDialogAction(
          label: copy.text('r2.apply'),
          onPressed:
              saving ||
                  target.matches(native) ||
                  (target == widget.collection.targetLanguage &&
                      native == widget.collection.nativeLanguage)
              ? null
              : save,
        ),
      ],
    );
  }
}
