import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/learning_prompt_card.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner;

void main() {
  for (final direction in LearningDirection.values) {
    for (final visibility in HintVisibility.values) {
      testWidgets(
        '${direction.name}/${visibility.name} examples and Hint reveal never grade/flip; next presentation resets',
        (tester) async {
          final repository = LiveVocabulary()
            ..records = [
              VocabularyRecord(
                id: 'one',
                collectionId: owner.id,
                targetText: 'Café',
                nativeText: 'Kaffee',
                content: VocabularyContent(
                  exampleTargetText: 'Un café, merci.',
                  exampleNativeText: 'Einen Kaffee, bitte.',
                  hintText: 'A hot drink',
                  hintVisibility: visibility,
                ),
              ),
            ];
          final presentation = ValueNotifier(0);
          var revealCount = 0;
          addTearDown(() async {
            presentation.dispose();
            await repository.close();
          });
          await tester.pumpWidget(
            PikoApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ValueListenableBuilder(
                    valueListenable: presentation,
                    builder: (context, handle, _) => LearningPromptCard(
                      presentation: handle,
                      entryId: 'one',
                      repository: repository,
                      collectionId: owner.id,
                      direction: direction,
                      canReveal: () => true,
                      onReveal: () {
                        revealCount++;
                        return true;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final promptExample = direction == LearningDirection.targetToNative
              ? 'Un café, merci.'
              : 'Einen Kaffee, bitte.';
          final answerExample = direction == LearningDirection.targetToNative
              ? 'Einen Kaffee, bitte.'
              : 'Un café, merci.';
          expect(find.text(promptExample), findsOneWidget);
          expect(find.text(answerExample), findsNothing);
          final hintAction = find.byKey(const ValueKey('learning-reveal-hint'));
          VoidCallback? stale;
          if (visibility == HintVisibility.hidden) {
            expect(find.text('A hot drink'), findsNothing);
            stale = tester.widget<PikoButton>(hintAction).onPressed!;
            final semantics = tester.ensureSemantics();
            expect(find.bySemanticsLabel('Show hint'), findsOneWidget);
            await tester.tap(hintAction);
            await tester.pumpAndSettle();
            semantics.dispose();
            expect(revealCount, 0);
            expect(
              find.byKey(const ValueKey('review-answer-text')),
              findsNothing,
            );
            expect(hintAction, findsNothing);
          }
          expect(find.text('A hot drink'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('review-prompt-text')));
          await tester.pumpAndSettle();
          expect(revealCount, 1);
          expect(find.text(promptExample), findsOneWidget);
          expect(find.text(answerExample), findsOneWidget);
          expect(find.text('A hot drink'), findsOneWidget);
          stale?.call();
          await tester.pumpAndSettle();
          expect(revealCount, 1);
          presentation.value++;
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('review-answer-text')),
            findsNothing,
          );
          expect(find.text(answerExample), findsNothing);
          expect(
            find.text('A hot drink'),
            visibility == HintVisibility.hidden ? findsNothing : findsOneWidget,
          );
          expect(
            hintAction,
            visibility == HintVisibility.hidden ? findsOneWidget : findsNothing,
          );
        },
      );
    }
  }
  testWidgets(
    'keyboard activates hidden Hint without revealing the answer; hidden Hint still appears on answer',
    (tester) async {
      final repository = LiveVocabulary()
        ..records = [
          VocabularyRecord(
            id: 'one',
            collectionId: owner.id,
            targetText: 'One',
            nativeText: 'Eins',
            content: const VocabularyContent(
              hintText: 'Stored hint',
              hintVisibility: HintVisibility.hidden,
            ),
          ),
        ];
      addTearDown(repository.close);
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: LearningPromptCard(
              presentation: Object(),
              entryId: 'one',
              repository: repository,
              collectionId: owner.id,
              direction: LearningDirection.targetToNative,
              canReveal: () => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.descendant(
        of: find.byKey(const ValueKey('learning-reveal-hint')),
        matching: find.byType(TextButton),
      );
      Focus.of(
        tester.element(
          find.descendant(of: button, matching: find.byType(Text)).first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Stored hint'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-answer-text')), findsNothing);
    },
  );
}
