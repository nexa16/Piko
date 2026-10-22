import 'package:flutter/material.dart';
import '../../data/learning_item.dart';
import '../../data/learning_reset.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/components/piko_icon.dart';

class VocabularyResetControl extends StatelessWidget {
  const VocabularyResetControl({
    required this.entryId,
    required this.repository,
    required this.enabled,
    required this.beforeReset,
    this.onPendingWrites,
    this.onLearningReset,
    super.key,
  });
  final String entryId;
  final LearningResetRepository repository;
  final bool enabled;
  final Future<void> Function() beforeReset;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<Set<LearningDirection>>? onLearningReset;

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return PikoFormRow(
      key: ValueKey('vocabulary-reset-$entryId'),
      title: copy.text('vocab.resetLearning'),
      trailing: const PikoIcon(PikoIconName.rotateCcw),
      onTap: !enabled
          ? null
          : () async {
              final directions = LearningDirection.values.toSet();
              var pending = false;
              Object? error;
              final complete = await showPikoDialog<bool>(
                context,
                canDismiss: () => !pending,
                builder: (dialogContext) => StatefulBuilder(
                  builder: (context, update) => PikoDialog(
                    title: copy.text('vocab.resetLearningConfirm'),
                    purpose: PikoDialogPurpose.confirmation,
                    dismissible: !pending,
                    body: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(copy.text('vocab.resetLearningHelp')),
                        for (final direction in LearningDirection.values)
                          CheckboxListTile(
                            key: ValueKey('reset-direction-${direction.name}'),
                            title: Text(
                              copy.text(
                                direction == LearningDirection.targetToNative
                                    ? 'settings.directionTargetToNative'
                                    : 'settings.directionNativeToTarget',
                              ),
                            ),
                            value: directions.contains(direction),
                            onChanged: pending
                                ? null
                                : (selected) => update(() {
                                    selected == true
                                        ? directions.add(direction)
                                        : directions.remove(direction);
                                  }),
                          ),
                        if (error != null) Text(copy.text('entry.saveFailed')),
                      ],
                    ),
                    actions: [
                      PikoDialogAction(
                        label: copy.text('action.cancel'),
                        role: PikoDialogActionRole.safe,
                        onPressed: pending
                            ? null
                            : () => Navigator.of(dialogContext).pop(false),
                      ),
                      PikoDialogAction(
                        label: copy.text('vocab.resetLearning'),
                        role: PikoDialogActionRole.destructive,
                        onPressed: pending || directions.isEmpty
                            ? null
                            : () async {
                                update(() {
                                  pending = true;
                                  error = null;
                                });
                                final operation = () async {
                                  await beforeReset();
                                  await repository.resetLearning(
                                    entryId: entryId,
                                    directions: {...directions},
                                  );
                                }();
                                onPendingWrites?.call(
                                  operation.then<void>(
                                    (_) {},
                                    onError: (Object _, StackTrace _) {},
                                  ),
                                );
                                try {
                                  await operation;
                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop(true);
                                  }
                                } catch (failure) {
                                  if (dialogContext.mounted) {
                                    update(() {
                                      pending = false;
                                      error = failure;
                                    });
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              );
              if (complete == true) {
                onLearningReset?.call(Set.unmodifiable(directions));
              }
              if (context.mounted && complete == true) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(copy.text('vocab.resetLearningDone'))),
                );
              }
            },
    );
  }
}
