import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../data/collection_query.dart';
import '../../data/categories_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_field.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import '../../ui/piko_theme.dart';

typedef CollectionFilterSelection = Map<String, Set<String>>;

/// Filter membership is staged; value order is independent, immediate metadata.
class FilterSelectionDialog extends StatefulWidget {
  const FilterSelectionDialog({
    required this.snapshot,
    required this.opening,
    required this.reloadDefinitions,
    required this.canApply,
    this.onPendingWrites,
    this.onClose,
    this.categories,
    super.key,
  });
  final CollectionQuerySnapshot snapshot;
  final CollectionFilterSelection opening;
  final Future<CollectionQuerySnapshot> Function() reloadDefinitions;
  final bool Function() canApply;
  final ValueChanged<Future<void>>? onPendingWrites;
  final VoidCallback? onClose;
  final CategoriesRepository? categories;
  @override
  State<FilterSelectionDialog> createState() => _FilterSelectionDialogState();
}

class _FilterSelectionDialogState extends State<FilterSelectionDialog> {
  late CollectionQuerySnapshot _definitions = widget.snapshot;
  late final CollectionFilterSelection _opening = _copy(widget.opening);
  late CollectionFilterSelection _draft = _copy(widget.opening);
  bool _pending = false;
  String? _error;
  String? _orderErrorValue;
  final _orders = <String, List<CategoryValueRecord>>{};
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _anchor = PikoInteractionAnchor();
  final _searchArea = GlobalKey();
  final _rows = <String, GlobalKey>{};
  bool _overflow = false, _measuring = false, _dragging = false;
  VoidCallback? _retryOrder;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<CategoryValueRecord> _values(String group) =>
      _orders[group] ?? _definitions.categoryValues[group] ?? const [];

