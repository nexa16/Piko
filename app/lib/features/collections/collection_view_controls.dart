import 'package:flutter/material.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_dialog.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/components/piko_interaction_anchor.dart';
import 'collection_list_chip.dart';
import '../../ui/piko_theme.dart';
import 'collection_query_binding.dart';
import 'collection_view_preferences.dart';

enum CollectionViewPicker { mode, languageOrder, grouping, sort }

Future<void> showCollectionViewPicker(
  BuildContext context,
  CollectionQueryBinding binding,
  CollectionViewPicker picker,
) => showPikoDialog<void>(
  context,
  builder: (_) => _ViewDialog(binding: binding, picker: picker),
);

class CollectionViewControls extends StatelessWidget {
  const CollectionViewControls({
    super.key,
    required this.binding,
    required this.enabled,
    this.onFilters,
  });
  final CollectionQueryBinding binding;
  final bool enabled;
  final VoidCallback? onFilters;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), scope = binding.scope;
    final available = enabled && binding.ready && !scope.viewPending;
    final count = scope.filters.values.expand((v) => v).toSet().length;
    final maximum =
        binding.snapshot?.categoryValues.values.expand((v) => v).length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: pikoDesign.dimension('spacing.2'),
          runSpacing: pikoDesign.dimension('spacing.2'),
          children: [
            CollectionListChip(
              key: const ValueKey('collection-filters'),
              label: copy.text('action.filters'),
              count: count,
              countCapacity: maximum,
              active: count > 0,
              resetLabel: copy.text('r2.clearFilters'),
              onOpen: available ? onFilters : null,
              onReset: available ? () => scope.setFilters(const {}) : null,
            ),
            CollectionListChip(
              key: const ValueKey('collection-group'),
              label: copy.text('list.group'),
              active: scope.view.grouping != null,
              resetLabel: copy.text('list.clearGrouping'),
              onOpen: available
                  ? () => showCollectionViewPicker(
                      context,
                      binding,
                      CollectionViewPicker.grouping,
                    )
                  : null,
              onReset: available
                  ? () => scope.saveView(
                      CollectionViewPreferences(
                        mode: scope.view.mode,
                        targetFirst: scope.view.targetFirst,
                        sort: scope.view.sort,
                      ),
                    )
                  : null,
            ),
            CollectionListChip(
              key: const ValueKey('collection-sort'),
              label: copy.text('list.sort'),
              active: scope.view.sort != VocabularySort.original,
              resetLabel: copy.text('list.resetSort'),
              onOpen: available
                  ? () => showCollectionViewPicker(
                      context,
                      binding,
                      CollectionViewPicker.sort,
                    )
                  : null,
              onReset: available
                  ? () => scope.saveView(
                      CollectionViewPreferences(
                        mode: scope.view.mode,
                        targetFirst: scope.view.targetFirst,
                        grouping: scope.view.grouping,
                      ),
                    )
                  : null,
            ),
          ],
        ),
        if (scope.viewError != null) Text(copy.text('entry.saveFailed')),
      ],
    );
  }
}

class CollectionListMenu extends StatelessWidget {
  const CollectionListMenu({
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
    return PikoAnchorRegion(
      child: Builder(
        builder: (anchorContext) => PopupMenuButton<String>(
          key: const ValueKey('collection-list-menu'),
          tooltip: copy.text('list.options'),
          enabled: available,
          onOpened: () => PikoAnchorRegion.capture(anchorContext),
          icon: const RotatedBox(
            quarterTurns: 1,
            child: PikoIcon(PikoIconName.ellipsis),
          ),
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'mode',
              child: Text(
                '${copy.text('view.mode')}\n${copy.text('view.${scope.view.mode.name}')}',
              ),
            ),
            PopupMenuItem(
              value: 'languageOrder',
              child: Text(
                '${copy.text('view.languageOrder')}\n${copy.text(scope.view.targetFirst ? 'view.targetFirst' : 'view.nativeFirst')}',
              ),
            ),
            if (scope.view.grouping != null) ...[
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                enabled: false,
                child: Text(copy.text('list.groups')),
              ),
              PopupMenuItem(
                value: 'expand',
                enabled: groups.any((id) => !scope.expandedGroups.contains(id)),
                child: Text(copy.text('view.expandAll')),
              ),
              PopupMenuItem(
                value: 'collapse',
                enabled: groups.any(scope.expandedGroups.contains),
                child: Text(copy.text('view.collapseAll')),
              ),
            ],
          ],
          onSelected: (value) {
            if (value == 'expand' || value == 'collapse') {
              scope.expandGroups(groups, value == 'expand');
            } else {
              showCollectionViewPicker(
                context,
                binding,
                value == 'mode'
                    ? CollectionViewPicker.mode
                    : CollectionViewPicker.languageOrder,
              );
            }
          },
        ),
      ),
    );
  }
}

