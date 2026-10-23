import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// Filter membership is staged. Category ordering belongs to Settings.
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
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _anchor = PikoInteractionAnchor();
  final _searchArea = GlobalKey();
  bool _overflow = false, _measuring = false;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<CategoryValueRecord> _values(String group) =>
      _definitions.categoryValues[group] ?? const [];

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
    if (!_canEdit) return;
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
    return Focus(
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
                  for (final dimension in _definitions.categoryDimensions) ...[
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
    );
  }

  Widget _orderedBody(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final needle = _query.text.trim().toLowerCase();
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
                      crossAxisAlignment: CrossAxisAlignment.end,
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
                _valueSliver(dimension.id, needle),
              ],
              if (_error != null) SliverToBoxAdapter(child: _errorFeedback()),
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
      ],
    );
  }

  Widget _valueSliver(String group, String needle) {
    final copy = PikoCopyScope.of(context);
    final values = _values(
      group,
    ).where((value) => value.name.toLowerCase().contains(needle)).toList();
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
    return SliverList.builder(
      itemCount: values.length,
      itemBuilder: (context, index) {
        final value = values[index];
        return PikoAnchorRegion(
          child: CheckboxListTile(
            key: ValueKey('filter-value-${value.id}'),
            title: Text(value.name),
            value: _draft[group]?.contains(value.id) ?? false,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: !_canEdit
                ? null
                : (selected) => _select(group, value.id, selected == true),
          ),
        );
      },
    );
  }
}
