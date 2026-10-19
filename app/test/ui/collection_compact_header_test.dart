import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_compact_action.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/learning/learning_direction_choice.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_launch.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner;
import 'collection_query_detail_test.dart' show projection, ProjectionService;
import 'collection_review_entry_points_test.dart' show Collections;

final words = List.generate(
  60,
  (i) => VocabularyRecord(
    id: 'word-$i',
    collectionId: owner.id,
    targetText: 'Word $i',
    nativeText: 'Wort $i',
  ),
);
CollectionQuerySnapshot headerProjection({
  int forward = 12,
  int reverse = 7,
  int speedForward = 3,
  int speedReverse = 4,
  bool pending = false,
}) {
  final base = projection(
    all: words,
    visible: words,
    forward: forward,
    reverse: reverse,
    pending: pending,
  );
  return CollectionQuerySnapshot(
    collection: base.collection,
    allEntries: base.allEntries,
    entries: base.entries,
    categoryDimensions: const [],
    categoryValues: const {},
    assignments: const {},
    directions: {
      for (final direction in LearningDirection.values)
        direction: CollectionDirectionSnapshot(
          review: base.directions[direction]!.review,
          newSpeedItems: [
            for (
              var i = 0;
              i <
                  (direction == LearningDirection.targetToNative
                      ? speedForward
                      : speedReverse);
              i++
            )
              LearningItemRecord(
                id: i,
                entryId: words[i].id,
                direction: direction,
                cardJson: '{}',
                formatVersion: 1,
              ),
          ],
        ),
    },
  );
}

Finder key(String key) => find.byKey(ValueKey(key));
final compactReview = key('collection-review-compact');
final compactSpeed = key('collection-speed-compact');

class HeaderHarness {
  final vocabulary = LiveVocabulary()..records = words;
  final scope = CollectionViewScope();
  final service = ProjectionService(headerProjection());
  final reviews = <LearningDirection>[];
  final speed = <LearningDirection>[];
  final locale = InterfaceLocaleController();
  Future<DueLearningSession> prepareReview(
    String _,
    LearningDirection direction,
  ) async {
    reviews.add(direction);
    throw StateError('Synthetic preparation failure');
  }

  Future<SpeedLearningSession> prepareSpeed({
    required String collectionId,
    required LearningDirection direction,
    required Set<String> visibleEntryIds,
    required int poolSize,
  }) async {
    speed.add(direction);
    throw StateError('Synthetic preparation failure');
  }

