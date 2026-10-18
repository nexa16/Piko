import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/speed/speed_launch.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner, one;
import 'collection_query_detail_test.dart' show ProjectionService, projection;
import 'collection_review_entry_points_test.dart' show Collections;

CollectionQuerySnapshot speedProjection({bool eligible = true}) {
  final base = projection(visible: [one], forward: 1);
  return CollectionQuerySnapshot(
    collection: base.collection,
    allEntries: base.allEntries,
    entries: base.entries,
    categoryDimensions: base.categoryDimensions,
    categoryValues: base.categoryValues,
    assignments: base.assignments,
    directions: {
      for (final entry in base.directions.entries)
        entry.key: CollectionDirectionSnapshot(
          review: entry.value.review,
          newSpeedItems:
              eligible && entry.key == LearningDirection.nativeToTarget
              ? [
                  LearningItemRecord(
                    id: 1,
                    entryId: one.id,
                    direction: entry.key,
                    cardJson: LearningCardCodec.encode(
                      LearningScheduler().initialCard(
                        itemId: 1,
                        at: DateTime.utc(2026),
                      ),
                    ),
                    formatVersion: 1,
                  ),
                ]
              : [],
        ),
    },
  );
}

class DetailSpeedHarness {
  final vocabulary = LiveVocabulary();
  final scope = CollectionViewScope();
  final service = ProjectionService(speedProjection());
  final requests =
      <({LearningDirection direction, Set<String> visible, int pool})>[];
  Completer<void>? factoryGate;
  Completer<void>? completionGate;
  bool failCompletion = false;
  late final binding = CollectionQueryBinding(
    collectionId: owner.id,
    service: service,
    scope: scope,
    invalidations: const Stream<void>.empty(),
  );
  Future<SpeedLearningSession> prepare({
    required String collectionId,
    required LearningDirection direction,
    required Set<String> visibleEntryIds,
    required int poolSize,
  }) async {
    requests.add((
      direction: direction,
      visible: visibleEntryIds,
      pool: poolSize,
    ));
    await factoryGate?.future;
    return SpeedLearningSession(
      initial: SpeedSession.start(
        collectionId: collectionId,
        direction: direction,
        eligibleEntryIds: visibleEntryIds,
        poolSize: poolSize,
      ),
      commitCompletion: (_) async {
        await completionGate?.future;
        if (failCompletion) throw StateError('Synthetic completion failure');
      },
      presentationActive: false,
    );
  }

  Future<void> mount(WidgetTester tester, {bool throughHome = false}) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      binding.dispose();
      scope.dispose();
      await vocabulary.close();
    });
    await tester.pumpWidget(
      PikoApp(
        home: throughHome
            ? CollectionsHome(
                repository: const Collections([owner]),
                vocabularyRepository: vocabulary,
                speedSessionFactory: prepare,
                queryBindingFactory: (_) => binding,
              )
            : CollectionDetail(
                repository: const Collections([owner]),
                collectionId: owner.id,
                vocabularyRepository: vocabulary,
                queryBinding: binding,
                speedSessionFactory: prepare,
                reviewSessionFactory: (_, _) async =>
                    throw StateError('Review was not requested'),
              ),
      ),
    );
    await tester.pumpAndSettle();
    if (throughHome) {
      await tester.tap(find.byKey(ValueKey('collection-${owner.id}')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> setup(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('collection-speed-nativeToTarget')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    final start = find.widgetWithText(
      PikoButton,
      PikoCopy('en').text('learn.startSpeed'),
    );
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'Home passes Speed into filtered Detail with its clicked direction and visible membership',
    (tester) async {
      final h = DetailSpeedHarness();
      await h.mount(tester, throughHome: true);
      expect(
        find.byKey(const ValueKey('collection-speed-targetToNative')),
        findsNothing,
      );
      await h.setup(tester);
      expect(
        find.byKey(const ValueKey('speed-fixed-direction')),
        findsOneWidget,
      );
      expect(find.text('DE → FR'), findsOneWidget);
      await h.start(tester);
      expect(h.requests.single.direction, LearningDirection.nativeToTarget);
      expect(h.requests.single.visible, {one.id});
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('speed-exit')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'passive loading and snapshots keep Speed setup, preparation and active session mounted',
    (tester) async {
      final h = DetailSpeedHarness();
      await h.mount(tester);
      await h.setup(tester);
      final owner = tester.state(find.byType(SpeedLaunch));
      h.service.gate = Completer<CollectionQuerySnapshot>();
      h.binding.refresh();
      await tester.pump();
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      expect(
        tester.state(find.byType(SpeedLaunch, skipOffstage: false)),
        same(owner),
      );
      h.service.gate!.complete(speedProjection());
      await tester.pumpAndSettle();
      h.service.gate = null;
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      h.factoryGate = Completer<void>();
      await h.start(tester);
      h.service.value = speedProjection(eligible: false);
      h.binding.refresh();
      await tester.pumpAndSettle();
      h.factoryGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      h.binding.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      expect(
        tester.state(find.byType(SpeedLaunch, skipOffstage: false)),
        same(owner),
      );
      await tester.tap(find.byKey(const ValueKey('speed-exit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collection-speed-nativeToTarget')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Speed safely preserves an invalid raw editor and blocks Review and menu while setup owns launch',
    (tester) async {
      final h = DetailSpeedHarness();
      await h.mount(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('vocabulary-one')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('vocabulary-one')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vocabulary-one')));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byKey(const ValueKey('inline-one-target')),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '  ');
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(field).controller;
      await h.setup(tester);
      final review = find.byKey(
        const ValueKey('collection-review-targetToNative'),
        skipOffstage: false,
      );
      expect(tester.widget<PikoButton>(review).onPressed, isNull);
      final menu = find.byKey(
        const ValueKey('collection-menu'),
        skipOffstage: false,
      );
      expect(tester.widget<PikoIconButton>(menu).onPressed, isNull);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(h.requests, isEmpty);
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller!.text, '  ');
      expect(
        tester
            .widget<PikoButton>(
              find.byKey(const ValueKey('collection-review-targetToNative')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
}