class CollectionListResults extends StatelessWidget {
  const CollectionListResults({
    super.key,
    required this.binding,
    required this.enabled,
  });
  final CollectionQueryBinding binding;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context),
        scope = binding.scope,
        snapshot = binding.snapshot;
    final groups = snapshot == null
        ? <String>[]
        : groupVocabulary(
            snapshot,
            scope.view,
          ).map((g) => g.id).whereType<String>().toList();
    final expand = groups.any((id) => !scope.expandedGroups.contains(id));
    return Column(
      children: [
        Divider(
          color: pikoDesign
              .color('muted')
              .withValues(
                alpha: pikoDesign.dimension(
                  'components.collectionList.outlineOpacity',
                ),
              ),
        ),
        SizedBox(
          key: const ValueKey('collection-list-results'),
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                copy.text('list.resultCount', {
                  'count': snapshot?.entries.length ?? 0,
                  'total': snapshot?.allEntries.length ?? 0,
                }),
                style: TextStyle(color: pikoDesign.color('muted')),
              ),
              if (scope.view.grouping != null)
                PikoAnchorRegion(
                  child: Builder(
                    builder: (anchorContext) => PikoButton(
                      key: const ValueKey('collection-toggle-groups'),
                      label: copy.text(
                        expand ? 'view.expandAll' : 'view.collapseAll',
                      ),
                      variant: PikoButtonVariant.ghost,
                      onPressed: enabled && binding.ready && groups.isNotEmpty
                          ? () {
                              PikoAnchorRegion.capture(anchorContext);
                              scope.expandGroups(groups, expand);
                            }
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ViewDialog extends StatefulWidget {
  const _ViewDialog({required this.binding, required this.picker});
  final CollectionViewPicker picker;
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
    ) => RadioGroup<T>(
      groupValue: value,
      onChanged: (next) {
        if (!pending && next != null) setState(() => select(next));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            RadioListTile<T>(
              key: ValueKey('$key-${option.$1}'),
              value: option.$1,
              title: Text(option.$2),
              enabled: !pending,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
    return PikoDialog(
      title: copy.text('view.${widget.picker.name}'),
      purpose: PikoDialogPurpose.selection,
      dismissible: !pending,
      onClose: pending ? null : () => Navigator.of(context).pop(),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.picker == CollectionViewPicker.mode)
            choice('view.mode', mode, [
              for (final v in VocabularyViewMode.values)
                (v, copy.text('view.${v.name}')),
            ], (v) => mode = v),
          if (widget.picker == CollectionViewPicker.languageOrder)
            choice('view.languageOrder', targetFirst, [
              (true, copy.text('view.targetFirst')),
              (false, copy.text('view.nativeFirst')),
            ], (v) => targetFirst = v),
          if (widget.picker == CollectionViewPicker.grouping)
            choice('view.grouping', grouping ?? '', [
              ('', copy.text('view.ungrouped')),
              for (final d in widget.binding.snapshot!.categoryDimensions)
                (d.id, d.name),
            ], (v) => grouping = v.isEmpty ? null : v),
          if (widget.picker == CollectionViewPicker.sort)
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
          icon: const PikoIcon(PikoIconName.check),
          onPressed: !pending && draft != widget.binding.scope.view
              ? apply
              : null,
        ),
      ],
    );
  }
}
