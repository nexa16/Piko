import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/piko_theme.dart';
import 'collection_query_binding.dart';
import 'collection_view_preferences.dart';

class CollectionViewControls extends StatelessWidget {
  const CollectionViewControls({
    super.key,
    required this.binding,
    required this.enabled,
  });
  final CollectionQueryBinding binding;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), scope = binding.scope;
    final groups = binding.snapshot == null
        ? <String>[]
        : groupVocabulary(
            binding.snapshot!,
            scope.view,
          ).map((g) => g.id).whereType<String>().toList();
    final available = enabled && binding.ready && !scope.viewPending;
    return Wrap(
      spacing: pikoDesign.dimension('spacing.2'),
      runSpacing: pikoDesign.dimension('spacing.2'),
      children: [
        PikoButton(
          key: const ValueKey('collection-view'),
          label: copy.text('view.title'),
          variant: PikoButtonVariant.ghost,
          onPressed: available
              ? () => showPikoDialog<void>(
                  context,
                  builder: (_) => _ViewDialog(binding: binding),
                )
              : null,
        ),
        if (scope.view.grouping != null) ...[
          PikoButton(
            key: const ValueKey('collection-collapse-all'),
            label: copy.text('view.collapseAll'),
            variant: PikoButtonVariant.ghost,
            onPressed: available && scope.expandedGroups.isNotEmpty
                ? () => scope.expandGroups(groups, false)
                : null,
          ),
          PikoButton(
            key: const ValueKey('collection-expand-all'),
            label: copy.text('view.expandAll'),
            variant: PikoButtonVariant.ghost,
            onPressed:
                available &&
                    groups.any((id) => !scope.expandedGroups.contains(id))
                ? () => scope.expandGroups(groups, true)
                : null,
          ),
        ],
        if (scope.viewError != null) Text(copy.text('entry.saveFailed')),
      ],
    );
  }
}

class _ViewDialog extends StatefulWidget {
  const _ViewDialog({required this.binding});
  final CollectionQueryBinding binding;
  @override
  State<_ViewDialog> createState() => _ViewDialogState();
}

class _ViewDialogState extends State<_ViewDialog> {
  late var mode = widget.binding.scope.view.mode;
  late var targetFirst = widget.binding.scope.view.targetFirst;
  late var grouping = widget.binding.scope.view.grouping;
  late var sort = widget.binding.scope.view.sort;
  bool pending = false;
  Object? error;
  CollectionViewPreferences get draft => CollectionViewPreferences(
    mode: mode,
    targetFirst: targetFirst,
    grouping: grouping,
    sort: sort,
  );
  Future<void> apply() async {
    if (pending) return;
    setState(() {
      pending = true;
      error = null;
    });
    final scope = widget.binding.scope;
    // A dimension can be deleted while the chooser is open.
    if (grouping != null &&
        !widget.binding.snapshot!.categoryDimensions.any(
          (d) => d.id == grouping,
        )) {
      grouping = null;
    }
    await scope.saveView(draft);
    if (!mounted) return;
    if (scope.viewError == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        pending = false;
        error = scope.viewError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    Widget choice<T>(
      String key,
      T value,
      List<(T, String)> options,
      void Function(T) select,
    ) => Padding(
      padding: EdgeInsets.only(bottom: pikoDesign.dimension('spacing.4')),
      child: DropdownButtonFormField<T>(
        key: ValueKey(key),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: copy.text(key)),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option.$1, child: Text(option.$2)),
        ],
        onChanged: pending
            ? null
            : (v) {
                if (v != null) setState(() => select(v));
              },
      ),
    );
    return PikoDialog(
      title: copy.text('view.title'),
      purpose: PikoDialogPurpose.selection,
      dismissible: !pending,
      onClose: pending ? null : () => Navigator.of(context).pop(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          choice('view.mode', mode, [
            for (final v in VocabularyViewMode.values)
              (v, copy.text('view.${v.name}')),
          ], (v) => mode = v),
          choice('view.languageOrder', targetFirst, [
            (true, copy.text('view.targetFirst')),
            (false, copy.text('view.nativeFirst')),
          ], (v) => targetFirst = v),
          choice('view.grouping', grouping ?? '', [
            ('', copy.text('view.ungrouped')),
            for (final d in widget.binding.snapshot!.categoryDimensions)
              (d.id, d.name),
          ], (v) => grouping = v.isEmpty ? null : v),
          choice('view.sort', sort, [
            for (final v in VocabularySort.values)
              (v, copy.text('view.sort.${v.name}')),
          ], (v) => sort = v),
          if (error != null) Text(copy.text('entry.saveFailed')),
        ],
      ),
      actions: [
        PikoDialogAction(
          label: copy.text('r2.apply'),
          onPressed: !pending && draft != widget.binding.scope.view
              ? apply
              : null,
        ),
      ],
    );
  }
}
