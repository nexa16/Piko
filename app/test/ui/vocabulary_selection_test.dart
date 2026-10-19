import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/features/vocabulary/vocabulary_selection.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'collection_inline_runtime_test.dart' show ObservedDatabase;
import '../data/regular_reviews_test.dart' show Fixture, instant;
import '../support/mutable_clock.dart';

Finder key(String value) => find.byKey(ValueKey(value));

class SelectionHarness {
  final db = ObservedDatabase();
  late final fixture = Fixture(database: db);
  late final json = SqliteVocabularyJsonService(
    db,
    clock: MutablePikoClock(instant),
  );
  late String topic, food, travel;
  late String before;
  VocabularySelection selection(WidgetTester tester) => tester
      .widget<CollectionVocabulary>(find.byType(CollectionVocabulary))
      .selection!;
  Future<void> mount(
    WidgetTester tester, {
    String locale = 'en',
    double width = 392,
    double scale = 1,
  }) async {
    await fixture.initialize();
    await SqliteSettingsRepository(db).write('locale', locale);
    await fixture.review();
    for (var i = 0; i < 19; i++) {
      await fixture.vocabulary.create(
        collectionId: fixture.owner.id,
        targetText: 'Word $i',
        nativeText: 'Translation $i',
      );
    }
    final categories = SqliteCategoriesRepository(db);
    final dimension = await categories.createDimension(
      collectionId: fixture.owner.id,
      name: 'Topic',
      mode: CategoryMode.multiple,
    );
    topic = dimension.id;
    food = (await categories.createValue(dimensionId: topic, name: 'Food')).id;
    travel = (await categories.createValue(
      dimensionId: topic,
      name: 'Travel',
    )).id;
    await categories.replaceAssignments(
      entryId: fixture.entry.id,
      assignments: {
        topic: {food, travel},
      },
    );
    before = await json.exportCollection(fixture.owner.id);
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      PikoApp(
        locale: Locale(locale),
        home: PikoRuntime(databaseFactory: () => db),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(key('collection-${fixture.owner.id}'));
    await tester.tap(
      find
          .descendant(
            of: key('collection-${fixture.owner.id}'),
            matching: find.text(fixture.owner.name),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    // A pinned header may cover an item aligned to the viewport's leading edge.
    // Center the actual target and require a real hit before the caller acts.
    for (var attempt = 0; attempt < 4; attempt++) {
      await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
      await tester.pumpAndSettle();
      if (finder.hitTestable().evaluate().isNotEmpty) break;
    }
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> start(WidgetTester tester) async {
    final card = key('vocabulary-${fixture.entry.id}');
    await reveal(tester, card);
    await tester.longPress(card);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'three card states retain positions, scroll and panel clearance',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester);
      final card = key('vocabulary-${h.fixture.entry.id}');
      await h.reveal(tester, card);
      final rect = tester.getRect(card);
      final text = find.descendant(of: card, matching: find.text('One'));
      final textOrigin = tester.getTopLeft(text);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = scroll.pixels;
      final indicator = key(
        'vocabulary-selection-indicator-${h.fixture.entry.id}',
      );
      expect(indicator, findsNothing);
      await tester.longPress(card);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids, {h.fixture.entry.id});
      expect(indicator, findsOneWidget);
      expect(tester.getRect(card), rect);
      expect(tester.getTopLeft(text), textOrigin);
      expect(scroll.pixels, offset);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(h.selection(tester).active, isTrue);
      expect(h.selection(tester).ids, isEmpty);
      expect(indicator, findsOneWidget);
      expect(tester.getRect(card), rect);
      h.selection(tester).clear();
      await tester.pumpAndSettle();
      expect(indicator, findsNothing);
      expect(tester.getTopLeft(text), textOrigin);
      expect(scroll.pixels, offset);
      await tester.longPress(card);
      await tester.pumpAndSettle();
      final scrollRect = tester.getRect(find.byType(Scrollable).first);
      final panelRect = tester.getRect(key('vocabulary-selection-panel'));
      expect(scrollRect.bottom, greaterThan(panelRect.top));
      expect(scrollRect.bottom, 900);
      final entries = tester
          .widget<CollectionDetail>(find.byType(CollectionDetail))
          .queryBinding!
          .snapshot!
          .allEntries;
      final last = key('vocabulary-${entries.last.id}');
      await h.reveal(tester, last);
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(panelRect.top + .1),
      );
      expect(await h.json.exportCollection(h.fixture.owner.id), h.before);
    },
  );

