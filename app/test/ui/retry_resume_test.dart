import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/shared/catalogs.dart';
import '../data/regular_reviews_test.dart' show instant;
import '../data/retry_gap_migration_test.dart' show gateway;
import 'review_launch_test.dart' as launch;
import 'review_grading_test.dart' as grading;
import 'review_prompt_test.dart' show start;
import 'review_no_due_test.dart' show snapshot;

void main() {
  launch.testWidgets(
    'same-day Exit/relaunch preserves partially earned gap; revealed unanswered work neither counts nor resets state',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      for (var index = 0; index < 5; index++) {
        await tester.runAsync(
          () => f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'Other $index',
            nativeText: 'Anders $index',
          ),
        );
      }
      final h = launch.Harness(f);
      await h.mount(tester);
      await start(tester, h);
      await grading.reveal(tester);
      await tester.tap(grading.gradeButton(AnswerGrade.incorrect));
      await h.finish(tester);
      for (var index = 0; index < 3; index++) {
        await grading.reveal(tester);
        await tester.tap(grading.gradeButton(AnswerGrade.correct));
        await h.finish(tester);
      }
      final source = (await tester.runAsync(() => gateway(f.db, f.owner.id)))!;
      final state = (await tester.runAsync(
        () => source.retryState(at: instant),
      ))!;
      expect(state.rounds.single.dueOrdinal - state.scope.ordinal, 17);
      expect(state.rounds.single.waitEligibleAt, isNull);
      expect(h.sessions.single.currentIsRetry, isFalse);
      final before = await tester.runAsync(() => snapshot(f));
      await grading.reveal(tester);
      await tester.tap(launch.button(PikoCopy('en').text('learn.exit')));
      await h.finish(tester);
      expect(await tester.runAsync(() => snapshot(f)), before);
      await start(tester, h);
      await h.flush(tester);
      expect(h.sessions.last.currentIsRetry, isFalse);
      expect(h.sessions.last.members, hasLength(2));
      expect(grading.actions, findsNothing);
      final resumed = (await tester.runAsync(
        () => source.retryState(at: instant),
      ))!;
      expect(resumed.rounds.single.sameStateAs(state.rounds.single), isTrue);
      expect(resumed.scope.sameStateAs(state.scope), isTrue);
      expect(await tester.runAsync(() => snapshot(f)), before);
      await grading.reveal(tester);
      await tester.tap(launch.button(PikoCopy('en').text('learn.exit')));
      await h.finish(tester);
      expect(await tester.runAsync(() => snapshot(f)), before);
      expect(tester.takeException(), isNull);
    },
  );
}
