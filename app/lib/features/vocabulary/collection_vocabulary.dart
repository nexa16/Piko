import '../collections/collection_view_preferences.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show MatrixUtils, RenderAbstractViewport, RenderSliver, ScrollDirection;
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../data/vocabulary_deletion.dart';
import '../../data/categories_repository.dart';
import '../../data/learning_item.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_swipe_reveal.dart';
import '../../ui/piko_theme.dart';
import 'inline_vocabulary_edit_controller.dart';
import 'collection_vocabulary_mutations.dart';
import '../collections/collection_write_barrier.dart';
import '../collections/collection_query_binding.dart';
import '../categories/vocabulary_categories.dart';
import 'vocabulary_learning_status.dart';
import 'vocabulary_content_editor.dart';
import 'saved_vocabulary_editor.dart';

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
    this.sliver = false,
    this.preferredDirections = const {
      LearningDirection.targetToNative,
      LearningDirection.nativeToTarget,
    },
  });
  final CollectionRecord collection;
  final VocabularyRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  final CollectionVocabularyMutations? mutations;
  final CollectionWriteBarrier? writeBarrier;
  final CollectionQueryBinding? queryBinding;
  final CategoriesRepository? categoriesRepository;

  /// Production Detail shares a single lazy viewport with its header.
  final bool sliver;
  final Set<LearningDirection> preferredDirections;
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
  String? editorOccurrence;
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
      final contentEnd = viewport != null && content is RenderSliver
          ? MatrixUtils.transformPoint(
              content.getTransformTo(viewport),
              Offset(0, content.geometry!.scrollExtent),
            ).dy
          : viewport != null && content is RenderBox
          ? viewport
                .globalToLocal(
                  content.localToGlobal(Offset(0, content.size.height)),
                )
                .dy
          : null;
      final slack = viewport != null && contentEnd != null
          ? ((viewport.constraints.hasBoundedHeight
                        ? viewport.constraints.maxHeight
                        : position.viewportDimension) -
                    contentEnd)
                .clamp(0.0, double.infinity)
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

  String errorKey(Object error) =>
      vocabularyContentErrorKey(error) ??
      switch (error) {
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

  String occurrence(String id, String? group) =>
      group == null ? id : '$group/$id';
  Future<void> activateOccurrence(String id, String? group) async {
    if (actionBusy) return;
    await activateRow(id);
    if (mounted && editor?.edits.entryId == id) {
      setState(() => editorOccurrence = occurrence(id, group));
    }
  }

  Widget row(VocabularyRecord record, String? group) {
    final copy = PikoCopyScope.of(context);
    final current =
        editor?.edits.entryId == record.id &&
            editorOccurrence == occurrence(record.id, group)
        ? editor
        : null;
    final view =
        widget.queryBinding?.scope.view ?? const CollectionViewPreferences();
    final first = view.targetFirst ? record.targetText : record.nativeText;
    final second = view.targetFirst ? record.nativeText : record.targetText;
    final expanded = current != null;
    Widget content;
    if (current == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view.mode == VocabularyViewMode.detailed) ...[
            Text(first, style: Theme.of(context).textTheme.titleMedium),
            Text(second),
            for (final pair in record.content.examples) ...[
              SizedBox(height: pikoDesign.dimension('spacing.2')),
              Text(view.targetFirst ? pair.targetText : pair.nativeText),
              Text(
                view.targetFirst ? pair.nativeText : pair.targetText,
                style: TextStyle(color: pikoDesign.color('muted')),
              ),
            ],
            if (record.content.hintText != null) ...[
              SizedBox(height: pikoDesign.dimension('spacing.2')),
              Text(record.content.hintText!),
            ],
          ] else
            ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(width: pikoDesign.dimension('spacing.3')),
                  Expanded(
                    child: Text(
                      second,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pikoDesign.color('muted')),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.categoriesRepository != null)
            VocabularyCategories(
              collectionId: widget.collection.id,
              entryId: record.id,
              repository: widget.categoriesRepository!,
              snapshot: widget.queryBinding?.snapshot,
              excludedValues: {
                ?group,
                ...?widget.queryBinding?.scope.filters.values.expand((v) => v),
              },
            ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SavedVocabularyEditor(
            collection: widget.collection,
            repository: widget.repository,
            edits: current.edits,
            target: current.target,
            native: current.native,
            targetFocus: current.targetFocus,
            nativeFocus: current.nativeFocus,
            categories: widget.categoriesRepository,
            snapshot: widget.queryBinding?.snapshot,
            busy:
                widget.writeBarrier?.frozen == true ||
                switching ||
                current.edits.isDiscarding ||
                widget.mutations?.isBusy == true,
            onPendingWrites: widget.onPendingWrites,
            onCollapse: () => activateRow(null),
            onDelete: widget.mutations == null
                ? null
                : () => deleteEntry(record),
          ),
          if (widget.mutations?.errorEntryId == record.id)
            Text(copy.text('vocab.deleteFailed')),
        ],
      );
    }
    content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (!record.active)
          Padding(
            padding: EdgeInsets.only(top: pikoDesign.dimension('spacing.2')),
            child: Text(
              copy.text('vocab.inactive'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          VocabularyLearningStatusView(
            collection: widget.collection,
            entryId: record.id,
            snapshot: widget.queryBinding?.ready == true
                ? widget.queryBinding?.snapshot
                : null,
            directions: widget.preferredDirections,
          ),
      ],
    );
    final card = Semantics(
      label: expanded
          ? null
          : copy.text('vocab.editPair', {
              'target': record.targetText,
              'native': record.nativeText,
            }),
      button: !expanded,
      expanded: expanded,
      onTap: expanded || actionBusy
          ? null
          : () => activateOccurrence(record.id, group),
      child: ExcludeSemantics(
        excluding: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: expanded || actionBusy
                ? null
                : () => activateOccurrence(record.id, group),
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
              key: ValueKey('vocabulary-${occurrence(record.id, group)}'),
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
            onPressed: actionBusy
                ? null
                : () => activateOccurrence(record.id, group),
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
    void onPointerMove(PointerMoveEvent event) {
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
    }

    final leading = Column(
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
                widget.queryBinding?.snapshot?.allEntries.isNotEmpty == true &&
                        widget.queryBinding!.scope.restricted
                    ? 'r2.noMatches'
                    : 'collection.empty',
              ),
            ),
          ),
      ],
    );
    final trailing = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mutations?.latest case final offer?) ...[
          SizedBox(height: pikoDesign.dimension('spacing.3')),
          undoBar(offer),
        ],
        if (bottomSpace > 0) SizedBox(height: bottomSpace),
      ],
    );
    final scope = widget.queryBinding?.scope;
    final snapshot = widget.queryBinding?.snapshot;
    final groups = snapshot != null && scope != null
        ? groupVocabulary(snapshot, scope.view)
        : [VocabularyViewGroup(null, null, rows)];
    final items =
        <({String key, VocabularyRecord? entry, VocabularyViewGroup group})>[];
    for (final group in groups) {
      if (group.id != null) {
        items.add((key: 'group-${group.id}', entry: null, group: group));
      }
      if (group.id == null || scope!.expandedGroups.contains(group.id)) {
        for (final entry in group.entries) {
          items.add((
            key: 'vocabulary-row-${occurrence(entry.id, group.id)}',
            entry: entry,
            group: group,
          ));
        }
      }
    }
    // A view change may move the one UUID-owned editor to another occurrence.
    if (editor != null &&
        !items.any(
          (i) =>
              i.entry != null &&
              occurrence(i.entry!.id, i.group.id) == editorOccurrence,
        )) {
      final visible = items
          .where((i) => i.entry?.id == editor!.edits.entryId)
          .firstOrNull;
      if (visible != null) {
        editorOccurrence = occurrence(visible.entry!.id, visible.group.id);
      }
    }
    Widget item(int index) {
      final item = items[index], record = item.entry;
      if (record == null) {
        final id = item.group.id!,
            expanded = scope!.expandedGroups.contains(item.group.id);
        return Container(
          key: ValueKey(item.key),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: pikoDesign
                    .color('muted')
                    .withValues(
                      alpha: pikoDesign.dimension(
                        'components.collectionList.dividerOpacity',
                      ),
                    ),
              ),
            ),
          ),
          child: Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: ValueKey('collection-group-$id'),
              onTap: actionBusy
                  ? null
                  : () => scope.expandGroups([id], !expanded),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: pikoDesign.dimension('spacing.3'),
                ),
                child: Row(
                  children: [
                    RotatedBox(
                      quarterTurns: expanded ? 1 : 0,
                      child: const PikoIcon(
                        PikoIconName.chevronRight,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: pikoDesign.dimension('spacing.2')),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  item.group.name ??
                                  copy.text('view.unassigned'),
                            ),
                            TextSpan(
                              text: ' (${item.group.entries.length})',
                              style: TextStyle(
                                color: pikoDesign.color('muted'),
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      final key = occurrence(record.id, item.group.id);
      return _RetainedVocabularyRow(
        key: ValueKey(item.key),
        retain: editor?.edits.entryId == record.id && editorOccurrence == key,
        child: Listener(
          onPointerMove: onPointerMove,
          child: Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : pikoDesign.dimension('spacing.2'),
            ),
            child: KeyedSubtree(
              key: rowKeys.putIfAbsent(key, GlobalKey.new),
              child: row(record, item.group.id),
            ),
          ),
        ),
      );
    }

    return widget.sliver
        ? SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Listener(onPointerMove: onPointerMove, child: leading),
              ),
              SliverList.builder(
                itemCount: items.length,
                findChildIndexCallback: (key) {
                  final index = items.indexWhere(
                    (item) => key == ValueKey(item.key),
                  );
                  return index < 0 ? null : index;
                },
                itemBuilder: (context, index) => item(index),
              ),
              SliverToBoxAdapter(
                child: Listener(onPointerMove: onPointerMove, child: trailing),
              ),
            ],
          )
        : Listener(
            onPointerMove: onPointerMove,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leading,
                for (var i = 0; i < items.length; i++) item(i),
                trailing,
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

/// Keep the one active editor mounted outside the cache so scrolling cannot
/// dispose its selection, focus, optional-content controls or validation.
class _RetainedVocabularyRow extends StatefulWidget {
  const _RetainedVocabularyRow({
    super.key,
    required this.retain,
    required this.child,
  });
  final bool retain;
  final Widget child;

  @override
  State<_RetainedVocabularyRow> createState() => _RetainedVocabularyRowState();
}

class _RetainedVocabularyRowState extends State<_RetainedVocabularyRow>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.retain;

  @override
  void didUpdateWidget(_RetainedVocabularyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.retain != widget.retain) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
