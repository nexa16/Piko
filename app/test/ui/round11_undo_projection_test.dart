import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../support/collection_deletion_fixture.dart';

class HeldProjection implements CollectionQueryService {
  HeldProjection(this.real);
  final CollectionQueryService real;
  Completer<void>? gate;
  @override
  Future<CollectionQuerySnapshot> query({
    required String collectionId,
    required DateTime at,
    Map<String, Set<String>> filters = const {},
    String search = '',
  }) async {
    await gate?.future;
    return real.query(
      collectionId: collectionId,
      at: at,
      filters: filters,
      search: search,
    );
  }
}

void main() {
  testWidgets(
    'Undo through visible feedback restores filtered grouped sorted projection and exact storage',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final categories = SqliteCategoriesRepository(f.db);
      final group = (await tester.runAsync(
        () => categories.createDimension(
          collectionId: f.owner.id,
          name: 'Topic',
          mode: CategoryMode.multiple,
        ),
      ))!;
      final value = (await tester.runAsync(
        () => categories.createValue(dimensionId: group.id, name: 'Food'),
      ))!;
      final selected = (await tester.runAsync(
        () => f.real.updateWithContent(
          id: f.entries.first.id,
          targetText: 'One',
          nativeText: 'Eins',
          assignments: {
            group.id: {value.id},
          },
          content: const VocabularyContent(
            examples: [
              ExamplePair(
                targetText: 'One example',
                nativeText: 'Ein Beispiel',
              ),
            ],
            hintText: 'Synthetic hint',
          ),
        ),
      ))!;
      final scope = CollectionViewScope();
      await scope.saveView(
        CollectionViewPreferences(
          grouping: group.id,
          sort: VocabularySort.targetDescending,
        ),
      );
      scope.setFilters({
        group.id: {value.id},
      });
      scope.expandGroups([value.id], true);
      final before = (await tester.runAsync(
        () async => {
          for (final table in [
            'vocabulary_entries',
            'vocabulary_examples',
            'learning_items',
            'regular_reviews',
            'retry_obligations',
            'vocabulary_category_assignments',
          ])
            table:
                (await f.db
                        .customSelect('SELECT * FROM $table ORDER BY rowid')
                        .get())
                    .map((row) => row.data)
                    .toList(),
        },
      ))!;
      final service = HeldProjection(SqliteCollectionQueryService(f.db));
      final binding = CollectionQueryBinding(
        collectionId: f.owner.id,
        service: service,
        scope: scope,
        invalidations: f.db.tableUpdates().map((_) {}),
        clock: f.clock,
      );
      tester.view.physicalSize = const Size(392, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        binding.dispose();
        scope.dispose();
        tester.view.reset();
        await tester.runAsync(f.db.close);
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: f.collections,
            collectionId: f.owner.id,
            vocabularyRepository: f.repository,
            categoriesRepository: categories,
            queryBinding: binding,
            vocabularyMutationsFactory: (_) => f.mutations,
          ),
        ),
      );
      Future<void> flush() async {
        await tester.runAsync(() async {
          await f.db.customSelect('SELECT 1').get();
          for (var attempt = 0; binding.loading && attempt < 100; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
        });
        await tester.pumpAndSettle();
      }

      await flush();
      scope.expandGroups([value.id], true);
      await tester.pumpAndSettle();
      expect(binding.snapshot!.allEntries.length, 3);
      expect(binding.snapshot!.entries.map((e) => e.id), [selected.id]);
      service.gate = Completer<void>();
      await tester.runAsync(() => f.mutations.delete(selected));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final undo = find.byWidgetPredicate(
        (w) => w is PikoButton && w.label == 'Undo',
      );
      expect(undo, findsOneWidget);
      expect(
        tester.widget<PikoButton>(undo).onPressed,
        isNull,
        reason:
            'Undo is temporarily blocked while authoritative projection reloads',
      );
      service.gate!.complete();
      await flush();
      expect(binding.snapshot!.allEntries.length, 2);
      expect(binding.snapshot!.entries, isEmpty);
      expect(undo.hitTestable(), findsOneWidget);
      expect(tester.widget<PikoButton>(undo).onPressed, isNotNull);
      await tester.tap(undo);
      await flush();
      expect(binding.snapshot!.allEntries.length, 3);
      expect(binding.snapshot!.entries.map((e) => e.id), [selected.id]);
      final restored = binding.snapshot!.entries.single;
      expect(restored.content, selected.content);
      final after = (await tester.runAsync(
        () async => {
          for (final table in before.keys)
            table:
                (await f.db
                        .customSelect('SELECT * FROM $table ORDER BY rowid')
                        .get())
                    .map((row) => row.data)
                    .toList(),
        },
      ))!;
      expect(after, before);
      expect(scope.filters, {
        group.id: {value.id},
      });
      expect(scope.expandedGroups, {value.id});
      expect(scope.view.sort, VocabularySort.targetDescending);
      expect(f.mutations.offers, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
