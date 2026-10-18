import 'package:piko/shared/copy_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';

import 'create_collection_test.dart' show PendingRepository;

TextField nameField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

Future<void> open(WidgetTester tester, InterfaceLocaleController locale) async {
  await tester.pumpWidget(
    PikoApp(
      localeController: locale,
      home: CollectionsHome(repository: PendingRepository()),
    ),
  );
  await tester.tap(
    find.text(PikoCopy(locale.value.languageCode).text('action.new')),
  );
  await tester.pumpAndSettle();
}

Future<void> changeLanguage(
  WidgetTester tester,
  VocabularyLanguage language, {
  bool native = false,
}) async {
  final trigger=find.byKey(ValueKey(native ? 'collection.nativeLanguage' : 'collection.targetLanguage'));
  await tester.ensureVisible(trigger); await tester.tap(trigger);
  await tester.pumpAndSettle();
  final search=find.byType(TextField).last;
  await tester.enterText(search, language.label(PikoCopyScope.of(tester.element(search)).locale));
  await tester.pumpAndSettle();
  final choice=find.byKey(ValueKey('language-${language.code}'));
  await tester.ensureVisible(choice); await tester.tap(choice); await tester.pumpAndSettle();
}

void main() {
  for (final localeCode in ['en', 'de']) {
    testWidgets(
      '$localeCode defaults follow target language until customization',
      (tester) async {
        final locale = InterfaceLocaleController(Locale(localeCode));
        addTearDown(locale.dispose);
        await open(tester, locale);
        final copy = PikoCopy(localeCode);
        expect(
          nameField(tester).controller!.text,
          copy.text('language.korean'),
        );
        for (final language in [VocabularyLanguage.korean, VocabularyLanguage.french, VocabularyLanguage.english, VocabularyLanguage.german, VocabularyLanguage.values.singleWhere((v)=>v.code=='zh-Hans')]) {
          await changeLanguage(tester, language);
          expect(
            nameField(tester).controller!.text,
            copy.text(language.copyKey),
          );
        }
        await tester.enterText(find.byType(TextField), 'My personal name');
        await changeLanguage(tester, VocabularyLanguage.french);
        expect(nameField(tester).controller!.text, 'My personal name');
        await changeLanguage(tester, VocabularyLanguage.english, native: true);
        expect(nameField(tester).controller!.text, 'My personal name');
      },
    );
  }

  testWidgets(
    'clearing or explicitly editing the same default stops replacement',
    (tester) async {
      final locale = InterfaceLocaleController();
      addTearDown(locale.dispose);
      await open(tester, locale);
      // Retyping the default is still customization, not an automatic reset.
      await tester.enterText(find.byType(TextField), 'Korean vocabulary');
      await tester.enterText(find.byType(TextField), 'Korean');
      await changeLanguage(tester, VocabularyLanguage.french);
      expect(nameField(tester).controller!.text, 'Korean');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await changeLanguage(tester, VocabularyLanguage.french);
      expect(nameField(tester).controller!.text, isEmpty);
      await tester.enterText(find.byType(TextField), 'Korean');
      await changeLanguage(tester, VocabularyLanguage.english);
      expect(nameField(tester).controller!.text, 'Korean');
    },
  );

  for (final edited in [null, 'My custom name', '']) {
    testWidgets(
      'locale-only change preserves ${edited ?? 'automatic'} name and editing state',
      (tester) async {
        final locale = InterfaceLocaleController();
        addTearDown(locale.dispose);
        await open(tester, locale);
        await tester.tap(find.byType(TextField));
        if (edited != null) {
          await tester.enterText(find.byType(TextField), edited);
        }
        final controller = nameField(tester).controller!;
        final original = controller.text;
        final selection = TextSelection(
          baseOffset: 0,
          extentOffset: original.isEmpty ? 0 : 1,
        );
        controller.selection = selection;
        await tester.pump();
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(editable.widget.focusNode.hasFocus, isTrue);
        locale.value = const Locale('de');
        await tester.pumpAndSettle();
        expect(nameField(tester).controller, same(controller));
        expect(controller.text, original);
        expect(controller.selection, selection);
        expect(editable.widget.focusNode.hasFocus, isTrue);
        expect(
          find.text(const PikoCopy('de').text('collection.name')),
          findsOneWidget,
        );
        await changeLanguage(tester, VocabularyLanguage.french);
        expect(controller.text, edited ?? 'Französisch');
      },
    );
  }

  testWidgets('native language alone never changes the automatic default', (
    tester,
  ) async {
    final locale = InterfaceLocaleController();
    addTearDown(locale.dispose);
    await open(tester, locale);
    await changeLanguage(tester, VocabularyLanguage.english, native: true);
    expect(nameField(tester).controller!.text, 'Korean');
  });
}
