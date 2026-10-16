import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/categories/category_assignment_picker.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../features/entry_session_category_test.dart' show EntryCategoryFixture;
import 'category_assignment_picker_test.dart' show value, checked;
import 'category_inline_value_test.dart' show press;
import 'entry_stack_test.dart' show field;
import 'entry_keyboard_layout_test.dart' show scrollActionIntoView;

Future<void> flush(WidgetTester tester, EntryCategoryFixture f) async {
  await tester.runAsync(f.flush);
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  EntryCategoryFixture f,
  String language,
) async {
  await tester.pumpWidget(
    PikoApp(
      localeController: InterfaceLocaleController(Locale(language)),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: EntrySessionScreen(
            collection: f.collection,
            session: f.session,
            categoriesRepository: f.categories,
          ),
        ),
      ),
    ),
  );
  await flush(tester, f);
}

Future<void> pressCardAction(WidgetTester tester, Finder action) async {
  if (action.evaluate().isEmpty) {
    final section = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'categories-toggle-',
              ),
        )
        .last;
    await scrollActionIntoView(tester, section);
    await tester.tap(section);
    await tester.pumpAndSettle();
  }
  await scrollActionIntoView(tester, action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Finder picker(EntryCategoryFixture f, String id) =>
    find.byKey(ValueKey('category-picker-$id-${f.dimension.id}'));
Finder chip(EntryCategoryFixture f, String id, String valueId) {
  final section = find.byKey(ValueKey('categories-toggle-$id'));
  final name = valueId == f.first.id ? f.first.name : f.second.name;
  return section.evaluate().isNotEmpty
      ? find.descendant(of: section, matching: find.textContaining(name))
      : find.byKey(ValueKey('category-label-$id-$valueId'));
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language new assignment Apply retains raw entry text, confirmation persists atomically, and saved invalid edit keeps category draft',
      (tester) async {
        final f = EntryCategoryFixture();
        await tester.runAsync(f.initialize);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.runAsync(f.close);
        });
        await mount(tester, f, language);
        await tester.enterText(field('draft', 'target'), ' Pomme ');
        await tester.enterText(field('draft', 'native'), ' Apfel ');
        final raw = tester
            .widget<TextField>(field('draft', 'native'))
            .controller!;
        final selection = raw.selection;
        await pressCardAction(tester, picker(f, 'draft'));
        await flush(tester, f);
        await press(tester, value(f.second));
        expect(
          await tester.runAsync(
            () => f.vocabulary.watchByCollection(f.collection.id).first,
          ),
          isEmpty,
        );
        await press(
          tester,
          find.widgetWithText(PikoButton, PikoCopy(language).text('r2.apply')),
        );
        await flush(tester, f);
        expect(
          identical(
            tester.widget<TextField>(field('draft', 'native')).controller,
            raw,
          ),
          isTrue,
        );
        expect(raw.text, ' Apfel ');
        expect(raw.selection, selection);
        expect(f.session.draft.assignments[f.dimension.id], {f.second.id});
        expect(chip(f, 'draft', f.second.id), findsOneWidget);
        expect(await tester.runAsync(f.learning), isEmpty);
        await pressCardAction(
          tester,
          find.byTooltip(PikoCopy(language).text('action.saveNext')),
        );
        await flush(tester, f);
        final saved = f.session.confirmedEntries.single;
        expect(
          (await tester.runAsync(
            () => f.categories.assignments(saved.id),
          ))!.single.valueIds,
          {f.second.id},
        );
        expect(f.session.draft.assignments, isEmpty);
        expect(chip(f, saved.id, f.second.id), findsOneWidget);
        expect(chip(f, 'draft', f.second.id), findsNothing);
        f.session.selectSavedEntry(saved.id);
        await flush(tester, f);
        await tester.enterText(field(saved.id, 'target'), ' ');
        await pressCardAction(tester, picker(f, saved.id));
        await flush(tester, f);
        expect(f.session.activeEntryId, saved.id);
        expect(checked(tester, f.second), isTrue);
        expect(checked(tester, f.first), isFalse);
        await press(tester, value(f.first));
        expect(checked(tester, f.first), isTrue);
        expect(checked(tester, f.second), isTrue);
        await press(
          tester,
          find.widgetWithText(PikoButton, PikoCopy(language).text('r2.apply')),
        );
        await flush(tester, f);
        expect(find.byType(CategoryAssignmentPicker), findsNothing);
        expect(f.session.activeEntryId, saved.id);
        expect(
          tester.widget<TextField>(field(saved.id, 'target')).controller!.text,
          ' ',
        );
        expect(
          f.session.savedEntryState(saved.id).draft.assignments[f.dimension.id],
          {f.first.id, f.second.id},
        );
        expect(
          (await tester.runAsync(
            () => f.categories.assignments(saved.id),
          ))!.single.valueIds,
          {f.second.id},
        );
        await tester.enterText(field(saved.id, 'target'), 'Changed');
        await flush(tester, f);
        expect(
          (await tester.runAsync(
            () => f.categories.assignments(saved.id),
          ))!.single.valueIds,
          {f.first.id, f.second.id},
        );
        expect(await tester.runAsync(f.learning), hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'new dimension creation retains unsaved entry and categories-only draft participates in safe exit',
    (tester) async {
      final f = EntryCategoryFixture();
      await tester.runAsync(f.initialize);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.close);
      });
      await mount(tester, f, 'en');
      await pressCardAction(
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
      await flush(tester, f);
      expect(
        (await tester.runAsync(() => f.categories.dimensions(f.collection.id))),
        hasLength(2),
      );
      expect(f.session.draft.targetText, isEmpty);
      expect(f.session.draft.assignments, isEmpty);
      await pressCardAction(tester, picker(f, 'draft'));
      await flush(tester, f);
      await press(tester, value(f.first));
      await press(
        tester,
        find.widgetWithText(PikoButton, PikoCopy('en').text('r2.apply')),
      );
      await flush(tester, f);
      expect(f.session.draft.assignments[f.dimension.id], {f.first.id});
      final back = find.byTooltip(PikoCopy('en').text('common.back'));
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text(PikoCopy('en').text('entry.exitTitle')), findsOneWidget);
      expect(
        await tester.runAsync(
          () => f.vocabulary.watchByCollection(f.collection.id).first,
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'picker result from a replaced session cannot mutate its new draft',
    (tester) async {
      final f = EntryCategoryFixture();
      await tester.runAsync(f.initialize);
      final replacement = EntrySessionController(
        collectionId: f.collection.id,
        repository: f.vocabulary,
      );
      final current = ValueNotifier(f.session);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        current.dispose();
        replacement.dispose();
        await tester.runAsync(replacement.awaitSavedEdits);
        await tester.runAsync(f.close);
      });
      await tester.pumpWidget(
        PikoApp(
          home: ValueListenableBuilder<EntrySessionController>(
            valueListenable: current,
            builder: (_, session, _) => EntrySessionScreen(
              collection: f.collection,
              session: session,
              categoriesRepository: f.categories,
            ),
          ),
        ),
      );
      await flush(tester, f);
      await pressCardAction(tester, picker(f, 'draft'));
      await flush(tester, f);
      await press(tester, value(f.first));
      current.value = replacement;
      await flush(tester, f);
      await press(
        tester,
        find.widgetWithText(PikoButton, PikoCopy('en').text('r2.apply')),
      );
      await flush(tester, f);
      expect(replacement.draft.assignments, isEmpty);
      expect(f.session.draft.assignments, isEmpty);
      expect(
        await tester.runAsync(
          () => f.vocabulary.watchByCollection(f.collection.id).first,
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
