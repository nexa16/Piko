import '../../data/categories_repository.dart';
import '../../data/learning_reset.dart';
import '../../data/learning_item.dart';
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
    this.categoriesRepository,
    this.learningReset,
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
  final CategoriesRepository? categoriesRepository;
  final LearningResetRepository? learningReset;
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
      final copy = PikoCopyScope.of(context);
      final unknown = count.value == null;
      final counts = unknown
          ? {for (final direction in LearningDirection.values) direction: 0}
          : count.directionCounts;
      final total = counts.values.fold<int>(0, (a, b) => a + b);
      if (!unknown && total == 0 && !count.loading && count.error == null) {
        return count.pendingRetryCount > 0 &&
                presentation != ReviewLaunchPresentation.collectionQuick
            ? Text(copy.text('r2.pending'))
            : const SizedBox.shrink();
      }
      final status = count.error != null
          ? copy.text(
              unknown ? 'collection.reviewLoadFailed' : 'collection.countStale',
            )
          : count.loading
          ? copy.text(
              unknown
                  ? 'collection.reviewLoading'
                  : 'collection.countRefreshing',
            )
          : ' ';
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReviewLaunch(
            collection: collection,
            factory: factory,
            vocabularyRepository: vocabularyRepository,
            categoriesRepository: categoriesRepository,
            learningReset: learningReset,
            beforeLaunch: beforeLaunch,
            onPendingWrites: onPendingWrites,
            onBusyChanged: onBusyChanged,
            presentation: presentation,
            dueCount: total,
            directionCounts: counts,
            countsUnknown: unknown,
            recheckCounts: count.loading || count.error != null,
            directionCountsLoader: () async => directionalReviewCounts(
              await loader(
                collectionId: collection.id,
                at: clock.now().toUtc(),
              ),
            ),
            enabled: enabled,
            onSessionClosed: retry,
          ),
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
      return presentation == ReviewLaunchPresentation.collectionQuick
          ? SizedBox(
              width: pikoDesign.dimension(
                'components.collectionReview.quickWidth',
              ),
              child: content,
            )
          : content;
    },
  );
}
