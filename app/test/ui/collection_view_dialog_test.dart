import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_view_controls.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'collection_filters_test.dart' show FilterHarness;

void main() {
  testWidgets('View omits bulk expansion while list entrance remains', (
    tester,
  ) async {
    final h = FilterHarness();
    await h.mount(tester);
    await h.scope.saveView(const CollectionViewPreferences(grouping: 'topic'));
    await tester.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: Column(
            children: [
              CollectionListMenu(binding: h.binding, enabled: true),
              CollectionListResults(binding: h.binding, enabled: true),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-toggle-groups')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('collection-list-menu')));
    await tester.pumpAndSettle();
    final dialog = find.byType(PikoDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Expand all')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Collapse all')),
      findsNothing,
    );
  });
  for (final language in ['en', 'de']) {
    for (final picker in CollectionViewPicker.values) {
      testWidgets('$language $picker staged picker at 320px/200%', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = FilterHarness(), copy = PikoCopy(language);
        await h.mount(tester);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(language),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showCollectionViewPicker(context, h.binding, picker),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
          const Color(0xffE8EFFA),
        );
        final apply = find.widgetWithText(PikoButton, copy.text('r2.apply'));
        final before = tester.getRect(apply);
        expect(before.bottom, lessThan(900));
        expect(tester.widget<PikoButton>(apply).onPressed, isNull);
        void choose(bool changed) {
          switch (picker) {
            case CollectionViewPicker.mode:
              tester
                  .widget<RadioGroup<VocabularyViewMode>>(
                    find.byType(RadioGroup<VocabularyViewMode>),
                  )
                  .onChanged(
                    changed
                        ? VocabularyViewMode.detailed
                        : VocabularyViewMode.compact,
                  );
            case CollectionViewPicker.languageOrder:
              tester
                  .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
                  .onChanged(!changed);
            case CollectionViewPicker.grouping:
              tester
                  .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
                  .onChanged(changed ? 'topic' : '');
            case CollectionViewPicker.sort:
              tester
                  .widget<RadioGroup<VocabularySort>>(
                    find.byType(RadioGroup<VocabularySort>),
                  )
                  .onChanged(
                    changed ? VocabularySort.newest : VocabularySort.original,
                  );
          }
        }

        choose(true);
        await tester.pumpAndSettle();
        expect(tester.getRect(apply), before);
        expect(tester.widget<PikoButton>(apply).onPressed, isNotNull);
        expect(h.scope.view, const CollectionViewPreferences());
        choose(false);
        await tester.pumpAndSettle();
        expect(tester.widget<PikoButton>(apply).onPressed, isNull);
        choose(true);
        await tester.pumpAndSettle();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(h.scope.view, isNot(const CollectionViewPreferences()));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
