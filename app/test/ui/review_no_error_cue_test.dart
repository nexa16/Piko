import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/shared/catalogs.dart';
import '../data/regular_reviews_test.dart' show instant;
import '../data/retry_gap_migration_test.dart' show gateway;
import 'review_launch_test.dart' as launch;
import 'review_grading_test.dart' as grading;
import 'review_prompt_test.dart' show start, text;
import 'review_category_policy_test.dart'
    show assertNoCategoryPresentation, target;
import 'review_no_due_test.dart' show snapshot;

void main() {
  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language prior retry errors are not a visible or semantic question cue; literal numeric vocabulary stays intact',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(
          () => f.vocabulary.update(
            id: f.entry.id,
            targetText: 'Mistakes 3',
            nativeText: 'Fehler 3',
          ),
        );
        final source = (await tester.runAsync(
          () => gateway(f.db, f.owner.id),
        ))!;
        final first = (await tester.runAsync(
          () => f.review(rating: LearningRating.again),
        ))!.retryNext!;
        await tester.runAsync(() => f.makeRetryEligible(first));
        final second = (await tester.runAsync(
          () async => source.answerRetry(
            expectedPrior: await f.current(),
            expectedRetry: first,
            rating: LearningRating.again,
            answeredAt: instant,
          ),
        ))!.retryNext!;
        expect(second.errorCount, 2);
        await tester.runAsync(
          () => f.makeRetryEligible(second),
        ); // Explicit cue fixture, not an earned-gap test.
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester);
        final before = await tester.runAsync(() => snapshot(f)),
            copy = PikoCopy(language);
        final semantics = tester.ensureSemantics();
        try {
          await start(tester, h, language: language);
          expect(h.sessions.single.currentIsRetry, isTrue);
          expect(text(target, tester), [
            'Mistakes 3',
            copy.text('learn.revealCue'),
          ]);
          assertNoCategoryPresentation(
            tester,
            'Mistakes 3',
            copy.text('learn.revealCue'),
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('review-counters')))
                .data,
            copy.text('learn.progress', {
              'completed': 0,
              'total': 1,
              'correct': 0,
            }),
          );
          await grading.reveal(tester);
          expect(text(target, tester), ['Mistakes 3', 'Fehler 3']);
          assertNoCategoryPresentation(tester, 'Mistakes 3\nFehler 3', '');
          expect(await tester.runAsync(() => snapshot(f)), before);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
