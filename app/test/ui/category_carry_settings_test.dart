import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_switch.dart';
import 'category_assignment_picker_test.dart' show PickerFixture;
import 'category_management_test.dart' show mount, expand, field;

Future<void> press(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  final body = find.byKey(const ValueKey('selection-dialog-body')).first;
  for (var i = 0; target.hitTestable().evaluate().isEmpty && i < 40; i++) {
    final viewport = tester.getRect(body), rect = tester.getRect(target);
    await tester.dragFrom(
      Offset(viewport.left + 4, viewport.center.dy),
      Offset(0, rect.center.dy > viewport.center.dy ? -180 : 180),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(target.hitTestable().first);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language carry uses staged group Save/cancel, rollback keeps raw input and retry is recoverable at 320dp/200%',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 780));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() async {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.binding.setSurfaceSize(null);
        });
        final f = PickerFixture(), copy = PikoCopy(language);
        final semantics = tester.ensureSemantics();
        try {
          await tester.runAsync(f.initialize);
          await mount(tester, f, language);
          await expand(tester, f);
          final toggle = find.byKey(
            ValueKey('category-carry-over-${f.dimension.id}'),
          );
          final save = find.widgetWithText(
            PikoButton,
            copy.text('category.saveDimension'),
          );
          expect(tester.widget<PikoSwitch>(toggle).value, isFalse);
          await press(tester, toggle);
          expect(tester.widget<PikoSwitch>(toggle).value, isTrue);
          expect(
            (await tester.runAsync(
              () => f.repository.dimensionById(f.dimension.id),
            ))!.carryOver,
            isFalse,
          );
          await press(tester, find.byTooltip(copy.text('common.close')));
          await press(tester, find.text('Open menu'));
          await f.flush(tester);
          await expand(tester, f);
          expect(tester.widget<PikoSwitch>(toggle).value, isFalse);
          final input = field('category-management-name-${f.dimension.id}');
          await tester.ensureVisible(input);
          await tester.enterText(input, ' Raw group name ');
          final controller = tester.widget<TextField>(input).controller!;
          controller.selection = const TextSelection(
            baseOffset: 2,
            extentOffset: 5,
          );
          await press(tester, toggle);
          expect(controller.text, ' Raw group name ');
          expect(
            controller.selection,
            const TextSelection(baseOffset: 2, extentOffset: 5),
          );
          await tester.runAsync(
            () => f.db.customStatement(
              "CREATE TRIGGER fail_carry BEFORE INSERT ON category_group_preferences BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
            ),
          );
          await press(tester, save);
          await f.flush(tester);
          expect(
            find.text(copy.text('category.dimensionSaveFailed')),
            findsOneWidget,
          );
          expect(controller.text, ' Raw group name ');
          expect(tester.widget<PikoSwitch>(toggle).value, isTrue);
          final unchanged = (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!;
          expect(unchanged.name, 'Difficulty');
          expect(unchanged.carryOver, isFalse);
          await tester.runAsync(
            () => f.db.customStatement('DROP TRIGGER fail_carry'),
          );
          await press(tester, save);
          await f.flush(tester);
          final saved = (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!;
          expect(saved.name, 'Raw group name');
          expect(saved.carryOver, isTrue);
          expect(save, findsNothing);
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          expect(tester.getSize(toggle).width, lessThanOrEqualTo(320));
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await press(tester, find.byTooltip(copy.text('common.close')));
          await press(tester, find.text('Open menu'));
          await f.flush(tester);
          await press(tester, find.text('Raw group name'));
          await f.flush(tester);
          expect(tester.widget<PikoSwitch>(toggle).value, isTrue);
        } finally {
          semantics.dispose();
          await f.cleanup(tester);
        }
      },
    );
  }
}
