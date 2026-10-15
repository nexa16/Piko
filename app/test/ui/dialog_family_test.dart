import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_dialog.dart';

void main() {
  for (final language in ['en', 'de']) {
    for (final narrow in [false, true]) {
      testWidgets(
        '$language confirmation layout, safe focus and dismissal: narrow=$narrow',
        (tester) async {
          tester.view.physicalSize = Size(narrow ? 320 : 600, 1100);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = narrow ? 2 : 1;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final copy = PikoCopy(language);
          final safe = copy.text('action.cancel');
          final danger = language == 'de' ? 'Löschen' : 'Delete';
          var deleted = false;
          await tester.pumpWidget(
            PikoApp(
              locale: Locale(language),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showPikoDialog<void>(
                      context,
                      builder: (context) => PikoDialog(
                        purpose: PikoDialogPurpose.confirmation,
                        title: danger,
                        body: const Text('Korean Basics'),
                        actions: [
                          PikoDialogAction(
                            label: safe,
                            role: PikoDialogActionRole.safe,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          PikoDialogAction(
                            label: danger,
                            role: PikoDialogActionRole.destructive,
                            onPressed: () {
                              deleted = true;
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
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
          expect(find.byTooltip(copy.text('common.close')), findsNothing);
          final cancel = find.widgetWithText(TextButton, safe);
          final remove = find.widgetWithText(TextButton, danger);
          final safeRect = tester.getRect(cancel);
          final dangerRect = tester.getRect(remove);
          expect(safeRect.height, greaterThanOrEqualTo(48));
          expect(dangerRect.height, greaterThanOrEqualTo(48));
          expect(tester.widget<TextButton>(cancel).autofocus, isTrue);
          expect(tester.widget<TextButton>(remove).autofocus, isFalse);
          if (narrow) {
            expect(dangerRect.bottom, lessThan(safeRect.top));
            expect(dangerRect.width, safeRect.width);
            expect(dangerRect.width, closeTo(240, 1));
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            final focus = FocusManager.instance.primaryFocus!.context!;
            expect(
              focus.findAncestorWidgetOfExactType<TextButton>(),
              isNotNull,
            );
          } else {
            expect(safeRect.right, lessThan(dangerRect.left));
            expect(safeRect.top, closeTo(dangerRect.top, 1));
            expect(
              dangerRect.right,
              closeTo(tester.getRect(find.text('Korean Basics')).right, 1),
            );
            expect(safeRect.width + dangerRect.width, lessThan(382));
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(deleted, isFalse);
          expect(find.byType(PikoDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'pending write blocks X, escape, barrier and Back until settled',
    (tester) async {
      final pending = ValueNotifier(true);
      addTearDown(pending.dispose);
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPikoDialog<void>(
                  context,
                  builder: (context) => ValueListenableBuilder(
                    valueListenable: pending,
                    builder: (context, busy, _) => PikoDialog(
                      title: 'Create',
                      dismissible: !busy,
                      body: const Text('Pending'),
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
      await tester.tap(find.byTooltip('Close'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(1, 1));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog), findsOneWidget);
      pending.value = false;
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog), findsNothing);
    },
  );
}
