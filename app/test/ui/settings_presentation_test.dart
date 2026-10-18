import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/components/piko_preference_picker.dart';
import 'settings_test.dart' as settings;

void main() {
  testWidgets(
    'real language and direction rows share 16px insets and centered chevrons',
    (tester) async {
      final h = settings.Harness();
      try {
        await h.mount(tester);
        await h.open(tester);
        await h.flush(tester);
        final rows = find.byType(PikoNavigationRow);
        expect(rows, findsNWidgets(3));
        for (var i = 0; i < 2; i++) {
          final row = rows.at(i), rect = tester.getRect(rows.at(i));
          final label = find
              .descendant(of: row, matching: find.byType(Text))
              .first;
          final icon = find.descendant(
            of: row,
            matching: find.byType(PikoIcon),
          );
          expect(tester.getRect(label).left - rect.left, 16);
          expect(rect.right - tester.getRect(icon).right, 16);
          expect(tester.getCenter(icon).dy, closeTo(rect.center.dy, .01));
        }
      } finally {
        await h.cleanup(tester);
      }
    },
  );
  for (final language in ['en', 'de']) {
    for (final width in [320.0, 392.0]) {
      testWidgets(
        '$language ${width.toInt()}px 200% settings are reachable and language choice is keyboard operated',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final h = settings.Harness();
          final semantics = tester.ensureSemantics();
          try {
            await tester.runAsync(
              () => h.repository.real.write('locale', language),
            );
            await h.mount(tester);
            final controller = await h.open(tester);
            await h.flush(tester);
            final copy = PikoCopy(language);
            expect(find.text(copy.text('nav.settings')), findsOneWidget);
            expect(find.byType(PikoFormSection), findsNWidgets(4));
            for (final row in find.byType(PikoNavigationRow).evaluate()) {
              final finder = find.byWidget(row.widget);
              await tester.ensureVisible(finder);
              await tester.pumpAndSettle();
              final rect = tester.getRect(finder);
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
            }
            final picker = find.byType(PikoPreferencePicker<Locale>);
            await tester.ensureVisible(picker);
            await tester.pumpAndSettle();
            FocusManager.instance.primaryFocus?.unfocus();
            var reached = false;
            for (var i = 0; i < 8; i++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
              reached =
                  FocusManager.instance.primaryFocus?.context
                      ?.findAncestorWidgetOfExactType<
                        PikoPreferencePicker<Locale>
                      >() !=
                  null;
              if (reached) break;
            }
            expect(reached, isTrue);
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
            await tester.pumpAndSettle();
            expect(find.byType(RadioGroup<Locale>), findsOneWidget);
            for (final tile in find.byType(RadioListTile<Locale>).evaluate()) {
              final rect = tester.getRect(find.byWidget(tile.widget));
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.right, lessThanOrEqualTo(width));
            }
            final next = language == 'en' ? 'de' : 'en';
            var selected = false;
            for (var i = 0; i < 8; i++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
              final tile = FocusManager.instance.primaryFocus?.context
                  ?.findAncestorWidgetOfExactType<RadioListTile<Locale>>();
              if (tile != null) {
                await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
                await tester.pumpAndSettle();
                selected = true;
                break;
              }
            }
            expect(selected, isTrue);
            await h.drain(tester, controller);
            expect(h.selected!.value.languageCode, next);
            final back = settings.button('common.back', next);
            expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
            await tester.ensureVisible(back);
            await tester.tap(back);
            await tester.pumpAndSettle();
            expect(find.byType(PikoPreferencePicker<Locale>), findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
            await h.cleanup(tester);
          }
        },
      );
    }
  }
}
