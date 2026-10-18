import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/vocabulary/vocabulary_content_editor.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';

import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/components/piko_form.dart';

void main() {
  testWidgets(
    'empty examples begin with Add, insert no content until typing, and return to Add after removal',
    (tester) async {
      var value = const VocabularyContent();
      var changes = 0;
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, update) => VocabularyContentEditor(
                  value: value,
                  targetLanguage: 'English',
                  nativeLanguage: 'German',
                  makeDefault: false,
                  onChanged: (next, _) => update(() {
                    value = next;
                    changes++;
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      final target = find.byKey(const ValueKey('content-example-target'));
      expect(target, findsNothing);
      expect(find.byKey(const ValueKey('content-hint')), findsOneWidget);
      final hintSection = find.byKey(const ValueKey('content-hint-section'));
      final hintGroup = find.descendant(
        of: hintSection,
        matching: find.byType(PikoFormGroup),
      );
      final switchTitle = find.text(
        const PikoCopy('en').text('vocab.hintAutomatic'),
      );
      expect(
        tester.getRect(switchTitle).left - tester.getRect(hintGroup).left,
        16,
      );
      expect(
        DefaultTextStyle.of(tester.element(switchTitle)).style.fontWeight,
        FontWeight.w700,
      );
      await tester.tap(find.byKey(const ValueKey('content-add-example')));
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      expect(changes, 0);
      expect(value.examples, isEmpty);
      await tester.enterText(target, 'Example');
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('content-example-native')),
        'Beispiel',
      );
      await tester.pump();
      expect(value.examples.single.targetText, 'Example');
      expect(value.examples.single.nativeText, 'Beispiel');
      final action = find.text(
        const PikoCopy('en').text('vocab.removeExample', {'number': 1}),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(target, findsNothing);
      expect(value.examples, isEmpty);
      expect(find.byKey(const ValueKey('content-add-example')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'existing examples open directly without creating or hiding content',
    (tester) async {
      const value = VocabularyContent(
        examples: [
          ExamplePair(targetText: 'Existing', nativeText: 'Vorhanden'),
        ],
      );
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VocabularyContentEditor(
                value: value,
                targetLanguage: 'English',
                nativeLanguage: 'German',
                makeDefault: false,
                onChanged: (_, _) =>
                    fail('Opening existing content must not edit it'),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('content-example-target')),
            )
            .controller!
            .text,
        'Existing',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('content-example-native')),
            )
            .controller!
            .text,
        'Vorhanden',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'de']) {
    testWidgets(
      '$language optional editor in PikoCard retains selection and reflows at320/200%',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1200);
        addTearDown(tester.view.reset);
        var value = const VocabularyContent(
          hintVisibility: HintVisibility.hidden,
        );
        var makeDefault = false;
        final editor = StatefulBuilder(
          builder: (context, update) => VocabularyContentEditor(
            value: value,
            targetLanguage: 'Français',
            nativeLanguage: 'Deutsch',
            makeDefault: makeDefault,
            onChanged: (content, selected) => update(() {
              value = content;
              makeDefault = selected;
            }),
          ),
        );
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(language),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(child: PikoCard(child: editor)),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Grouped forms must paint inside the real decorated card',
        );
        expect(
          find.byKey(const ValueKey('content-example-target')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('content-add-example')));
        await tester.pumpAndSettle();
        final example = find.byKey(const ValueKey('content-example-target'));
        await tester.enterText(example, ' raw example ');
        await tester.pump();
        final controller = tester.widget<TextField>(example).controller!;
        controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 5,
        );
        expect(value.exampleTargetText, ' raw example ');
        expect(value.exampleNativeText, '');
        expect(value.hintVisibility, HintVisibility.hidden);
        expect(
          find.byKey(const ValueKey('content-example-target')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('content-hint')), findsOneWidget);
        expect(makeDefault, isFalse);
        final visibility = find.byKey(const ValueKey('content-hint-automatic'));
        await tester.ensureVisible(visibility);
        await tester.tap(visibility);
        await tester.pumpAndSettle();
        expect(value.hintVisibility, HintVisibility.always);
        expect(controller.text, ' raw example ');
        expect(
          controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 5),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
