import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/learning_session_progress.dart';
import 'package:piko/features/learning/review_progress.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/ui/piko_theme.dart';
import 'review_launch_test.dart' as launch;
import 'review_grading_test.dart' as grading;

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language progress direction has its own row and metric groups reflow at 320px/200%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final copy = PikoCopy(language);
        await tester.pumpWidget(
          PikoCopyScope(
            copy: copy,
            child: MaterialApp(
              theme: PikoTheme.build(),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(18),
                    child: ReviewProgress(
                      direction: 'KO → DE',
                      progress: LearningSessionProgress(
                        members: const {
                          (itemId: 1, generation: 0),
                          (itemId: 2, generation: 0),
                        },
                        completed: const {(itemId: 1, generation: 0)},
                        firstTry: const {(itemId: 1, generation: 0)},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final direction = tester.getRect(
          find.byKey(const ValueKey('review-fixed-direction')),
        );
        final completed = find.byKey(const ValueKey('review-completed-group'));
        final firstTry = find.byKey(const ValueKey('review-first-try-group'));
        expect(
          tester.widget<Text>(completed).data,
          copy.text('learn.completedGroup', {'completed': 1, 'total': 2}),
        );
        expect(
          tester.widget<Text>(firstTry).data,
          copy.text('learn.firstTryGroup', {'correct': 1}),
        );
        expect(tester.getRect(completed).top, greaterThan(direction.bottom));
        expect(
          tester.getRect(firstTry).top,
          greaterThan(tester.getRect(completed).bottom),
        );
        for (final group in [completed, firstTry]) {
          expect(tester.getRect(group).left, greaterThanOrEqualTo(18));
          expect(tester.getRect(group).right, lessThanOrEqualTo(302));
        }
        expect(tester.takeException(), isNull);
      },
    );

    for (final rating in ['incorrect', 'correct', 'hard']) {
      launch.testWidgets(
        '$language correction explicitly names previous $rating grade',
        (tester) async {
          final h = await grading.open(tester, language: language);
          final copy = PikoCopy(language);
          await grading.reveal(tester);
          if (rating == 'hard') {
            final session = h.sessions.single;
            session.setHard(session.current!, true);
            await tester.pump();
          }
          await tester.tap(
            grading.gradeButton(
              rating == 'incorrect'
                  ? AnswerGrade.incorrect
                  : AnswerGrade.correct,
            ),
          );
          await h.finish(tester);
          final correction = find.byKey(
            const ValueKey('review-correct-previous'),
          );
          expect(correction, findsOneWidget);
          await tester.ensureVisible(correction);
          await tester.tap(correction);
          await tester.pumpAndSettle();
          final grade = copy.text(
            rating == 'hard' ? 'learn.hard' : 'action.$rating',
          );
          expect(
            find.text(copy.text('learn.previousGrade', {'grade': grade})),
            findsOneWidget,
          );
          expect(correction, findsNothing);
          expect(h.sessions.single.isCorrecting, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