  testWidgets(
    'hidden selections, collapsed Select all and duplicate appearances share UUIDs',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester);
      await h.start(tester);
      final detail = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      final scope = detail.queryBinding!.scope;
      scope.setSearch('Word 9');
      await tester.pumpAndSettle();
      expect(
        h
            .selection(tester)
            .hidden(detail.queryBinding!.snapshot!.entries.map((e) => e.id)),
        1,
      );
      expect(find.text('1 hidden by filters or search'), findsOneWidget);
      await tester.tap(key('vocabulary-select-all'));
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids.length, 2);
      scope.setSearch('');
      await tester.pumpAndSettle();
      await scope.saveView(CollectionViewPreferences(grouping: h.topic));
      await tester.pumpAndSettle();
      expect(scope.expandedGroups, isEmpty);
      await tester.tap(key('vocabulary-select-all'));
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids.length, 20);
      scope.expandGroups([h.food, h.travel], true);
      await tester.pumpAndSettle();
      final first = key('vocabulary-${h.food}/${h.fixture.entry.id}');
      await h.reveal(tester, first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids.length, 19);
      final duplicate = key('vocabulary-${h.travel}/${h.fixture.entry.id}');
      await h.reveal(tester, duplicate);
      await tester.tap(duplicate);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids.length, 20);
      scope.setSearch('no matches');
      await tester.pumpAndSettle();
      await tester.tap(key('vocabulary-clear-selection'));
      await tester.pumpAndSettle();
      expect(h.selection(tester).active, isFalse);
      expect(h.selection(tester).ids, isEmpty);
      expect(await h.json.exportCollection(h.fixture.owner.id), h.before);
    },
  );

  testWidgets(
    'same-page popup retains selection and real page departure clears it',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester);
      await h.start(tester);
      final chip = key('collection-filters');
      await h.reveal(tester, chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids.length, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids.length, 1);
      final context = tester.element(find.byType(CollectionDetail));
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Another page')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(h.selection(tester).active, isFalse);
      expect(h.selection(tester).ids, isEmpty);
    },
  );

  testWidgets('keyboard selection toggles the same accessible card state', (
    tester,
  ) async {
    final h = SelectionHarness();
    await h.mount(tester);
    final semantics = tester.ensureSemantics();
    try {
      final card = key('vocabulary-${h.fixture.entry.id}');
      await h.reveal(tester, card);
      Focus.of(tester.element(card)).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids, {h.fixture.entry.id});
      expect(find.bySemanticsLabel('One, Eins'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids, isEmpty);
      expect(h.selection(tester).active, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(h.selection(tester).ids, {h.fixture.entry.id});
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'text long-press and invalid modal draft preserve background selection and data',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester);
      final card = key('vocabulary-${h.fixture.entry.id}');
      await h.reveal(tester, card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: key('inline-${h.fixture.entry.id}-target'),
        matching: find.byType(TextField),
      );
      await h.reveal(tester, field);
      await tester.longPress(field);
      await tester.pumpAndSettle();
      expect(h.selection(tester).active, isFalse);
      // Collapse the text selection before checking modal/background isolation.
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, '   ');
      await tester.pumpAndSettle();
      // Saved editing is modal. Background cards are intentionally unreachable;
      // exercise the real barrier instead of claiming a missed card long press
      // delivered an event. Keep the dirty modal and exact stored data intact.
      expect(find.byType(ModalBarrier), findsWidgets);
      expect(card.hitTestable(), findsNothing);
      await tester.longPressAt(const Offset(4, 450));
      await tester.pumpAndSettle();
      expect(h.selection(tester).active, isFalse);
      expect(find.byType(ModalBarrier), findsWidgets);
      expect(tester.widget<TextField>(field).controller!.text, '   ');
      expect(await h.json.exportCollection(h.fixture.owner.id), h.before);
    },
  );

  testWidgets(
    'German narrow enlarged panel overlays the full viewport with reachable controls',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester, locale: 'de', width: 320, scale: 2);
      await h.start(tester);
      final detail = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      detail.queryBinding!.scope.setSearch('no matches');
      await tester.pumpAndSettle();
      expect(
        find.text(const PikoCopy('de').text('selection.hidden', {'count': 1})),
        findsOneWidget,
      );
      final viewport = tester.getRect(find.byType(Scrollable).first);
      final panel = tester.getRect(key('vocabulary-selection-scroll'));
      expect(
        viewport.height -
            tester.getSize(key('collection-compact-header')).height,
        greaterThanOrEqualTo(48),
      );
      expect(viewport.bottom, 900);
      expect(panel.top, lessThan(viewport.bottom));
      expect(panel.left, greaterThanOrEqualTo(0));
      expect(panel.right, lessThanOrEqualTo(320));
      expect(panel.bottom, lessThanOrEqualTo(900));
      for (final id in [
        'vocabulary-clear-selection',
        'vocabulary-select-all',
      ]) {
        await tester.ensureVisible(key(id));
        await tester.pumpAndSettle();
        expect(key(id).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'enlarged help Back retains mounted selection even with the list outside the viewport',
    (tester) async {
      final h = SelectionHarness();
      await h.mount(tester, locale: 'de', width: 320, scale: 2);
      await h.start(tester);
      final retained = h.selection(tester);
      final help = key('collection-learning-help');
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      for (var i = 0; i < 20 && help.hitTestable().evaluate().isEmpty; i++) {
        final viewport = tester.getRect(find.byType(Scrollable).first);
        await tester.dragFrom(
          Offset(viewport.center.dx, viewport.bottom - 24),
          const Offset(0, -80),
        );
        await tester.pumpAndSettle();
      }
      expect(help.hitTestable(), findsOneWidget);
      await tester.tap(help);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CollectionDetail), findsOneWidget);
      expect(
        find.byType(CollectionVocabulary, skipOffstage: false),
        findsOneWidget,
      );
      expect(retained.ids, {h.fixture.entry.id});
      await h.reveal(tester, key('vocabulary-${h.fixture.entry.id}'));
      expect(h.selection(tester).ids, {h.fixture.entry.id});
    },
  );
}
