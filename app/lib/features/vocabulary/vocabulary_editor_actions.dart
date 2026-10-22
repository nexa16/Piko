import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/piko_theme.dart';

Future<bool> confirmVocabularyDeletion(BuildContext context) async {
  final copy = PikoCopyScope.of(context);
  ModalRoute<bool>? confirmation;
  final result = await showPikoDialog<bool>(
    context,
    onRouteCreated: (route) => confirmation = route,
    builder: (context) => PikoDialog(
      purpose: PikoDialogPurpose.confirmation,
      title: copy.text('vocab.deleteConfirmTitle'),
      body: Text(copy.text('vocab.deleteConfirmHelp')),
      actions: [
        PikoDialogAction(
          label: copy.text('action.cancel'),
          role: PikoDialogActionRole.safe,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PikoDialogAction(
          label: copy.text('vocab.delete'),
          role: PikoDialogActionRole.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (confirmation case final TransitionRoute<bool> route) {
    await route.completed;
  }
  return result == true;
}

/// Title/status share a wrapping line without making status the route name.
class VocabularyEditorTitle extends StatelessWidget {
  const VocabularyEditorTitle({
    required this.title,
    required this.status,
    super.key,
  });
  final String title, status;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: pikoDesign.dimension('spacing.3'),
    runSpacing: pikoDesign.dimension('spacing.1'),
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ExcludeSemantics(child: Text(title)),
      Semantics(
        liveRegion: true,
        child: Text(status, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}
