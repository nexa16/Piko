import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show card, text;

void main() {
  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language active ineligible retry launches honest pending work with Exit, not no-due or another regular card; opposite direction remains isolated',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(() => f.review(rating: LearningRating.again));
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester);
        final before = await tester.runAsync(() => snapshot(f)),
            copy = PikoCopy(language);
        await h.open(tester);
        await tester.tap(launch.button(copy.text('learn.start')));
        await h.finish(tester);
        expect(find.text(copy.text('learn.retryPending')), findsOneWidget);
        expect(find.text(copy.text('learn.prepareFailed')), findsNothing);
        expect(find.byType(ReviewSessionRoute), findsOneWidget);
        expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
        expect(card, findsNothing);
        expect(h.sessions.single.hasInitialWork, isTrue);
        expect(h.sessions.single.members, isEmpty);
        expect(await tester.runAsync(() => snapshot(f)), before);
        await tester.tap(launch.button(copy.text('learn.exit')));
        await h.finish(tester);
        await h.open(tester);
        await h.reverse(tester);
        await tester.tap(launch.button(copy.text('learn.start')));
        await h.finish(tester);
        await h.flush(tester);
        expect(find.byType(ReviewSessionRoute), findsOneWidget);
        expect(h.sessions.last.direction, LearningDirection.nativeToTarget);
        expect(text(card, tester), ['Eins']);
        expect(await tester.runAsync(() => snapshot(f)), before);
        await tester.tap(launch.button(copy.text('learn.exit')));
        await h.finish(tester);
        expect(await tester.runAsync(() => snapshot(f)), before);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
