import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/vocabulary/vocabulary_content_editor.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_checkbox.dart';

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language raw optional editor retains selection and reflows at320/200%',
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
                child: Scaffold(body: SingleChildScrollView(child: editor)),
              ),
            ),
          ),
        );
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
        final checkbox = find.byType(PikoCheckbox);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(makeDefault, isTrue);
        expect(
          controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 5),
        );
        final visibility = find.byKey(
          const ValueKey('content-hint-visibility-always'),
        );
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
