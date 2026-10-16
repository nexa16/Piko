import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner, one, two;
import 'collection_query_detail_test.dart' show ProjectionService, projection;
import 'collection_filters_test.dart' show topic, food, travel;

CollectionQuerySnapshot grouped() => CollectionQuerySnapshot(
  collection: owner,
  allEntries: const [one, two],
  entries: const [one, two],
  categoryDimensions: const [topic],
  categoryValues: const {
    'topic': [travel, food],
  },
  assignments: {
    one.id: [
      CategoryAssignmentRecord(
        dimensionId: topic.id,
        valueIds: {food.id, travel.id},
      ),
    ],
  },
  directions: projection().directions,
);

void main() {
  test(
    'Unicode lexical sorting is stable, original order explicit, unknown dates last in both directions',
    () {
      VocabularyRecord word(String id, String text, [DateTime? at]) =>
          VocabularyRecord(
            id: id,
            collectionId: owner.id,
            targetText: text,
            nativeText: id,
            addedAt: at,
          );
      final rows = [
        word('a', 'é'),
        word('b', 'e\u0301'),
        word('c', 'E'),
        word('d', '2'),
        word('e', '10'),
        word('f', 'ß'),
        word('g', 'ss'),
      ];
      expect(
        sortVocabulary(rows, VocabularySort.targetAscending).map((r) => r.id),
        ['e', 'd', 'c', 'g', 'f', 'a', 'b'],
      );
      expect(sortVocabulary(rows, VocabularySort.original), rows);
      final dated = [
        word('unknown', 'x'),
        word('old', 'x', DateTime.utc(2020)),
        word('new', 'x', DateTime.utc(2025)),
      ];
      expect(sortVocabulary(dated, VocabularySort.newest).map((r) => r.id), [
        'new',
        'old',
        'unknown',
      ]);
      expect(sortVocabulary(dated, VocabularySort.oldest).map((r) => r.id), [
        'old',
        'new',
        'unknown',
      ]);
      final groups = groupVocabulary(
        grouped(),
        const CollectionViewPreferences(grouping: 'topic'),
      );
      expect(groups.map((g) => g.id), ['food', 'travel', 'unassigned']);
      expect(groups.take(2).map((g) => g.entries.single.id), [one.id, one.id]);
      expect(groups.last.entries.single.id, two.id);
    },
  );
  test(
    'Collection preferences persist independently; expansion does not persist',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final settings = SqliteSettingsRepository(db);
      final a = CollectionViewScope(repository: settings, collectionId: 'a');
      await a.loadView();
      while (a.viewPending) {
        await Future<void>.delayed(Duration.zero);
      }
      const chosen = CollectionViewPreferences(
        mode: VocabularyViewMode.detailed,
        targetFirst: false,
        grouping: 'topic',
        sort: VocabularySort.newest,
      );
      await a.saveView(chosen);
      a.expandGroups(['food'], true);
      a.dispose();
      final reopened = CollectionViewScope(
            repository: settings,
            collectionId: 'a',
          ),
          b = CollectionViewScope(repository: settings, collectionId: 'b');
      addTearDown(reopened.dispose);
      addTearDown(b.dispose);
      while (reopened.viewPending || b.viewPending) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(reopened.view, chosen);
      expect(reopened.expandedGroups, isEmpty);
      expect(b.view, const CollectionViewPreferences());
    },
  );
  testWidgets(
    'duplicated grouped appearances share one raw editor through collapse, filtering and view switches',
    (tester) async {
      final scope = CollectionViewScope();
      await scope.saveView(const CollectionViewPreferences(grouping: 'topic'));
      final repo = LiveVocabulary(), service = ProjectionService(grouped());
      final binding = CollectionQueryBinding(
        collectionId: owner.id,
        service: service,
        scope: scope,
        invalidations: const Stream<void>.empty(),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        binding.dispose();
        scope.dispose();
        await repo.close();
      });
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollectionVocabulary(
                collection: owner,
                repository: repo,
                queryBinding: binding,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('vocabulary-food/${one.id}')), findsNothing);
      scope.expandGroups(['food', 'travel'], true);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('vocabulary-food/${one.id}')), findsOneWidget);
      expect(
        find.byKey(ValueKey('vocabulary-travel/${one.id}')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('vocabulary-food/${one.id}')));
      await tester.pumpAndSettle();
      final field = find.byKey(ValueKey('inline-${one.id}-target'));
      await tester.enterText(field, '  ');
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      scope.expandGroups(['food'], false);
      await tester.pumpAndSettle();
      expect(
        field,
        findsOneWidget,
      ); // Same UUID editor moved to its other occurrence.
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        '  ',
      );
      scope.expandGroups(['travel'], false);
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      scope.expandGroups(['food'], true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        '  ',
      );
      service.value = projection(all: const [one, two], visible: const []);
      binding.refresh();
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      service.value = grouped();
      binding.refresh();
      await tester.pumpAndSettle();
      await scope.saveView(
        const CollectionViewPreferences(
          mode: VocabularyViewMode.detailed,
          targetFirst: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        '  ',
      );
      expect(repo.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
