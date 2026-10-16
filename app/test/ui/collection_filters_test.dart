import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/collections/filter_selection_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner;
import 'collection_query_detail_test.dart' show ProjectionService, projection;
import 'collection_review_entry_points_test.dart' show Collections;

const topic = CategoryDimensionRecord(
  id: 'topic',
  collectionId: 'owner',
  name: 'Topic',
  mode: CategoryMode.single,
  position: 0,
);
const food = CategoryValueRecord(
  id: 'food',
  dimensionId: 'topic',
  name: 'Food',
  position: 0,
);
const travel = CategoryValueRecord(
  id: 'travel',
  dimensionId: 'topic',
  name: 'Travel',
  position: 1,
);
CollectionQuerySnapshot definitions({
  bool deleted = false,
  bool empty = false,
}) {
  final base = projection(visible: empty ? [] : projection().entries);
  return CollectionQuerySnapshot(
    collection: base.collection,
    allEntries: base.allEntries,
    entries: base.entries,
    categoryDimensions: const [topic],
    categoryValues: {
      'topic': [food, if (!deleted) travel],
    },
    assignments: const {},
    directions: base.directions,
  );
}

Finder apply() => find.widgetWithText(PikoButton, 'Apply');
Finder value(String id) => find.byKey(ValueKey('filter-value-$id'));

class FilterHarness {
  final scope = CollectionViewScope();
  final service = ProjectionService(definitions());
  final vocabulary = LiveVocabulary();
  late final binding = CollectionQueryBinding(
    collectionId: owner.id,
    service: service,
    scope: scope,
    invalidations: const Stream<void>.empty(),
  );
  Future<void> mount(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      binding.dispose();
      scope.dispose();
      await vocabulary.close();
    });
    await tester.pumpWidget(
      PikoApp(
        home: CollectionDetail(
          repository: const Collections([owner]),
          collectionId: owner.id,
          vocabularyRepository: vocabulary,
          queryBinding: binding,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('collection-filters')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'filters stage changes and Clear until changed-only Apply, preserving raw search',
    (tester) async {
      final h = FilterHarness()..scope.setSearch('  Straße  ');
      h.scope.setFilters({
        'topic': {'food'},
      });
      await h.mount(tester);
      await h.open(tester);
      expect(tester.widget<PikoButton>(apply()).onPressed, isNull);
      final rowBefore = tester.getRect(value('travel'));
      await tester.tap(value('travel'));
      await tester.pumpAndSettle();
      expect(h.scope.filters, {
        'topic': {'food'},
      });
      expect(apply(), findsOneWidget);
      expect(tester.getRect(value('travel')), rowBefore);
      await tester.tap(value('travel'));
      await tester.pumpAndSettle();
      expect(tester.widget<PikoButton>(apply()).onPressed, isNull);
      expect(tester.getRect(value('travel')), rowBefore);
      await tester.tap(find.byKey(const ValueKey('filters-clear-pending')));
      await tester.pumpAndSettle();
      expect(h.scope.filters, {
        'topic': {'food'},
      });
      expect(apply(), findsOneWidget);
      expect(tester.getRect(value('travel')), rowBefore);
      await tester.tap(apply());
      await tester.pumpAndSettle();
      expect(h.scope.filters, isEmpty);
      expect(h.scope.search, '  Straße  ');
      await h.open(tester);
      await tester.tap(value('food'));
      await tester.tap(value('travel'));
      await tester.pumpAndSettle();
      await tester.tap(apply());
      await tester.pumpAndSettle();
      // Single assignment cardinality does not restrict OR filter selection.
      expect(h.scope.filters, {
        'topic': {'food', 'travel'},
      });
      expect(h.scope.search, '  Straße  ');
    },
  );
  testWidgets(
    'X Escape backdrop and system Back discard pending filter choices',
    (tester) async {
      final h = FilterHarness();
      await h.mount(tester);
      for (final mode in ['close', 'escape', 'backdrop', 'system']) {
        await h.open(tester);
        await tester.tap(value('food'));
        await tester.pumpAndSettle();
        if (mode == 'close') {
          await tester.tap(find.byTooltip('Close'));
        } else if (mode == 'escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else if (mode == 'backdrop') {
          await tester.tapAt(const Offset(1, 1));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(h.scope.filters, isEmpty, reason: mode);
        expect(find.byType(FilterSelectionDialog), findsNothing, reason: mode);
      }
    },
  );
  testWidgets(
    'Apply detects deleted UUIDs and retains an editable draft after read failure',
    (tester) async {
      final h = FilterHarness();
      await h.mount(tester);
      await h.open(tester);
      await tester.tap(value('travel'));
      await tester.pumpAndSettle();
      h.service.value = definitions(deleted: true);
      await tester.tap(apply());
      await tester.pumpAndSettle();
      expect(h.scope.filters, isEmpty);
      expect(
        find.text(
          'Category values changed. Review the selection before applying.',
        ),
        findsOneWidget,
      );
      expect(value('travel'), findsNothing);
      await tester.tap(value('food'));
      await tester.pumpAndSettle();
      h.service.error = StateError('read failed');
      await tester.tap(apply());
      await tester.pumpAndSettle();
      expect(h.scope.filters, isEmpty);
      expect(tester.widget<CheckboxListTile>(value('food')).value, isTrue);
      h.service.error = null;
      await tester.tap(apply());
      await tester.pumpAndSettle();
      expect(h.scope.filters, {
        'topic': {'food'},
      });
    },
  );
  testWidgets(
    'no-match Clear filters applies directly and search X remains independent',
    (tester) async {
      final h = FilterHarness()..scope.setSearch('missing');
      h.scope.setFilters({
        'topic': {'food'},
      });
      h.service.value = definitions(empty: true);
      await h.mount(tester);
      expect(find.text('No matching vocabulary.'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('collection-no-matches-clear-filters')),
      );
      await tester.pumpAndSettle();
      expect(h.scope.filters, isEmpty);
      expect(h.scope.search, 'missing');
      h.scope.setFilters({
        'topic': {'food'},
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('collection-clear-search')));
      await tester.pumpAndSettle();
      expect(h.scope.search, '');
      expect(h.scope.filters, {
        'topic': {'food'},
      });
    },
  );
}
