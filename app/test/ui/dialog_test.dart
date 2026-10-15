import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_dialog.dart';

void main() {
  for (final dismissal in ['close', 'barrier', 'escape', 'back', 'positive']) {
    testWidgets('$dismissal returns safe result and restores opener focus', (
      tester,
    ) async {
      final opener = FocusNode();
      final draft = TextEditingController(text: 'Unconfirmed draft');
      addTearDown(draft.dispose);
      addTearDown(opener.dispose);
      var positive = 0;
      String? result = 'pending';
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                focusNode: opener,
                onPressed: () async {
                  result = await showPikoDialog<String>(
                    context,
                    builder: (context) => PikoDialog(
                      title: PikoCopyScope.of(
                        context,
                      ).text('dialog.newCollection'),
                      body: TextField(controller: draft),
                      actions: [
                        PikoDialogAction(
                          onPressed: () {
                            positive++;
                            Navigator.of(context).pop('created');
                          },
                          label: PikoCopyScope.of(
                            context,
                          ).text('action.create'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open test dialog'),
              ),
            ),
          ),
        ),
      );
      opener.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Open test dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
      final title = tester.widget<Text>(find.text('New Collection'));
      expect(title.style!.fontSize, 20);
      expect(title.style!.fontWeight, FontWeight.w700);
      expect(tester.widget<Dialog>(find.byType(Dialog)).elevation, 0);
      switch (dismissal) {
        case 'close':
          await tester.tap(find.byTooltip('Close'));
        case 'barrier':
          await tester.tapAt(const Offset(1, 1));
        case 'escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        case 'back':
          await tester.binding.handlePopRoute();
        case 'positive':
          await tester.tap(find.text('Create collection'));
      }
      await tester.pumpAndSettle();
      expect(result, dismissal == 'positive' ? 'created' : null);
      expect(positive, dismissal == 'positive' ? 1 : 0);
      expect(opener.hasFocus, isTrue);
      expect(draft.text, 'Unconfirmed draft');
    });
  }
  testWidgets(
    'dialog traps tab focus and live locale updates its close label',
    (tester) async {
      final locale = InterfaceLocaleController();
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        PikoApp(
          localeController: locale,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () => showPikoDialog<void>(
                  context,
                  builder: (context) => PikoDialog(
                    title: PikoCopyScope.of(
                      context,
                    ).text('dialog.newCollection'),
                    body: const TextField(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (var index = 0; index < 6; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(focused.findAncestorWidgetOfExactType<Dialog>(), isNotNull);
      }
      locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Schließen'), findsOneWidget);
    },
  );

  testWidgets('large German content fits narrow keyboard-constrained popup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(392, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      PikoApp(
        locale: const Locale('de'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => showPikoDialog<void>(
                context,
                builder: (context) => PikoDialog(
                  title: PikoCopyScope.of(context).text('dialog.newCollection'),
                  body: Text(
                    PikoCopyScope.of(context).text('collection.deleteWarning', {
                      'name': 'Eine besonders lange Sammlung',
                    }),
                  ),
                  actions: [
                    PikoDialogAction(
                      onPressed: () {},
                      label: PikoCopyScope.of(context).text('action.create'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Dialog)).width, lessThanOrEqualTo(392));
    await tester.ensureVisible(find.text('Sammlung erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Sammlung erstellen').hitTestable(), findsOneWidget);
  });
}
