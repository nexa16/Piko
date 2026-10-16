import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/review_due_membership.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/speed/speed_launch.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';
import 'speed_session_route_test.dart' show owner, SpeedVocabulary;

CollectionQuerySnapshot snapshot({
  int forward = 2,
  int reverse = 1,
  List<String> visible = const ['a', 'b'],
  Set<(String, LearningDirection)> progress = const {},
  bool speedMarker = false,
  int generation = 0,
}) {
  final words = SpeedVocabulary().entries;
  LearningItemRecord item(String id, LearningDirection direction) {
    final scheduler = LearningScheduler();
    final record = LearningItemRecord(
      id: id == 'a' ? 1 : 2,
      entryId: id,
      direction: direction,
      cardJson: LearningCardCodec.encode(scheduler.initialCard(
        itemId: id == 'a' ? 1 : 2,
        at: DateTime.utc(2026, 10, 16),
      )),
      formatVersion: LearningCardCodec.version,
      generation: generation,
      speedCompleted: speedMarker,
    );
    return progress.contains((id, direction))
        ? scheduler.review(record, rating: LearningRating.good, reviewedAt: DateTime.utc(2026, 10, 16)).next
        : record;
  }
  return CollectionQuerySnapshot(
    collection: owner,
    allEntries: words.values,
    entries: visible.map((id) => words[id]!),
    categoryDimensions: const [],
    categoryValues: const {},
    assignments: const {},
    directions: {
      for (final direction in LearningDirection.values)
        direction: CollectionDirectionSnapshot(
          review: ReviewDueMembershipSnapshot(
            memberships: const [],
            nextChangeAt: null,
          ),
          newSpeedItems: visible
              .take(
                direction == LearningDirection.targetToNative
                    ? forward
                    : reverse,
              )
              .map(
                (id) => item(id, direction),
              ),
        ),
    },
  );
}

class LaunchHarness {
  LaunchHarness({
    CollectionQuerySnapshot? initial,
    this.language = 'en',
    this.scopeIdentity,
  }) : current = ValueNotifier(initial ?? snapshot());

  final String language;
  Object? scopeIdentity;
  final ValueNotifier<CollectionQuerySnapshot> current;
  final repository = SpeedVocabulary();
  final busy = <bool>[];
  final drains = <Future<void>>[];
  final requests =
      <
        ({
          String collectionId,
          LearningDirection direction,
          Set<String> visible,
          int poolSize,
        })
      >[];
  final created = <SpeedLearningSession>[];
  CollectionQuerySnapshot? loaded;
  Completer<void>? beforeGate;
  Completer<void>? factoryGate;
  bool failFactory = false;
  int returned = 0;
  final completedCounts = <int>[];

  Future<SpeedLearningSession> prepare({
    required String collectionId,
    required LearningDirection direction,
    required Set<String> visibleEntryIds,
    required int poolSize,
  }) async {
    requests.add((
      collectionId: collectionId,
      direction: direction,
      visible: visibleEntryIds,
      poolSize: poolSize,
    ));
    final entries = (loaded ?? current.value)
        .directions[direction]!
        .newSpeedItems
        .map((item) => item.entryId)
        .where(visibleEntryIds.contains)
        .toList();
    await factoryGate?.future;
    if (failFactory) throw StateError('preparation unavailable');
    final session = SpeedLearningSession(
      initial: SpeedSession.start(
        collectionId: collectionId,
        direction: direction,
        eligibleEntryIds: entries,
        poolSize: poolSize,
      ),
      commitCompletion: (_) async {},
      presentationActive: false,
    );
    created.add(session);
    return session;
  }

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(current.dispose);
    await tester.pumpWidget(
      PikoApp(
        locale: Locale(language),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ValueListenableBuilder<CollectionQuerySnapshot>(
              valueListenable: current,
              builder: (context, query, _) => SpeedLaunch(
                scopeIdentity: scopeIdentity,
                snapshot: query,
                factory: prepare,
                vocabularyRepository: repository,
                beforeLaunch: () async {
                  await beforeGate?.future;
                },
                snapshotLoader: () async => loaded ?? current.value,
                onBusyChanged: busy.add,
                onPendingWrites: drains.add,
                onSessionClosed: () => returned++,
                onCompleted: completedCounts.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, LearningDirection direction) async {
    await tester.tap(action(direction));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester, {String poolSize = '5'}) async {
    final field = find.byKey(const ValueKey('speed-pool-size'));
    await tester.ensureVisible(field);
    await tester.enterText(field, poolSize);
    await tester.pumpAndSettle();
    final start = find.widgetWithText(
      PikoButton,
      PikoCopy(language).text('learn.startSpeed'),
    );
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
  }

  Future<void> exit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('speed-exit')));
    await tester.tap(find.byKey(const ValueKey('speed-exit')));
    await tester.pumpAndSettle();
  }
}