  void _measureOverflow() {
    if (_measuring) return;
    _measuring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      if (!mounted || !_scroll.hasClients || _query.text.isNotEmpty) return;
      final searchHeight = _searchArea.currentContext?.size?.height ?? 0;
      final overflow = _scroll.position.maxScrollExtent > searchHeight + 1;
      if (_overflow != overflow) setState(() => _overflow = overflow);
    });
  }

  Future<void> _move(String group, int from, int to) async {
    final repository = widget.categories;
    if (!_canEdit || repository == null || _query.text.isNotEmpty) return;
    final previous = List<CategoryValueRecord>.of(_values(group));
    if (from < 0 || from >= previous.length || to < 0 || to > previous.length) {
      return;
    }
    if (to > from) to--;
    if (from == to) return;
    final next = List<CategoryValueRecord>.of(previous);
    final moved = next.removeAt(from);
    next.insert(to, moved);
    final retryTo = to > from ? to + 1 : to;
    _anchor.clear(); // Explicit movement owns scroll, not the old row's top.
    setState(() {
      _pending = true;
      _orders[group] = next;
      _error = null;
      _orderErrorValue = null;
      _retryOrder = null;
    });
    final done = Completer<void>();
    try {
      widget.onPendingWrites?.call(done.future);
      final saved = await repository.reorderValues(
        dimensionId: group,
        expectedOrder: previous.map((value) => value.id).toList(),
        orderedIds: next.map((value) => value.id).toList(),
      );
      if (!mounted) return;
      setState(() => _orders[group] = saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _orders[group] = previous;
        _orderErrorValue = moved.id;
        _error = error == CategoryValidation.staleOrder
            ? 'category.reorderStale'
            : 'category.reorderFailed';
        _retryOrder = () => _move(group, from, retryTo);
      });
      if (error == CategoryValidation.staleOrder && widget.canApply()) {
        try {
          final fresh = await widget.reloadDefinitions();
          if (!mounted ||
              fresh.collection.id != widget.snapshot.collection.id) {
            return;
          }
          setState(() {
            _definitions = fresh;
            _orders.clear();
            if (!fresh.categoryValues.values
                .expand((v) => v)
                .any((v) => v.id == moved.id)) {
              _orderErrorValue = null;
            }
            _retryOrder =
                null; // New membership requires a deliberate new move.
          });
        } catch (_) {
          /* Keep prior display and an explicit retry. */
        }
      }
    } finally {
      if (mounted) {
        setState(() => _pending = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
          final row = _rows[moved.id]?.currentContext;
          if (row != null) {
            Scrollable.ensureVisible(
              row,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
      }
      done.complete();
    }
  }

  static CollectionFilterSelection _copy(CollectionFilterSelection source) => {
    for (final entry in source.entries)
      if (entry.value.isNotEmpty) entry.key: {...entry.value},
  };
  bool get _changed =>
      _draft.length != _opening.length ||
      _draft.entries.any(
        (entry) => !setEquals(entry.value, _opening[entry.key]),
      );
  bool get _canEdit =>
      !_pending &&
      widget.canApply() &&
      ModalRoute.of(context)?.isCurrent == true;
  void _select(String dimension, String value, bool selected) {
    if (!_canEdit || _dragging) return;
    setState(() {
      final values = {...?_draft[dimension]};
      if (selected) {
        values.add(value);
      } else {
        values.remove(value);
      }
      if (values.isEmpty) {
        _draft.remove(dimension);
      } else {
        _draft[dimension] = values;
      }
      _error = null;
    });
  }

  Future<void> _apply() async {
    if (!_canEdit || !_changed) return;
    setState(() {
      _pending = true;
      _error = null;
      _orderErrorValue = null;
    });
    final done = Completer<void>();
    try {
      widget.onPendingWrites?.call(done.future);
      final fresh = await widget.reloadDefinitions();
      if (!mounted ||
          !widget.canApply() ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (fresh.collection.id != widget.snapshot.collection.id) {
        throw StateError('Changed Collection');
      }
      final dimensionIds = fresh.categoryDimensions
          .map((dimension) => dimension.id)
          .toSet();
      final valid = <String, Set<String>>{};
      for (final selection in _draft.entries) {
        if (!dimensionIds.contains(selection.key)) continue;
        final available =
            fresh.categoryValues[selection.key]
                ?.map((value) => value.id)
                .toSet() ??
            <String>{};
        final kept = selection.value.intersection(available);
        if (kept.isNotEmpty) valid[selection.key] = kept;
      }
      final stale =
          valid.length != _draft.length ||
          valid.entries.any(
            (entry) => !setEquals(entry.value, _draft[entry.key]),
          );
      if (stale) {
        setState(() {
          _definitions = fresh;
          _draft = valid;
          _error = 'category.selectionInvalid';
        });
        return;
      }
      Navigator.of(context).pop<CollectionFilterSelection>(
        Map.unmodifiable({
          for (final selection in valid.entries)
            selection.key: Set<String>.unmodifiable(selection.value),
        }),
      );
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        setState(() => _error = 'category.managementLoadFailed');
      }
    } finally {
      if (mounted) setState(() => _pending = false);
      done.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return Listener(
      onPointerCancel: (_) => _dragging = false,
      child: Focus(
        autofocus: true,
        child: PikoDialog(
          purpose: PikoDialogPurpose.selection,
          title: copy.text('action.filters'),
          onClose: widget.onClose,
          bodyOwnsScroll: widget.categories != null,
          body: widget.categories != null
              ? _orderedBody(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_definitions.categoryDimensions.isEmpty)
                      Text(copy.text('r2.noCategories')),
                    for (final dimension
                        in _definitions.categoryDimensions) ...[
                      Text(
                        dimension.name,
                        style: TextStyle(
                          fontWeight: pikoDesign.weight(
                            'components.buttons.weight',
                          ),
                        ),
                      ),
                      for (final value
                          in _definitions.categoryValues[dimension.id] ??
                              const [])
                        CheckboxListTile(
                          key: ValueKey('filter-value-${value.id}'),
                          title: Text(value.name),
                          value:
                              _draft[dimension.id]?.contains(value.id) ?? false,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: !_canEdit
                              ? null
                              : (selected) => _select(
                                  dimension.id,
                                  value.id,
                                  selected == true,
                                ),
                        ),
                      SizedBox(height: pikoDesign.dimension('spacing.2')),
                    ],
                    if (_error != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          copy.text(_error!),
                          style: TextStyle(color: pikoDesign.color('danger')),
                        ),
                      ),
                  ],
                ),
          actions: [
            PikoDialogAction(
              key: const ValueKey('filters-clear-pending'),
              label: copy.text('r2.clearFilters'),
              role: PikoDialogActionRole.safe,
              onPressed: !_canEdit || _draft.isEmpty
                  ? null
                  : () => setState(() {
                      _draft = {};
                      _error = null;
                    }),
            ),
            PikoDialogAction(
              label: copy.text('r2.apply'),
              icon: const PikoIcon(PikoIconName.check),
              onPressed: _canEdit && _changed ? _apply : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderedBody(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final needle = _query.text.trim().toLowerCase();
    final canMove = _canEdit && _query.text.isEmpty;
    _measureOverflow();
    return LayoutBuilder(
      builder: (context, constraints) {
        _measureOverflow();
        return _anchor.scope(
          child: PikoAnchoredScrollView(
            key: const ValueKey('filter-values-scroll'),
            interactionAnchor: _anchor,
            controller: _scroll,
            shrinkWrap: true,
            slivers: [
              if (_overflow || _query.text.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    key: _searchArea,
                    padding: EdgeInsets.only(
                      bottom: pikoDesign.dimension('spacing.2'),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: PikoTextField(
                            key: const ValueKey('filter-value-search'),
                            label: copy.text('r2.categorySearch'),
                            controller: _query,
                            onChanged: (_) {
                              _anchor.clear();
                              setState(() {});
                            },
                          ),
                        ),
                        PikoIconButton(
                          icon: const PikoIcon(PikoIconName.x),
                          semanticLabel: copy.text('category.clearValueSearch'),
                          onPressed: _query.text.isEmpty
                              ? null
                              : () {
                                  _anchor.clear();
                                  _query.clear();
                                  setState(() {});
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: pikoDesign.dimension('spacing.2'),
                  ),
                  child: Text(
                    copy.text(
                      _query.text.isNotEmpty
                          ? 'category.reorderSearch'
                          : 'category.reorderHelp',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              if (_definitions.categoryDimensions.isEmpty)
                SliverToBoxAdapter(child: Text(copy.text('r2.noCategories'))),
              for (final dimension in _definitions.categoryDimensions) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: pikoDesign.dimension('spacing.2'),
                    ),
                    child: Text(
                      dimension.name,
                      style: TextStyle(
                        fontWeight: pikoDesign.weight(
                          'components.buttons.weight',
                        ),
                      ),
                    ),
                  ),
                ),
                _valueSliver(dimension.id, needle, canMove),
              ],
              if (_error != null && _orderErrorValue == null)
                SliverToBoxAdapter(child: _errorFeedback()),
            ],
          ),
        );
      },
    );
  }

  Widget _errorFeedback() {
    final copy = PikoCopyScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            copy.text(_error!),
            style: TextStyle(color: pikoDesign.color('danger')),
          ),
        ),
        if (_retryOrder != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PikoButton(
              label: copy.text('action.retry'),
              onPressed: _canEdit && _query.text.isEmpty ? _retryOrder : null,
            ),
          ),
      ],
    );
  }

  Widget _valueSliver(String group, String needle, bool canMove) {
    final copy = PikoCopyScope.of(context);
    final values = _values(
      group,
    ).where((v) => v.name.toLowerCase().contains(needle)).toList();
    if (values.isEmpty) {
      return SliverToBoxAdapter(
        child: Text(
          copy.text(
            _values(group).isEmpty
                ? 'category.emptyValues'
                : 'r2.noValueMatches',
          ),
        ),
      );
    }
    Widget rowBuilder(BuildContext context, int index) {
      final value = values[index];
      void moveUp() => _move(group, index, index - 1);
      void moveDown() => _move(group, index, index + 2);
      return ReorderableDelayedDragStartListener(
        key: ValueKey(value.id),
        index: index,
        enabled: canMove,
        child: PikoAnchorRegion(
          key: _rows.putIfAbsent(value.id, () => GlobalKey()),
          child: Semantics(
            customSemanticsActions: {
              if (canMove && index > 0)
                CustomSemanticsAction(label: copy.text('category.moveUp')):
                    moveUp,
              if (canMove && index < values.length - 1)
                CustomSemanticsAction(label: copy.text('category.moveDown')):
                    moveDown,
            },
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        key: ValueKey('filter-value-${value.id}'),
                        title: Text(value.name),
                        value: _draft[group]?.contains(value.id) ?? false,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: !_canEdit
                            ? null
                            : (selected) =>
                                  _select(group, value.id, selected == true),
                      ),
                    ),
                    PopupMenuButton<int>(
                      key: ValueKey('filter-value-menu-${value.id}'),
                      tooltip: copy.text('category.reorder', {
                        'value': value.name,
                      }),
                      icon: const PikoIcon(PikoIconName.ellipsis),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: -1,
                          enabled: canMove && index > 0,
                          child: Text(
                            copy.text(
                              index == 0
                                  ? 'category.firstPosition'
                                  : 'category.moveUp',
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 1,
                          enabled: canMove && index < values.length - 1,
                          child: Text(
                            copy.text(
                              index == values.length - 1
                                  ? 'category.lastPosition'
                                  : 'category.moveDown',
                            ),
                          ),
                        ),
                      ],
                      onSelected: (direction) {
                        if (direction < 0) {
                          moveUp();
                        } else {
                          moveDown();
                        }
                      },
                    ),
                  ],
                ),
                if (_error != null && _orderErrorValue == value.id)
                  _errorFeedback(),
              ],
            ),
          ),
        ),
      );
    }

    if (!canMove) {
      return SliverList.builder(
        itemCount: values.length,
        itemBuilder: rowBuilder,
      );
    }
    return SliverReorderableList(
      itemCount: values.length,
      onReorderStart: (_) {
        _anchor.clear();
        _dragging = true;
      },
      onReorderEnd: (_) => _dragging = false,
      onReorderItem: (from, to) => _move(group, from, to > from ? to + 1 : to),
      proxyDecorator: (child, index, animation) => Material(
        color: pikoDesign.color('surface'),
        elevation: 2,
        child: child,
      ),
      itemBuilder: rowBuilder,
    );
  }
}
