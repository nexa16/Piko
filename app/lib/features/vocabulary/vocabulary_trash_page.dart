import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_deletion.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_form.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_page.dart';
import '../../ui/piko_theme.dart';
import 'compact_vocabulary_pair.dart';

class VocabularyTrashPage extends StatefulWidget {
  const VocabularyTrashPage({
    required this.collection,
    required this.repository,
    this.onPendingWrites,
    super.key,
  });
  final CollectionRecord collection;
  final VocabularyTrashService repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<VocabularyTrashPage> createState() => _VocabularyTrashPageState();
}

class _VocabularyTrashPageState extends State<VocabularyTrashPage> {
  late Future<List<VocabularyTrashGroup>> groups = load();
  final expanded = <String>{};
  bool busy = false;
  String? error;
  Future<List<VocabularyTrashGroup>> load() =>
      widget.repository.trashGroups(collectionId: widget.collection.id);
  void refresh() => setState(() {
    groups = load();
  });

  Future<void> restore(VocabularyTrashGroup group, [String? entryId]) async {
    if (busy || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    final operation = entryId == null
        ? widget.repository.restoreTrashGroup(group.id)
        : widget.repository.restoreTrashEntry(entryId);
    widget.onPendingWrites?.call(
      operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    try {
      final result = await operation;
      if (!mounted) return;
      refresh();
      final copy = PikoCopyScope.of(context);
      await showPikoDialog<void>(
        context,
        builder: (_) => PikoDialog(
          purpose: PikoDialogPurpose.summary,
          title: copy.text('trash.restoreResult'),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.text('trash.restoreSummary', {
                  'restored': result.restoredIds.length,
                  'conflicts': result.conflicts.length,
                }),
              ),
              for (final conflict in result.conflicts.entries)
                Text(
                  '${group.entries.where((entry) => entry.id == conflict.key).firstOrNull?.targetText ?? conflict.key} · ${copy.text(conflict.value == VocabularyUndoFailure.duplicatePair ? 'vocab.inlineDuplicate' : 'vocab.undoFailed')}',
                ),
              if (result.omittedCategoryEntryIds.isNotEmpty)
                Text(
                  copy.text('trash.categoryWarning', {
                    'count': result.omittedCategoryEntryIds.length,
                  }),
                ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => error = 'trash.restoreFailed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clear() async {
    if (busy || ModalRoute.of(context)?.isCurrent != true) return;
    final copy = PikoCopyScope.of(context);
    final confirmed = await showPikoDialog<bool>(
      context,
      builder: (context) => PikoDialog(
        purpose: PikoDialogPurpose.confirmation,
        title: copy.text('trash.clearTitle'),
        body: Text(copy.text('trash.clearHelp')),
        actions: [
          PikoDialogAction(
            label: copy.text('action.cancel'),
            role: PikoDialogActionRole.safe,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PikoDialogAction(
            label: copy.text('trash.clear'),
            role: PikoDialogActionRole.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    final operation = widget.repository.clearTrash(widget.collection.id);
    widget.onPendingWrites?.call(
      operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    try {
      await operation;
      if (mounted) refresh();
    } catch (_) {
      if (mounted) setState(() => error = 'trash.clearFailed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final dates = MaterialLocalizations.of(context);
    String date(DateTime instant) => dates.formatMediumDate(instant.toLocal());
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        body: PikoPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PikoFormHeading(
                title: copy.text('collection.trash'),
                subtitle: widget.collection.name,
                leading: PikoIconButton(
                  icon: const PikoIcon(PikoIconName.arrowLeft),
                  semanticLabel: copy.text('common.back'),
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).maybePop(),
                ),
              ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    copy.text(error!),
                    style: TextStyle(color: pikoDesign.color('danger')),
                  ),
                ),
              FutureBuilder<List<VocabularyTrashGroup>>(
                future: groups,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        Text(copy.text('vocab.loadFailed')),
                        PikoButton(
                          label: copy.text('action.retry'),
                          onPressed: busy ? null : refresh,
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final rows = snapshot.data!;
                  if (rows.isEmpty) return Text(copy.text('trash.empty'));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final group in rows) ...[
                        PikoFormGroup(
                          children: [
                            PikoFormRow(
                              key: ValueKey('trash-group-${group.id}'),
                              title:
                                  '${copy.text('trash.deletedAt', {'date': date(group.deletedAt)})} · ${group.entries.length}',
                              subtitle: copy.text('trash.expiresAt', {
                                'date': date(group.expiresAt),
                              }),
                              trailing: RotatedBox(
                                quarterTurns: expanded.contains(group.id)
                                    ? 1
                                    : 0,
                                child: const PikoIcon(
                                  PikoIconName.chevronRight,
                                ),
                              ),
                              onTap: busy
                                  ? null
                                  : () => setState(() {
                                      expanded.contains(group.id)
                                          ? expanded.remove(group.id)
                                          : expanded.add(group.id);
                                    }),
                            ),
                            if (expanded.contains(group.id)) ...[
                              for (final entry in group.entries)
                                PikoFormFieldRow(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      CompactVocabularyPair.preview(
                                        first: entry.targetText,
                                        second: entry.nativeText,
                                      ),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: PikoButton(
                                          key: ValueKey(
                                            'trash-restore-${entry.id}',
                                          ),
                                          label: copy.text('trash.restore'),
                                          variant: PikoButtonVariant.ghost,
                                          onPressed: busy
                                              ? null
                                              : () => restore(group, entry.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              PikoFormRow(
                                key: ValueKey(
                                  'trash-restore-group-${group.id}',
                                ),
                                title: copy.text('trash.restoreGroup'),
                                trailing: const PikoIcon(
                                  PikoIconName.rotateCcw,
                                ),
                                onTap: busy ? null : () => restore(group),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: pikoDesign.dimension('spacing.6')),
                      ],
                      PikoFormGroup(
                        children: [
                          PikoFormRow(
                            key: const ValueKey('trash-clear'),
                            title: copy.text('trash.clear'),
                            danger: true,
                            trailing: const PikoIcon(PikoIconName.trash),
                            onTap: busy ? null : clear,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
