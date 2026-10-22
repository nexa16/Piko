import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/learning_session_progress.dart';
import 'package:piko/features/learning/review_progress.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'package:piko/ui/piko_theme.dart';

String progressDescription(PikoCopy copy, Map<String, Object> counts) =>
    '${copy.text('learn.progress', counts)} · ${copy.text('learn.totalRetries', {'count': 0})}';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Reproduce the real glyph widths rather than the widget-test Ahem font.
    await (FontLoader(
      'Piko Nunito Sans',
    )..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'))).load();
  });

  for (final language in ['en', 'de']) {
    for (final scale in [1.0, 2.0]) {
      for (final correct in [0, 1, 23]) {
        testWidgets(
          'F08 $language 320dp/${scale}x keeps final first-try words together with $correct correct',
          (tester) async {
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final semantics = tester.ensureSemantics();
            try {
              final copy = PikoCopy(language);
              final members = {
                for (var i = 0; i < 30; i++) (itemId: i, generation: 0),
              };
              final progress = LearningSessionProgress(
                members: members,
                completed: members.take(correct).toSet(),
                firstTry: members.take(correct).toSet(),
              );
              await tester.pumpWidget(
                PikoCopyScope(
                  copy: copy,
                  child: MaterialApp(
                    theme: PikoTheme.build(),
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: const Size(320, 900),
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: Scaffold(
                        body: PikoPage(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const PikoHeading(title: 'Collection'),
                              ReviewProgress(
                                direction: 'KO → DE',
                                progress: progress,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              final metric = find.byKey(
                const ValueKey('review-first-try-group'),
              );
              final label = copy.text('learn.firstTryGroup', {
                'correct': correct,
              });
              final rendered = tester.widget<Text>(metric).data!;
              expect(rendered.replaceAll('\u00a0', ' '), label);
              final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(of: metric, matching: find.byType(RichText)),
              );
              expect(paragraph.textScaler.scale(14), 14 * scale);
              final lastWord = label.lastIndexOf(' ') + 1;
              final previousWord = label.lastIndexOf(' ', lastWord - 2) + 1;
              final finalBoxes = paragraph.getBoxesForSelection(
                TextSelection(baseOffset: lastWord, extentOffset: label.length),
              );
              final previousBoxes = paragraph.getBoxesForSelection(
                TextSelection(
                  baseOffset: previousWord,
                  extentOffset: lastWord - 1,
                ),
              );
              expect(finalBoxes, hasLength(1));
              expect(previousBoxes, hasLength(1));
              expect(finalBoxes.single.toRect().width, greaterThan(0));
              expect(previousBoxes.single.toRect().width, greaterThan(0));
              expect(
                finalBoxes.single.top,
                closeTo(previousBoxes.single.top, .01),
                reason:
                    'The last word must share a rendered line with its label.',
              );
              expect(
                finalBoxes.single.bottom,
                closeTo(previousBoxes.single.bottom, .01),
              );
              final lineBoxes = paragraph.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: label.length),
              );
              for (final box in lineBoxes) {
                expect(box.left, greaterThanOrEqualTo(0));
                expect(
                  box.right,
                  lessThanOrEqualTo(paragraph.size.width + .01),
                );
              }
              if (language == 'de' && scale == 2) {
                expect(
                  finalBoxes.single.top,
                  greaterThan(lineBoxes.first.top),
                  reason: 'Exercise the reported multiline German composition.',
                );
              }
              final direction = tester.getRect(
                find.byKey(const ValueKey('review-fixed-direction')),
              );
              final completed = find.byKey(
                const ValueKey('review-completed-group'),
              );
              expect(
                tester.getRect(completed).top,
                greaterThan(direction.bottom),
              );
              expect(
                tester.widget<Text>(completed).data,
                copy.text('learn.completedGroup', {
                  'completed': correct,
                  'total': 30,
                }),
              );
              expect(
                tester
                    .getSemantics(find.byKey(const ValueKey('review-counters')))
                    .label,
                progressDescription(copy, {
                  'completed': correct,
                  'total': 30,
                  'correct': correct,
                }),
              );
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
