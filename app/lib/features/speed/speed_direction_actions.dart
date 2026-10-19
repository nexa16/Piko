import 'package:flutter/material.dart';
import '../../data/collections_repository.dart';
import '../../data/learning_item.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/components/piko_icon.dart';
import '../../ui/piko_theme.dart';
import '../learning/review_launch.dart' show reviewDirectionLabel;

/// The same directional label, icon, target and semantics for automatic and selected Speed.
class SpeedDirectionActions extends StatelessWidget {
  const SpeedDirectionActions({
    super.key,
    required this.collection,
    required this.counts,
    this.onPressed,
  });
  final CollectionRecord collection;
  final Map<LearningDirection, int> counts;
  final ValueChanged<LearningDirection>? onPressed;
  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context), d = pikoDesign;
    final available = LearningDirection.values
        .where(counts.containsKey)
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();
    Widget action(LearningDirection direction) {
      final count = counts[direction]!;
      final label = reviewDirectionLabel(collection, direction);
      final activate = count > 0 && onPressed != null
          ? () => onPressed!(direction)
          : null;
      return Semantics(
        button: true,
        enabled: activate != null,
        label: count == 1
            ? copy.text('r2.speedDirectionOne', {'direction': label})
            : copy.text('r2.speedDirectionAction', {
                'direction': label,
                'count': count,
              }),
        onTap: activate,
        child: ExcludeSemantics(
          child: PikoButton(
            key: ValueKey('collection-speed-${direction.name}'),
            label:
                '${copy.text('action.speed')}\n${copy.text('r2.speedDirectionCount', {'direction': label, 'count': count})}',
            variant: PikoButtonVariant.speed,
            icon: const PikoIcon(PikoIconName.zap),
            expandLabel: true,
            labelAlignment: TextAlign.left,
            onPressed: activate,
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        key: const ValueKey('collection-speed-actions'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: action(available.first)),
          SizedBox(width: d.dimension('spacing.2')),
          Expanded(
            child: available.length > 1
                ? action(available[1])
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
