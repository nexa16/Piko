import 'package:flutter/material.dart';
import '../../data/collection_query.dart';
import '../../data/collections_repository.dart';
import '../../data/learning_item.dart';
import '../../data/vocabulary_learning_status.dart';
import '../../shared/copy_scope.dart';
import '../../ui/piko_theme.dart';
import '../learning/review_launch.dart' show reviewDirectionLabel;

/// Read-only display of the authoritative directional projection. Missing data
/// does not imply a New word; category tags remain a separate content block.
class VocabularyLearningStatusView extends StatelessWidget {
  const VocabularyLearningStatusView({
    required this.collection,
    required this.entryId,
    required this.snapshot,
    required this.directions,
    super.key,
  });
  final CollectionRecord collection;
  final String entryId;
  final CollectionQuerySnapshot? snapshot;
  final Set<LearningDirection> directions;

  @override
  Widget build(BuildContext context) {
    final copy = PikoCopyScope.of(context);
    final localizations = MaterialLocalizations.of(context);
    final labels = <Widget>[];
    for (final direction in LearningDirection.values.where(
      directions.contains,
    )) {
      final status = snapshot?.directions[direction]?.statuses[entryId];
      if (status == null) continue;
      final String label;
      switch (status.kind) {
        case VocabularyLearningStatusKind.pendingRetry:
          label = copy.text('vocab.statusRetryPending');
        case VocabularyLearningStatusKind.newWord:
          label = copy.text('vocab.statusNew');
        case VocabularyLearningStatusKind.due:
          label = copy.text('vocab.statusDue');
        case VocabularyLearningStatusKind.nextReview:
          final at = status.nextReviewAt?.toLocal();
          if (at == null) continue;
          label = copy.text('vocab.statusNext', {
            'date': localizations.formatMediumDate(at),
            'time': localizations.formatTimeOfDay(
              TimeOfDay.fromDateTime(at),
              alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                context,
              ),
            ),
          });
      }
      final description = directions.length == 1
          ? label
          : '${reviewDirectionLabel(collection, direction)} · $label';
      labels.add(
        Text(
          status.speedCompleted
              ? '$description · ${copy.text('vocab.statusSpeedCompleted')}'
              : description,
          key: ValueKey('vocabulary-status-$entryId-${direction.name}'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: pikoDesign.dimension('spacing.2')),
      child: Column(
        key: ValueKey('vocabulary-status-$entryId'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: labels,
      ),
    );
  }
}
