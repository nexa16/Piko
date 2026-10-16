import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';
import 'package:piko/shared/catalogs.dart';
import '../data/regular_reviews_test.dart' show instant, rows;
import '../features/due_learning_session_test.dart' show GatedSource;
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show start, card, text, ObservedVocabulary;

final target = find.byKey(const ValueKey('review-reveal-target'));
final answer = find.byKey(const ValueKey('review-answer-text'));
final cue = find.byKey(const ValueKey('review-reveal-cue'));
VoidCallback action(WidgetTester tester) => tester
    .widget<GestureDetector>(
      find.descendant(of: target, matching: find.byType(GestureDetector)),
    )
    .onTap!;

void main() {
  for (final reverse in [false, true]) {
    launch.testWidgets(
      'whole real ${reverse ? "reverse card surface" : "forward prompt text"} reveals both stored languages once without writes or headings',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        final h = launch.Harness(f);
        await h.mount(tester);
        await start(tester, h, reverse: reverse);
        final before = await tester.runAsync(() => snapshot(f));
        final semantics = tester.ensureSemantics();
        try {
          final hidden = tester.getSemantics(target);
          expect(hidden.label, reverse ? 'Eins' : 'One');
          expect(
            hidden.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          expect(answer, findsNothing);
          expect(cue, findsOneWidget);
          final stale = action(tester);
          if (reverse) {
            await tester.tapAt(
              tester.getRect(card).topLeft + const Offset(5, 5),
            );
          } else {
            await tester.tap(find.byKey(const ValueKey('review-prompt-text')));
          }
          await tester.pumpAndSettle();
          expect(
            text(card, tester),
            reverse ? ['Eins', 'One'] : ['One', 'Eins'],
          );
          expect(cue, findsNothing);
          final shown = tester.getSemantics(target);
          expect(shown.label, reverse ? 'Eins\nOne' : 'One\nEins');
          expect(shown.flagsCollection.isButton, isFalse);
          expect(
            shown.getSemanticsData().hasAction(SemanticsAction.tap),
            isFalse,
          );
          expect(
            find.descendant(of: card, matching: find.byType(Chip)),
            findsNothing,
          );
          expect(
            find.descendant(of: card, matching: find.byType(PikoButton)),
            findsNothing,
          );
          expect(find.text('Show Answer'), findsNothing);
          expect(find.text('Answer revealed'), findsNothing);
          stale();
          await tester.tap(card);
          await tester.pumpAndSettle();
          expect(
            text(card, tester),
            reverse ? ['Eins', 'One'] : ['One', 'Eins'],
          );
          expect(await tester.runAsync(() => snapshot(f)), before);
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    launch.testWidgets(
      '${key.keyLabel} keyboard reveal exposes focused single-action semantics without moving card layout',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        final h = launch.Harness(f);
        await h.mount(tester);
        await start(tester, h);
        final before = await tester.runAsync(() => snapshot(f));
        final beforeCard = tester.getRect(card),
            beforeWord = tester.getRect(
              find.byKey(const ValueKey('review-prompt-text')),
            );
        final semantics = tester.ensureSemantics();
        try {
          expect(
            tester.getSemantics(target).flagsCollection.isFocused,
            Tristate.isFalse,
          );
          for (
            var index = 0;
            index < 3 &&
                tester.getSemantics(target).flagsCollection.isFocused !=
                    Tristate.isTrue;
            index++
          ) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          }
          expect(
            tester.getSemantics(target).flagsCollection.isFocused,
            Tristate.isTrue,
          );
          expect(
            tester.getSemantics(target).flagsCollection.isFocused,
            isNot(Tristate.none),
          );
          expect(tester.getRect(card), beforeCard);
          expect(
            tester.getRect(find.byKey(const ValueKey('review-prompt-text'))),
            beforeWord,
          );
          await tester.sendKeyEvent(key);
          await tester.pumpAndSettle();
          expect(text(card, tester), ['One', 'Eins']);
          expect(
            tester.getSemantics(target).flagsCollection.isFocused,
            Tristate.none,
          );
          expect(
            tester
                .getSemantics(target)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isFalse,
          );
          expect(await tester.runAsync(() => snapshot(f)), before);
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  launch.testWidgets(
    'locale rebuild keeps reveal and subscription; live stored pair update rejects old displayed callback',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final observed = ObservedVocabulary(f.vocabulary);
      final h = launch.Harness(f)..gatedVocabulary = observed;
      await h.mount(tester);
      await start(tester, h);
      final stale = action(tester);
      await tester.runAsync(
        () => f.vocabulary.update(
          id: f.entry.id,
          targetText: 'Changed',
          nativeText: 'Geändert',
        ),
      );
      await h.flush(tester);
      stale();
      await tester.pumpAndSettle();
      expect(answer, findsNothing);
      final before = await tester.runAsync(() => snapshot(f));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(text(card, tester), ['Changed', 'Geändert']);
      final reads = observed.reads;
      h.locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(text(card, tester), ['Changed', 'Geändert']);
      expect(observed.reads, reads);
      expect(await tester.runAsync(() => snapshot(f)), before);
    },
  );

  launch.testWidgets(
    'revealed current card survives read error and same-handle retry without showing stale content',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final stream = StreamController<VocabularyRecord?>.broadcast(sync: true);
      addTearDown(stream.close);
      final observed = ObservedVocabulary(f.vocabulary)
        ..supplied[f.entry.id] = stream.stream;
      final h = launch.Harness(f)..gatedVocabulary = observed;
      await h.mount(tester);
      await start(tester, h);
      final stored = (await tester.runAsync(
        () => f.vocabulary.watchById(f.entry.id).first,
      ))!;
      stream.add(stored);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(answer, findsOneWidget);
      stream.addError(StateError('read'));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      await tester.tap(launch.button(PikoCopy('en').text('action.retry')));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      stream.add(stored);
      await tester.pumpAndSettle();
      expect(text(card, tester), ['One', 'Eins']);
      expect(cue, findsNothing);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'failed grade retains revealed card; actual accepted advance resets next handle to hidden answer',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      await tester.runAsync(
        () => f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Next',
          nativeText: 'Weiter',
        ),
      );
      final h = launch.Harness(f);
      await h.mount(tester);
      await start(tester, h);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final session = h.sessions.single, handle = h.sessions.single.current!;
      await tester.runAsync(
        () => f.db.customStatement(
          "CREATE TRIGGER reveal_fail AFTER UPDATE ON learning_items BEGIN SELECT RAISE(FAIL, 'failed'); END",
        ),
      );
      final failure = await tester.runAsync(() async {
        try {
          await session.submit(
            handle,
            AnswerGrade.correct,
            reviewedAt: instant,
          );
          return false;
        } catch (_) {
          return true;
        }
      });
      expect(failure, isTrue);
      await tester.pumpAndSettle();
      expect(text(card, tester), ['One', 'Eins']);
      await tester.runAsync(
        () => f.db.customStatement('DROP TRIGGER reveal_fail'),
      );
      await tester.runAsync(
        () => session.submit(handle, AnswerGrade.correct, reviewedAt: instant),
      );
      await tester.pump();
      await h.flush(tester);
      expect(text(card, tester), ['Next']);
      expect(answer, findsNothing);
      expect(cue, findsOneWidget);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        hasLength(1),
      );
    },
  );

  launch.testWidgets(
    'old hidden callback rejects actual accepted advance before a Flutter rebuild',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      await tester.runAsync(
        () => f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Next',
          nativeText: 'Weiter',
        ),
      );
      final h = launch.Harness(f);
      await h.mount(tester);
      await start(tester, h);
      final stale = action(tester), session = h.sessions.single;
      await tester.runAsync(
        () => session.submit(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        ),
      );
      stale();
      await tester.pump();
      await h.flush(tester);
      expect(text(card, tester), ['Next']);
      expect(answer, findsNothing);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        hasLength(1),
      );
    },
  );

  launch.testWidgets(
    'covered and disposed card callbacks cannot reveal or write',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final h = launch.Harness(f);
      await h.mount(tester);
      await start(tester, h);
      final stale = action(tester),
          before = await tester.runAsync(() => snapshot(f));
      final navigator = Navigator.of(
        tester.element(find.byType(ReviewSessionRoute)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('cover')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('review-answer-text'), skipOffstage: false),
        findsNothing,
      );
      expect(find.text('cover'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.tap(launch.button('Exit review'));
      await h.finish(tester);
      stale();
      await tester.pumpAndSettle();
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(await tester.runAsync(() => snapshot(f)), before);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'pending grade and synchronous stop refuse reveal before Flutter rebuild',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final h = launch.Harness(f);
      late GatedSource gated;
      h.factory = (id, direction) async {
        gated = GatedSource(
          await f.learning.forCollection(
            collectionId: id,
            direction: direction,
          ),
        );
        h.gate = gated
            .gate; // Fail-safe body cleanup releases the actual grade gate.
        final session = await DueLearningSession.start(
          source: gated,
          cutoff: instant,
          onPendingWrites: h.drains.add,
        );
        h.sessions.add(session);
        return session;
      };
      await h.mount(tester);
      await start(tester, h);
      final stale = action(tester), session = h.sessions.single;
      late Future<dynamic> pending;
      await tester.runAsync(() async {
        pending = session.submit(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        );
        await gated.entered.future;
      });
      stale();
      await tester.pump();
      expect(answer, findsNothing);
      final stopped = session.stop();
      stale();
      await tester.pump();
      gated.gate.complete();
      await tester.runAsync(() => pending);
      await tester.runAsync(() => stopped);
      await h.finish(tester);
      expect(answer, findsNothing);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language 320px/200% cue stays inside card, subordinate and non-overlapping; answer hierarchy uses canonical styles',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester, scale: 2);
        tester.view.physicalSize = const Size(320, 900);
        await tester.pumpAndSettle();
        await start(tester, h, language: language);
        await tester.ensureVisible(card);
        final cardRect = tester.getRect(card),
            cueRect = tester.getRect(cue),
            wordRect = tester.getRect(
              find.byKey(const ValueKey('review-prompt-text')),
            );
        expect(cardRect.contains(cueRect.topLeft), isTrue);
        expect(cardRect.contains(cueRect.bottomRight), isTrue);
        expect(cueRect.top, greaterThanOrEqualTo(wordRect.bottom));
        expect(
          cardRect.right - cueRect.right,
          closeTo(
            pikoDesign.dimension('components.learningCard.cueRight'),
            0.1,
          ),
        );
        expect(
          cardRect.bottom - cueRect.bottom,
          closeTo(
            pikoDesign.dimension('components.learningCard.cueBottom'),
            0.1,
          ),
        );
        final icon = find.descendant(
          of: target,
          matching: find.byType(PikoIcon),
        );
        expect(tester.getSize(icon), const Size(16, 16));
        final cueText = tester.widget<Text>(cue);
        expect(cueText.style!.fontSize, 12);
        await tester.tap(card);
        await tester.pumpAndSettle();
        final prompt = tester.widget<Text>(
              find.byKey(const ValueKey('review-prompt-text')),
            ),
            translation = tester.widget<Text>(answer);
        expect(prompt.style!.fontSize, 22);
        expect(prompt.style!.color, pikoDesign.color('muted'));
        expect(
          prompt.style!.fontWeight,
          FontWeight.w400,
        );
        expect(translation.style!.fontSize, 37);
        expect(
          translation.style!.fontWeight,
          FontWeight.w600,
        );
        expect(prompt.style!.height, 1.4);
        expect(translation.style!.height, 1.3);
        expect(text(card, tester), ['One', 'Eins']);
        expect(cue, findsNothing);
        expect(tester.getRect(card).right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
