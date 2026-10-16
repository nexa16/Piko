import 'dart:ui' show SemanticsRole;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/piko_theme.dart';
import 'review_launch_test.dart' as launch;
import 'review_grading_test.dart' as grading;
import 'review_prompt_test.dart' show card;

void main() {
  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language binding above-card counters/progress remain readable and semantic at 320px/200%',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(
          () => f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'Next',
            nativeText: 'Weiter',
          ),
        );
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester, scale: 2);
        tester.view.physicalSize = const Size(320, 900);
        await tester.pump();
        await h.open(tester);
        await tester.tap(launch.button(PikoCopy(language).text('learn.start')));
        await h.finish(tester);
        await h.flush(tester);
        final copy = PikoCopy(language), session = h.sessions.single;
        final counter = find.byKey(const ValueKey('review-counters')),
            progress = find.byKey(const ValueKey('review-progress'));
        expect(
          tester.widget<Semantics>(counter).properties.label,
          copy.text('learn.progress', {
            'completed': 0,
            'total': 2,
            'correct': 0,
          }),
        );
        final semantics = tester.ensureSemantics();
        try {
          final node = tester.getSemantics(progress);
          expect(node.getSemanticsData().role, SemanticsRole.progressBar);
          expect(node.label, contains(copy.text('learn.progressLabel')));
          expect(node.label, contains(tester.widget<Semantics>(counter).properties.label));
          expect(node.value, '0');
          final bar = tester.getRect(progress),
              counters = tester.getRect(counter),
              prompt = tester.getRect(card);
          expect(
            bar.height,
            pikoDesign.dimension('components.progress.height'),
          );
          expect(
            bar.top - counters.bottom,
            closeTo(pikoDesign.dimension('components.progress.marginY'), .01),
          );
          expect(
            prompt.top - bar.bottom,
            closeTo(pikoDesign.dimension('components.progress.marginY'), .01),
          );
          expect(bar.left, prompt.left);
          expect(bar.right, prompt.right);
          expect(counters.left, greaterThanOrEqualTo(prompt.left));
          expect(counters.right, closeTo(prompt.right, .01));
          expect(
            tester
                .getSize(find.byKey(const ValueKey('review-progress-fill')))
                .width,
            0,
          );
          expect(
            tester.getSize(find.byKey(const ValueKey('review-progress-fill'))).height,
            bar.height,
          );
          await tester.ensureVisible(card);
          await grading.reveal(tester);
          expect(session.progress.completed, 0);
          await tester.ensureVisible(grading.gradeButton(AnswerGrade.correct));
          await tester.tap(grading.gradeButton(AnswerGrade.correct));
          await h.finish(tester);
          await h.flush(tester);
          expect(
            tester.widget<Semantics>(counter).properties.label,
            copy.text('learn.progress', {
              'completed': 1,
              'total': 2,
              'correct': 1,
            }),
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('review-progress-fill')))
                .width,
            closeTo(tester.getSize(progress).width / 2, .01),
          );
          expect(
            tester.getSize(find.byKey(const ValueKey('review-progress-fill'))).height,
            tester.getSize(progress).height,
          );
          await tester.ensureVisible(card);
          await grading.reveal(tester);
          await tester.ensureVisible(grading.gradeButton(AnswerGrade.correct));
          await tester.tap(grading.gradeButton(AnswerGrade.correct));
          await h.finish(tester);
          final filled = tester.getSize(find.byKey(const ValueKey('review-progress-fill')));
          expect(filled.width, closeTo(tester.getSize(progress).width, .01));
          expect(filled.height, tester.getSize(progress).height);
          expect(session.progress.completed, 2);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
