import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/features/vocabulary/compact_vocabulary_pair.dart';
import 'package:piko/features/vocabulary/vocabulary_selection.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/piko_theme.dart';
import 'collection_filters_test.dart' show topic, food, travel;
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner, one, two;
import 'collection_query_detail_test.dart' show ProjectionService, projection;
import 'collection_scroll_test.dart' show mountCollection, pageScroll;

Finder keyed(String key) => find.byKey(ValueKey(key));

class FeedbackHarness {
  FeedbackHarness(this.entries, {this.grouped = false});
  final List<VocabularyRecord> entries;
  final bool grouped;
  final scope = CollectionViewScope();
  final selection = VocabularySelection();
  final repository = LiveVocabulary();
  late CollectionQueryBinding binding;

  Future<void> mount(
    WidgetTester tester, {
    VocabularyViewMode mode = VocabularyViewMode.compact,
    bool targetFirst = true,
    double scale = 1,
  }) async {
    repository.records = entries;
    await scope.saveView(
      CollectionViewPreferences(
        mode: mode,
        targetFirst: targetFirst,
        grouping: grouped ? topic.id : null,
      ),
    );
    final base = projection(all: entries, visible: entries);
    final snapshot = grouped
        ? CollectionQuerySnapshot(
            collection: owner,
            allEntries: entries,
            entries: entries,
            categoryDimensions: const [topic],
            categoryValues: const {
              'topic': [food, travel],
            },
            assignments: {
              one.id: [
                CategoryAssignmentRecord(
                  dimensionId: topic.id,
                  valueIds: {food.id, travel.id},
                ),
              ],
              two.id: [
                CategoryAssignmentRecord(
                  dimensionId: topic.id,
                  valueIds: {food.id},
                ),
              ],
            },
            directions: base.directions,
          )
        : base;
    binding = CollectionQueryBinding(
      collectionId: owner.id,
      service: ProjectionService(snapshot),
      scope: scope,
      invalidations: const Stream<void>.empty(),
    );
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      binding.dispose();
      scope.dispose();
      selection.dispose();
      await repository.close();
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CollectionVocabulary(
              collection: owner,
              repository: repository,
              queryBinding: binding,
              selection: selection,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'compact cards wrap both full languages at narrow enlarged width',
    (tester) async {
      const source = '한국어 긴 문장과 여러 단어를 모두 잘 보여 주세요';
      const translation =
          'Eine vollständige lange Übersetzung wird ohne Abschneiden angezeigt';
      final h = FeedbackHarness([
        const VocabularyRecord(
          id: 'long',
          collectionId: 'c',
          targetText: source,
          nativeText: translation,
        ),
      ]);
      await h.mount(tester, scale: 2);
      final pair = find.byType(CompactVocabularyPair);
      expect(pair, findsOneWidget);
      final first = find.descendant(of: pair, matching: find.text(source));
      final second = find.descendant(
        of: pair,
        matching: find.text(translation),
      );
      expect(tester.widget<Text>(first).maxLines, isNull);
      expect(tester.widget<Text>(second).maxLines, isNull);
      expect(
        tester.getTopLeft(second).dy,
        greaterThan(tester.getBottomLeft(first).dy - 1),
      );
      expect(
        find.ancestor(of: pair, matching: find.byType(PikoCard)),
        findsOneWidget,
      );
      expect(keyed('vocabulary-edit-long'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail shows first example with isolated disclosure and right edge edit',
    (tester) async {
      final entry = VocabularyRecord(
        id: 'examples',
        collectionId: owner.id,
        targetText: 'word',
        nativeText: 'Wort',
        content: const VocabularyContent(
          examples: [
            ExamplePair(
              targetText: 'First example',
              nativeText: 'Erstes Beispiel',
            ),
            ExamplePair(
              targetText: 'Second example',
              nativeText: 'Zweites Beispiel',
            ),
            ExamplePair(
              targetText: 'Third example',
              nativeText: 'Drittes Beispiel',
            ),
          ],
        ),
      );
      final h = FeedbackHarness([entry]);
      await h.mount(tester, mode: VocabularyViewMode.detailed);
      expect(find.text('First example'), findsOneWidget);
      expect(find.text('Second example'), findsNothing);
      expect(find.text('Third example'), findsNothing);
      final card = keyed('vocabulary-examples');
      final edit = keyed('vocabulary-edit-examples');
      expect(
        tester.getRect(card).right - tester.getRect(edit).right,
        closeTo(pikoDesign.dimension('spacing.4'), 1),
      );
      await tester.tap(keyed('vocabulary-examples-examples'));
      await tester.pumpAndSettle();
      expect(find.text('Second example'), findsOneWidget);
      expect(find.text('Third example'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(keyed('vocabulary-examples-examples'));
      await tester.pumpAndSettle();
      expect(find.text('Second example'), findsNothing);
      final before = tester.getRect(card);
      await tester.longPress(card);
      await tester.pumpAndSettle();
      final indicator = keyed('vocabulary-selection-indicator-examples');
      expect(tester.getCenter(indicator).dy, lessThan(before.center.dy));
      expect(tester.getRect(card), before);
      expect(edit, findsNothing);
      expect(h.selection.ids, {'examples'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden group controls activate by long press; partial tap selects all matching UUIDs',
    (tester) async {
      final h = FeedbackHarness(const [one, two], grouped: true);
      await h.mount(tester);
      final group = keyed('collection-group-food');
      final control = keyed('collection-group-selection-food');
      expect(find.byType(Checkbox), findsNothing);
      expect(h.scope.expandedGroups, isEmpty);
      await tester.longPress(group);
      await tester.pumpAndSettle();
      expect(h.selection.ids, {one.id, two.id});
      expect(h.scope.expandedGroups, isEmpty);
      expect(tester.widget<Checkbox>(control).value, isTrue);
      h.selection.toggle(two.id);
      h.selection.toggle('outside');
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(control).value, isNull);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(h.selection.ids, {one.id, two.id, 'outside'});
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(h.selection.ids, {'outside'});
      h.selection.clear();
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scroll to top appears after viewport and clears without changing content',
    (tester) async {
      await mountCollection(tester, count: 80);
      final position = pageScroll(tester).position;
      expect(keyed('collection-scroll-to-top'), findsNothing);
      position.jumpTo(position.viewportDimension * .5);
      await tester.pumpAndSettle();
      expect(keyed('collection-scroll-to-top'), findsNothing);
      position.jumpTo(position.viewportDimension * 1.1);
      await tester.pumpAndSettle();
      expect(keyed('collection-scroll-to-top'), findsOneWidget);
      await tester.tap(keyed('collection-scroll-to-top'));
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      expect(keyed('collection-scroll-to-top'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
