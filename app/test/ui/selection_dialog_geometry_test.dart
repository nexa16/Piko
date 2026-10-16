import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_button.dart';

void main() {
  for (final language in ['en', 'de']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$language selection geometry stays still as real actions appear at scale $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 650);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final copy = PikoCopy(language);
        var selected = false;
        await tester.pumpWidget(PikoApp(locale: Locale(language), home: Scaffold(body: Builder(
          builder: (context) => TextButton(child: const Text('Open'), onPressed: () => showPikoDialog<void>(
            context, builder: (context) => StatefulBuilder(builder: (context, update) => PikoDialog(
              title: copy.text('action.filters'), purpose: PikoDialogPurpose.selection,
              selectionFooterLabels: [copy.text('r2.clearFilters'), copy.text('r2.apply')],
              body: Column(children: [
                CheckboxListTile(key: const ValueKey('selected-row'), title: const Text('Korean / 한국어'),
                  value: selected, onChanged: (next) => update(() => selected = next!)),
                for (var i = 0; i < 12; i++) Text('Vocabulary $i'),
              ]),
              actions: selected ? [
                PikoDialogAction(label: copy.text('r2.clearFilters'),
                  role: PikoDialogActionRole.safe, onPressed: () => update(() => selected = false)),
                PikoDialogAction(label: copy.text('r2.apply'), onPressed: () => Navigator.of(context).pop()),
              ] : const [],
            )),
          )),
        ))));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final title = find.text(copy.text('action.filters'));
        final row = find.byKey(const ValueKey('selected-row'));
        final titleRect = tester.getRect(title), rowRect = tester.getRect(row);
        expect(find.text(copy.text('r2.apply')), findsNothing);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(tester.getRect(title), titleRect);
        expect(tester.getRect(row), rowRect);
        final clear = find.widgetWithText(PikoButton, copy.text('r2.clearFilters'));
        final apply = find.widgetWithText(PikoButton, copy.text('r2.apply'));
        expect(clear.hitTestable(), findsOneWidget);
        expect(apply.hitTestable(), findsOneWidget);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('r2.apply')), findsNothing);
        expect(tester.getRect(title), titleRect);
        expect(tester.getRect(row), rowRect);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
