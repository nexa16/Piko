import 'package:piko/ui/components/piko_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'package:piko/shared/catalogs.dart';
import 'speed_setup_test.dart' show SetupHarness, startButton;

void assertFieldInset(WidgetTester tester, Finder field, Finder group) {
  expect(tester.getRect(field).left - tester.getRect(group).left, 16);
  expect(tester.getRect(group).right - tester.getRect(field).right, 16);
}

void main() {
  testWidgets(
    'F12 geometry guard rejects an extra parent inset in an isolated fixture',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PikoFormGroup(
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: PikoFormFieldRow(
                    child: SizedBox(
                      key: ValueKey('seeded-field'),
                      width: 100,
                      height: 48,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        () => assertFieldInset(
          tester,
          find.byKey(const ValueKey('seeded-field')),
          find.byType(PikoFormGroup),
        ),
        throwsA(isA<TestFailure>()),
      );
    },
  );
  testWidgets(
    'F12 setup uses shared groups and actual 16px pool inset without nested padding',
    (tester) async {
      final h = SetupHarness();
      await h.mount(tester);
      expect(
        tester.widget<PikoDialog>(find.byType(PikoDialog)).presentation,
        PikoDialogPresentation.groupedForm,
      );
      final pool = find.byType(PikoField);
      final group = find
          .ancestor(of: pool, matching: find.byType(PikoFormGroup))
          .first;
      assertFieldInset(tester, pool, group);
      final groups = find.byType(PikoFormGroup);
      expect(
        tester.getRect(groups.at(1)).top - tester.getRect(groups.first).bottom,
        24,
      );
      for (final pair in [
        ('speed.rulesTitle', 'speed.rulesExplanation'),
        ('speed.leavingTitle', 'speed.exitExplanation'),
      ]) {
        final title = find.text(PikoCopy('en').text(pair.$1));
        final body = find.text(PikoCopy('en').text(pair.$2));
        expect(tester.getRect(body).top - tester.getRect(title).bottom, 16);
      }
      expect(
        tester.getRect(groups.at(3)).top - tester.getRect(groups.at(2)).bottom,
        24,
      );
      final field = find.byKey(const ValueKey('speed-pool-size'));
      expect(tester.getSize(field).height, greaterThanOrEqualTo(48));
      await tester.enterText(field, '1e2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(h.closed, false);
      expect(tester.widget<TextField>(field).controller!.text, '1e2');
      expect(find.text(PikoCopy('en').text('r2.poolInvalid')), findsOneWidget);
      expect(tester.widget<PikoButton>(startButton('en')).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
