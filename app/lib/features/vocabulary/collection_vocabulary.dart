import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_card.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';
import 'inline_vocabulary_edit_controller.dart';

/// A repository-backed Collection list. This widget owns editors, never storage.
class CollectionVocabulary extends StatefulWidget {
  const CollectionVocabulary({
    super.key,
    required this.collection,
    required this.repository,
    this.onPendingWrites,
  });
  final CollectionRecord collection;
  final VocabularyRepository repository;
  final ValueChanged<Future<void>>? onPendingWrites;
  @override
  State<CollectionVocabulary> createState() => _CollectionVocabularyState();
}

class _Editor {
  _Editor(VocabularyRecord record, VocabularyRepository repository)
    : edits = InlineVocabularyEditController(
        entry: record,
        repository: repository,
      ),
      target = TextEditingController(text: record.targetText),
      native = TextEditingController(text: record.nativeText);
  final InlineVocabularyEditController edits;
  final TextEditingController target, native;
  final targetFocus = FocusNode(), nativeFocus = FocusNode();
}

class _CollectionVocabularyState extends State<CollectionVocabulary> {
  StreamSubscription<List<VocabularyRecord>>? subscription;
  List<VocabularyRecord> rows = [];
  Object? loadError;
  bool waiting = true, switching = false;
  Object? transition;
  int generation = 0;
  String? focusedId;
  _Editor? editor;
  final retired = <_Editor>{};

  @override
  void initState() {
    super.initState();
    watch();
  }

  @override
  void didUpdateWidget(CollectionVocabulary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.id != widget.collection.id ||
        oldWidget.repository != widget.repository) {
      retireEditor(oldWidget.onPendingWrites);
      switching = false;
      rows = [];
      waiting = true;
      loadError = null;
      watch();
    }
  }

  void watch() {
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
            if (editor != null &&
                !value.any((row) => row.id == editor!.edits.entryId)) {
              retireEditor(widget.onPendingWrites);
            }
            setState(() {
              rows = value;
              waiting = false;
              loadError = null;
            });
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

  void changed() {
    if (mounted) setState(() {});
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
    if (switching || editor?.edits.entryId == id && id != null) return;
    final current = editor;
    final version = generation;
    final request = Object();
    transition = request;
    try {
      if (current != null) {
        setState(() => switching = true);
        await current.edits.awaitSavedEdits();
        if (!mounted ||
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
      setState(() {
        switching = false;
        if (record != null) {
          editor = _Editor(record, widget.repository);
          editor!.edits.addListener(changed);
        }
      });
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
    _ => 'entry.saveFailed',
  };

  Widget row(VocabularyRecord record) {
    final copy = PikoCopyScope.of(context);
    final current = editor?.edits.entryId == record.id ? editor : null;
    final expanded = current != null;
    Widget content;
    if (current == null) {
      content = Row(
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
        enabled: !switching,
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
          if (!identical(editor, current) || switching) return;
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
                icon: const PikoIcon(PikoIconName.x),
                semanticLabel: copy.text('vocab.inlineCollapse'),
                onPressed: switching ? null : () => activateRow(null),
              ),
            ],
          ),
          SizedBox(height: pikoDesign.dimension('spacing.3')),
          fields,
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
          if (error != null && error is! VocabularyValidation)
            PikoButton(
              label: copy.text('action.retry'),
              onPressed: switching || edits.isSaving ? null : edits.retry,
            ),
          SizedBox(height: pikoDesign.dimension('spacing.2')),
          Text(
            copy.text(
              edits.isSaving
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
    return Semantics(
      label: expanded
          ? null
          : copy.text('vocab.editPair', {
              'target': record.targetText,
              'native': record.nativeText,
            }),
      button: !expanded,
      expanded: expanded,
      onTap: expanded || switching ? null : () => activateRow(record.id),
      child: ExcludeSemantics(
        excluding: !expanded,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: expanded || switching ? null : () => activateRow(record.id),
            excludeFromSemantics: true,
            canRequestFocus: !expanded && !switching,
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
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (waiting) Text(copy.text('vocab.loading')),
        if (loadError != null) ...[
          Text(copy.text('vocab.loadFailed')),
          PikoButton(
            label: copy.text('action.retry'),
            onPressed: () => setState(watch),
          ),
        ],
        if (!waiting && loadError == null && rows.isEmpty)
          PikoCard(child: Text(copy.text('collection.empty'))),
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) SizedBox(height: pikoDesign.dimension('spacing.3')),
          KeyedSubtree(
            key: ValueKey('vocabulary-row-${rows[index].id}'),
            child: row(rows[index]),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    generation++;
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
