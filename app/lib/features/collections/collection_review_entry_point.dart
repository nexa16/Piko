import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../data/collections_repository.dart';
import '../../data/vocabulary_repository.dart';
import '../../shared/copy_scope.dart';
import '../../ui/components/piko_button.dart';
import '../../ui/piko_theme.dart';
import '../learning/review_launch.dart';
import 'collection_review_count.dart';

class CollectionReviewEntryPoint extends StatelessWidget {
  const CollectionReviewEntryPoint({
    required this.collection,
    required this.loader,
    required this.policy,
    required this.factory,
    required this.vocabularyRepository,
    required this.beforeLaunch,
    required this.onPendingWrites,
    required this.onBusyChanged,
    required this.presentation,
    this.clock = const SystemPikoClock(),
    this.enabled = true,
    super.key,
  });

  final CollectionRecord collection;
  final CollectionReviewMembershipLoader loader;
  final CollectionReviewCountPolicy policy;
  final ReviewSessionFactory factory;
  final VocabularyRepository vocabularyRepository;
  final Future<void> Function() beforeLaunch;
  final ValueChanged<Future<void>>? onPendingWrites;
  final ValueChanged<bool> onBusyChanged;
  final ReviewLaunchPresentation presentation;
  final PikoClock clock;
  final bool enabled;

  @override
  Widget build(BuildContext context) => CollectionReviewCountBuilder(
    key: ValueKey('collection-review-count-${collection.id}'),
    collectionId: collection.id,
    loader: loader,
    policy: policy,
    clock: clock,
    builder: (context, count, retry) {
      if (count.value != null) {
        return ReviewLaunch(
          collection: collection,
          factory: factory,
          vocabularyRepository: vocabularyRepository,
          beforeLaunch: beforeLaunch,
          onPendingWrites: onPendingWrites,
          onBusyChanged: onBusyChanged,
          presentation: presentation,
          dueCount: count.value,
          enabled: enabled,
          onSessionClosed: retry,
        );
      }
      final copy = PikoCopyScope.of(context);
      final status = count.error == null
          ? copy.text('collection.reviewLoading')
          : copy.text('collection.reviewLoadFailed');
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              style: TextStyle(
                fontSize: pikoDesign.dimension('typography.small'),
                color: pikoDesign.color('muted'),
              ),
            ),
          ),
          if (count.error != null)
            PikoButton(
              label: copy.text('action.retry'),
              variant: PikoButtonVariant.ghost,
              onPressed: count.loading ? null : retry,
            ),
        ],
      );
      if (presentation == ReviewLaunchPresentation.collectionQuick) {
        return SizedBox(
          width: pikoDesign.dimension('components.collectionReview.quickWidth'),
          child: content,
        );
      }
      return content;
    },
  );
}
