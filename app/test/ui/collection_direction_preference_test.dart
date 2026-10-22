import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/data/vocabulary_learning_status.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_compact_action.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/settings/preferred_direction_controller.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../features/preferred_direction_controller_test.dart'
    show HeldDirectionSettings;
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner, one;
import 'collection_query_detail_test.dart' show ProjectionService, projection;
import 'collection_review_entry_points_test.dart' show Collections;
import 'collection_speed_launch_test.dart' show DetailSpeedHarness;

Finder action(String mode, LearningDirection direction) => find.byKey(
  ValueKey('collection-$mode-${direction.name}'),
  skipOffstage: false,
);

CollectionQuerySnapshot bothDirections() {
  final base = projection(forward: 1, reverse: 1);
  return CollectionQuerySnapshot(
    collection: base.collection,
    allEntries: base.allEntries,
    entries: base.entries,
    categoryDimensions: base.categoryDimensions,
    categoryValues: base.categoryValues,
    assignments: base.assignments,
    directions: {
      for (final direction in LearningDirection.values)
        direction: CollectionDirectionSnapshot(
          review: base.directions[direction]!.review,
          statuses: {
            one.id: const VocabularyLearningStatus(
              kind: VocabularyLearningStatusKind.newWord,
            ),
          },
          newSpeedItems: [
            LearningItemRecord(
              id: direction.index + 1,
              entryId: one.id,
              direction: direction,
              formatVersion: 1,
              cardJson: LearningCardCodec.encode(
                LearningScheduler().initialCard(
                  itemId: direction.index + 1,
                  at: DateTime.utc(2026),
                ),
              ),
            ),
          ],
        ),
    },
  );
}

void main() {
  testWidgets(
    'Detail changes directional launch owners, compact counts and statuses live without altering snapshot',
    (tester) async {
      tester.view.physicalSize = const Size(800, 450);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = HeldDirectionSettings('both');
      final preference = PreferredDirectionController(
        repository: repository,
        registerPending: (_) {},
      );
      final directionBinding = ValueNotifier<PreferredDirectionController?>(
        preference,
      );
      final vocabulary = LiveVocabulary();
      final scope = CollectionViewScope();
      await scope.saveView(
        const CollectionViewPreferences(mode: VocabularyViewMode.detailed),
      );
      final source = bothDirections();
      final projectionService = ProjectionService(source);
      final binding = CollectionQueryBinding(
        collectionId: owner.id,
        service: projectionService,
        scope: scope,
        invalidations: const Stream<void>.empty(),
      );
      final speed = DetailSpeedHarness();
      final reviews = <LearningDirection>[];
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        binding.dispose();
        scope.dispose();
        directionBinding.dispose();
        preference.dispose();
        speed.binding.dispose();
        speed.scope.dispose();
        await vocabulary.close();
        await speed.vocabulary.close();
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: const Collections([owner]),
            collectionId: owner.id,
            vocabularyRepository: vocabulary,
            queryBinding: binding,
            directionBinding: directionBinding,
            speedSessionFactory: speed.prepare,
            reviewSessionFactory: (_, direction) async {
              reviews.add(direction);
              throw StateError('Unexpected stale launch');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Unknown preferences retain the F29 action shell without allowing a
      // launch or inventing a settled zero count.
      for (final direction in LearningDirection.values) {
        final review = action('review', direction);
        expect(review, findsOneWidget);
        expect(tester.widget<PikoButton>(review).onPressed, isNull);
      }
      expect(find.textContaining('…'), findsWidgets);
      expect(reviews, isEmpty);
      expect(speed.requests, isEmpty);
      expect(find.byKey(ValueKey('vocabulary-status-${one.id}')), findsNothing);
      await preference.load();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('vocabulary-status-${one.id}-targetToNative')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      for (final direction in LearningDirection.values) {
        expect(action('review', direction), findsOneWidget);
        expect(action('speed', direction), findsOneWidget);
        expect(
          find.byKey(ValueKey('vocabulary-status-${one.id}-${direction.name}')),
          findsOneWidget,
        );
      }
      final staleReview = tester
          .widget<PikoButton>(
            action('review', LearningDirection.targetToNative),
          )
          .onPressed!;
      final staleSpeed = tester
          .widget<PikoButton>(action('speed', LearningDirection.targetToNative))
          .onPressed!;
      await preference.select(PreferredDirection.nativeToTarget);
      await tester.pumpAndSettle();
      expect(action('review', LearningDirection.targetToNative), findsNothing);
      expect(action('speed', LearningDirection.targetToNative), findsNothing);
      expect(
        action('review', LearningDirection.nativeToTarget),
        findsOneWidget,
      );
      expect(action('speed', LearningDirection.nativeToTarget), findsOneWidget);
      final speedRect = tester.getRect(
        action('speed', LearningDirection.nativeToTarget),
      );
      final speedRow = tester.getRect(
        find.byKey(
          const ValueKey('collection-speed-actions'),
          skipOffstage: false,
        ),
      );
      expect(speedRect.left, speedRow.left);
      expect(speedRect.width, closeTo((speedRow.width - 8) / 2, .01));
      final status = tester.widget<Text>(
        find.byKey(ValueKey('vocabulary-status-${one.id}-nativeToTarget')),
      );
      expect(status.data!.contains('→'), isFalse);
      await scope.saveView(
        const CollectionViewPreferences(mode: VocabularyViewMode.compact),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('vocabulary-status-${one.id}-nativeToTarget')),
        findsNothing,
      );
      await scope.saveView(
        const CollectionViewPreferences(mode: VocabularyViewMode.detailed),
      );
      await tester.pumpAndSettle();
      staleReview();
      staleSpeed();
      await tester.pumpAndSettle();
      expect(reviews, isEmpty);
      expect(speed.requests, isEmpty);
      expect(identical(binding.snapshot, source), isTrue);
      expect(source.directions.values.map((direction) => direction.dueCount), [
        1,
        1,
      ]);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      for (final mode in ['review', 'speed']) {
        final compact = find.byKey(ValueKey('collection-$mode-compact'));
        expect(compact.hitTestable(), findsOneWidget);
        expect(tester.widget<CollectionCompactAction>(compact).count, '1');
      }
      await tester.tap(find.byKey(const ValueKey('collection-speed-compact')));
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      await preference.select(PreferredDirection.targetToNative);
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsNothing);
      expect(speed.requests, isEmpty);
      expect(
        action('review', LearningDirection.targetToNative),
        findsOneWidget,
      );
      expect(action('review', LearningDirection.nativeToTarget), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
