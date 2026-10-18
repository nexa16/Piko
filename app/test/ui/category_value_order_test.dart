import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/features/collections/filter_selection_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'category_assignment_picker_test.dart' show PickerFixture;

class HeldOrder implements CategoriesRepository {
  HeldOrder(this.real);
  final CategoriesRepository real;
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<List<CategoryValueRecord>> reorderValues({
    required String dimensionId,
    required List<String> expectedOrder,
    required List<String> orderedIds,
  }) async {
    calls++;
    await gate.future;
    return real.reorderValues(
      dimensionId: dimensionId,
      expectedOrder: expectedOrder,
      orderedIds: orderedIds,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OrderHarness {
  final fixture = PickerFixture();
  final results = <CollectionFilterSelection?>[];
  final pending = <Future<void>>[];
  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    int count = 3,
    CategoriesRepository? Function(CategoriesRepository)? decorate,
    double scale = 1,
  }) async {
    await tester.runAsync(() => fixture.initialize(count: count));
    final repository = decorate?.call(fixture.repository) ?? fixture.repository;
    final service = SqliteCollectionQueryService(fixture.db);
    await tester.pumpWidget(
      PikoApp(
        localeController: InterfaceLocaleController(Locale(language)),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    final snapshot = await service.query(
                      collectionId: fixture.dimension.collectionId,
                      at: DateTime.utc(2026, 10, 18),
                    );
                    if (!context.mounted) return;
                    results.add(
                      await showPikoDialog<CollectionFilterSelection>(
                        context,
                        builder: (dialogContext) => MediaQuery(
                          data: MediaQuery.of(
                            dialogContext,
                          ).copyWith(textScaler: TextScaler.linear(scale)),
                          child: FilterSelectionDialog(
                            snapshot: snapshot,
                            opening: const {},
                            categories: repository,
                            canApply: () => true,
                            onPendingWrites: pending.add,
                            reloadDefinitions: () => service.query(
                              collectionId: fixture.dimension.collectionId,
                              at: DateTime.utc(2026, 10, 18),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open filters'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await open(tester);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open filters'));
    await fixture.flush(tester);
  }

  Finder row(int i) =>
      find.byKey(ValueKey('filter-value-${fixture.values[i].id}'));
  Finder menu(int i) =>
      find.byKey(ValueKey('filter-value-menu-${fixture.values[i].id}'));
  Future<void> move(WidgetTester tester, int i, String label) async {
    await tester.ensureVisible(menu(i));
    await tester.pumpAndSettle();
    await tester.tap(menu(i));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await fixture.flush(tester);
  }

  Future<List<String>> order(WidgetTester tester) async =>
      (await tester.runAsync(
        () => fixture.repository.values(fixture.dimension.id),
      ))!.map((v) => v.id).toList();
}

void main() {
  testWidgets(
    'persistent menu order is independent of staged membership and cancel/Apply',
    (tester) async {
      final h = OrderHarness();
      try {
        await h.mount(tester);
        final apply = find.widgetWithText(PikoButton, 'Apply');
        final semantics = tester.ensureSemantics();
        try {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        } finally {
          semantics.dispose();
        }
        final footer = tester.getRect(apply);
        await h.move(tester, 2, 'Move up');
        await h.move(tester, 2, 'Move up');
        expect(await h.order(tester), [
          h.fixture.values[2].id,
          h.fixture.values[0].id,
          h.fixture.values[1].id,
        ]);
        expect(tester.widget<PikoButton>(apply).onPressed, isNull);
        expect(tester.getRect(apply), footer);
        await tester.tap(h.row(0));
        await tester.pumpAndSettle();
        expect(tester.widget<PikoButton>(apply).onPressed, isNotNull);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(h.results.single, isNull);
        await h.open(tester);
        expect(
          tester.getTopLeft(h.row(2)).dy,
          lessThan(tester.getTopLeft(h.row(0)).dy),
        );
        expect(tester.widget<CheckboxListTile>(h.row(0)).value, isFalse);
        await tester.tap(h.row(0));
        await tester.pumpAndSettle();
        await tester.tap(apply);
        await h.fixture.flush(tester);
        expect(h.results.last, {
          h.fixture.dimension.id: {h.fixture.values[0].id},
        });
      } finally {
        await h.fixture.cleanup(tester);
      }
    },
  );

  testWidgets(
    'failed reorder rolls back, retains choices and retries; admission drains after dismissal',
    (tester) async {
      final h = OrderHarness();
      try {
        await h.mount(tester);
        await tester.tap(h.row(0));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => h.fixture.db.customStatement(
            "CREATE TRIGGER fail_order BEFORE UPDATE OF position ON category_values BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
          ),
        );
        await h.move(tester, 2, 'Move up');
        expect(await h.order(tester), h.fixture.values.map((v) => v.id));
        expect(tester.widget<CheckboxListTile>(h.row(0)).value, isTrue);
        expect(
          find.text(PikoCopy('en').text('category.reorderFailed')),
          findsOneWidget,
        );
        await tester.runAsync(
          () => h.fixture.db.customStatement('DROP TRIGGER fail_order'),
        );
        final retry = find.widgetWithText(
          PikoButton,
          PikoCopy('en').text('action.retry'),
        );
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        await tester.tap(retry);
        await h.fixture.flush(tester);
        expect(await h.order(tester), [
          h.fixture.values[0].id,
          h.fixture.values[2].id,
          h.fixture.values[1].id,
        ]);
      } finally {
        await h.fixture.cleanup(tester);
      }
      final delayed = OrderHarness();
      late HeldOrder held;
      try {
        await delayed.mount(tester, decorate: (real) => held = HeldOrder(real));
        await delayed.move(tester, 2, 'Move up');
        expect(held.calls, 1);
        expect(
          tester
              .widget<PikoButton>(find.widgetWithText(PikoButton, 'Apply'))
              .onPressed,
          isNull,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(FilterSelectionDialog), findsNothing);
        held.gate.complete();
        await tester.runAsync(() => Future.wait(delayed.pending));
        await delayed.fixture.flush(tester);
        expect(held.calls, 1);
        expect(await delayed.order(tester), [
          delayed.fixture.values[0].id,
          delayed.fixture.values[2].id,
          delayed.fixture.values[1].id,
        ]);
        expect(tester.takeException(), isNull);
      } finally {
        if (!held.gate.isCompleted) held.gate.complete();
        await delayed.fixture.cleanup(tester);
      }
    },
  );

  testWidgets('long press drag and pointer cancel never toggle membership', (
    tester,
  ) async {
    final h = OrderHarness();
    try {
      await h.mount(tester);
      final before = await h.order(tester);
      var gesture = await tester.startGesture(tester.getCenter(h.row(2)));
      await tester.pump(const Duration(milliseconds: 650));
      await gesture.moveTo(tester.getTopLeft(h.row(0)) + const Offset(80, -32));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.cancel();
      await h.fixture.flush(tester);
      expect(await h.order(tester), before);
      await tester.tap(h.row(0));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(h.row(0)).value, isTrue);
      await tester.tap(h.row(0));
      await tester.pumpAndSettle();
      gesture = await tester.startGesture(tester.getCenter(h.row(2)));
      await tester.pump(const Duration(milliseconds: 650));
      await gesture.moveTo(tester.getTopLeft(h.row(0)) + const Offset(80, -32));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future.wait(h.pending));
      await h.fixture.flush(tester);
      expect((await h.order(tester)).first, h.fixture.values[2].id);
      expect(
        tester
            .widget<PikoButton>(find.widgetWithText(PikoButton, 'Apply'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await h.fixture.cleanup(tester);
    }
  });

  testWidgets(
    'stale group refresh preserves draft and keyboard move retains its control focus',
    (tester) async {
      final h = OrderHarness();
      try {
        await h.mount(tester);
        await tester.tap(h.row(0));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => h.fixture.repository.createValue(
            dimensionId: h.fixture.dimension.id,
            name: 'AAA',
          ),
        );
        await h.move(tester, 2, 'Move up');
        expect(
          find.text(PikoCopy('en').text('category.reorderStale')),
          findsOneWidget,
        );
        expect(tester.widget<CheckboxListTile>(h.row(0)).value, isTrue);
        final before = await h.order(tester);
        await tester.ensureVisible(h.menu(2));
        await tester.pumpAndSettle();
        final focus = Focus.of(
          tester.element(
            find
                .descendant(of: h.menu(2), matching: find.byType(PikoIcon))
                .first,
          ),
        );
        focus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.text('Move up'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await h.fixture.flush(tester);
        final expected = List<String>.of(before)
          ..remove(h.fixture.values[2].id);
        expected.insert(2, h.fixture.values[2].id);
        expect(await h.order(tester), expected);
        expect(focus.hasFocus, isTrue);
        expect(tester.widget<CheckboxListTile>(h.row(0)).value, isTrue);
        await tester.runAsync(
          () => h.fixture.repository.deleteDimension(h.fixture.dimension.id),
        );
        await h.move(tester, 2, 'Move up');
        expect(
          find.text(PikoCopy('en').text('category.reorderStale')),
          findsOneWidget,
        );
        expect(
          find.text(PikoCopy('en').text('r2.noCategories')),
          findsOneWidget,
        );
        expect(find.byType(CheckboxListTile), findsNothing);
      } finally {
        await h.fixture.cleanup(tester);
      }
    },
  );

  testWidgets(
    'value search appears when viewport shrinks and retains its active query on growth',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final h = OrderHarness();
      try {
        await h.mount(tester);
        final search = find.descendant(
          of: find.byKey(const ValueKey('filter-value-search')),
          matching: find.byType(TextField),
        );
        expect(search, findsNothing);
        await tester.binding.setSurfaceSize(const Size(400, 360));
        await tester.pumpAndSettle();
        expect(search, findsOneWidget);
        await tester.enterText(search, 'Value 1');
        await tester.pumpAndSettle();
        final controller = tester.widget<TextField>(search).controller!;
        controller.selection = const TextSelection(
          baseOffset: 1,
          extentOffset: 5,
        );
        await tester.binding.setSurfaceSize(const Size(800, 900));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(search).controller, same(controller));
        expect(controller.text, 'Value 1');
        expect(
          controller.selection,
          const TextSelection(baseOffset: 1, extentOffset: 5),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await h.fixture.cleanup(tester);
      }
    },
  );

  for (final language in ['en', 'de']) {
    testWidgets(
      '$language narrow 200% search disables all subset moves and keeps footer fixed',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final h = OrderHarness(), copy = PikoCopy(language);
        try {
          await h.mount(tester, count: 24, language: language, scale: 2);
          final search = find.descendant(
            of: find.byKey(const ValueKey('filter-value-search')),
            matching: find.byType(TextField),
          );
          expect(search, findsOneWidget);
          final apply = find.widgetWithText(PikoButton, copy.text('r2.apply'));
          final footer = tester.getRect(apply);
          final before = await h.order(tester);
          await tester.enterText(search, 'Value 2');
          await tester.pumpAndSettle();
          expect(
            find.text(copy.text('category.reorderSearch')),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            h.menu(1),
            80,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('filter-values-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(h.menu(1));
          await tester.pumpAndSettle();
          await tester.tap(h.menu(1));
          await tester.pumpAndSettle();
          expect(
            tester
                .widgetList<PopupMenuItem<int>>(find.byType(PopupMenuItem<int>))
                .every((item) => !item.enabled),
            isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(await h.order(tester), before);
          final clearSearch = find.byTooltip(
            copy.text('category.clearValueSearch'),
          );
          await tester.ensureVisible(clearSearch);
          await tester.pumpAndSettle();
          await tester.tap(clearSearch);
          await tester.pumpAndSettle();
          expect(tester.getRect(apply), footer);
          expect(tester.takeException(), isNull);
        } finally {
          await h.fixture.cleanup(tester);
        }
      },
    );
  }
}
