import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_field.dart';

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

void main() {
  testWidgets(
    'binding field and option order retain localized accessible names',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await openForm(tester);
      final fields = tester
          .widgetList<PikoField>(find.byType(PikoField))
          .toList();
      final copy = const PikoCopy('de');
      expect(fields.map((f) => f.label), [
        copy.text('collection.targetLanguage'),
        copy.text('collection.nativeLanguage'),
        copy.text('collection.name'),
      ]);
      final dropdowns = tester
          .widgetList<DropdownButton<VocabularyLanguage>>(
            find.byType(DropdownButton<VocabularyLanguage>),
          )
          .toList();
      expect(
        dropdowns.first.items!.map((item) => item.value),
        VocabularyLanguage.values,
      );
      expect(dropdowns.last.items!.map((item) => item.value), [
        VocabularyLanguage.german,
        VocabularyLanguage.english,
        VocabularyLanguage.french,
        VocabularyLanguage.korean,
      ]);
      final text = tester.widget<TextField>(find.byType(TextField));
      expect(text.controller!.text, copy.text('language.korean'));
      expect(
        tester
            .getSemantics(find.byType(DropdownButton<VocabularyLanguage>).first)
            .getSemanticsData()
            .label,
        contains(copy.text('collection.targetLanguage')),
      );
      expect(
        tester
            .getSemantics(find.byType(DropdownButton<VocabularyLanguage>).last)
            .getSemanticsData()
            .label,
        contains(copy.text('collection.nativeLanguage')),
      );
      expect(
        tester.getSemantics(find.byType(TextField)).getSemanticsData().label,
        contains(copy.text('collection.name')),
      );
      final positions = fields
          .map((field) => tester.getTopLeft(find.byWidget(field)).dy)
          .toList();
      expect(positions[0], lessThan(positions[1]));
      expect(positions[1], lessThan(positions[2]));
      semantics.dispose();
    },
  );

  testWidgets(
    'keyboard traversal reaches target, native and name in reading order',
    (tester) async {
      await openForm(tester);
      final order = <String>[];
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final dropdown = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<
              DropdownButton<VocabularyLanguage>
            >();
        if (dropdown != null) {
          final value = dropdown.value == VocabularyLanguage.korean
              ? 'target'
              : 'native';
          if (!order.contains(value)) order.add(value);
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
      '392px doubled German form stays reachable above keyboard with "$draft"',
      (tester) async {
        tester.view.physicalSize = const Size(392, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openForm(tester);
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), draft);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final target = tester.widget<DropdownButton<VocabularyLanguage>>(
          find.byType(DropdownButton<VocabularyLanguage>).first,
        );
        target.onChanged!(VocabularyLanguage.french);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          draft,
        );
        await tester.ensureVisible(find.text('Sammlung erstellen'));
        await tester.pumpAndSettle();
        final createBox = tester.getRect(find.text('Sammlung erstellen'));
        expect(createBox.top, greaterThanOrEqualTo(0));
        expect(createBox.bottom, lessThanOrEqualTo(500));
        await tester.ensureVisible(find.byType(TextField));
        await tester.pumpAndSettle();
        final inputBox = tester.getRect(find.byType(TextField));
        expect(inputBox.bottom, lessThanOrEqualTo(500));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
