import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/speed/selected_speed_launch.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/features/vocabulary/vocabulary_selection.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'speed_session_route_test.dart' show owner, SpeedVocabulary;

class Harness {
  final selection = VocabularySelection()
    ..selectAll(['b', 'a', 'inactive', 'deleted']);
  final repository = SpeedVocabulary();
  Set<String> inactive = {};
  Set<LearningDirection> directions = {LearningDirection.targetToNative};
  final requests = <(LearningDirection, List<String>, int)>[];
  final busy = <bool>[];
  final sessions = <SpeedLearningSession>[];
  bool failDrain = false, failFactory = false;
  Completer<void>? gate;
  final pending = <Future<void>>[];
  SelectedSpeedScope scope(Set<String> ids) => SelectedSpeedScope(
    CollectionQuerySnapshot(
      collection: owner,
      allEntries: [
        for (final word in repository.entries.values)
          VocabularyRecord(
            id: word.id,
            collectionId: owner.id,
            targetText: word.targetText,
            nativeText: word.nativeText,
            active: !inactive.contains(word.id),
          ),
        const VocabularyRecord(
          id: 'inactive',
          collectionId: 'collection',
          targetText: 'Zero',
          nativeText: 'Null',
          active: false,
        ),
      ],
      entries: [repository.entries['b']!],
      categoryDimensions: const [],
      categoryValues: const {},
      assignments: const {},
      directions: const {},
    ),
    ids,
    VocabularySort.targetAscending,
  );
  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      PikoApp(
        locale: Locale(language),
        home: Scaffold(
          body: SelectedSpeedLaunch(
            collection: owner,
            selection: selection,
            directions: directions,
            loadScope: (ids) async => scope(ids),
            beforeLaunch: () async {
              if (failDrain) throw StateError('Pending edit failed');
            },
            onBusyChanged: busy.add,
            onPendingWrites: pending.add,
            vocabularyRepository: repository,
            factory:
                ({
                  required collectionId,
                  required direction,
                  required orderedEntryIds,
                  required poolSize,
                }) async {
                  requests.add((direction, orderedEntryIds, poolSize));
                  await gate?.future;
                  if (failFactory) throw StateError('Unavailable');
                  final session = SpeedLearningSession(
                    initial: SpeedSession.start(
                      collectionId: collectionId,
                      direction: direction,
                      eligibleEntryIds: orderedEntryIds,
                      poolSize: poolSize,
                    ),
                    presentationActive: false,
                    commitCompletion: (_) async {},
                  );
                  sessions.add(session);
                  return session;
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('selected-speed-launch')));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester, {String language = 'en'}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 60 && tester.view.viewInsets.bottom > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.view.viewInsets.bottom, 0);
    final button = find.text(PikoCopy(language).text('learn.startSpeed'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'hidden reviewed selection uses full sort, truthful exclusions and cancel preserves selection',
    (tester) async {
      final h = Harness();
      await h.mount(tester);
      await h.open(tester);
      expect(find.text('Selected active words: 2'), findsOneWidget);
      expect(find.text('Included but hidden in the list: 1'), findsOneWidget);
      expect(find.text('Excluded inactive words: 1'), findsOneWidget);
      expect(find.text('No longer available: 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('speed-new-count')), findsNothing);
      expect(
        find.byKey(const ValueKey('speed-fixed-direction')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(h.selection.ids, {'b', 'a', 'inactive', 'deleted'});
      expect(h.requests, isEmpty);
      expect(h.busy, [true, false]);
      await h.open(tester);
      await h.start(tester);
      expect(h.requests.single.$1, LearningDirection.targetToNative);
      expect(h.requests.single.$2, ['a', 'b']);
      expect(h.requests.single.$3, 5);
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await Future.wait(h.pending);
    },
  );

  testWidgets(
    'both directions picker cancel and fixed reverse DE320/200 setup',
    (tester) async {
      final h = Harness()..directions = LearningDirection.values.toSet();
      await h.mount(tester, language: 'de', scale: 2);
      await h.open(tester);
      expect(find.byType(SpeedSetupDialog), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(h.selection.ids.length, 4);
      await h.open(tester);
      final reverse = find.byKey(
        const ValueKey('learning-direction-nativeToTarget'),
      );
      await tester.ensureVisible(reverse);
      await tester.tap(reverse);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('speed-fixed-direction')),
        findsOneWidget,
      );
      await h.start(tester, language: 'de');
      expect(h.requests.single.$1, LearningDirection.nativeToTarget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'drain/factory failures retain setup, pool and selection; retry rechecks changed membership',
    (tester) async {
      final h = Harness()..failDrain = true;
      await h.mount(tester);
      await h.open(tester);
      expect(
        find.byKey(const ValueKey('selected-speed-retry')),
        findsOneWidget,
      );
      expect(h.requests, isEmpty);
      h.failDrain = false;
      await tester.tap(find.byKey(const ValueKey('selected-speed-retry')));
      await tester.pumpAndSettle();
      final pool = find.byKey(const ValueKey('speed-pool-size'));
      await tester.ensureVisible(pool);
      await tester.enterText(pool, '3');
      h.inactive.add('a');
      await h.start(tester);
      expect(find.text('Selected active words: 1'), findsOneWidget);
      expect(h.requests, isEmpty);
      h.failFactory = true;
      await h.start(tester);
      expect(h.requests.single.$2, ['b']);
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      expect(tester.widget<TextField>(pool).controller!.text, '3');
      expect(h.selection.ids.length, 4);
      h.failFactory = false;
      await tester.ensureVisible(
        find.byKey(const ValueKey('selected-speed-retry')),
      );
      await tester.tap(find.byKey(const ValueKey('selected-speed-retry')));
      await tester.pumpAndSettle();
      await h.start(tester);
      expect(h.requests.last.$3, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'all inactive has no fallback; cancellation during admitted preparation disposes abandoned session',
    (tester) async {
      final h = Harness()..inactive = {'a', 'b'};
      await h.mount(tester);
      await h.open(tester);
      await h.start(tester);
      expect(h.requests, isEmpty);
      h.inactive.clear();
      await tester.ensureVisible(
        find.byKey(const ValueKey('selected-speed-retry')),
      );
      await tester.tap(find.byKey(const ValueKey('selected-speed-retry')));
      await tester.pumpAndSettle();
      h.gate = Completer<void>();
      await h.start(tester);
      await h.start(tester);
      expect(h.requests.length, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      h.gate!.complete();
      await tester.pumpAndSettle();
      await Future.wait(h.pending);
      expect(h.sessions.single.isStopped, isTrue);
      expect(find.byType(SpeedSessionRoute), findsNothing);
      expect(h.selection.ids.length, 4);
    },
  );
}
