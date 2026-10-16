import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, ScrollDirection;
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../data/vocabulary_deletion.dart';
import '../../data/categories_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_swipe_reveal.dart';
import '../../ui/piko_theme.dart';
import 'inline_vocabulary_edit_controller.dart';
import 'collection_vocabulary_mutations.dart';
import '../collections/collection_write_barrier.dart';
import '../collections/collection_query_binding.dart';
import '../categories/vocabulary_categories.dart';

/// A repository-backed Collection list. This widget owns editors, never storage.
class CollectionVocabulary extends StatefulWidget {
  const CollectionVocabulary({
    super.key,
    required this.collection,
    required this.repository,
    this.onPendingWrites,
    this.mutations,
    this.writeBarrier,
    this.queryBinding,
    this.categoriesRepository,
  });
  final CollectionRecord collection;
  final VocabularyRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  final CollectionVocabularyMutations? mutations;
  final CollectionWriteBarrier? writeBarrier;
  final CollectionQueryBinding? queryBinding;
  final CategoriesRepository? categoriesRepository;
  @override
  State<CollectionVocabulary> createState() => _CollectionVocabularyState();
}

class _Editor {
  _Editor(this.edits)
    : target = TextEditingController(text: edits.opening.targetText),
      native = TextEditingController(text: edits.opening.nativeText) {
    targetFocus.addListener(() {
      if (targetFocus.hasFocus) lastFocus = targetFocus;
    });
    nativeFocus.addListener(() {
      if (nativeFocus.hasFocus) lastFocus = nativeFocus;
    });
  }
  final InlineVocabularyEditController edits;
  bool get changed => edits.changedSinceOpening;
  final TextEditingController target, native;
  final targetFocus = FocusNode(), nativeFocus = FocusNode();
  FocusNode? lastFocus;
}

class _CollectionVocabularyState extends State<CollectionVocabulary> {
  StreamSubscription<List<VocabularyRecord>>? subscription;
  List<VocabularyRecord> rows = [];
  Object? loadError;
  String? openingErrorId;
  bool waiting = true, switching = false;
  Object? transition;
  int generation = 0;
  String? focusedId;
  _Editor? editor;
  final retired = <_Editor>{};
  final rowKeys = <String, GlobalKey>{};
  double topSpace = 0, bottomSpace = 0;
  int anchorRevision = 0;
  bool get actionBusy =>
      widget.writeBarrier?.frozen == true ||
      widget.queryBinding != null && !widget.queryBinding!.ready ||
      switching ||
      editor?.edits.isDiscarding == true ||
      widget.mutations?.isBusy == true;

  @override
  void initState() {
    super.initState();
    widget.mutations?.addListener(changed);
    widget.writeBarrier?.addListener(barrierChanged);
    widget.writeBarrier?.attach(drainEditor);
    widget.queryBinding?.addListener(projectionChanged);
    watch();
  }

