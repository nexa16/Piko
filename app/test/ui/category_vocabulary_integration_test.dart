import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'category_assignment_picker_test.dart'
    show PickerFixture, value, checked;
import 'category_inline_value_test.dart' as actions;

Future<void> press(WidgetTester tester, Finder action) async {
  await tester.pumpAndSettle();
  if (action.evaluate().isEmpty) {
    final section = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('categories-toggle-'),
    );
    await tester.ensureVisible(section.last);
    await tester.pumpAndSettle();
    await tester.tap(section.last.hitTestable());
    await tester.pumpAndSettle();
  }
  await actions.press(tester, action);
}

Finder target(PickerFixture f) => find.descendant(
  of: find.byKey(ValueKey('inline-${f.entryId}-target')),
  matching: find.byType(TextField),
);
Finder picker(PickerFixture f) =>
    find.byKey(ValueKey('category-picker-${f.entryId}-${f.dimension.id}'));
Finder label(PickerFixture f, int index) {
  final section = find.byKey(ValueKey('categories-toggle-${f.entryId}'));
  return section.evaluate().isNotEmpty
      ? find.descendant(
          of: section,
          matching: find.textContaining(f.values[index].name),
        )
      : find.byKey(
          ValueKey('category-label-${f.entryId}-${f.values[index].id}'),
        );
}

Future<void> mount(
  WidgetTester tester,
  PickerFixture f,
  String language,
) async {
  final collection = await tester.runAsync(
    () => SqliteCollectionsRepository(
      f.db,
    ).watchById(f.dimension.collectionId).first,
  );
  await tester.pumpWidget(
    PikoApp(
      localeController: InterfaceLocaleController(Locale(language)),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CollectionVocabulary(
            collection: collection!,
            repository: SqliteVocabularyRepository(f.db),
            categoriesRepository: f.repository,
          ),
        ),
      ),
    ),
  );
  await f.flush(tester);
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language picker stages assignments; Apply preserves raw invalid text until atomic autosave and collapsed chips update',
      (tester) async {
        final f = PickerFixture();
        await tester.runAsync(f.initialize);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.runAsync(f.db.close);
          f.raw.dispose();
        });
        await mount(tester, f, language);
        expect(label(f, 0), findsOneWidget);
        expect(label(f, 1), findsNothing);
        await tester.tap(find.byKey(ValueKey('vocabulary-${f.entryId}')));
        await f.flush(tester);
        final raw = tester.widget<TextField>(target(f)).controller!;
        await tester.enterText(target(f), ' ');
        final selection = raw.selection;
        await press(tester, picker(f));
        await f.flush(tester);
        await press(tester, value(f.values[1]));
        expect(checked(tester, f.values[1]), isTrue);
        expect(
          (await tester.runAsync(
            () => f.repository.assignments(f.entryId),
          ))!.single.valueIds,
          {f.values[0].id},
        );
        await press(
          tester,
          find.widgetWithText(PikoButton, PikoCopy(language).text('r2.apply')),
        );
        await f.flush(tester);
        expect(
          identical(tester.widget<TextField>(target(f)).controller, raw),
          isTrue,
        );
        expect(raw.text, ' ');
        expect(raw.selection, selection);
        expect(label(f, 0), findsOneWidget);
        expect(label(f, 1), findsOneWidget);
        expect(
          (await tester.runAsync(
            () => f.repository.assignments(f.entryId),
          ))!.single.valueIds,
          {f.values[0].id},
        );
        await tester.enterText(target(f), ' pomme modifiée ');
        await f.flush(tester);
        expect(
          (await tester.runAsync(
            () => f.repository.assignments(f.entryId),
          ))!.single.valueIds,
          {f.values[0].id, f.values[1].id},
        );
        expect(raw.text, ' pomme modifiée ');
        await press(
          tester,
          find.byKey(ValueKey('inline-complete-${f.entryId}')),
        );
        await f.flush(tester);
        expect(find.byType(TextField), findsNothing);
        expect(label(f, 0), findsOneWidget);
        expect(label(f, 1), findsOneWidget);
      },
    );
  }

  testWidgets(
    'external category deletion does not leave a hidden invalid reference in an open editor',
    (tester) async {
      final f = PickerFixture();
      await tester.runAsync(f.initialize);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.db.close);
        f.raw.dispose();
      });
      await mount(tester, f, 'en');
      await tester.tap(find.byKey(ValueKey('vocabulary-${f.entryId}')));
      await f.flush(tester);
      final raw = tester.widget<TextField>(target(f)).controller!;
      await tester.enterText(target(f), ' ');
      await tester.runAsync(() => f.repository.deleteDimension(f.dimension.id));
      await f.flush(tester);
      expect(picker(f), findsNothing);
      expect(label(f, 0), findsNothing);
      expect(raw.text, ' ');
      await tester.enterText(target(f), 'Après suppression');
      await f.flush(tester);
      expect(
        (await tester.runAsync(
          () => SqliteVocabularyRepository(f.db).watchById(f.entryId).first,
        ))!.targetText,
        'Après suppression',
      );
      await press(tester, find.byKey(ValueKey('inline-complete-${f.entryId}')));
      await f.flush(tester);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new dimension creation stays in vocabulary editing and leaves raw text and assignments intact',
    (tester) async {
      final f = PickerFixture();
      await tester.runAsync(f.initialize);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.db.close);
        f.raw.dispose();
      });
      await mount(tester, f, 'en');
      await tester.tap(find.byKey(ValueKey('vocabulary-${f.entryId}')));
      await f.flush(tester);
      final raw = tester.widget<TextField>(target(f)).controller!;
      await tester.enterText(target(f), ' ');
      await press(
        tester,
        find.widgetWithText(
          PikoButton,
          PikoCopy('en').text('category.addDimension'),
        ),
      );
      final name = find.descendant(
        of: find.byKey(const ValueKey('category-dimension-name')),
        matching: find.byType(TextField),
      );
      await tester.enterText(name, 'New dimension');
      await press(
        tester,
        find.widgetWithText(
          PikoButton,
          PikoCopy('en').text('category.saveDimension'),
        ),
      );
      await f.flush(tester);
      expect(
        identical(tester.widget<TextField>(target(f)).controller, raw),
        isTrue,
      );
      expect(raw.text, ' ');
      final definitions = await tester.runAsync(
        () => f.repository.dimensions(f.dimension.collectionId),
      );
      expect(definitions, hasLength(2));
      final added = definitions!.singleWhere(
        (dimension) => dimension.name == 'New dimension',
      );
      expect(
        find.byKey(ValueKey('category-picker-${f.entryId}-${added.id}')),
        findsOneWidget,
      );
      expect(
        await tester.runAsync(() => f.repository.values(added.id)),
        isEmpty,
      );
      expect(
        (await tester.runAsync(
          () => f.repository.assignments(f.entryId),
        ))!.single.valueIds,
        {f.values[0].id},
      );
    },
  );
}
