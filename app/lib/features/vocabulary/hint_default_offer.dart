import 'package:flutter/material.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';

Future<void> offerCollectionHintDefault(
  BuildContext context,
  CollectionHintPreferences preferences,
  String collectionId,
) async {
  if (await preferences.hintDefaultOfferHandled(collectionId) ||
      !context.mounted) {
    return;
  }
  var busy = false;
  var failed = false;
  final result = await showPikoDialog<bool>(
    context,
    canDismiss: () => !busy,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) {
        final copy = PikoCopyScope.of(context);
        Future<void> complete(bool accept) async {
          if (busy) return;
          update(() {
            busy = true;
            failed = false;
          });
          try {
            await preferences.completeHintDefaultOffer(
              collectionId,
              accept: accept,
            );
            if (context.mounted) Navigator.of(context).pop(true);
          } catch (_) {
            if (context.mounted) {
              update(() {
                busy = false;
                failed = true;
              });
            }
          }
        }

        return PikoDialog(
          purpose: PikoDialogPurpose.confirmation,
          title: copy.text('vocab.hintDefaultOfferTitle'),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(copy.text('vocab.hintDefaultOfferBody')),
              if (failed) Text(copy.text('vocab.hintDefaultFailed')),
            ],
          ),
          actions: [
            PikoDialogAction(
              label: copy.text('vocab.hintDefaultKeep'),
              role: PikoDialogActionRole.safe,
              onPressed: busy ? null : () => complete(false),
            ),
            PikoDialogAction(
              label: copy.text(
                failed ? 'action.retry' : 'vocab.hintDefaultAccept',
              ),
              onPressed: busy ? null : () => complete(true),
            ),
          ],
        );
      },
    ),
  );
  // Back/barrier dismissal is a consumed offer too; callers retain retry on a
  // failed write and register this whole operation with their storage lifetime.
  if (result != true) {
    await preferences.completeHintDefaultOffer(collectionId, accept: false);
  }
}
