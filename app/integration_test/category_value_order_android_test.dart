import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/filter_selection_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native value ordering across Filters, tags, picker and reopen', (
    tester,
  ) async {
    final config = CatalogueConfiguration(),
        copy = PikoCopy(CatalogueConfiguration().locale);
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/value-order-${config.runId}');
    if (await directory.exists()) throw StateError('Evidence already exists');
    await directory.create();
    final file = File('${directory.path}/fixture.sqlite');
    final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12));
    final db = review.ReviewFixtureDatabase(file, clock);
    // All app services use this one isolated connection; production is guarded
    // externally by the attach-only runner and never opened by this fixture.
    final data = Fixture(database: db);
    final categories = SqliteCategoriesRepository(db);
    var passed = false, converted = false;
    final manifest = <String, Object?>{
      'sourceCommit': config.commit,
      'locale': config.locale,
      'scale': config.scale,
    };
    Finder key(String value) => find.byKey(ValueKey(value));
    Finder filterScroll() => find
        .descendant(
          of: key('filter-values-scroll'),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> tap(Finder target, {Finder? scroll}) async {
      if (target.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          target,
          100,
          scrollable: scroll ?? find.byType(Scrollable).first,
          maxScrolls: 100,
        );
      }
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target.hitTestable().first);
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      if (config.locale != 'en') return;
      await settleCatalogueCapture(tester, name);
      if (!converted) {
        await integration.convertFlutterSurfaceToImage();
        await tester.pump();
        converted = true;
      }
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(await integration.takeScreenshot(name));
    }

    Future<Map<String, Object?>> protectedRows() async => {
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
        'vocabulary_entries',
        'vocabulary_category_assignments',
        'statistics_activity',
        'speed_completion_receipts',
      ])
        table: await review.rows(db, table),
    };
    try {
      await data.initialize();
      final group = await categories.createDimension(
        collectionId: data.owner.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final mainValues = <CategoryValueRecord>[];
      for (final name in ['apple', 'Banana', 'Zebra']) {
        mainValues.add(
          await categories.createValue(dimensionId: group.id, name: name),
        );
      }
      for (var i = 0; i < 24; i++) {
        await categories.createValue(
          dimensionId: group.id,
          name: 'Value ${i.toString().padLeft(2, '0')}',
        );
      }
      await categories.replaceAssignments(
        entryId: data.entry.id,
        assignments: {group.id: mainValues.map((v) => v.id).toSet()},
      );
      await data.review();
      await data.review(reverse: true);
      await SqliteSettingsRepository(db).write('locale', config.locale);
      final baseline = await protectedRows();
      await tester.pumpWidget(
        PikoApp(
          locale: Locale(config.locale),
          home: PikoRuntime(
            databaseFactory: () => db,
            jsonPlatform: CatalogueJsonPlatform(),
          ),
        ),
      );
      await hydratedRuntimeCopy(tester);
      await review.waitUntil(
        tester,
        () => key('collection-${data.owner.id}').evaluate().isNotEmpty,
      );
      await tap(key('collection-${data.owner.id}'));
      final media = MediaQuery.of(
        tester.element(find.byType(CollectionDetail)),
      );
      manifest['width'] = media.size.width;
      manifest['textScale'] = media.textScaler.scale(14) / 14;
      if (config.scale == '200') {
        expect(media.size.width, closeTo(320, 1));
        expect(media.textScaler.scale(14), closeTo(28, 1));
      }
      await tap(key('collection-filters'));
      final apply = find.widgetWithText(PikoButton, copy.text('r2.apply'));
      final footer = tester.getRect(apply);
      final opening = (await categories.values(
        group.id,
      )).map((v) => v.id).toList();
      final moved = config.locale == 'en' ? mainValues[2] : mainValues[1];
      if (config.locale == 'en') {
        await tester.scrollUntilVisible(
          key('filter-value-${moved.id}'),
          160,
          scrollable: filterScroll(),
          maxScrolls: 100,
        );
        await tester.ensureVisible(key('filter-value-${moved.id}'));
        await tester.pumpAndSettle();
        final state = tester.state<ScrollableState>(filterScroll());
        final bottom = state.position.pixels;
        expect(bottom, greaterThan(400));
        // Canceled pointer leaves both order and membership unchanged.
        var gesture = await tester.startGesture(
          tester.getCenter(key('filter-value-${moved.id}')),
        );
        await tester.pump(const Duration(milliseconds: 650));
        await gesture.moveBy(const Offset(0, -90));
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect((await categories.values(group.id)).map((v) => v.id), opening);
        gesture = await tester.startGesture(
          tester.getCenter(key('filter-value-${moved.id}')),
        );
        await tester.pump(const Duration(milliseconds: 650));
        final viewport = tester.getRect(key('filter-values-scroll'));
        await gesture.moveTo(Offset(viewport.center.dx, viewport.top + 2));
        for (var i = 0; i < 180 && state.position.pixels > 0; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(state.position.pixels, lessThan(bottom - 400));
        await gesture.moveTo(
          tester.getTopLeft(key('filter-value-${mainValues[0].id}')) +
              const Offset(70, -32),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pumpAndSettle();
      } else {
        await tap(key('filter-value-menu-${moved.id}'), scroll: filterScroll());
        await tap(find.text(copy.text('category.moveUp')));
      }
      await review.waitUntil(
        tester,
        () async => (await categories.values(group.id)).first.id == moved.id,
      );
      expect(tester.widget<PikoButton>(apply).onPressed, isNull);
      expect(tester.getRect(apply), footer);
      final custom = (await categories.values(
        group.id,
      )).map((v) => v.id).toList();
      await tap(
        key('filter-value-${mainValues[0].id}'),
        scroll: filterScroll(),
      );
      expect(tester.widget<PikoButton>(apply).onPressed, isNotNull);
      await tap(key('filters-clear-pending'));
      expect(tester.widget<PikoButton>(apply).onPressed, isNull);
      await tap(
        key('filter-value-${mainValues[0].id}'),
        scroll: filterScroll(),
      );
      await tap(find.byTooltip(copy.text('common.close')));
      await tap(key('collection-filters'));
      await tap(key('filter-value-menu-${moved.id}'), scroll: filterScroll());
      expect(find.text(copy.text('category.firstPosition')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(key('filter-value-${moved.id}')).value,
        isFalse,
      );
      final search = find.descendant(
        of: key('filter-value-search'),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'Value 2');
      await tester.pumpAndSettle();
      expect(find.text(copy.text('category.reorderSearch')), findsOneWidget);
      await tap(
        find.byType(PopupMenuButton<int>).first,
        scroll: filterScroll(),
      );
      expect(
        tester
            .widgetList<PopupMenuItem<int>>(find.byType(PopupMenuItem<int>))
            .every((item) => !item.enabled),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tap(find.byTooltip(copy.text('category.clearValueSearch')));
      expect((await categories.values(group.id)).map((v) => v.id), custom);
      await tap(key('filter-value-${moved.id}'), scroll: filterScroll());
      await tap(apply);
      await review.waitUntil(
        tester,
        () => find.byType(FilterSelectionDialog).evaluate().isEmpty,
      );
      await tap(key('collection-filters'));
      await tap(key('filters-clear-pending'));
      await tap(apply);
      // Actual saved-word editor consumes the same effective sequence.
      await tester.scrollUntilVisible(
        key('vocabulary-${data.entry.id}'),
        100,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      final selectedIds = mainValues.map((v) => v.id).toSet();
      final tags = tester
          .widgetList(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'category-label-${data.entry.id}-',
                  ),
            ),
          )
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      expect(
        tags,
        custom
            .where(selectedIds.contains)
            .map((id) => 'category-label-${data.entry.id}-$id')
            .toList(),
      );
      await tap(key('vocabulary-${data.entry.id}'));
      await tap(key('categories-toggle-${data.entry.id}'));
      await tap(key('category-picker-${data.entry.id}-${group.id}'));
      final pickerIds = tester
          .widgetList<PikoCheckbox>(find.byType(PikoCheckbox))
          .map((w) => (w.key as ValueKey).value.toString())
          .toList();
      expect(pickerIds, custom.map((id) => 'category-value-$id').toList());
      await tap(find.byTooltip(copy.text('common.close')));
      expect(await protectedRows(), baseline);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await review.waitUntil(
        tester,
        () => key('collection-${data.owner.id}').evaluate().isNotEmpty,
      );
      await tap(key('collection-${data.owner.id}'));
      await tap(key('collection-menu'));
      await tap(key('collection-menu-categories'));
      await tap(key('category-dimension-${group.id}'));
      final managementRows = find.descendant(
        of: key('category-dimension-${group.id}'),
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              custom.contains((w.key! as ValueKey<String>).value),
        ),
      );
      await review.waitUntil(
        tester,
        () => managementRows.evaluate().length == custom.length,
      );
      expect(
        tester
            .widgetList(managementRows)
            .map((w) => (w.key! as ValueKey<String>).value),
        custom,
      );
      await tap(find.byTooltip(copy.text('common.close')));
      await tap(key('collection-group'));
      await tap(key('view.grouping-${group.id}'));
      await tap(find.widgetWithText(PikoButton, copy.text('r2.apply')));
      final groupedIds = custom.where(selectedIds.contains).toList();
      for (final id in groupedIds) {
        await tester.scrollUntilVisible(
          key('collection-group-$id'),
          80,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 100,
        );
        await tester.pumpAndSettle();
      }
      final headingTops = groupedIds
          .map((id) => tester.getTopLeft(key('collection-group-$id')).dy)
          .toList();
      expect(headingTops, orderedEquals(List<double>.of(headingTops)..sort()));
      expect(await protectedRows(), baseline);
      // Return to a new popup and capture one normal-size important surface.
      await tap(key('collection-filters'));
      final scroll = tester.state<ScrollableState>(filterScroll());
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      await capture('values-order');
      await tap(find.byTooltip(copy.text('common.close')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await db.closed.future;
      final reopened = PikoDatabase(NativeDatabase(file), clock: clock);
      try {
        expect(
          (await SqliteCategoriesRepository(
            reopened,
          ).values(group.id)).map((v) => v.id),
          custom,
        );
        for (final entry in baseline.entries) {
          expect(await review.rows(reopened, entry.key), entry.value);
        }
        expect(
          await reopened.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await reopened.close();
      }
      manifest['assertions'] = [
        'direct order independent of Apply/Clear/cancel',
        if (config.locale == 'en')
          'long-press drag, pointer cancellation and long-list autoscroll',
        if (config.locale != 'en')
          'accessible move-up menu at native320dp/200%',
        'search disables subset moves',
        'fixed footer',
        'real saved-word picker sequence',
        'actual tags and category management sequence; grouped headings reachable',
        'reopened order and exact vocabulary/learning/assignments/statistics',
      ];
      passed = true;
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      if (!db.closed.isCompleted) await db.close();
      manifest['passed'] = passed;
      await File('${directory.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      debugPrint('PIKO_VALUE_ORDER_EVIDENCE:${directory.path}');
    }
  });
}
