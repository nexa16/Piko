import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'create_collection_test.dart' show PendingRepository;

Future<void> openForm(WidgetTester tester) async {
  await tester.pumpWidget(
    PikoApp(
      locale: const Locale('de'),
      home: CollectionsHome(repository: PendingRepository()),
    ),
  );
  await tester.tap(find.text('Neu'));
  await tester.pumpAndSettle();
}

Finder role(String name) => find.byKey(ValueKey('collection.$name'));

void main() {
  testWidgets(
    'shared language navigation roles keep accessible target/native/name order and 16px content inset',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openForm(tester);
      final target = role('targetLanguage'),
          native = role('nativeLanguage'),
          name = find.byType(TextField);
      for (final (finder, key) in [
        (target, 'collection.targetLanguage'),
        (native, 'collection.nativeLanguage'),
      ]) {
        expect(
          find.bySemanticsLabel(RegExp(const PikoCopy('de').text(key))),
          findsWidgets,
        );
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
        final group = find
            .ancestor(of: finder, matching: find.byType(PikoFormGroup))
            .first;
        final title = find.descendant(
          of: finder,
          matching: find.text(const PikoCopy('de').text(key)),
        );
        expect(
          tester.getTopLeft(title).dx - tester.getTopLeft(group).dx,
          closeTo(16, 0.01),
        );
      }
      expect(
        tester.getTopLeft(target).dy,
        lessThan(tester.getTopLeft(native).dy),
      );
      expect(
        tester.getTopLeft(native).dy,
        lessThan(tester.getTopLeft(name).dy),
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('language-zh-Hans')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-zh-Hant')), findsOneWidget);
      expect(find.byKey(const ValueKey('language-zh')), findsOneWidget);
      semantics.dispose();
    },
  );
  testWidgets(
    'keyboard traversal reaches target, native and name in reading order',
    (tester) async {
      await openForm(tester);
      final order = <String>[];
      for (var i = 0; i < 16; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final row = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<PikoFormRow>();
        if (row?.title == 'Zielsprache' && !order.contains('target')) {
          order.add('target');
        }
        if (row?.title == 'Muttersprache' && !order.contains('native')) {
          order.add('native');
        }
        if (tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus) {
          order.add('name');
          break;
        }
      }
      expect(order, ['target', 'native', 'name']);
    },
  );
  for (final draft in ['Meine eigene Sammlung', '']) {
    testWidgets(
      '320px/200% child cancellation and IME keep raw parent draft "$draft"',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openForm(tester);
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), draft);
        final controller = tester
            .widget<TextField>(find.byType(TextField))
            .controller!;
        controller.selection = TextSelection.collapsed(offset: draft.length);
        final original = controller.value;
        await tester.ensureVisible(role('targetLanguage'));
        await tester.tap(role('targetLanguage'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Mandarin');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Schließen').last);
        await tester.pumpAndSettle();
        expect(controller.value, original);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Sammlung erstellen'));
        expect(
          tester.getRect(find.text('Sammlung erstellen')).bottom,
          lessThanOrEqualTo(600),
        );
        await tester.ensureVisible(find.byType(TextField));
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(600),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
