import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';

/// Settings-only ordering composition shared by group and Value management.
class CategoryOrderList<T> extends StatelessWidget {
  const CategoryOrderList({
    required this.items,
    required this.id,
    required this.label,
    required this.row,
    required this.onMove,
    required this.enabled,
    super.key,
  });
  final List<T> items;
  final String Function(T) id, label;
  final Widget Function(T) row;
  final void Function(int from, int to) onMove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: (from, to) {
        if (enabled) onMove(from, to);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        void move(int to) {
          if (enabled) onMove(index, to);
        }

        return Semantics(
          key: ValueKey('category-order-${id(item)}'),
          customSemanticsActions: {
            if (enabled && index > 0)
              CustomSemanticsAction(label: copy.text('category.moveUp')): () =>
                  move(index - 1),
            if (enabled && index + 1 < items.length)
              CustomSemanticsAction(
                label: copy.text('category.moveDown'),
              ): () =>
                  move(index + 1),
          },
          child: Row(
            children: [
              Expanded(child: row(item)),
              ReorderableDragStartListener(
                index: index,
                enabled: enabled,
                child: PopupMenuButton<int>(
                  key: ValueKey('category-order-menu-${id(item)}'),
                  enabled: enabled,
                  tooltip: copy.text('category.reorder', {
                    'value': label(item),
                  }),
                  icon: const PikoIcon(PikoIconName.ellipsis),
                  iconColor: pikoDesign.color('primary'),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: -1,
                      enabled: index > 0,
                      child: Text(copy.text('category.moveUp')),
                    ),
                    PopupMenuItem(
                      value: 1,
                      enabled: index + 1 < items.length,
                      child: Text(copy.text('category.moveDown')),
                    ),
                  ],
                  onSelected: (direction) => move(index + direction),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
