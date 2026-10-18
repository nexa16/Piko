import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';
import 'package:piko/main.dart';
import 'package:piko/features/collections/create_collection.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'collection_home_header_test.dart' show EmptyCollections;

void main() {
  testWidgets(
    'form headings keep the same 16px section gap with and without object context',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PikoTheme.build(),
          home: Scaffold(
            body: Column(
              children: [
                const PikoFormHeading(title: 'General Settings'),
                PikoFormSection(
                  title: 'General',
                  children: [
                    PikoNavigationRow(title: 'Language', onTap: () {}),
                  ],
                ),
                const PikoFormHeading(
                  title: 'Collection Settings',
                  subtitle: 'French · FR · DE',
                ),
                PikoFormSection(
                  title: 'Learning',
                  children: [
                    PikoNavigationRow(title: 'Hint default', onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        final header = find.byType(PikoHeading).at(i);
        final sectionTitle = find.text(i == 0 ? 'General' : 'Learning');
        expect(
          tester.getRect(sectionTitle).top - tester.getRect(header).bottom,
          16,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Collection creation consumes the same grouped form and 16px field insets',
    (tester) async {
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: CreateCollectionDialog(repository: const EmptyCollections()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PikoDialog>(find.byType(PikoDialog)).presentation,
        PikoDialogPresentation.groupedForm,
      );
      final group = tester.getRect(find.byType(PikoFormGroup));
      final fields = find.byType(PikoFormFieldRow);
      expect(fields, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        final padding = find
            .descendant(of: fields.at(i), matching: find.byType(Padding))
            .first;
        final content = tester.widget<Padding>(padding).child!;
        expect(tester.getRect(find.byWidget(content)).left - group.left, 16);
        expect(group.right - tester.getRect(find.byWidget(content)).right, 16);
      }
      expect(tester.takeException(), isNull);
    },
  );
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
