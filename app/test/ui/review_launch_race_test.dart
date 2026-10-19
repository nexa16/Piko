import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/collections/collection_review_count.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/review_session_route.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant;
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show futureItems, snapshot;

/// Passive production reads, deliberately separate from the displayed count so
/// a competing change can land while the accepted editor drain is pending.
Future<Map<LearningDirection, int>> liveCounts(Fixture f) async {
  final memberships = await Future.wait([
    for (final direction in LearningDirection.values)
      (() async {
        final gateway = await f.learning.forCollection(
          collectionId: f.owner.id,
          direction: direction,
        );
        return gateway.dueMemberships(at: instant);
      })(),
  ]);
  return directionalReviewCounts(memberships.expand((items) => items));
}

void main() {
  for (final detail in [false, true]) {
    launch.testWidgets(
      'REVIEW-002 ${detail ? "Detail fixed reverse" : "Overview sole reverse after a zero first map entry"} '
      'positive display races to authoritative zero and can relaunch fresh work without empty-attempt writes',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        // Initially only reverse is actually due; the first map entry is zero.
        await tester.runAsync(() async {
          final forward = await f.current();
          await f.learning.saveCard(
            forward.id,
            forward.card..due = instant.add(const Duration(days: 7)),
          );
        });
        final barrier = Completer<void>();
        final h = launch.Harness(f)..gate = barrier;
        await h.mountDirectional(
          tester,
          presentation: detail
              ? ReviewLaunchPresentation.collectionCard
              : ReviewLaunchPresentation.collectionQuick,
          counts: {
            LearningDirection.targetToNative: 0,
            LearningDirection.nativeToTarget: 1,
          },
          before: () => barrier.future,
          loader: () => liveCounts(f),
        );
        final action = detail
            ? find.byKey(const ValueKey('collection-review-nativeToTarget'))
            : find.byKey(const ValueKey('collection-review-quick'));
        expect(action, findsOneWidget);
        expect(
          find.byKey(const ValueKey('collection-review-targetToNative')),
          findsNothing,
        );
        await tester.tap(action);
        await tester.pump();
        expect(h.calls, 0); // Membership must be checked after the drain.
        await tester.runAsync(() => futureItems(f, reverseOnly: true));
        final afterCompetingChange = await tester.runAsync(() => snapshot(f));
        barrier.complete();
        await h.finish(tester);

        // A fresh zero result refuses launch before creating any session. The
        // prior empty-session route expectation predates F29's checked starts.
        expect(h.calls, 0);
        expect(h.selections, isEmpty);
        expect(h.sessions, isEmpty);
        expect(find.byType(ReviewDirectionDialog), findsNothing);
        expect(find.byType(ReviewSessionRoute), findsNothing);
        expect(find.byKey(const ValueKey('review-prompt')), findsNothing);
        expect(
          find.byKey(const ValueKey('review-grade-correct')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('review-grade-incorrect')),
          findsNothing,
        );
        expect(await tester.runAsync(() => snapshot(f)), afterCompetingChange);

        // Returning work is another external change, never a launch side effect.
        // The same displayed directional action can now succeed after rechecking.
        await tester.runAsync(() async {
          final reverse = await f.current(null, true);
          await f.learning.saveCard(reverse.id, reverse.card..due = instant);
        });
        final beforeRetry = await tester.runAsync(() => snapshot(f));
        await tester.tap(action);
        await h.finish(tester);
        expect(h.calls, 1);
        expect(h.selections, [LearningDirection.nativeToTarget]);
        expect(h.sessions, hasLength(1));
        expect(h.sessions.last.members.single.entryId, f.entry.id);
        expect(find.byType(ReviewSessionRoute), findsOneWidget);
        expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
        expect(find.byKey(const ValueKey('review-prompt')), findsOneWidget);
        expect(find.byType(ReviewDirectionDialog), findsNothing);
        expect(await tester.runAsync(() => snapshot(f)), beforeRetry);
        expect(tester.takeException(), isNull);
      },
    );
  }

  launch.testWidgets(
    'REVIEW-002 Overview revalidation chooses the actual sole due direction after both were displayed',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final barrier = Completer<void>();
      final h = launch.Harness(f)..gate = barrier;
      await h.mountDirectional(
        tester,
        counts: {
          LearningDirection.targetToNative: 1,
          LearningDirection.nativeToTarget: 1,
        },
        before: () => barrier.future,
        loader: () => liveCounts(f),
      );
      await tester.tap(find.byKey(const ValueKey('collection-review-quick')));
      await tester.pump();
      await tester.runAsync(() async {
        final forward = await f.current();
        await f.learning.saveCard(
          forward.id,
          forward.card..due = instant.add(const Duration(days: 7)),
        );
      });
      final beforePreparation = await tester.runAsync(() => snapshot(f));
      barrier.complete();
      await h.finish(tester);
      expect(h.selections, [LearningDirection.nativeToTarget]);
      expect(find.byType(ReviewDirectionDialog), findsNothing);
      expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
      expect(find.text('DE → FR'), findsOneWidget);
      expect(h.sessions.single.members.single.entryId, f.entry.id);
      expect(await tester.runAsync(() => snapshot(f)), beforePreparation);
      expect(tester.takeException(), isNull);
    },
  );
}
