import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/categories_repository.dart';
import '../../data/collection_query.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';
import 'category_assignment_picker.dart';
import 'category_dimension_form.dart';

/// Shared category presentation for one vocabulary row. A Collection projection
/// supplies labels without additional reads; standalone consumers use streams.
class VocabularyCategories extends StatefulWidget {
  const VocabularyCategories({
    super.key,
    required this.collectionId,
    required this.entryId,
    required this.repository,
    this.snapshot,
    this.draftAssignments,
    this.onSelection,
    this.disabled = false,
    this.onPendingWrites,
    this.onMetadataChanged,
  });
  final String collectionId, entryId;
  final CategoriesRepository repository;
  final CollectionQuerySnapshot? snapshot;
  final Map<String, Set<String>>? draftAssignments;
  final ValueChanged<CategoryAssignmentRecord>? onSelection;
  final bool disabled;
  final ValueChanged<Future<void>>? onPendingWrites;
  final VoidCallback? onMetadataChanged;
  @override
  State<VocabularyCategories> createState() => _VocabularyCategoriesState();
}

class _VocabularyCategoriesState extends State<VocabularyCategories> {
  StreamSubscription<List<CategoryDimensionRecord>>? dimensionsSubscription;
  StreamSubscription<List<CategoryAssignmentRecord>>? assignmentsSubscription;
  final valueSubscriptions =
      <String, StreamSubscription<List<CategoryValueRecord>>>{};
  List<CategoryDimensionRecord> dimensions = const [];
  List<CategoryAssignmentRecord> assignments = const [];
  final values = <String, List<CategoryValueRecord>>{};
  bool dimensionsReady = false, assignmentsReady = false, popup = false;
  Object? error;
  int generation = 0;
  String? metadataSignature;
  @override
  void initState() {
    super.initState();
    bind();
  }