  @override
  void didUpdateWidget(CollectionVocabulary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryBinding != widget.queryBinding) {
      oldWidget.queryBinding?.removeListener(projectionChanged);
      widget.queryBinding?.addListener(projectionChanged);
      watch();
    }
    if (oldWidget.writeBarrier != widget.writeBarrier) {
      oldWidget.writeBarrier?.removeListener(barrierChanged);
      oldWidget.writeBarrier?.detach(drainEditor);
      widget.writeBarrier?.addListener(barrierChanged);
      widget.writeBarrier?.attach(drainEditor);
    }
    if (oldWidget.mutations != widget.mutations) {
      oldWidget.mutations?.removeListener(changed);
      widget.mutations?.addListener(changed);
    }
    if (oldWidget.collection.id != widget.collection.id ||
        oldWidget.repository != widget.repository) {
      retireEditor(oldWidget.onPendingWrites);
      switching = false;
      rows = [];
      waiting = true;
      loadError = null;
      openingErrorId = null;
      rowKeys.clear();
      topSpace = 0;
      bottomSpace = 0;
      anchorRevision++;
      watch();
    }
  }

  void watch() {
    if (widget.queryBinding != null) {
      ++generation;
      unawaited(subscription?.cancel());
      subscription = null;
      applyProjection();
      return;
    }
    transition = null;
    switching = false;
    final version = ++generation;
    unawaited(subscription?.cancel());
    waiting = true;
    subscription = widget.repository
        .watchByCollection(widget.collection.id)
        .listen(
          (value) {
            if (!mounted || version != generation) return;
            final structural =
                rows.map((r) => r.id).join('|') !=
                value.map((r) => r.id).join('|');
            final anchorId =
                structural && value.any((r) => r.id == editor?.edits.entryId)
                ? editor?.edits.entryId
                : null;
            final anchorBox = rowKeys[anchorId]?.currentContext
                ?.findRenderObject();
            final anchorTop = anchorBox is RenderBox && anchorBox.attached
                ? anchorBox.localToGlobal(Offset.zero).dy
                : null;
            if (editor != null &&
                !value.any((row) => row.id == editor!.edits.entryId)) {
              retireEditor(widget.onPendingWrites);
            }
            setState(() {
              rows = value;
              waiting = false;
              loadError = null;
            });
            if (anchorId != null && anchorTop != null) {
              preserveAnchor(anchorId, anchorTop, ++anchorRevision);
            }
          },
          onError: (Object error) {
            if (mounted && version == generation) {
              setState(() {
                loadError = error;
                waiting = false;
              });
            }
          },
        );
  }

  void projectionChanged() {
    if (mounted) setState(applyProjection);
  }

  void applyProjection() {
    final binding = widget.queryBinding!;
    waiting = binding.loading;
    loadError = binding.error;
    final snapshot = binding.snapshot;
    if (snapshot == null) return;
    // A filter may temporarily hide an editor. Its raw draft and controller
    // remain owned here until the user changes editor or the entry is deleted.
    if (binding.ready &&
        editor != null &&
        !snapshot.allEntries.any((row) => row.id == editor!.edits.entryId)) {
      retireEditor(widget.onPendingWrites);
    }
    rows = snapshot.entries;
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void barrierChanged() {
    final previous = editor;
    changed();
    if (widget.writeBarrier?.frozen != true) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => restoreEditorFocus(previous),
      );
    }
  }

  Future<void> drainEditor() =>
      editor?.edits.awaitSavedEdits() ?? Future<void>.value();

  void preserveAnchor(String id, double top, int revision, [int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != anchorRevision || attempt > 3) return;
      final position = Scrollable.maybeOf(context)?.position;
      final box = rowKeys[id]?.currentContext?.findRenderObject();
      if (position == null ||
          !position.hasContentDimensions ||
          box is! RenderBox ||
          !box.attached) {
        return;
      }
      final delta = box.localToGlobal(Offset.zero).dy - top;
      if (delta.abs() < .5) return;
      // Reconcile temporary leading compensation when an insertion reverses a
      // prior removal, rather than forcing a short list to become scrollable.
      if (delta > 0 && topSpace > 0) {
        setState(() => topSpace -= delta.clamp(0, topSpace));
        preserveAnchor(id, top, revision, attempt + 1);
        return;
      }
      final desired = position.pixels + delta;
      final viewportObject = RenderAbstractViewport.maybeOf(box);
      final viewport = viewportObject is RenderBox
          ? viewportObject as RenderBox
          : null;
      final content = context.findRenderObject();
      // Measure visible slack from actual bounds. A short list can be hundreds
      // of pixels below its viewport height despite maxScrollExtent == 0.
      final slack = viewport != null && content is RenderBox
          ? (viewport
                        .localToGlobal(
                          Offset(
                            0,
                            viewport.constraints.hasBoundedHeight
                                ? viewport.constraints.maxHeight
                                : position.viewportDimension,
                          ),
                        )
                        .dy -
                    content.localToGlobal(Offset(0, content.size.height)).dy)
                .clamp(0, double.infinity)
          : 0.0;
      if (desired < position.minScrollExtent ||
          desired > position.maxScrollExtent) {
        setState(() {
          if (desired < position.minScrollExtent) {
            topSpace += position.minScrollExtent - desired;
          } else {
            bottomSpace += desired - position.maxScrollExtent + slack;
          }
        });
        preserveAnchor(id, top, revision, attempt + 1);
      } else {
        position.jumpTo(desired);
      }
    });
  }

  Future<void> deleteEntry(VocabularyRecord entry) async {
    final mutations = widget.mutations;
    if (mutations == null || actionBusy) return;
    final current = editor?.edits.entryId == entry.id ? editor : null;
    final unrelated = current == null ? editor : null;
    // Mutation owner enters busy synchronously before any accepted-save await.
    final operation = mutations.delete(
      entry,
      acceptedWrites: current?.edits.awaitSavedEdits(),
    );
    widget.onPendingWrites?.call(operation);
    try {
      await operation;
    } catch (_) {
      /* Owner exposes localized row failure. */
    }
    restoreEditorFocus(unrelated);
  }

  Future<void> undoEntry(CollectionUndoOffer offer) async {
    final mutations = widget.mutations;
    if (mutations == null || actionBusy) return;
    final current = editor;
    final operation = mutations.undo(offer);
    widget.onPendingWrites?.call(operation);
    try {
      await operation;
    } catch (_) {
      /* Offer retains localized failure. */
    }
    restoreEditorFocus(current);
  }

  void restoreEditorFocus(_Editor? previous) {
    if (!mounted ||
        previous == null ||
        !identical(editor, previous) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    previous.lastFocus?.requestFocus();
  }

  void retireEditor(
    ValueChanged<Future<void>>? register, {
    bool invalidateTransition = true,
  }) {
    if (invalidateTransition) {
      transition = null;
      switching = false;
    }
    final old = editor;
    editor = null;
    if (old == null) return;
    anchorRevision++;
    topSpace = 0;
    bottomSpace = 0;
    old.edits.removeListener(changed);
    final drain = old.edits.awaitSavedEdits();
    register?.call(drain);
    old.edits.dispose();
    // Dispose widget-owned controllers after the old fields detach.
    retired.add(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (retired.remove(old)) {
        old.target.dispose();
        old.native.dispose();
        old.targetFocus.dispose();
        old.nativeFocus.dispose();
      }
    });
  }

  Future<void> activateRow(String? id) async {
    if (actionBusy || editor?.edits.entryId == id && id != null) return;
    final current = editor;
    final version = generation;
    final request = Object();
    transition = request;
    setState(() {
      switching = true;
      openingErrorId = null;
    });
    try {
      if (current != null) {
        setState(() => switching = true);
        await current.edits.awaitSavedEdits();
        if (!mounted ||
            widget.writeBarrier?.frozen == true ||
            generation != version ||
            !identical(editor, current) ||
            !identical(transition, request)) {
          return;
        }
        if (current.edits.error != null) {
          setState(() => switching = false);
          return;
        }
        // Stream delivery may lag the completed write; collapse shows the actual
        // last committed record rather than stale input from an earlier event.
        rows = [
          for (final row in rows)
            row.id == current.edits.entryId ? current.edits.committed : row,
        ];
        retireEditor(widget.onPendingWrites, invalidateTransition: false);
      }
      if (!mounted || generation != version) return;
      final record = rows.where((row) => row.id == id).firstOrNull;
      if (record == null) return;
      final capture = InlineVocabularyEditController.open(
        entryId: record.id,
        collectionId: widget.collection.id,
        repository: widget.repository,
      );
      widget.onPendingWrites?.call(
        capture.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      final captured = await capture;
      if (!mounted ||
          widget.writeBarrier?.frozen == true ||
          generation != version ||
          !identical(transition, request) ||
          !rows.any((row) => row.id == record.id)) {
        captured.dispose();
        return;
      }
      setState(() {
        switching = false;
        editor = _Editor(captured);
        editor!.edits.addListener(changed);
      });
    } catch (_) {
      if (mounted && generation == version && identical(transition, request)) {
        setState(() => openingErrorId = id);
      }
    } finally {
      if (mounted && identical(transition, request)) {
        setState(() {
          switching = false;
          transition = null;
        });
      }
    }
  }

  String errorKey(Object error) => switch (error) {
    VocabularyValidation.requiredTarget => 'entry.requiredTarget',
    VocabularyValidation.requiredNative => 'entry.requiredNative',
    VocabularyValidation.duplicatePair => 'vocab.inlineDuplicate',
    VocabularyValidation.entryNotFound => 'entry.notFound',
    CategoryValidation() => 'category.selectionInvalid',
    _ => 'entry.saveFailed',
  };

  Future<void> discardEditor(_Editor current) async {
    if (actionBusy || !identical(editor, current)) return;
    final version = generation;
    final request = Object();
    transition = request;
    setState(() => switching = true);
    var failed = false;
    try {
      final operation = current.edits.discard();
      widget.onPendingWrites?.call(
        operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      final restored = await operation;
      if (!mounted ||
          generation != version ||
          !identical(editor, current) ||
          !identical(transition, request)) {
        return;
      }
      setState(() {
        rows = [for (final row in rows) row.id == restored.id ? restored : row];
        retireEditor(widget.onPendingWrites);
      });
    } catch (_) {
      failed = true; // Controller retains the raw input and rollback error.
    } finally {
      if (mounted && identical(transition, request)) {
        setState(() {
          switching = false;
          transition = null;
        });
      }
      if (failed) restoreEditorFocus(current);
    }
  }

  String discardErrorKey(Object error) => switch (error) {
    VocabularyValidation.duplicatePair => 'vocab.inlineDuplicate',
    VocabularyValidation.entryNotFound ||
    VocabularyValidation.collectionNotFound => 'entry.notFound',
    CategoryValidation() => 'category.selectionInvalid',
    _ => 'vocab.inlineDiscardFailed',
  };

  Widget row(VocabularyRecord record) {
    final copy = PikoCopyScope.of(context);
    final current = editor?.edits.entryId == record.id ? editor : null;
    final expanded = current != null;
    Widget content;
    if (current == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    record.targetText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: pikoDesign.dimension('typography.body'),
                      fontWeight: pikoDesign.weight('typography.titleWeight'),
                    ),
                  ),
                ),
                SizedBox(width: pikoDesign.dimension('spacing.3')),
                Expanded(
                  child: Text(
                    record.nativeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: pikoDesign.dimension('typography.body'),
                      color: pikoDesign.color('muted'),
                    ),
                  ),
                ),
                SizedBox(width: pikoDesign.dimension('spacing.3')),
                const PikoIcon(PikoIconName.pencil),
              ],
            ),
          ),
          if (widget.categoriesRepository != null)
            VocabularyCategories(
              collectionId: widget.collection.id,
              entryId: record.id,
              repository: widget.categoriesRepository!,
              snapshot: widget.queryBinding?.snapshot,
            ),
        ],
      );
    } else {
      final edits = current.edits;
      final error = edits.error;
      Widget field(bool target) => PikoTextField(
        key: ValueKey('inline-${record.id}-${target ? 'target' : 'native'}'),
        label: copy.text(
          (target
                  ? widget.collection.targetLanguage
                  : widget.collection.nativeLanguage)
              .copyKey,
        ),
        controller: target ? current.target : current.native,
        focusNode: target ? current.targetFocus : current.nativeFocus,
        enabled:
            widget.writeBarrier?.frozen != true &&
            !switching &&
            !edits.isDiscarding &&
            widget.mutations?.deletingId != record.id,
        style: TextStyle(
          fontSize: pikoDesign.dimension('typography.body'),
          fontWeight: pikoDesign.weight('components.fields.labelWeight'),
        ),
        error:
            error ==
                (target
                    ? VocabularyValidation.requiredTarget
                    : VocabularyValidation.requiredNative)
            ? copy.text(errorKey(error!))
            : null,
        onChanged: (value) {
          if (!identical(editor, current) ||
              widget.writeBarrier?.frozen == true ||
              switching ||
              edits.isDiscarding ||
              widget.mutations?.deletingId == record.id) {
            return;
          }
          if (target) {
            edits.setTargetText(value);
          } else {
            edits.setNativeText(value);
          }
        },
      );
      final fields =
          MediaQuery.sizeOf(context).width <=
              pikoDesign.dimension(
                'components.inlineVocabulary.compactBreakpoint',
              )
          ? Column(
              children: [
                field(true),
                SizedBox(height: pikoDesign.dimension('spacing.3')),
                field(false),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field(true)),
                SizedBox(width: pikoDesign.dimension('spacing.3')),
                Expanded(child: field(false)),
              ],
            );
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  copy.text('vocab.inlineEdit'),
                  style: TextStyle(
                    fontSize: pikoDesign.dimension('typography.body'),
                    fontWeight: pikoDesign.weight('typography.titleWeight'),
                  ),
                ),
              ),
              SizedBox(width: pikoDesign.dimension('spacing.3')),
              PikoIconButton(
                key: ValueKey('inline-complete-${record.id}'),
                icon: PikoIcon(
                  current.changed ? PikoIconName.check : PikoIconName.x,
                ),
                semanticLabel: copy.text(
                  current.changed
                      ? 'vocab.inlineFinish'
                      : 'vocab.inlineCollapse',
                ),
                onPressed: actionBusy ? null : () => activateRow(null),
              ),
              if (current.changed) ...[
                SizedBox(width: pikoDesign.dimension('spacing.3')),
                PikoIconButton(
                  key: ValueKey('inline-discard-${record.id}'),
                  icon: const PikoIcon(PikoIconName.x),
                  semanticLabel: copy.text('vocab.inlineDiscard'),
                  onPressed: actionBusy ? null : () => discardEditor(current),
                ),
              ],
            ],
          ),
          SizedBox(height: pikoDesign.dimension('spacing.3')),
          fields,
          if (widget.categoriesRepository != null && edits.supportsCategories)
            VocabularyCategories(
              collectionId: widget.collection.id,
              entryId: record.id,
              repository: widget.categoriesRepository!,
              snapshot: widget.queryBinding?.snapshot,
              draftAssignments: edits.draft.assignments,
              disabled: actionBusy,
              onPendingWrites: widget.onPendingWrites,
              onMetadataChanged: () {
                if (!mounted ||
                    !identical(editor, current) ||
                    edits.isDiscarding) {
                  return;
                }
                final refresh = edits.refreshCategoryReferences(
                  widget.categoriesRepository!,
                );
                widget.onPendingWrites?.call(refresh);
              },
              onSelection: (assignment) {
                if (!mounted ||
                    !identical(editor, current) ||
                    actionBusy ||
                    ModalRoute.of(context)?.isCurrent != true) {
                  return;
                }
                edits.setCategoryValues(
                  assignment.dimensionId,
                  assignment.valueIds,
                );
                unawaited(
                  edits.refreshCategoryReferences(widget.categoriesRepository!),
                );
                widget.onPendingWrites?.call(edits.awaitSavedEdits());
              },
            ),
          if (error != null &&
              error != VocabularyValidation.requiredTarget &&
              error != VocabularyValidation.requiredNative)
            Padding(
              padding: EdgeInsets.only(top: pikoDesign.dimension('spacing.3')),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  copy.text(errorKey(error)),
                  style: TextStyle(
                    fontSize: pikoDesign.dimension('typography.small'),
                    color: pikoDesign.color('danger'),
                  ),
                ),
              ),
            ),
          if (edits.discardError != null)
            Padding(
              padding: EdgeInsets.only(top: pikoDesign.dimension('spacing.3')),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  copy.text(discardErrorKey(edits.discardError!)),
                  style: TextStyle(
                    fontSize: pikoDesign.dimension('typography.small'),
                    color: pikoDesign.color('danger'),
                  ),
                ),
              ),
            ),
          if (edits.discardError != null)
            PikoButton(
              label: copy.text('action.retry'),
              onPressed: actionBusy ? null : () => discardEditor(current),
            )
          else if (error != null &&
              error is! VocabularyValidation &&
              error is! CategoryValidation)
            PikoButton(
              label: copy.text('action.retry'),
              onPressed: actionBusy || edits.isSaving ? null : edits.retry,
            ),
          if (widget.mutations != null) ...[
            SizedBox(height: pikoDesign.dimension('spacing.3')),
            Align(
              alignment: Alignment.centerLeft,
              child: PikoButton(
                label: copy.text('vocab.delete'),
                icon: const PikoIcon(PikoIconName.trash),
                variant: PikoButtonVariant.dangerGhost,
                onPressed: actionBusy ? null : () => deleteEntry(record),
              ),
            ),
          ],
          if (widget.mutations?.errorEntryId == record.id)
            Semantics(
              liveRegion: true,
              child: Text(
                copy.text('vocab.deleteFailed'),
                style: TextStyle(color: pikoDesign.color('danger')),
              ),
            ),
          SizedBox(height: pikoDesign.dimension('spacing.2')),
          Text(
            copy.text(
              edits.isDiscarding
                  ? 'vocab.inlineDiscarding'
                  : edits.isSaving
                  ? 'entry.saving'
                  : error != null
                  ? 'entry.unsaved'
                  : 'vocab.inlineAutoSave',
            ),
            style: TextStyle(
              fontSize: pikoDesign.dimension(
                'components.inlineVocabulary.captionSize',
              ),
              color: pikoDesign.color('muted'),
            ),
          ),
        ],
      );
    }
    final card = Semantics(
      label: expanded
          ? null
          : copy.text('vocab.editPair', {
              'target': record.targetText,
              'native': record.nativeText,
            }),
      button: !expanded,
      expanded: expanded,
      onTap: expanded || actionBusy ? null : () => activateRow(record.id),
      child: ExcludeSemantics(
        excluding: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: expanded || actionBusy ? null : () => activateRow(record.id),
            excludeFromSemantics: true,
            canRequestFocus: !expanded && !actionBusy,
            onFocusChange: (value) => setState(
              () => focusedId = value
                  ? record.id
                  : focusedId == record.id
                  ? null
                  : focusedId,
            ),
            borderRadius: BorderRadius.circular(
              pikoDesign.dimension('radii.card'),
            ),
            child: PikoCard(
              key: ValueKey('vocabulary-${record.id}'),
              focused: focusedId == record.id,
              padding: EdgeInsets.all(
                pikoDesign.dimension(
                  expanded ? 'components.cards.padding' : 'spacing.4',
                ),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!expanded && openingErrorId == record.id) ...[
          Semantics(
            liveRegion: true,
            child: Text(copy.text('vocab.loadFailed')),
          ),
          PikoButton(
            label: copy.text('action.retry'),
            onPressed: actionBusy ? null : () => activateRow(record.id),
          ),
        ],
        if (widget.mutations == null)
          card
        else
          PikoSwipeReveal(
            enabled: !expanded && !actionBusy,
            label: copy.text('vocab.delete'),
            onDelete: actionBusy ? null : () => deleteEntry(record),
            child: card,
          ),
        if (!expanded && widget.mutations?.errorEntryId == record.id)
          Semantics(
            liveRegion: true,
            child: Text(
              copy.text('vocab.deleteFailed'),
              style: TextStyle(color: pikoDesign.color('danger')),
            ),
          ),
      ],
    );
  }

  String undoErrorKey(Object error) => switch (error) {
    VocabularyUndoFailure.expired ||
    VocabularyUndoFailure.alreadyUsed ||
    VocabularyUndoFailure.invalidReceipt => 'vocab.undoExpired',
    VocabularyUndoFailure.duplicatePair => 'vocab.inlineDuplicate',
    _ => 'vocab.undoFailed',
  };
  Widget undoBar(CollectionUndoOffer offer) {
    final copy = PikoCopyScope.of(context);
    return Container(
      key: ValueKey('collection-undo-${offer.entry.id}'),
      padding: EdgeInsets.all(pikoDesign.dimension('spacing.3')),
      decoration: BoxDecoration(
        color: pikoDesign.color('tint'),
        borderRadius: BorderRadius.circular(
          pikoDesign.dimension('components.buttons.radius'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: pikoDesign.dimension('spacing.3'),
            runSpacing: pikoDesign.dimension('spacing.2'),
            children: [
              Semantics(
                liveRegion: true,
                child: Text(copy.text('vocab.deleted')),
              ),
              PikoButton(
                label: copy.text('vocab.undo'),
                variant: PikoButtonVariant.ghost,
                onPressed: !actionBusy && widget.mutations!.canUndo(offer)
                    ? () => undoEntry(offer)
                    : null,
              ),
            ],
          ),
          Text(
            '${offer.entry.targetText} · ${offer.entry.nativeText}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: pikoDesign.color('muted'),
              fontSize: pikoDesign.dimension('typography.small'),
            ),
          ),
          if (offer.error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                copy.text(undoErrorKey(offer.error!)),
                style: TextStyle(color: pikoDesign.color('danger')),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Listener(
      onPointerMove: (event) {
        anchorRevision++;
        if (Scrollable.maybeOf(context)?.position.userScrollDirection !=
                ScrollDirection.idle &&
            event.delta.dy.abs() > event.delta.dx.abs() &&
            (topSpace != 0 || bottomSpace != 0)) {
          setState(() {
            topSpace = 0;
            bottomSpace = 0;
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topSpace > 0) SizedBox(height: topSpace),
          if (waiting) Text(copy.text('vocab.loading')),
          if (loadError != null) ...[
            Text(copy.text('vocab.loadFailed')),
            PikoButton(
              label: copy.text('action.retry'),
              onPressed:
                  widget.writeBarrier?.frozen == true ||
                      editor?.edits.isDiscarding == true
                  ? null
                  : widget.queryBinding?.refresh ?? () => setState(watch),
            ),
          ],
          if (!waiting && loadError == null && rows.isEmpty)
            PikoCard(
              child: Text(
                copy.text(
                  widget.queryBinding?.snapshot?.allEntries.isNotEmpty ==
                              true &&
                          widget.queryBinding!.scope.restricted
                      ? 'r2.noMatches'
                      : 'collection.empty',
                ),
              ),
            ),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) SizedBox(height: pikoDesign.dimension('spacing.3')),
            KeyedSubtree(
              key: ValueKey('vocabulary-row-${rows[index].id}'),
              child: KeyedSubtree(
                key: rowKeys.putIfAbsent(rows[index].id, GlobalKey.new),
                child: row(rows[index]),
              ),
            ),
          ],
          if (widget.mutations?.latest case final offer?) ...[
            SizedBox(height: pikoDesign.dimension('spacing.3')),
            undoBar(offer),
          ],
          if (bottomSpace > 0) SizedBox(height: bottomSpace),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.queryBinding?.removeListener(projectionChanged);
    generation++;
    widget.mutations?.removeListener(changed);
    widget.writeBarrier?.removeListener(barrierChanged);
    widget.writeBarrier?.detach(drainEditor);
    unawaited(subscription?.cancel());
    retireEditor(widget.onPendingWrites);
    for (final old in retired) {
      old.target.dispose();
      old.native.dispose();
      old.targetFocus.dispose();
      old.nativeFocus.dispose();
    }
    retired.clear();
    super.dispose();
  }
}