Finder action(LearningDirection direction) =>
    find.byKey(ValueKey('collection-speed-${direction.name}'));

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      'UX-SETUP-002 $language positive counts share two gold halves and fixed direction survives setup',
      (tester) async {
        final h = LaunchHarness(language: language);
        await h.mount(tester, scale: 2);
        final first = action(LearningDirection.targetToNative);
        final second = action(LearningDirection.nativeToTarget);
        final row = tester.getRect(
          find.byKey(const ValueKey('collection-speed-actions')),
        );
        final left = tester.getRect(first), right = tester.getRect(second);
        expect(left.width, right.width);
        expect(left.height, right.height);
        expect(
          left.width,
          closeTo((row.width - pikoDesign.dimension('spacing.2')) / 2, .01),
        );
        for (final finder in [first, second]) {
          expect(tester.widget<PikoButton>(finder).labelAlignment, TextAlign.left);
          expect(tester.widget<PikoButton>(finder).expandLabel, isTrue);
          expect(
            tester.widget<PikoButton>(finder).variant,
            PikoButtonVariant.speed,
          );
          final textButton = tester.widget<TextButton>(
            find.descendant(of: finder, matching: find.byType(TextButton)),
          );
          expect(
            textButton.style!.backgroundColor!.resolve({}),
            pikoDesign.color('gold'),
          );
          expect(
            textButton.style!.foregroundColor!.resolve({}),
            pikoDesign.color('ink'),
          );
        }
        await h.open(tester, LearningDirection.nativeToTarget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('speed-fixed-direction')))
              .data,
          'DE → FR',
        );
        expect(
          find.text(PikoCopy(language).text('r2.speedNewOne')),
          findsOneWidget,
        );
        await h.start(tester, poolSize: '17');
        expect(h.requests.single.collectionId, owner.id);
        expect(h.requests.single.direction, LearningDirection.nativeToTarget);
        expect(h.requests.single.poolSize, 17);
        expect(h.requests.single.visible, {'a', 'b'});
        expect(() => h.requests.single.visible.clear(), throwsUnsupportedError);
        expect(find.byType(SpeedSessionRoute), findsOneWidget);
        expect(
          h.created.single.state!.direction,
          LearningDirection.nativeToTarget,
        );
        await h.exit(tester);
        expect(h.returned, 1);
        expect(h.completedCounts, isEmpty);
        expect(h.busy, [true, false]);
        await Future.wait(h.drains);
      },
    );
  }

  for (final direction in LearningDirection.values) {
    testWidgets('warning uses only included $direction card progress from the fresh snapshot', (tester) async {
      final opposite = LearningDirection.values.firstWhere((value) => value != direction);
      final h = LaunchHarness();
      await h.mount(tester);
      h.loaded = snapshot(progress: {('a', opposite)});
      await h.open(tester, direction);
      expect(find.byKey(const ValueKey('speed-reset-warning')), findsNothing);
      await tester.tap(find.byTooltip(PikoCopy('en').text('common.close')));
      await tester.pumpAndSettle();
      h.loaded = snapshot(visible: ['b'], progress: {('a', direction)});
      await h.open(tester, direction);
      expect(find.byKey(const ValueKey('speed-reset-warning')), findsNothing);
      await tester.tap(find.byTooltip(PikoCopy('en').text('common.close')));
      await tester.pumpAndSettle();
      h.loaded = snapshot(generation: 3, speedMarker: true);
      await h.open(tester, direction);
      expect(find.byKey(const ValueKey('speed-reset-warning')), findsNothing);
      await tester.tap(find.byTooltip(PikoCopy('en').text('common.close')));
      await tester.pumpAndSettle();
      h.loaded = snapshot(progress: {('a', direction)});
      await h.open(tester, direction);
      expect(find.byKey(const ValueKey('speed-reset-warning')), findsOneWidget);
      await tester.tap(find.byTooltip(PikoCopy('en').text('common.close')));
      await tester.pumpAndSettle();
      expect(h.requests, isEmpty);
      expect(h.completedCounts, isEmpty);
    });
  }

  testWidgets('completion callback returns the committed round count exactly once', (tester) async {
    final h = LaunchHarness();
    await h.mount(tester);
    await h.open(tester, LearningDirection.targetToNative);
    expect(find.byKey(const ValueKey('speed-reset-warning')), findsNothing);
    await h.start(tester);
    for (var index = 0; index < 2; index++) {
      await tester.ensureVisible(find.byKey(const ValueKey('review-prompt')));
      await tester.tap(find.byKey(const ValueKey('review-prompt')));
      await tester.pumpAndSettle();
      final grade = find.byKey(const ValueKey('speed-grade-correct'));
      await tester.ensureVisible(grade);
      await tester.tap(grade);
      await tester.pumpAndSettle();
    }
    expect(find.byType(SpeedSessionRoute), findsNothing);
    expect(h.completedCounts, [2]);
    expect(h.returned, 1);
    await tester.pumpAndSettle();
    expect(h.completedCounts, [2]);
  });

  testWidgets(
    'a lone reverse action stays left half-width and zero counts disappear',
    (tester) async {
      final h = LaunchHarness(initial: snapshot(forward: 0));
      await h.mount(tester);
      expect(action(LearningDirection.targetToNative), findsNothing);
      final row = tester.getRect(
        find.byKey(const ValueKey('collection-speed-actions')),
      );
      final only = tester.getRect(action(LearningDirection.nativeToTarget));
      expect(only.left, row.left);
      expect(
        only.width,
        closeTo((row.width - pikoDesign.dimension('spacing.2')) / 2, .01),
      );
      h.current.value = snapshot(forward: 0, reverse: 0);
      await tester.pumpAndSettle();
      expect(find.byType(PikoButton), findsNothing);
    },
  );

  testWidgets(
    'changed filters retire an open setup and reject its stale Start',
    (tester) async {
      final h = LaunchHarness();
      await h.mount(tester);
      await h.open(tester, LearningDirection.targetToNative);
      final stale = tester
          .widget<PikoButton>(
            find.widgetWithText(
              PikoButton,
              PikoCopy('en').text('learn.startSpeed'),
            ),
          )
          .onPressed!;
      h.current.value = snapshot(visible: ['b']);
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsNothing);
      stale();
      await tester.pumpAndSettle();
      expect(h.requests, isEmpty);
      expect(h.busy, [true, false]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same explicit query intent retains setup across passive refreshed results',
    (tester) async {
      final h = LaunchHarness(
        initial: snapshot(forward: 1),
        scopeIdentity: ('collection', 'filter-A'),
      );
      await h.mount(tester);
      await h.open(tester, LearningDirection.targetToNative);
      h.current.value = snapshot(forward: 2);
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      expect(h.busy, [true]);
      await h.start(tester);
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      expect(h.created.single.state!.entryIds, ['a', 'b']);
      expect(h.requests.single.visible, {'a', 'b'});
      await h.exit(tester);
      expect(h.busy, [true, false]);
      await Future.wait(h.drains);
    },
  );

  testWidgets(
    'changed explicit query intent cancels setup even when visible IDs match',
    (tester) async {
      final h = LaunchHarness(scopeIdentity: ('collection', 'filter-A'));
      await h.mount(tester);
      await h.open(tester, LearningDirection.targetToNative);
      final stale = tester
          .widget<PikoButton>(
            find.widgetWithText(
              PikoButton,
              PikoCopy('en').text('learn.startSpeed'),
            ),
          )
          .onPressed!;
      h.scopeIdentity = ('collection', 'filter-B');
      h.current.value = snapshot();
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSetupDialog), findsNothing);
      stale();
      await tester.pumpAndSettle();
      expect(h.requests, isEmpty);
      expect(h.busy, [true, false]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed scope during the write barrier prevents setup and drains admitted preparation',
    (tester) async {
      final h = LaunchHarness()..beforeGate = Completer<void>();
      await h.mount(tester);
      await h.open(tester, LearningDirection.targetToNative);
      expect(find.byType(SpeedSetupDialog), findsNothing);
      h.current.value = snapshot(visible: ['b']);
      await tester.pump();
      h.beforeGate!.complete();
      await tester.pumpAndSettle();
      await Future.wait(h.drains);
      expect(find.byType(SpeedSetupDialog), findsNothing);
      expect(h.requests, isEmpty);
      expect(h.busy, [true, false]);
    },
  );

  testWidgets(
    'a session prepared after scope replacement is stopped rather than pushed',
    (tester) async {
      final h = LaunchHarness()..factoryGate = Completer<void>();
      await h.mount(tester);
      await h.open(tester, LearningDirection.targetToNative);
      await h.start(tester);
      expect(h.requests, hasLength(1));
      h.current.value = snapshot(visible: ['b']);
      await tester.pumpAndSettle();
      h.factoryGate!.complete();
      await tester.pumpAndSettle();
      await Future.wait(h.drains);
      expect(h.created.single.isStopped, isTrue);
      expect(h.created.single.state, isNull);
      expect(find.byType(SpeedSessionRoute), findsNothing);
      expect(h.busy, [true, false]);
    },
  );

  testWidgets(
    'owner disposal while preparing drains and disposes the unused session',
    (tester) async {
      final h = LaunchHarness()..factoryGate = Completer<void>();
      await h.mount(tester);
      await h.open(tester, LearningDirection.targetToNative);
      await h.start(tester);
      await tester.pumpWidget(const SizedBox());
      h.factoryGate!.complete();
      await tester.pumpAndSettle();
      await Future.wait(h.drains);
      expect(h.created.single.isStopped, isTrue);
      expect(h.created.single.state, isNull);
      expect(find.byType(SpeedSessionRoute), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real preparation failure offers Retry with the accepted pool and fixed direction',
    (tester) async {
      final h = LaunchHarness()..failFactory = true;
      await h.mount(tester);
      await h.open(tester, LearningDirection.nativeToTarget);
      await h.start(tester, poolSize: '7');
      expect(
        find.text(PikoCopy('en').text('learn.prepareFailed')),
        findsOneWidget,
      );
      expect(find.byType(SpeedSessionRoute), findsNothing);
      h.failFactory = false;
      await tester.tap(
        find.widgetWithText(PikoButton, PikoCopy('en').text('action.retry')),
      );
      await tester.pumpAndSettle();
      expect(h.requests, hasLength(2));
      expect(
        h.requests.every(
          (request) =>
              request.poolSize == 7 &&
              request.direction == LearningDirection.nativeToTarget,
        ),
        isTrue,
      );
      expect(find.byType(SpeedSetupDialog), findsNothing);
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      await h.exit(tester);
    },
  );

  testWidgets(
    'fresh zero eligibility and safe setup dismissal do not prepare a round',
    (tester) async {
      final h = LaunchHarness()..loaded = snapshot(forward: 0, reverse: 0);
      await h.mount(tester);
      await h.open(tester, LearningDirection.targetToNative);
      expect(find.byType(SpeedSetupDialog), findsNothing);
      expect(h.requests, isEmpty);
      h.loaded = null;
      await h.open(tester, LearningDirection.targetToNative);
      await tester.tap(find.byTooltip(PikoCopy('en').text('common.close')));
      await tester.pumpAndSettle();
      expect(h.requests, isEmpty);
      await h.open(tester, LearningDirection.targetToNative);
      h.loaded = snapshot(forward: 0, reverse: 0);
      await h.start(tester);
      expect(h.requests, isEmpty);
      expect(h.completedCounts, isEmpty);
      expect(find.byType(SpeedSessionRoute), findsNothing);
      await Future.wait(h.drains);
    },
  );
}
