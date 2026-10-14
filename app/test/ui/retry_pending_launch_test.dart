import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show card, text;

void main() {
  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language active selected-scope retry shows honest preparation failure, not no-due or another regular card; opposite direction remains isolated',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(() => f.review(rating: LearningRating.again));
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester);
        final before = await tester.runAsync(() => snapshot(f)),
            copy = PikoCopy(language);
        await h.open(tester);
        for (var attempt = 0; attempt < 2; attempt++) {
          await tester.tap(launch.button(copy.text('learn.start')));
          await h.finish(tester);
          expect(find.text(copy.text('learn.prepareFailed')), findsOneWidget);
          expect(find.byType(ReviewSessionRoute), findsNothing);
          expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
          expect(card, findsNothing);
          expect(
            tester
                .widget<PikoDropdown<LearningDirection>>(
                  find.byType(PikoDropdown<LearningDirection>),
                )
                .value,
            LearningDirection.targetToNative,
          );
          expect(await tester.runAsync(() => snapshot(f)), before);
        }
        await h.reverse(tester);
        await tester.tap(launch.button(copy.text('learn.start')));
        await h.finish(tester);
        await h.flush(tester);
        expect(find.byType(ReviewSessionRoute), findsOneWidget);
        expect(h.sessions.single.direction, LearningDirection.nativeToTarget);
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
