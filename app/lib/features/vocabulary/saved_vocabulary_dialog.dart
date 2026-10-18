import 'package:flutter/material.dart';
import '../../data/categories_repository.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_button.dart';
import 'inline_vocabulary_edit_controller.dart';
import 'saved_vocabulary_editor.dart';

class VocabularyEditorSourceStatus extends ChangeNotifier {
  Object? error;
  VoidCallback? retry;
  void update(Object? failure, VoidCallback action) {
    final changed = error != failure;
    error = failure;
    retry = action;
    if (changed) notifyListeners();
  }
}

Future<void> showSavedVocabularyDialog(
  BuildContext context, {
  required CollectionRecord collection,
  required VocabularyRepository repository,
  required String entryId,
  CategoriesRepository? categories,
  ValueChanged<Future<void>>? onPendingWrites,
  Future<void> Function(VocabularyRecord)? onDelete,
  ValueChanged<ModalRoute<void>>? onRouteCreated,
  bool Function()? canUse,
  VocabularyEditorSourceStatus? sourceStatus,
}) async {
  final capture = InlineVocabularyEditController.open(
    entryId: entryId,
    collectionId: collection.id,
    repository: repository,
  );
  onPendingWrites?.call(
    capture.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
  );
  final edits = await capture;
  final key = GlobalKey<_SavedVocabularyDialogState>();
  ModalRoute<void>? ownedRoute;
  try {
    if (!context.mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        canUse?.call() == false) {
      return;
    }
    await showPikoDialog<void>(
      context,
      onRouteCreated: (route) {
        ownedRoute = route;
        onRouteCreated?.call(route);
      },
      canDismiss: () {
        key.currentState?.close();
        return false;
      },
      builder: (_) => _SavedVocabularyDialog(
        key: key,
        collection: collection,
        repository: repository,
        edits: edits,
        categories: categories,
        onPendingWrites: onPendingWrites,
        onDelete: onDelete,
        canUse: canUse,
        sourceStatus: sourceStatus,
      ),
    );
  } finally {
    // The push result completes before the reverse transition detaches fields.
    if (ownedRoute case final TransitionRoute<void> route) {
      await route.completed;
    }
    final drain = edits.awaitSavedEdits();
    onPendingWrites?.call(drain);
    await drain;
    edits.dispose();
  }
}

class _SavedVocabularyDialog extends StatefulWidget {
  const _SavedVocabularyDialog({
    super.key,
    required this.collection,
    required this.repository,
    required this.edits,
    this.categories,
    this.onPendingWrites,
    this.onDelete,
    this.canUse,
    this.sourceStatus,
  });
  final CollectionRecord collection;
  final VocabularyRepository repository;
  final InlineVocabularyEditController edits;
  final CategoriesRepository? categories;
  final ValueChanged<Future<void>>? onPendingWrites;
  final Future<void> Function(VocabularyRecord)? onDelete;
  final bool Function()? canUse;
  final VocabularyEditorSourceStatus? sourceStatus;
  @override
  State<_SavedVocabularyDialog> createState() => _SavedVocabularyDialogState();
}

class _SavedVocabularyDialogState extends State<_SavedVocabularyDialog> {
  late final target = TextEditingController(
    text: widget.edits.draft.targetText,
  );
  late final native = TextEditingController(
    text: widget.edits.draft.nativeText,
  );
  final targetFocus = FocusNode(), nativeFocus = FocusNode();
  bool closing = false;
  int closeEpoch = 0;
  FocusNode? lastFocus;
  @override
  void initState() {
    super.initState();
    targetFocus.addListener(() {
      if (targetFocus.hasFocus) lastFocus = targetFocus;
    });
    nativeFocus.addListener(() {
      if (nativeFocus.hasFocus) lastFocus = nativeFocus;
    });
  }

  void retrySource() {
    if (!mounted) return;
    closeEpoch++;
    setState(() => closing = false);
    widget.sourceStatus?.retry?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) lastFocus?.requestFocus();
    });
  }

  Future<void> close({bool delete = false}) async {
    if (closing || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final epoch = ++closeEpoch;
    setState(() => closing = true);
    try {
      await widget.edits.awaitSavedEdits();
      if (!mounted ||
          epoch != closeEpoch ||
          (!delete &&
              (widget.edits.error != null ||
                  widget.edits.hasUncommittedChanges))) {
        return;
      }
      if (delete && widget.canUse?.call() != false) {
        await widget.onDelete?.call(widget.edits.committed);
      }
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted && epoch == closeEpoch) setState(() => closing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: AnimatedBuilder(
      animation: widget.edits,
      builder: (context, _) => PikoDialog(
        presentation: PikoDialogPresentation.groupedForm,
        title: PikoCopyScope.of(context).text('vocab.inlineEdit'),
        onClose: close,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SavedVocabularyEditor(
              collection: widget.collection,
              repository: widget.repository,
              edits: widget.edits,
              target: target,
              native: native,
              targetFocus: targetFocus,
              nativeFocus: nativeFocus,
              onCollapse: close,
              onDelete: widget.onDelete == null
                  ? null
                  : () => close(delete: true),
              categories: widget.categories,
              onPendingWrites: widget.onPendingWrites,
              busy: closing || widget.canUse?.call() == false,
              showHeader: false,
            ),
            if (widget.sourceStatus != null)
              ListenableBuilder(
                listenable: widget.sourceStatus!,
                builder: (context, _) => widget.sourceStatus!.error == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            PikoCopyScope.of(context).text('vocab.loadFailed'),
                          ),
                          PikoButton(
                            key: const ValueKey('editor-source-retry'),
                            label: PikoCopyScope.of(
                              context,
                            ).text('action.retry'),
                            onPressed: retrySource,
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    target.dispose();
    native.dispose();
    targetFocus.dispose();
    nativeFocus.dispose();
    super.dispose();
  }
}