  @override
  void didUpdateWidget(VocabularyCategories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.entryId != widget.entryId ||
        oldWidget.collectionId != widget.collectionId ||
        (oldWidget.snapshot == null) != (widget.snapshot == null)) {
      bind();
    }
  }

  void cancel() {
    unawaited(dimensionsSubscription?.cancel());
    unawaited(assignmentsSubscription?.cancel());
    for (final subscription in valueSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    valueSubscriptions.clear();
  }

  void bind() {
    cancel();
    final revision = ++generation;
    popup = false;
    dimensionsReady = false;
    assignmentsReady = false;
    error = null;
    values.clear();
    metadataSignature = null;
    if (widget.snapshot != null) return;
    void failed(Object failure) {
      if (mounted && generation == revision) {
        setState(() {
          error = failure;
        });
      }
    }

    dimensionsSubscription = widget.repository
        .watchDimensions(widget.collectionId)
        .listen((next) {
          if (!mounted || generation != revision) return;
          final ids = next.map((dimension) => dimension.id).toSet();
          for (final id
              in valueSubscriptions.keys
                  .where((id) => !ids.contains(id))
                  .toList()) {
            unawaited(valueSubscriptions.remove(id)?.cancel());
            values.remove(id);
          }
          for (final dimension in next) {
            valueSubscriptions.putIfAbsent(
              dimension.id,
              () => widget.repository.watchValues(dimension.id).listen((
                nextValues,
              ) {
                if (mounted && generation == revision) {
                  setState(() {
                    values[dimension.id] = List.unmodifiable(nextValues);
                  });
                }
              }, onError: failed),
            );
          }
          setState(() {
            dimensions = List.unmodifiable(next);
            dimensionsReady = true;
          });
        }, onError: failed);
    assignmentsSubscription = widget.repository
        .watchAssignments(widget.entryId)
        .listen((next) {
          if (mounted && generation == revision) {
            setState(() {
              assignments = List.unmodifiable(next);
              assignmentsReady = true;
            });
          }
        }, onError: failed);
  }

  bool owned(int revision) =>
      mounted &&
      generation == revision &&
      !widget.disabled &&
      ModalRoute.of(context)?.isCurrent != false;

  Future<void> pick(
    CategoryDimensionRecord dimension,
    Set<String> selected,
  ) async {
    if (popup || widget.onSelection == null || widget.disabled) return;
    final revision = generation;
    final selection = widget.onSelection;
    setState(() {
      popup = true;
    });
    try {
      final result = await showCategoryAssignmentPicker(
        context,
        entryId: widget.entryId,
        dimension: dimension,
        repository: widget.repository,
        initialValueIds: selected,
        onPendingWrites: widget.onPendingWrites,
      );
      if (owned(revision) && result != null) {
        selection?.call(result);
      }
    } finally {
      if (mounted && generation == revision)
        setState(() {
          popup = false;
        });
    }
  }

  Future<void> createDimension() async {
    if (popup || widget.disabled) return;
    final revision = generation;
    setState(() {
      popup = true;
    });
    try {
      await showCreateCategoryDimension(
        context,
        collectionId: widget.collectionId,
        repository: widget.repository,
        onPendingWrites: widget.onPendingWrites,
      );
    } finally {
      if (mounted && generation == revision)
        setState(() {
          popup = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final projection = widget.snapshot;
    final dims = projection?.categoryDimensions ?? dimensions;
    final definitions = projection?.categoryValues ?? values;
    final assigned =
        widget.draftAssignments ??
        {
          for (final row
              in projection?.assignments[widget.entryId] ?? assignments)
            row.dimensionId: row.valueIds,
        };
    final copy = PikoCopyScope.of(context), design = pikoDesign;
    final editable = widget.onSelection != null;
    if (error != null && projection == null) {
      return Column(
        children: [
          Text(copy.text('category.loadFailed')),
          PikoButton(
            label: copy.text('action.retry'),
            onPressed: widget.disabled ? null : () => setState(bind),
          ),
        ],
      );
    }
    if (projection == null &&
        (!dimensionsReady ||
            !assignmentsReady ||
            dims.any((dimension) => !definitions.containsKey(dimension.id)))) {
      return editable
          ? const LinearProgressIndicator()
          : const SizedBox.shrink();
    }
    final signature = dims
        .map(
          (dimension) =>
              '${dimension.id}:${(definitions[dimension.id] ?? const <CategoryValueRecord>[]).map((value) => value.id).join(',')}',
        )
        .join(';');
    if (signature != metadataSignature && widget.onMetadataChanged != null) {
      metadataSignature = signature;
      final revision = generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && revision == generation) {
          widget.onMetadataChanged?.call();
        }
      });
    }
    List<Widget> chips(CategoryDimensionRecord dimension) => [
      for (final value
          in definitions[dimension.id] ?? const <CategoryValueRecord>[])
        if (assigned[dimension.id]?.contains(value.id) == true)
          Container(
            key: ValueKey('category-label-${widget.entryId}-${value.id}'),
            padding: EdgeInsets.symmetric(
              horizontal: design.dimension('spacing.2'),
              vertical: design.dimension('spacing.1'),
            ),
            decoration: BoxDecoration(
              color: design.color('tint'),
              borderRadius: BorderRadius.circular(
                design.dimension('components.buttons.radius'),
              ),
            ),
            child: Text(
              value.name,
              style: TextStyle(
                color: design.color('primary'),
                fontSize: design.dimension('typography.small'),
              ),
            ),
          ),
    ];
    final all = [for (final dimension in dims) ...chips(dimension)];
    if (!editable) {
      if (all.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: design.dimension('spacing.2')),
        child: Wrap(
          spacing: design.dimension('spacing.1'),
          runSpacing: design.dimension('spacing.1'),
          children: all,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final dimension in dims) ...[
          SizedBox(height: design.dimension('spacing.2')),
          SizedBox(
            width: double.infinity,
            child: PikoButton(
              key: ValueKey(
                'category-picker-${widget.entryId}-${dimension.id}',
              ),
              label: dimension.name,
              icon: const PikoIcon(PikoIconName.layers),
              trailing: const PikoIcon(PikoIconName.chevronRight),
              variant: PikoButtonVariant.neutral,
              onPressed: popup || widget.disabled
                  ? null
                  : () => pick(dimension, assigned[dimension.id] ?? const {}),
            ),
          ),
          if (chips(dimension).isNotEmpty)
            Wrap(
              spacing: design.dimension('spacing.1'),
              runSpacing: design.dimension('spacing.1'),
              children: chips(dimension),
            ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PikoButton(
            label: copy.text('category.addDimension'),
            icon: const PikoIcon(PikoIconName.plus),
            variant: PikoButtonVariant.ghost,
            onPressed: popup || widget.disabled ? null : createDimension,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    generation++;
    cancel();
    super.dispose();
  }
}
