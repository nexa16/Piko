import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/learning_prompt_card.dart';
import 'package:piko/main.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner;

class ExamplePreferences extends LiveVocabulary
    implements QuestionExamplesRepository {
  bool show = true;
  int reads = 0;
  @override
  Future<bool> readQuestionExamples() async {
    reads++;
    return show;
  }
}

void main() {
  for (final direction in LearningDirection.values) {
    testWidgets(
      '${direction.name}: preference captured per presentation; answers show all pairs and Hint is independent',
      (tester) async {
        final repository = ExamplePreferences()
          ..records = [
            VocabularyRecord(
              id: 'one',
              collectionId: owner.id,
              targetText: 'Word',
              nativeText: 'Wort',
              content: const VocabularyContent(
                examples: [
                  ExamplePair(targetText: 'First', nativeText: 'Erstes'),
                  ExamplePair(targetText: 'Second', nativeText: 'Zweites'),
                ],
                hintText: 'Hint',
              ),
            ),
          ];
        addTearDown(repository.close);
        var presentation = 0;
        Future<void> mount() async {
          await tester.pumpWidget(
            PikoApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: LearningPromptCard(
                    presentation: presentation,
                    entryId: 'one',
                    repository: repository,
                    collectionId: owner.id,
                    direction: direction,
                    canReveal: () => true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        final question = direction == LearningDirection.targetToNative
            ? ['First', 'Second']
            : ['Erstes', 'Zweites'];
        await mount();
        expect(repository.reads, 1);
        for (final text in question) {
          expect(find.text(text), findsOneWidget);
        }
        repository.show = false;
        await mount();
        expect(repository.reads, 1);
        for (final text in question) {
          expect(find.text(text), findsOneWidget);
        }
        presentation++;
        await mount();
        expect(repository.reads, 2);
        for (final text in question) {
          expect(find.text(text), findsNothing);
        }
        expect(find.text('Hint'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('review-prompt-text')));
        await tester.pumpAndSettle();
        for (final text in ['First', 'Second', 'Erstes', 'Zweites']) {
          expect(find.text(text), findsOneWidget);
        }
        expect(find.text('Hint'), findsOneWidget);
      },
    );
  }
}