  late final binding = CollectionQueryBinding(
    collectionId: owner.id,
    service: service,
    scope: scope,
    invalidations: const Stream<void>.empty(),
  );
  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    double scale = 1,
    String name = 'Words',
  }) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    locale.value = Locale(language);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      binding.dispose();
      scope.dispose();
      locale.dispose();
      await vocabulary.close();
      tester.view.reset();
    });
    final collection = CollectionRecord(
      id: owner.id,
      name: name,
      targetLanguage: owner.targetLanguage,
      nativeLanguage: owner.nativeLanguage,
    );
    await tester.pumpWidget(
      PikoApp(
        localeController: locale,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: CollectionDetail(
              repository: Collections([collection]),
              collectionId: owner.id,
              vocabularyRepository: vocabulary,
              queryBinding: binding,
              reviewSessionFactory: prepareReview,
              speedSessionFactory: prepareSpeed,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> collapse(WidgetTester tester) async {
    for (
      var i = 0;
      compactReview.hitTestable().evaluate().isEmpty && i < 25;
      i++
    ) {
      final viewport = tester.getRect(find.byType(Scrollable).first);
      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.bottom - 32),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
    }
    final offstage = find.byKey(
      const ValueKey('collection-review-compact'),
      skipOffstage: false,
    );
    expect(
      compactReview.hitTestable(),
      findsOneWidget,
      reason:
          'offset=${position(tester).pixels}, max=${position(tester).maxScrollExtent}, '
          'onstage=${compactReview.evaluate().length}, bounds=${tester.getRect(offstage)}, '
          'header=${tester.getSize(find.byKey(const ValueKey('collection-compact-header'), skipOffstage: false))}, viewport=${tester.getRect(find.byType(Scrollable).first)}',
    );
  }

  Future<void> refresh(WidgetTester tester) async {
    binding.refresh();
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'collapse keeps independent directional sums, one launch owner and stable scroll geometry',
    (tester) async {
      final h = HeaderHarness();
      await h.mount(tester);
      final reviewOwner = tester.state(find.byType(ReviewLaunch));
      final speedOwner = tester.state(find.byType(SpeedLaunch));
      expect(
        key('collection-review-targetToNative').hitTestable(),
        findsOneWidget,
      );
      expect(compactReview.hitTestable(), findsNothing);
      await h.collapse(tester);
      expect(tester.widget<CollectionCompactAction>(compactReview).count, '19');
      expect(tester.widget<CollectionCompactAction>(compactSpeed).count, '7');
      expect(
        find.descendant(
          of: key('collection-compact-header'),
          matching: find.text('60 entries'),
        ),
        findsOneWidget,
      );
      expect(
        key('collection-review-targetToNative').hitTestable(),
        findsNothing,
      );
      expect(
        tester.state(find.byType(ReviewLaunch, skipOffstage: false)),
        same(reviewOwner),
      );
      expect(
        tester.state(find.byType(SpeedLaunch, skipOffstage: false)),
        same(speedOwner),
      );
      final top = tester.getTopLeft(compactReview),
          offset = h.position(tester).pixels;
      h.service.value = headerProjection(
        forward: 1,
        reverse: 0,
        speedForward: 0,
        speedReverse: 2,
      );
      await h.refresh(tester);
      expect(h.position(tester).pixels, closeTo(offset, .5));
      expect(tester.getTopLeft(compactReview), top);
      expect(tester.widget<CollectionCompactAction>(compactReview).count, '1');
      expect(tester.widget<CollectionCompactAction>(compactSpeed).count, '2');
      h.position(tester).jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        key('collection-review-targetToNative').hitTestable(),
        findsOneWidget,
      );
      expect(compactReview.hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'single Review starts directly, Speed uses its own direction and cancel preserves offset',
    (tester) async {
      final h = HeaderHarness();
      h.service.value = headerProjection(
        forward: 1,
        reverse: 0,
        speedForward: 0,
        speedReverse: 2,
      );
      await h.mount(tester);
      await h.collapse(tester);
      await tester.tap(compactReview);
      await tester.pumpAndSettle();
      expect(h.reviews, [LearningDirection.targetToNative]);
      expect(find.byType(LearningDirectionChoice), findsNothing);
      final offset = h.position(tester).pixels;
      await tester.tap(compactSpeed);
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      expect(find.text('DE → FR'), findsOneWidget);
      expect(h.speed, isEmpty);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(h.position(tester).pixels, closeTo(offset, .5));
      expect(h.reviews.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'merged pickers refresh counts and reject a direction that disappears at activation',
    (tester) async {
      final h = HeaderHarness();
      await h.mount(tester);
      await h.collapse(tester);
      await tester.tap(compactReview);
      await tester.pumpAndSettle();
      expect(find.byType(LearningDirectionChoice), findsOneWidget);
      h.service.value = headerProjection(forward: 0, reverse: 3);
      await h.refresh(tester);
      expect(key('learning-direction-targetToNative'), findsNothing);
      expect(find.text('DE → FR · 3 to review'), findsWidgets);
      h.service.value = headerProjection(forward: 0, reverse: 0);
      await tester.tap(key('learning-direction-nativeToTarget'));
      await tester.pumpAndSettle();
      expect(h.reviews, isEmpty);
      expect(
        find.text(PikoCopy('en').text('collection.noLearningDirection')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      h.service.value = headerProjection();
      await h.refresh(tester);
      await tester.tap(compactSpeed);
      await tester.pumpAndSettle();
      expect(find.byType(LearningDirectionChoice), findsOneWidget);
      h.service.value = headerProjection(speedForward: 0, speedReverse: 0);
      await tester.tap(key('learning-direction-targetToNative'));
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsNothing);
      expect(h.speed, isEmpty);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading, failed reads, waiting and settled zero stay distinct without losing focus',
    (tester) async {
      final h = HeaderHarness();
      await h.mount(tester);
      await h.collapse(tester);
      final action = tester.widget<CollectionCompactAction>(compactReview);
      action.focusNode.requestFocus();
      await tester.pumpAndSettle();
      final offset = h.position(tester).pixels;
      final gate = h.service.gate = Completer<CollectionQuerySnapshot>();
      h.binding.refresh();
      await tester.pump();
      expect(tester.widget<CollectionCompactAction>(compactReview).count, '…');
      expect(action.focusNode.hasFocus, isTrue);
      expect(
        tester.widget<CollectionCompactAction>(compactReview).onPressed,
        isNull,
      );
      gate.completeError(StateError('synthetic read failure'));
      await tester.pumpAndSettle();
      h.service.gate = null;
      expect(tester.widget<CollectionCompactAction>(compactReview).count, '!');
      expect(action.focusNode.hasFocus, isTrue);
      expect(h.position(tester).pixels, closeTo(offset, .5));
      h.service.value = headerProjection(
        forward: 0,
        reverse: 0,
        speedForward: 0,
        speedReverse: 0,
        pending: true,
      );
      await h.refresh(tester);
      expect(
        tester.widget<CollectionCompactAction>(compactReview).label,
        PikoCopy('en').text('collection.compactPending'),
      );
      expect(tester.widget<CollectionCompactAction>(compactSpeed).count, '0');
      h.service.value = headerProjection(
        forward: 0,
        reverse: 0,
        speedForward: 0,
        speedReverse: 0,
      );
      await h.refresh(tester);
      expect(tester.widget<CollectionCompactAction>(compactReview).count, '0');
      expect(action.focusNode.hasFocus, isTrue);
      expect(h.reviews, isEmpty);
      expect(h.speed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard focus transfers between one accessible header representation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final h = HeaderHarness();
        await h.mount(tester);
        final text = find.descendant(
          of: key('collection-review-targetToNative'),
          matching: find.byType(Text),
        );
        final focus = Focus.of(tester.element(text.first));
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        await h.collapse(tester);
        final compactFocus = tester
            .widget<CollectionCompactAction>(compactReview)
            .focusNode;
        expect(compactFocus.hasFocus, isTrue);
        final nodes = <SemanticsNode>[];
        void collect(SemanticsNode node) {
          nodes.add(node);
          node.visitChildren((child) {
            collect(child);
            return true;
          });
        }

        collect(tester.getSemantics(find.byType(Scaffold)));
        expect(
          nodes.where(
            (node) => node.label.contains('Review, 19 directional items'),
          ),
          hasLength(1),
        );
        expect(
          nodes.where((node) => node.label.contains('FR → DE · 12 to review')),
          isEmpty,
        );
        expect(
          nodes.where((node) => node.label == 'Rename collection'),
          isEmpty,
        );
        h.position(tester).jumpTo(0);
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorStateOfType<ReviewLaunchState>(),
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'rapid launch stays single and a changed query closes its stale picker without locking the page',
    (tester) async {
      final h = HeaderHarness();
      await h.mount(tester);
      await h.collapse(tester);
      final start = tester
          .widget<CollectionCompactAction>(compactReview)
          .onPressed!;
      start();
      start();
      await tester.pumpAndSettle();
      expect(find.byType(LearningDirectionChoice), findsOneWidget);
      expect(h.reviews, isEmpty);
      h.scope.setSearch('changed scope');
      await tester.pumpAndSettle();
      expect(find.byType(LearningDirectionChoice), findsNothing);
      expect(
        tester.widget<CollectionCompactAction>(compactReview).onPressed,
        isNotNull,
      );
      await tester.tap(compactSpeed);
      await tester.pumpAndSettle();
      await tester.tap(key('learning-direction-nativeToTarget'));
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      expect(find.text('DE → FR'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(
          PikoButton,
          PikoCopy('en').text('learn.startSpeed'),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.speed, [LearningDirection.nativeToTarget]);
      expect(h.reviews, isEmpty);
      expect(
        find.text(PikoCopy('en').text('learn.prepareFailed')),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a short keyboard-sized viewport keeps the list reachable without a pinned obstruction',
    (tester) async {
      final h = HeaderHarness();
      await h.mount(tester);
      tester.view.physicalSize = const Size(320, 120);
      await tester.pumpAndSettle();
      final first = key('vocabulary-word-0');
      await tester.scrollUntilVisible(
        first,
        80,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      expect(first.hitTestable(), findsOneWidget);
      expect(compactReview, findsNothing);
      tester.view.physicalSize = const Size(320, 800);
      await tester.pumpAndSettle();
      await h.collapse(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'de']) {
    testWidgets(
      '$language narrow 200% long title grows with two accessible 48px mode targets',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final h = HeaderHarness();
          await h.mount(
            tester,
            language: language,
            scale: 2,
            name: 'Meine Sammlung für den nächsten Urlaub',
          );
          await h.collapse(tester);
          for (final target in [compactReview, compactSpeed]) {
            final rect = tester.getRect(target);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.right, lessThanOrEqualTo(320));
          }
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          h.position(tester).jumpTo(0);
          await tester.pumpAndSettle();
          expect(compactReview.hitTestable(), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
