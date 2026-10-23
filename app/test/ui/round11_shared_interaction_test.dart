import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/features/collections/language_picker.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  testWidgets('shared checkbox choice paints a cream action surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: PikoCheckbox(label: 'Choice', value: true, onChanged: (_) {}),
        ),
      ),
    );
    final surfaces = tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(PikoCheckbox),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      surfaces.any(
        (w) =>
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                pikoDesign.color('surface'),
      ),
      isTrue,
    );
    expect(
      tester.getSize(find.byType(PikoCheckbox)).height,
      greaterThanOrEqualTo(48),
    );
  });
  testWidgets(
    'native touch outside keeps text, switches field and activates first tap',
    (tester) async {
      final first = TextEditingController(text: 'retained');
      final second = TextEditingController();
      final firstFocus = FocusNode(), secondFocus = FocusNode();
      var taps = 0;
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: Column(
              children: [
                PikoTextField(
                  label: 'First',
                  controller: first,
                  focusNode: firstFocus,
                ),
                PikoTextField(
                  label: 'Second',
                  controller: second,
                  focusNode: secondFocus,
                ),
                TextButton(onPressed: () => taps++, child: const Text('Act')),
                const SizedBox(
                  height: 48,
                  child: ColoredBox(
                    key: ValueKey('blank'),
                    color: Colors.transparent,
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(firstFocus.hasFocus, isTrue);
      await tester.tap(find.byType(TextField).last);
      await tester.pump();
      expect(secondFocus.hasFocus, isTrue);
      await tester.tap(find.text('Act'));
      await tester.pump();
      expect(taps, 1);
      expect(secondFocus.hasFocus, isFalse);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('blank')));
      await tester.pump();
      expect(firstFocus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(first.text, 'retained');
      await tester.pumpWidget(const SizedBox.shrink());
      first.dispose();
      second.dispose();
      firstFocus.dispose();
      secondFocus.dispose();
    },
  );

  testWidgets(
    'choice modal owns cream option surface and accessible minimum target',
    (tester) async {
      await tester.pumpWidget(
        PikoApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPikoDialog<void>(
                  context,
                  builder: (_) => PikoDialog(
                    title: 'Choose',
                    purpose: PikoDialogPurpose.directChoice,
                    body: RadioGroup<int>(
                      groupValue: 1,
                      onChanged: (_) {},
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<int>(value: 1, title: Text('Option')),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final option = find.byType(RadioListTile<int>);
      final role = ListTileTheme.of(tester.element(option));
      expect(role.tileColor, pikoDesign.color('surface'));
      expect(role.selectedTileColor, pikoDesign.color('surface'));
      expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
    },
  );

  testWidgets(
    'direct language commits without navigation chevron, custom retains it',
    (tester) async {
      VocabularyLanguage? selected;
      await tester.pumpWidget(
        PikoApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showPikoDialog<VocabularyLanguage>(
                    context,
                    builder: (_) => const LanguagePickerDialog(target: true),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final english = find.byKey(const ValueKey('language-en'));
      expect(english, findsOneWidget);
      expect(
        find.descendant(of: english, matching: find.byType(PikoIcon)),
        findsNothing,
      );
      // The navigation role remains on the custom-language branch regardless of
      // its localized wording, unlike a direct choice.
      expect(find.byType(PikoNavigationRow), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PikoNavigationRow),
          matching: find.byType(PikoIcon),
        ),
        findsOneWidget,
      );
      await tester.tap(english);
      await tester.pumpAndSettle();
      expect(selected, VocabularyLanguage.english);
      expect(find.byType(LanguagePickerDialog), findsNothing);
    },
  );
}
