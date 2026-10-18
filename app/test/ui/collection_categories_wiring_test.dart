import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/categories/category_management.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'category_assignment_picker_test.dart' show PickerFixture;
import 'category_management_test.dart' show HeldUpdate, field;

class MenuHeldUpdate extends HeldUpdate {
  MenuHeldUpdate(super.real);
  @override
  Future<List<CategoryDimensionRecord>> dimensions(String collectionId) =>
      real.dimensions(collectionId);
  @override
  Future<List<CategoryValueRecord>> values(String dimensionId) =>
      real.values(dimensionId);
}

class MenuFixture {
  MenuFixture(this.f);
  final PickerFixture f;
  final scope = CollectionViewScope();
  final writes = <Future<void>>[];
  late final binding = CollectionQueryBinding(
    collectionId: f.dimension.collectionId,
    service: SqliteCollectionQueryService(f.db),
    scope: scope,
    invalidations: const Stream<void>.empty(),
  );
  Future<void> mount(
    WidgetTester tester, {
    CategoriesRepository? categories,
  }) async {
    await tester.pumpWidget(
      PikoApp(
        home: CollectionsHome(
          repository: SqliteCollectionsRepository(f.db),
          vocabularyRepository: SqliteVocabularyRepository(f.db),
          categoriesRepository: categories ?? f.repository,
          queryBindingFactory: (_) => binding,
          onPendingVocabularyWrites: writes.add,
        ),
      ),
    );
    await f.flush(tester);
    await tester.tap(
      find.byKey(ValueKey('collection-${f.dimension.collectionId}')),
    );
    await f.flush(tester);
  }

  Future<void> open(WidgetTester tester) async {
    final compact = find.byKey(const ValueKey('collection-compact-menu'));
    if (compact.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(compact);
    } else {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('collection-menu')));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit categories'));
    await f.flush(tester);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    binding.dispose();
    scope.dispose();
    await f.cleanup(tester);
  }
}

void main() {
  testWidgets(
    'Home forwards actual category repository to Detail rows and inline menu management',
    (tester) async {
      final f = PickerFixture();
      await tester.runAsync(f.initialize);
      final h = MenuFixture(f);
      try {
        await h.mount(tester);
        expect(
          tester
              .widget<CollectionDetail>(find.byType(CollectionDetail))
              .categoriesRepository,
          same(f.repository),
        );
        expect(
          tester
              .widget<CollectionVocabulary>(find.byType(CollectionVocabulary))
              .categoriesRepository,
          same(f.repository),
        );
        expect(find.text('Value 1'), findsOneWidget);
        await h.open(tester);
        expect(find.byType(CategoryManagement), findsOneWidget);
        expect(find.byType(CollectionDetail), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(CategoryManagement),
            matching: find.text(f.dimension.name),
          ),
        );
        await f.flush(tester);
        final name = field('category-management-name-${f.dimension.id}');
        await tester.enterText(name, ' Retained category draft ');
        final controller = tester.widget<TextField>(name).controller;
        await tester.tap(find.text('Edit categories'));
        await tester.pumpAndSettle();
        expect(name, findsNothing);
        await tester.tap(find.text('Edit categories'));
        await f.flush(tester);
        expect(tester.widget<TextField>(name).controller, same(controller));
        expect(controller!.text, ' Retained category draft ');
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!.name,
          'Difficulty',
        );
      } finally {
        await h.dispose(tester);
      }
    },
  );
  testWidgets(
    'pending category save blocks menu dismissal and Delete while retaining raw vocabulary draft',
    (tester) async {
      final f = PickerFixture();
      await tester.runAsync(f.initialize);
      final categories = MenuHeldUpdate(f.repository);
      final h = MenuFixture(f);
      try {
        await h.mount(tester, categories: categories);
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('vocabulary-${f.entryId}')),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('vocabulary-${f.entryId}')));
        await f.flush(tester);
        final target = find.descendant(
          of: find.byKey(ValueKey('inline-${f.entryId}-target')),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.enterText(target, '  ');
        await tester.pumpAndSettle();
        final raw = tester.widget<TextField>(target).controller;
        await h.open(tester);
        final close = tester
            .widget<PikoIconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is PikoIconButton && widget.semanticLabel == 'Close',
              ),
            )
            .onPressed!;
        final delete = tester
            .widget<PikoButton>(
              find.byKey(const ValueKey('collection-menu-delete')),
            )
            .onPressed!;
        await tester.tap(
          find.descendant(
            of: find.byType(CategoryManagement),
            matching: find.text(f.dimension.name),
          ),
        );
        await f.flush(tester);
        await tester.enterText(
          field('category-management-name-${f.dimension.id}'),
          'Confirmed category',
        );
        await tester.pumpAndSettle();
        final save = find.widgetWithText(
          PikoButton,
          const PikoCopy('en').text('category.saveDimension'),
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(categories.updates, 1);
        expect(h.writes, isNotEmpty);
        close();
        delete();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.tapAt(const Offset(1, 1));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CategoryManagement), findsOneWidget);
        expect(
          tester
              .widget<PikoButton>(
                find.byKey(const ValueKey('collection-menu-delete')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<ExpansionTile>(
                find.byKey(const ValueKey('collection-menu-categories')),
              )
              .enabled,
          isFalse,
        );
        categories.gate.complete();
        await f.flush(tester);
        await tester.ensureVisible(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryManagement), findsNothing);
        await tester.scrollUntilVisible(
          target,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(target).controller, same(raw));
        expect(raw!.text, '  ');
        expect(
          (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!.name,
          'Confirmed category',
        );
      } finally {
        if (!categories.gate.isCompleted) {
          categories.gate.complete();
          await f.flush(tester);
        }
        await h.dispose(tester);
      }
    },
  );
}
