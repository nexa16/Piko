import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/categories/category_settings_page.dart';
import 'package:piko/features/collections/filter_selection_dialog.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'category_assignment_picker_test.dart' show PickerFixture;

Future<void> move(
  WidgetTester tester,
  PickerFixture fixture,
  String id, {
  String locale = 'en',
}) async {
  final menu = find.byKey(ValueKey('category-order-menu-$id'));
  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(PikoCopy(locale).text('category.moveUp')).last);
  await fixture.flush(tester);
}

void registerRound10OrderTests({String locale = 'en', double scale = 1}) {
  testWidgets(
    '$locale Value order lives in Settings and persists to other category consumers',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fixture = PickerFixture();
      await tester.runAsync(() => fixture.initialize(count: 3));
      try {
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: CategoryGroupSettingsPage(
              group: fixture.dimension,
              repository: fixture.repository,
            ),
          ),
        );
        await fixture.flush(tester);
        final before = await tester.runAsync(
          () => fixture.repository.values(fixture.dimension.id),
        );
        await move(tester, fixture, before!.last.id, locale: locale);
        final after = await tester.runAsync(
          () => fixture.repository.values(fixture.dimension.id),
        );
        expect(after!.map((value) => value.id), [
          before[0].id,
          before[2].id,
          before[1].id,
        ]);
        final projection = await tester.runAsync(
          () => SqliteCollectionQueryService(fixture.db).query(
            collectionId: fixture.dimension.collectionId,
            at: DateTime.utc(2026),
          ),
        );
        expect(
          projection!.categoryValues[fixture.dimension.id]!.map(
            (value) => value.id,
          ),
          after.map((value) => value.id),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.cleanup(tester);
      }
    },
  );

  testWidgets(
    '$locale failed Settings reorder keeps stored order and reports failure',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fixture = PickerFixture();
      await tester.runAsync(() => fixture.initialize(count: 3));
      try {
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: CategoryGroupSettingsPage(
              group: fixture.dimension,
              repository: fixture.repository,
            ),
          ),
        );
        await fixture.flush(tester);
        final before = await tester.runAsync(
          () => fixture.repository.values(fixture.dimension.id),
        );
        await tester.runAsync(
          () => fixture.db.customStatement(
            "CREATE TRIGGER fail_order BEFORE UPDATE OF position ON category_values BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
          ),
        );
        await move(tester, fixture, before!.last.id, locale: locale);
        final after = await tester.runAsync(
          () => fixture.repository.values(fixture.dimension.id),
        );
        expect(
          after!.map((value) => value.id),
          before.map((value) => value.id),
        );
        expect(
          find.text(PikoCopy(locale).text('category.dimensionSaveFailed')),
          findsOneWidget,
        );
      } finally {
        await fixture.cleanup(tester);
      }
    },
  );
}

void main() {
  registerRound10OrderTests();
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale Filters retain staged selection and search without reorder controls',
      (tester) async {
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final fixture = PickerFixture();
        await tester.runAsync(() => fixture.initialize(count: 24));
        final service = SqliteCollectionQueryService(fixture.db);
        final snapshot = (await tester.runAsync(
          () => service.query(
            collectionId: fixture.dimension.collectionId,
            at: DateTime.utc(2026),
          ),
        ))!;
        final results = <CollectionFilterSelection?>[];
        try {
          await tester.pumpWidget(
            PikoApp(
              locale: Locale(locale),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Open'),
                    onPressed: () async {
                      results.add(
                        await showPikoDialog<CollectionFilterSelection>(
                          context,
                          builder: (_) => FilterSelectionDialog(
                            snapshot: snapshot,
                            opening: const {},
                            reloadDefinitions: () => service.query(
                              collectionId: fixture.dimension.collectionId,
                              at: DateTime.utc(2026),
                            ),
                            canApply: () => true,
                            categories: fixture.repository,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await fixture.flush(tester);
          expect(
            find.byType(ReorderableDelayedDragStartListener),
            findsNothing,
          );
          expect(find.byType(PopupMenuButton<int>), findsNothing);
          final search = find.descendant(
            of: find.byKey(const ValueKey('filter-value-search')),
            matching: find.byType(TextField),
          );
          expect(search, findsOneWidget);
          await tester.enterText(search, 'Value 1');
          await tester.pumpAndSettle();
          final row = find.byKey(
            ValueKey('filter-value-${fixture.values.first.id}'),
          );
          await tester.scrollUntilVisible(
            row,
            80,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('filter-values-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          await tester.tap(row);
          await tester.pumpAndSettle();
          final apply = find.widgetWithText(
            PikoButton,
            PikoCopy(locale).text('r2.apply'),
          );
          expect(tester.widget<PikoButton>(apply).onPressed, isNotNull);
          await tester.tap(apply);
          await fixture.flush(tester);
          expect(results.single!.values.single, hasLength(1));
          expect(tester.takeException(), isNull);
        } finally {
          await fixture.cleanup(tester);
        }
      },
    );
  }
}
