import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show start, text;

final target = find.byKey(const ValueKey('review-reveal-target'));
const targetText = 'Question #topic';
const nativeText = 'Answer #Thema';

void main() {
  for (final language in ['en', 'de']) {
    for (final reverse in [false, true]) {
      launch.testWidgets(
        '$language ${reverse ? "native" : "target"} hidden and revealed cards omit category UI without stripping literal label or hashtag vocabulary',
        (tester) async {
          final f = launch.fixture();
          await tester.runAsync(f.initialize);
          await tester.runAsync(
            () => f.vocabulary.update(
              id: f.entry.id,
              targetText: targetText,
              nativeText: nativeText,
            ),
          );
          final h = launch.Harness(f)..locale.value = Locale(language);
          await h.mount(tester);
          final before = await tester.runAsync(() => snapshot(f));
          final prompt = reverse ? nativeText : targetText;
          final answer = reverse ? targetText : nativeText;
          final copy = PikoCopy(language);
          final semantics = tester.ensureSemantics();
          try {
            for (var launchIndex = 0; launchIndex < 2; launchIndex++) {
              await start(tester, h, reverse: reverse, language: language);
              expect(h.sessions.last.current!.item.entryId, f.entry.id);
              expect(text(target, tester), [
                prompt,
                copy.text('learn.revealCue'),
              ]);
              expect(
                find.byKey(const ValueKey('review-answer-text')),
                findsNothing,
              );
              assertNoCategoryPresentation(
                tester,
                prompt,
                copy.text('learn.revealCue'),
              );

              await tester.tap(
                find.byKey(const ValueKey('review-prompt-text')),
              );
              await tester.pumpAndSettle();
              expect(text(target, tester), [prompt, answer]);
              assertNoCategoryPresentation(tester, '$prompt\n$answer', '');
              expect(await tester.runAsync(() => snapshot(f)), before);

              await tester.tap(launch.button(copy.text('learn.exit')));
              await h.finish(tester);
              expect(find.byType(ReviewSessionRoute), findsNothing);
              expect(await tester.runAsync(() => snapshot(f)), before);
            }
          } finally {
            semantics.dispose();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void assertNoCategoryPresentation(
  WidgetTester tester,
  String label,
  String hint,
) {
  // Exact text/semantic content also catches custom pill or placeholder labels,
  // without treating user-authored hashtags or Question/Answer as UI metadata.
  expect(
    find.descendant(of: target, matching: find.byType(RawChip)),
    findsNothing,
  );
  expect(
    find.descendant(of: target, matching: find.byType(PikoButton)),
    findsNothing,
  );
  final node = tester.getSemantics(target);
  expect(node.label, label);
  expect(node.hint, hint);
  expect(node.flagsCollection.isHeader, isFalse);
  var children = 0;
  node.visitChildren((child) {
    children++;
    return true;
  });
  expect(children, 0);
}
