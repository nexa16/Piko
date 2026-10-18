import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/features/categories/category_settings_page.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_view_controls.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/settings/collection_settings_overview.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_switch.dart';
import 'category_assignment_picker_test.dart' show PickerFixture;
import 'collection_filters_test.dart' show FilterHarness;
import 'settings_test.dart' as settings;

const copy = PikoCopy('en');
Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder button(String key) => find.widgetWithText(PikoButton, copy.text(key));
Finder nav(String key) =>
    find.widgetWithText(PikoNavigationRow, copy.text(key));

void main() {
  testWidgets(
    'global and direct Collection Settings entrances share the scoped page and return to their origin',
    (tester) async {
      final h = settings.Harness();
      try {
        await tester.runAsync(h.f.initialize);
        await h.mount(tester);
        await h.open(tester);
        await h.flush(tester);
        await press(tester, nav('settingsPreview.collections'));
        await h.flush(tester);
        expect(find.byType(CollectionSettingsOverview), findsOneWidget);
        await press(
          tester,
          find.byKey(ValueKey('collection-settings-${h.f.owner.id}')),
        );
        await h.flush(tester);
        expect(
          tester
              .widget<CollectionDetail>(find.byType(CollectionDetail))
              .settingsOnly,
          isTrue,
        );
        expect(
          find.byKey(const ValueKey('collection-hint-default')),
          findsOneWidget,
        );
        await press(tester, find.byTooltip(copy.text('common.back')));
        expect(find.byType(CollectionSettingsOverview), findsOneWidget);
        await press(tester, find.byTooltip(copy.text('common.back')));
        await press(tester, find.byTooltip(copy.text('common.back')));
        await press(tester, find.byKey(ValueKey('collection-${h.f.owner.id}')));
        await h.flush(tester);
        for (
          var i = 0;
          i < 20 &&
              find
                  .byKey(const ValueKey('collection-menu'))
                  .evaluate()
                  .isEmpty &&
              find
                  .byKey(const ValueKey('collection-compact-menu'))
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await h.flush(tester);
        }
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CollectionDetail>(find.byType(CollectionDetail))
              .settingsOnly,
          isFalse,
        );
        await tester.tap(
          find
              .byTooltip(copy.text('settingsPreview.collectionSettings'))
              .hitTestable()
              .first,
        );
        await tester.pumpAndSettle();
        await h.flush(tester);
        expect(
          tester
              .widget<CollectionDetail>(find.byType(CollectionDetail))
              .settingsOnly,
          isTrue,
        );
        await press(
          tester,
          find.byKey(const ValueKey('collection-menu-delete')),
        );
        await press(tester, button('action.cancel'));
        expect(
          (await tester.runAsync(
            () => h.f.vocabulary.watchById(h.f.entry.id).first,
          )),
          isNotNull,
        );
        await press(tester, find.byTooltip(copy.text('common.back')));
        expect(
          tester
              .widget<CollectionDetail>(find.byType(CollectionDetail))
              .settingsOnly,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await h.cleanup(tester);
      }
    },
  );

  testWidgets(
    'group properties stage atomically; mode dismissal retains raw text and Values/assignments survive Save',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(f.initialize);
        await tester.pumpWidget(
          PikoApp(
            home: CategorySettingsPage(
              collectionId: f.dimension.collectionId,
              collectionName: 'Words',
              repository: f.repository,
            ),
          ),
        );
        await f.flush(tester);
        await press(tester, find.text(f.dimension.name));
        await f.flush(tester);
        final input = find.descendant(
          of: find.byKey(
            ValueKey('category-management-name-${f.dimension.id}'),
          ),
          matching: find.byType(TextField),
        );
        await tester.enterText(input, ' New group ');
        await tester.pump();
        await press(tester, nav('r2.mode'));
        await press(
          tester,
          find.widgetWithText(
            RadioListTile<CategoryMode>,
            copy.text('r2.single'),
          ),
        );
        await press(tester, find.byTooltip(copy.text('common.close')));
        expect(tester.widget<TextField>(input).controller!.text, ' New group ');
        expect(
          (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!.mode,
          CategoryMode.multiple,
        );
        await press(tester, nav('r2.mode'));
        await press(
          tester,
          find.widgetWithText(
            RadioListTile<CategoryMode>,
            copy.text('r2.single'),
          ),
        );
        await press(tester, button('r2.apply'));
        await press(tester, find.byType(PikoSwitch));
        expect(
          (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!.carryOver,
          isFalse,
        );
        await press(tester, button('category.saveDimension'));
        await f.flush(tester);
        final saved = (await tester.runAsync(
          () => f.repository.dimensionById(f.dimension.id),
        ))!;
        expect(saved.name, 'New group');
        expect(saved.mode, CategoryMode.single);
        expect(saved.carryOver, isTrue);
        expect(
          tester.widget<PikoButton>(button('category.saveDimension')).onPressed,
          isNull,
        );
        expect(
          (await tester.runAsync(
            () => f.repository.values(f.dimension.id),
          ))!.map((value) => value.id),
          f.values.map((value) => value.id),
        );
        expect(
          (await tester.runAsync(
            () => f.repository.assignments(f.entryId),
          ))!.single.valueIds,
          {f.values.first.id},
        );
        await tester.enterText(input, ' Unconfirmed ');
        await tester.pump();
        await press(tester, find.byTooltip(copy.text('common.back')));
        await press(tester, button('entry.continue'));
        expect(
          tester.widget<TextField>(input).controller!.text,
          ' Unconfirmed ',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await f.cleanup(tester);
      }
    },
  );

  testWidgets(
    'View uses one dialog; Back discards the child choice and Apply returns to the updated overview',
    (tester) async {
      final h = FilterHarness();
      try {
        await h.mount(tester);
        await tester.pumpWidget(
          PikoApp(
            home: Scaffold(
              body: CollectionListMenu(binding: h.binding, enabled: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await press(tester, button('settingsPreview.view'));
        await press(tester, nav('view.mode'));
        expect(find.byType(Dialog), findsOneWidget);
        await press(
          tester,
          find.widgetWithText(
            RadioListTile<VocabularyViewMode>,
            copy.text('view.detailed'),
          ),
        );
        await press(tester, find.byTooltip(copy.text('common.back')));
        expect(h.binding.scope.view.mode, VocabularyViewMode.compact);
        await press(tester, nav('view.mode'));
        await press(
          tester,
          find.widgetWithText(
            RadioListTile<VocabularyViewMode>,
            copy.text('view.detailed'),
          ),
        );
        await press(tester, button('r2.apply'));
        expect(h.binding.scope.view.mode, VocabularyViewMode.detailed);
        expect(nav('view.mode'), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        await press(tester, find.byTooltip(copy.text('common.close')));
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
