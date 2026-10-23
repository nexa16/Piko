import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/shared/catalogs.dart';
import 'review_launch_test.dart' as launch;
import 'review_grading_test.dart' as grading;

// Replaces the removed Hard control's alignment and toggle scenarios.
// Historical Hard ratings retain independent storage/scheduler tests.
void main() {
  for (final reverse in [false, true]) {
    for (final grade in AnswerGrade.values) {
      launch.testWidgets(
        'two-grade review direction $reverse records ${grade.name}',
        (tester) async {
          final h = await grading.open(tester, reverse: reverse);
          await grading.reveal(tester);
          expect(find.byKey(const ValueKey('review-hard')), findsNothing);
          expect(find.text(PikoCopy('en').text('learn.hard')), findsNothing);
          expect(find.byType(Checkbox), findsNothing);
          expect(
            h.sessions.single.setHard(h.sessions.single.current!, true),
            isFalse,
          );
          await tester.tap(grading.gradeButton(grade));
          await h.finish(tester);
          expect(
            h.sessions.single.acceptedReviews.single.event.rating,
            grade == AnswerGrade.correct
                ? LearningRating.good
                : LearningRating.again,
          );
        },
      );
    }
  }
}
