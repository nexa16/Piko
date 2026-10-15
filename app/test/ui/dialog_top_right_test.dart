import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';

void main() {
  testWidgets('wrapped German dialog title keeps close action at top-right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const copy = PikoCopy('de');
    final title = copy.text('summary.title');

    await tester.pumpWidget(
      PikoApp(
        locale: const Locale('de'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPikoDialog<void>(
                context,
                builder: (context) => PikoDialog(
                  title: PikoCopyScope.of(context).text('summary.title'),
                  body: const SizedBox.shrink(),
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

    final titleRect = tester.getRect(find.text(title));
    final closeFinder = find.byWidgetPredicate(
      (widget) =>
          widget is PikoIconButton &&
          widget.semanticLabel == copy.text('common.close'),
    );
    final closeRect = tester.getRect(closeFinder);
    final dialogRect = tester.getRect(find.byType(Dialog));

    expect(titleRect.height, greaterThan(closeRect.height));
    expect(closeRect.top, closeTo(titleRect.top, 0.01));
    expect(closeRect.width, greaterThanOrEqualTo(44));
    expect(closeRect.height, greaterThanOrEqualTo(44));
    expect(closeRect.center.dx, greaterThan(dialogRect.center.dx));
    expect(closeRect.right, lessThanOrEqualTo(dialogRect.right));
    expect(tester.takeException(), isNull);
  });
}
