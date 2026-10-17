import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_interaction_anchor.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/main.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner;
import 'collection_query_detail_test.dart' show ProjectionService, projection;
import 'collection_filters_test.dart' show topic, food, travel, apply, value;
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_review_entry_points_test.dart' show Collections;

void main() {
  Future<
    ({
      ScrollController scroll,
      ValueNotifier<double> height,
      ValueNotifier<bool> visible,
    })
  >
  mount(WidgetTester tester) async {
    final anchor = PikoInteractionAnchor();
    final scroll = ScrollController();
    final height = ValueNotifier(300.0);
    final visible = ValueNotifier(true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
      height.dispose();
      visible.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: anchor.scope(
            child: PikoAnchoredScrollView(
              controller: scroll,
              interactionAnchor: anchor,
              slivers: [
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (_, value, _) => Column(
                      children: [
                        SizedBox(height: value),
                        ValueListenableBuilder<bool>(
                          valueListenable: visible,
                          builder: (_, show, _) => show
                              ? PikoAnchorRegion(
                                  child: TextButton(
                                    key: const ValueKey('origin'),
                                    onPressed: () {},
                                    child: const Text('Filter'),
                                  ),
                                )
                              : const SizedBox(),
                        ),
                        PikoAnchorRegion(
                          child: TextButton(
                            key: const ValueKey('neighbor'),
                            onPressed: () {},
                            child: const Text('Group'),
                          ),
                        ),
                        const SizedBox(height: 1800),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(150);
    await tester.pumpAndSettle();
    return (scroll: scroll, height: height, visible: visible);
  }

  final origin = find.byKey(const ValueKey('origin'));

  testWidgets(
    'real Collection filter popup retains its origin through loading and changed learning actions',
    (tester) async {
      final words = List.generate(
        30,
        (i) => VocabularyRecord(
          id: 'entry-$i',
          collectionId: owner.id,
          targetText: 'Word $i',
          nativeText: 'Translation $i',
        ),
      );
      CollectionQuerySnapshot snapshot(int count) => CollectionQuerySnapshot(
        collection: owner,
        allEntries: words,
        entries: words,
        categoryDimensions: const [topic],
        categoryValues: const {
          'topic': [food, travel],
        },
        assignments: {
          for (var i = 0; i < words.length; i++)
            words[i].id: [
              CategoryAssignmentRecord(
                dimensionId: topic.id,
                valueIds: {i < 15 ? food.id : travel.id},
              ),
            ],
        },
        directions: projection(forward: count).directions,
      );
      final scope = CollectionViewScope();
      final service = ProjectionService(snapshot(1));
      final binding = CollectionQueryBinding(
        collectionId: owner.id,
        service: service,
        scope: scope,
        invalidations: const Stream<void>.empty(),
      );
      final vocabulary = LiveVocabulary()..records = words;
      tester.view.physicalSize = const Size(392, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        binding.dispose();
        scope.dispose();
        await vocabulary.close();
        tester.view.reset();
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: const Collections([owner]),
            collectionId: owner.id,
            vocabularyRepository: vocabulary,
            queryBinding: binding,
            reviewSessionFactory: (_, _) async =>
                throw StateError('Unexpected launch'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chip = find.byKey(const ValueKey('collection-filters'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(chip).dy;
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(value(food.id));
      await tester.pumpAndSettle();
      service.value = snapshot(0);
      await tester.tap(apply());
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.getTopLeft(chip).dy, closeTo(top, .01));
      }
      service.value = snapshot(1);
      await tester.tap(find.byTooltip('Clear filters'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.getTopLeft(chip).dy, closeTo(top, .01));
      }
      for (final (control, option) in [
        ('collection-group', 'view.grouping-${topic.id}'),
        ('collection-sort', 'view.sort-VocabularySort.targetDescending'),
      ]) {
        final origin = find.byKey(ValueKey(control));
        await tester.ensureVisible(origin);
        await tester.pumpAndSettle();
        final before = tester.getTopLeft(origin).dy;
        await tester.tap(origin);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(option)));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PikoButton, 'Apply'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          final delta = tester.getTopLeft(origin).dy - before;
          if (delta.abs() > .01) {
            // Collapsing every group can leave less than one viewport of content.
            // Exact compensation is then outside the valid scroll range.
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            final desired = position.pixels + delta;
            expect(
              desired < position.minScrollExtent ||
                  desired > position.maxScrollExtent,
              isTrue,
            );
            expect(
              position.pixels,
              delta > 0 ? position.maxScrollExtent : position.minScrollExtent,
            );
          }
        }
      }
      expect(scope.view.sort, VocabularySort.targetDescending);
      scope.expandGroups([travel.id], true);
      await tester.pumpAndSettle();
      final group = find.byKey(ValueKey('collection-group-${food.id}'));
      await tester.ensureVisible(group);
      await tester.pumpAndSettle();
      final groupTop = tester.getTopLeft(group).dy;
      for (var repeat = 0; repeat < 4; repeat++) {
        await tester.tap(group);
        await tester.pump();
        expect(tester.getTopLeft(group).dy, closeTo(groupTop, .01));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'holds the originating control before every painted async result',
    (tester) async {
      final fixture = await mount(tester);
      await tester.tap(origin);
      final top = tester.getTopLeft(origin).dy;
      for (final height in [420.0, 200.0, 360.0, 300.0]) {
        fixture.height.value = height;
        await tester.pump();
        expect(tester.getTopLeft(origin).dy, closeTo(top, .01));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('user drag wins over an older asynchronous interaction', (
    tester,
  ) async {
    final fixture = await mount(tester);
    await tester.tap(origin);
    await tester.drag(
      find.byType(PikoAnchoredScrollView),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    final pixels = fixture.scroll.position.pixels;
    fixture.height.value = 410;
    await tester.pump();
    expect(fixture.scroll.position.pixels, closeTo(pixels, .01));
  });

  testWidgets('clamps at zero without introducing blank padding', (
    tester,
  ) async {
    final fixture = await mount(tester);
    fixture.scroll.jumpTo(0);
    await tester.pump();
    await tester.tap(origin);
    fixture.height.value = 0;
    await tester.pump();
    expect(fixture.scroll.position.pixels, 0);
    expect(tester.getTopLeft(origin).dy, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removed target uses its surviving contextual neighbor', (
    tester,
  ) async {
    final fixture = await mount(tester);
    await tester.tap(origin);
    final neighbor = find.byKey(const ValueKey('neighbor'));
    final top = tester.getTopLeft(neighbor).dy;
    fixture.visible.value = false;
    await tester.pump();
    expect(tester.getTopLeft(neighbor).dy, closeTo(top, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewport change releases the old coordinate', (tester) async {
    final fixture = await mount(tester);
    await tester.tap(origin);
    tester.view.physicalSize = const Size(800, 500);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pump();
    final pixels = fixture.scroll.position.pixels;
    fixture.height.value = 420;
    await tester.pump();
    expect(fixture.scroll.position.pixels, pixels);
  });

  testWidgets('explicit reveal scrolling supersedes an old interaction', (
    tester,
  ) async {
    final fixture = await mount(tester);
    await tester.tap(origin);
    fixture.scroll.jumpTo(200);
    await tester.pump();
    fixture.height.value = 420;
    await tester.pump();
    expect(fixture.scroll.position.pixels, 200);
  });
}
