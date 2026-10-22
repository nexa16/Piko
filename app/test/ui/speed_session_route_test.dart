import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/speed_completion.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';

const owner = CollectionRecord(
  id: 'collection',
  name: 'Words',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);

class SpeedVocabulary implements VocabularyRepository {
  final entries = {
    'a': const VocabularyRecord(
      id: 'a',
      collectionId: 'collection',
      targetText: 'Alpha',
      nativeText: 'Eins',
    ),
    'b': const VocabularyRecord(
      id: 'b',
      collectionId: 'collection',
      targetText: 'Beta',
      nativeText: 'Zwei',
    ),
  };
  bool failRead = false;
  int reads = 0;

  @override
  Stream<VocabularyRecord?> watchById(String id) {
    reads++;
    return failRead
        ? Stream.error(StateError('read failed'))
        : Stream.value(entries[id]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SpeedHarness {
  SpeedHarness({
    this.language = 'en',
    this.direction = LearningDirection.targetToNative,
    this.injectGame = true,
    int poolSize = 1,
    bool correctable = false,
  }) {
    session = SpeedLearningSession(
      initial: SpeedSession.start(
        collectionId: owner.id,
        direction: direction,
        eligibleEntryIds: ['a', 'b'],
        poolSize: poolSize,
      ),
      commitCompletion: (completion) async {
        commitCalls++;
        await commitGate?.future;
        if (failCommit) throw StateError('commit failed');
        durable.add(completion);
      },
      commitCorrectableCompletion: !correctable
          ? null
          : (completion) async {
              durable.add(completion);
              final card = LearningCardCodec.encode(
                LearningScheduler().initialCard(
                  itemId: 1,
                  at: DateTime.utc(2026),
                ),
              );
              return SpeedCompletionResult(
                prior: LearningItemRecord(
                  id: 1,
                  entryId: completion.entryId,
                  direction: direction,
                  cardJson: card,
                  formatVersion: LearningCardCodec.version,
                ),
                next: LearningItemRecord(
                  id: 1,
                  entryId: completion.entryId,
                  direction: direction,
                  cardJson: card,
                  formatVersion: LearningCardCodec.version,
                  speedCompleted: true,
                ),
                alreadyApplied: false,
              );
            },
      reverseCompletion: !correctable
          ? null
          : (_) async {
              durable.removeLast();
            },
    );
  }

  final String language;
  final LearningDirection direction;
  final bool injectGame;
  final repository = SpeedVocabulary();
  final durable = <SpeedCompletion>[];
  late final SpeedLearningSession session;
  Completer<void>? commitGate;
  bool failCommit = false;
  int commitCalls = 0;
  int gameBuilds = 0;
  SpeedSessionResult? result;

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      PikoApp(
        locale: Locale(language),
        home: Scaffold(
          body: Builder(
            builder: (context) => PikoButton(
              label: 'Collection',
              onPressed: () async {
                result = await Navigator.of(context).push<SpeedSessionResult>(
                  MaterialPageRoute<SpeedSessionResult>(
                    builder: (_) => SpeedSessionRoute(
                      collection: owner,
                      session: session,
                      vocabularyRepository: repository,
                      gameBuilder: !injectGame
                          ? null
                          : (context, session) {
                              gameBuilds++;
                              return const Text('Injected numbers game');
                            },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester) async {
    await tester.ensureVisible(prompt);
    await tester.tap(prompt);
    await tester.pumpAndSettle();
  }

  Future<void> grade(WidgetTester tester, SpeedAnswer answer) async {
    await tester.ensureVisible(gradeButton(answer));
    await tester.tap(gradeButton(answer));
    await tester.pumpAndSettle();
  }

  Future<void> exit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('speed-exit')));
    await tester.tap(find.byKey(const ValueKey('speed-exit')));
    await tester.pumpAndSettle();
  }
}

final prompt = find.byKey(const ValueKey('review-prompt'));
Finder gradeButton(SpeedAnswer answer) =>
    find.byKey(ValueKey('speed-grade-${answer.name}'));

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      'Speed $language Previous replaces revealed answer during minigame and shows transient retries',
      (tester) async {
        final h = SpeedHarness(
          language: language,
          poolSize: 2,
          correctable: true,
          injectGame: false,
        );
        await h.mount(tester, scale: 2);
        await h.reveal(tester);
        await h.grade(tester, SpeedAnswer.incorrect);
        await h.reveal(tester);
        await h.grade(tester, SpeedAnswer.correct);
        expect(h.session.needsBreak, isTrue);
        final previous = find.byKey(const ValueKey('speed-correct-previous'));
        expect(previous, findsOneWidget);
        await tester.ensureVisible(previous);
        await tester.tap(previous);
        await tester.pumpAndSettle();
        expect(h.session.isCorrecting, isTrue);
        expect(gradeButton(SpeedAnswer.incorrect), findsOneWidget);
        expect(
          find.text(
            PikoCopy(language).text('learn.previousGrade', {
              'grade': PikoCopy(language).text('action.correct'),
            }),
          ),
          findsOneWidget,
        );
        await h.grade(tester, SpeedAnswer.incorrect);
        expect(h.session.state!.completedEntryIds, isEmpty);
        expect(h.session.needsBreak, isFalse);
        expect(h.durable, isEmpty);
        expect(h.session.state!.totalRetries, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final language in ['en', 'de']) {
    for (final direction in LearningDirection.values) {
      testWidgets(
        'UX-REVIEW-001 Speed $language $direction reveals/grades at320px/200% and completes without summary',
        (tester) async {
          final h = SpeedHarness(language: language, direction: direction);
          await h.mount(tester, scale: 2);
          final copy = PikoCopy(language);
          expect(
            find.text(
              direction == LearningDirection.targetToNative
                  ? 'FR → DE'
                  : 'DE → FR',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              direction == LearningDirection.targetToNative ? 'Alpha' : 'Eins',
            ),
            findsOneWidget,
          );
          expect(find.byType(Checkbox), findsNothing);
          expect(find.text(copy.text('learn.hard')), findsNothing);
          expect(find.text(copy.text('learn.correctPrevious')), findsNothing);
          expect(find.byType(TextField), findsNothing);
          expect(gradeButton(SpeedAnswer.correct), findsNothing);
          final before = h.session.state;
          await h.reveal(tester);
          expect(h.session.state, same(before));
          expect(h.session.revealed, isTrue);
          expect(h.durable, isEmpty);
          expect(find.text('Alpha'), findsOneWidget);
          expect(find.text('Eins'), findsOneWidget);
          expect(
            tester.getRect(gradeButton(SpeedAnswer.incorrect)).left,
            lessThan(tester.getRect(gradeButton(SpeedAnswer.correct)).left),
          );
          expect(
            tester.getSize(gradeButton(SpeedAnswer.incorrect)),
            tester.getSize(gradeButton(SpeedAnswer.correct)),
          );
          expect(
            tester
                .widget<PikoButton>(gradeButton(SpeedAnswer.incorrect))
                .variant,
            PikoButtonVariant.gradeIncorrect,
          );
          expect(
            tester.widget<PikoButton>(gradeButton(SpeedAnswer.correct)).variant,
            PikoButtonVariant.gradeCorrect,
          );
          final stale = tester
              .widget<PikoButton>(gradeButton(SpeedAnswer.correct))
              .onPressed!;
          await h.grade(tester, SpeedAnswer.correct);
          expect(h.durable.single.entryId, 'a');
          expect(h.durable.single.errors, 0);
          expect(h.session.current!.entryId, 'b');
          expect(h.session.revealed, isFalse);
          expect(
            find.text(
              copy.text('learn.speedProgress', {'completed': 1, 'total': 2}),
            ),
            findsOneWidget,
          );
          final track = tester.getSize(
            find.byKey(const ValueKey('speed-progress')),
          );
          final fill = tester.getSize(
            find.byKey(const ValueKey('speed-progress-fill')),
          );
          expect(fill.width, closeTo(track.width / 2, .01));
          expect(fill.height, track.height);
          stale();
          await tester.pumpAndSettle();
          expect(h.commitCalls, 1);
          await h.reveal(tester);
          await h.grade(tester, SpeedAnswer.correct);
          expect(h.durable.map((value) => value.entryId), ['a', 'b']);
          expect(h.session.isStopped, isTrue);
          expect(h.session.state, isNull);
          expect(h.result!.completedCount, 2);
          expect(find.byType(SpeedSessionRoute), findsNothing);
          expect(find.byType(ReviewSummaryDialog), findsNothing);
          expect(find.text('Collection'), findsOneWidget);
          expect(h.gameBuilds, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'leaving during the final write retains its result without completion feedback',
    (tester) async {
      final h = SpeedHarness();
      await h.mount(tester);
      await h.reveal(tester);
      await h.grade(tester, SpeedAnswer.correct);
      h.commitGate = Completer<void>();
      await h.reveal(tester);
      await h.grade(tester, SpeedAnswer.correct);
      await h.exit(tester);
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      expect(h.result, isNull);
      h.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSessionRoute), findsNothing);
      expect(h.durable, hasLength(2));
      expect(h.result, isNull);
    },
  );

  testWidgets(
    'pending completion disables grades; failure retains revealed card and exact retry',
    (tester) async {
      final h = SpeedHarness()
        ..commitGate = Completer<void>()
        ..failCommit = true;
      await h.mount(tester);
      await h.reveal(tester);
      final handle = h.session.current;
      final state = h.session.state;
      await h.grade(tester, SpeedAnswer.correct);
      expect(h.session.isSubmitting, isTrue);
      expect(h.session.state, same(state));
      expect(
        tester.widget<PikoButton>(gradeButton(SpeedAnswer.correct)).onPressed,
        isNull,
      );
      expect(
        find.text(PikoCopy('en').text('learn.gradeSaving')),
        findsOneWidget,
      );
      h.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(h.session.error, isNotNull);
      expect(h.session.current, same(handle));
      expect(h.session.revealed, isTrue);
      expect(find.text('Eins'), findsOneWidget);
      expect(
        find.text(PikoCopy('en').text('learn.gradeFailed')),
        findsOneWidget,
      );
      h.failCommit = false;
      h.commitGate = null;
      await h.grade(tester, SpeedAnswer.correct);
      expect(h.commitCalls, 2);
      expect(h.durable, hasLength(1));
      expect(h.result, isNull);
      expect(h.session.current!.entryId, 'b');
      await h.exit(tester);
      expect(h.session.state, isNull);
      expect(h.durable, hasLength(1));
    },
  );

  testWidgets(
    'covered and paused callbacks cannot grade; resume keeps revealed live turn',
    (tester) async {
      final h = SpeedHarness();
      await h.mount(tester);
      await h.reveal(tester);
      final handle = h.session.current;
      final state = h.session.state;
      final stale = tester
          .widget<PikoButton>(gradeButton(SpeedAnswer.correct))
          .onPressed!;
      final navigator = Navigator.of(
        tester.element(find.byType(SpeedSessionRoute)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Cover')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(h.commitCalls, 0);
      expect(h.session.state, same(state));
      navigator.pop();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      stale();
      await tester.pump();
      expect(h.commitCalls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.session.current, same(handle));
      expect(h.session.revealed, isTrue);
      await h.grade(tester, SpeedAnswer.incorrect);
      expect(h.session.state!.itemProgress['a']!.errors, 1);
      expect(h.durable, isEmpty);
      await h.exit(tester);
      expect(h.session.state, isNull);
    },
  );

  testWidgets(
    'exit drains a completing item then returns without restoring unfinished round',
    (tester) async {
      final h = SpeedHarness()..commitGate = Completer<void>();
      await h.mount(tester);
      await h.reveal(tester);
      await h.grade(tester, SpeedAnswer.correct);
      await tester.ensureVisible(find.byKey(const ValueKey('speed-exit')));
      await tester.tap(find.byKey(const ValueKey('speed-exit')));
      await tester.pumpAndSettle();
      expect(h.session.isStopped, isTrue);
      expect(h.session.state, isNull);
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      h.commitGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SpeedSessionRoute), findsNothing);
      expect(h.durable.single.entryId, 'a');
      expect(h.result, isNull);
      expect(find.byType(ReviewSummaryDialog), findsNothing);
    },
  );

  for (final failFinalCommit in [false, true]) {
    testWidgets(
      'final commit must succeed before a completion result: failure=$failFinalCommit',
      (tester) async {
        final h = SpeedHarness();
        await h.mount(tester);
        await h.reveal(tester);
        await h.grade(tester, SpeedAnswer.correct);
        h.commitGate = Completer<void>();
        h.failCommit = failFinalCommit;
        await h.reveal(tester);
        await h.grade(tester, SpeedAnswer.correct);
        expect(h.session.isSubmitting, isTrue);
        expect(h.durable, hasLength(1));
        expect(h.result, isNull);
        expect(find.byType(SpeedSessionRoute), findsOneWidget);
        h.commitGate!.complete();
        await tester.pumpAndSettle();
        if (failFinalCommit) {
          expect(h.session.error, isNotNull);
          expect(find.byType(SpeedSessionRoute), findsOneWidget);
          expect(h.result, isNull);
          await h.exit(tester);
          expect(h.result, isNull);
          expect(h.durable, hasLength(1));
        } else {
          expect(find.byType(SpeedSessionRoute), findsNothing);
          expect(h.result!.completedCount, 2);
          expect(h.durable, hasLength(2));
        }
      },
    );
  }

  testWidgets(
    'only a complete short-pool pass invokes supplied game presentation',
    (tester) async {
      final h = SpeedHarness(poolSize: 5);
      await h.mount(tester);
      await h.reveal(tester);
      await h.grade(tester, SpeedAnswer.incorrect);
      expect(h.gameBuilds, 0);
      expect(h.session.current!.entryId, 'b');
      await h.reveal(tester);
      await h.grade(tester, SpeedAnswer.incorrect);
      expect(h.gameBuilds, greaterThan(0));
      expect(find.text('Injected numbers game'), findsOneWidget);
      expect(h.session.state!.numberGame, isNotNull);
      expect(h.session.current, isNull);
      expect(h.durable, isEmpty);
      await h.exit(tester);
      expect(find.byType(SpeedSessionRoute), findsNothing);
    },
  );

  testWidgets(
    'failed vocabulary read offers Retry without grading; keyboard reveal uses shared card',
    (tester) async {
      final h = SpeedHarness();
      h.repository.failRead = true;
      await h.mount(tester);
      expect(
        find.text(PikoCopy('en').text('vocab.loadFailed')),
        findsOneWidget,
      );
      expect(prompt, findsNothing);
      expect(gradeButton(SpeedAnswer.correct), findsNothing);
      h.repository.failRead = false;
      await tester.tap(
        find.widgetWithText(PikoButton, PikoCopy('en').text('action.retry')),
      );
      await tester.pumpAndSettle();
      final target = find
          .descendant(
            of: find.byKey(const ValueKey('review-reveal-target')),
            matching: find.byType(GestureDetector),
          )
          .first;
      Focus.of(tester.element(target)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(h.session.revealed, isTrue);
      expect(h.durable, isEmpty);
      expect(find.text('Eins'), findsOneWidget);
      await h.exit(tester);
    },
  );
}
