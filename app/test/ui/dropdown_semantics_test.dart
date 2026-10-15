import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_field.dart';

SemanticsNode expectDropdownSemantics<T>(WidgetTester tester, String label) {
  final dropdown = find.byType(PikoDropdown<T>);
  final labeledFinder = find.descendant(
    of: dropdown,
    matching: find.bySemanticsLabel(label),
  );
  final actionFinder = find.descendant(
    of: dropdown,
    matching: find.byType(DropdownButton<T>),
  );
  expect(labeledFinder, findsOneWidget);
  expect(actionFinder, findsOneWidget);
  final labeled = tester.getSemantics(labeledFinder);
  final action = tester.getSemantics(actionFinder);
  final diagnostic =
      'Labeled dropdown semantics subtree:\n${labeled.toStringDeep()}'
      '\nActionable dropdown semantics subtree:\n${action.toStringDeep()}';
  expect(labeled.label, label, reason: diagnostic);
  // Flutter merges the field's semantic label into the actionable control;
  // the visible caption remains a sibling rather than a semantic ancestor.
  expect(action.label.split('\n'), contains(label), reason: diagnostic);
  final data = action.getSemanticsData();
  expect(data.flagsCollection.isButton, isTrue, reason: diagnostic);
  expect(data.flagsCollection.isExpanded, Tristate.isFalse, reason: diagnostic);
  expect(
    data.flagsCollection.isEnabled,
    isNot(Tristate.isFalse),
    reason: diagnostic,
  );
  expect(data.hasAction(SemanticsAction.tap), isTrue, reason: diagnostic);
  return action;
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language dropdown exposes its localized label and actionable button',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        final copy = PikoCopy(language);
        final initial = Locale(language);
        Locale? selected;
        try {
          await tester.pumpWidget(
            PikoApp(
              locale: initial,
              home: Scaffold(
                body: Center(
                  child: PikoDropdown<Locale>(
                    label: copy.text('settings.language'),
                    value: initial,
                    items: const [
                      DropdownMenuItem(
                        value: Locale('en'),
                        child: Text('English'),
                      ),
                      DropdownMenuItem(
                        value: Locale('de'),
                        child: Text('Deutsch'),
                      ),
                    ],
                    onChanged: (value) => selected = value,
                  ),
                ),
              ),
            ),
          );
          final action = expectDropdownSemantics<Locale>(
            tester,
            copy.text('settings.language'),
          );
          action.owner!.performAction(action.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          final next = language == 'en' ? 'Deutsch' : 'English';
          expect(find.text(next), findsWidgets);
          await tester.tap(find.text(next).last);
          await tester.pumpAndSettle();
          expect(selected, Locale(language == 'en' ? 'de' : 'en'));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
