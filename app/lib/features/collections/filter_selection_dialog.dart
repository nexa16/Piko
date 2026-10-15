import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/collection_query.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';

typedef CollectionFilterSelection = Map<String, Set<String>>;

/// Read-only category constraints: the parent receives a result only after an
/// explicit Apply. Search is intentionally outside this popup's ownership.
class FilterSelectionDialog extends StatefulWidget {
  const FilterSelectionDialog({
    required this.snapshot,
    required this.opening,
    required this.reloadDefinitions,
    required this.canApply,
    this.onPendingWrites,
    this.onClose,
    super.key,
  });
  final CollectionQuerySnapshot snapshot;
  final CollectionFilterSelection opening;
  final Future<CollectionQuerySnapshot> Function() reloadDefinitions;
  final bool Function() canApply;
  final ValueChanged<Future<void>>? onPendingWrites;
  final VoidCallback? onClose;
  @override
  State<FilterSelectionDialog> createState() => _FilterSelectionDialogState();
}

class _FilterSelectionDialogState extends State<FilterSelectionDialog> {
  late CollectionQuerySnapshot _definitions = widget.snapshot;
  late final CollectionFilterSelection _opening = _copy(widget.opening);
  late CollectionFilterSelection _draft = _copy(widget.opening);
  bool _pending = false;
  String? _error;
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
          ModalRoute.of(context)?.isCurrent != true)
        return;
      if (fresh.collection.id != widget.snapshot.collection.id)
        throw StateError('Changed Collection');
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_definitions.categoryDimensions.isEmpty)
              Text(copy.text('r2.noCategories')),
            for (final dimension in _definitions.categoryDimensions) ...[
              Text(
                dimension.name,
                style: TextStyle(
                  fontWeight: pikoDesign.weight('components.buttons.weight'),
                ),
              ),
              for (final value
                  in _definitions.categoryValues[dimension.id] ?? const [])
                CheckboxListTile(
                  key: ValueKey('filter-value-${value.id}'),
                  title: Text(value.name),
                  value: _draft[dimension.id]?.contains(value.id) ?? false,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: !_canEdit
                      ? null
                      : (selected) =>
                            _select(dimension.id, value.id, selected == true),
                ),
              SizedBox(height: pikoDesign.dimension('spacing.2')),
            ],
            if (_draft.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: PikoButton(
                  key: const ValueKey('filters-clear-pending'),
                  label: copy.text('r2.clearFilters'),
                  variant: PikoButtonVariant.ghost,
                  onPressed: !_canEdit
                      ? null
                      : () => setState(() {
                          _draft = {};
                          _error = null;
                        }),
                ),
              ),
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
          if (_changed)
            PikoDialogAction(
              label: copy.text('r2.apply'),
              icon: const PikoIcon(PikoIconName.check),
              onPressed: _canEdit ? _apply : null,
            ),
        ],
      ),
    );
  }
}
