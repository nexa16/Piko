import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  testWidgets(
    'navigation rows share 16px content inset and centered chevron despite wrapped labels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PikoTheme.build(),
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: PikoFormGroup(
                children: [
                  PikoNavigationRow(title: 'Short', onTap: () {}),
                  PikoNavigationRow(
                    title:
                        'A much longer navigation label that wraps across lines',
                    subtitle: 'Description',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final rows = find.byType(PikoFormRow);
      for (var i = 0; i < 2; i++) {
        final row = rows.at(i);
        final rect = tester.getRect(row);
        final label = find
            .descendant(of: row, matching: find.byType(Text))
            .first;
        final icon = find.descendant(of: row, matching: find.byType(PikoIcon));
        expect(tester.getRect(label).left - rect.left, 16);
        expect(rect.right - tester.getRect(icon).right, 16);
        expect(tester.getCenter(icon).dy, closeTo(rect.center.dy, .01));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
