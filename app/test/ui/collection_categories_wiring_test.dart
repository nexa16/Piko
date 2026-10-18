import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/categories/category_settings_page.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_dialog.dart';
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
    await tester.tap(find.text('Categories'));
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
    'Home forwards repository through shared category settings and dirty Back retains raw draft',
    (tester) async {
      final f = PickerFixture();
      await tester.runAsync(f.initialize);
      final h = MenuFixture(f);
      try {
        await h.mount(tester);
        expect(
          tester
              .widget<CollectionVocabulary>(find.byType(CollectionVocabulary))
              .categoriesRepository,
          same(f.repository),
        );
        await h.open(tester);
        expect(
          tester
              .widget<CategorySettingsPage>(find.byType(CategorySettingsPage))
              .repository,
          same(f.repository),
        );
        await tester.tap(find.text(f.dimension.name));
        await f.flush(tester);
        final name = field('category-management-name-${f.dimension.id}');
        await tester.enterText(name, ' Retained category draft ');
        final controller = tester.widget<TextField>(name).controller!;
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            PikoButton,
            const PikoCopy('en').text('entry.continue'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(name).controller, same(controller));
        expect(controller.text, ' Retained category draft ');
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
    'pending category save blocks Back and stale underlying Delete; accepted write survives',
    (tester) async {
      final f = PickerFixture();
      await tester.runAsync(f.initialize);
      final categories = MenuHeldUpdate(f.repository);
      final h = MenuFixture(f);
      try {
        await h.mount(tester, categories: categories);
        await h.open(tester);
        final staleDelete = tester
            .widget<PikoFormRow>(
              find.byKey(
                const ValueKey('collection-menu-delete'),
                skipOffstage: false,
              ),
            )
            .onTap;
        await tester.tap(find.text(f.dimension.name));
        await f.flush(tester);
        await tester.enterText(
          field('category-management-name-${f.dimension.id}'),
          'Confirmed category',
        );
        await tester.pump();
        final save = find.widgetWithText(
          PikoButton,
          const PikoCopy('en').text('category.saveDimension'),
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(categories.updates, 1);
        expect(h.writes, isNotEmpty);
        expect(staleDelete, isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CategoryGroupSettingsPage), findsOneWidget);
        expect(find.byType(PikoDialog), findsNothing);
        categories.gate.complete();
        await f.flush(tester);
        expect(
          (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!.name,
          'Confirmed category',
        );
        expect(
          (await tester.runAsync(
            () => f.repository.assignments(f.entryId),
          ))!.single.valueIds,
          {f.values.first.id},
        );
      } finally {
        if (!categories.gate.isCompleted) categories.gate.complete();
        await h.dispose(tester);
      }
    },
  );
}
