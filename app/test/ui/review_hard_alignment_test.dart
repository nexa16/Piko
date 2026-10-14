import 'dart:async';
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:piko/ui/piko_theme.dart';
import '../data/regular_reviews_test.dart' show instant, rows;
import '../features/due_learning_session_test.dart' show GatedSource;
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show card, text, ObservedVocabulary;
import 'review_grading_test.dart' as grading;

final hard = find.byKey(const ValueKey('review-hard'));
final checkbox = find.descendant(of: hard, matching: find.byType(PikoCheckbox));
ValueChanged<bool> change(WidgetTester tester) =>
    tester.widget<PikoCheckbox>(checkbox).onChanged!;

void main() {
  for (final reverse in [false, true]) {
    for (final selected in [false, true]) {
      for (final grade in AnswerGrade.values) {
        launch.testWidgets(
          '${reverse ? "native" : "target"} optional Hard=$selected + ${grade.name} records exact real rating; toggle never grades and next resets',
          (tester) async {
            final h = await grading.open(tester, reverse: reverse);
            expect(hard, findsNothing);
            final before = await tester.runAsync(() => snapshot(h.f));
            await grading.reveal(tester);
            expect(tester.widget<PikoCheckbox>(checkbox).value, isFalse);
            final oldChange = change(tester);
            await tester.tap(find.text(PikoCopy('en').text('learn.hard')));
            await tester.pumpAndSettle();
            expect(h.sessions.single.hard, isTrue);
            if (!selected) {
              await tester.tap(find.text(PikoCopy('en').text('learn.hard')));
              await tester.pumpAndSettle();
            }
            expect(h.sessions.single.hard, selected);
            expect(await tester.runAsync(() => snapshot(h.f)), before);
            await tester.tap(grading.gradeButton(grade));
            await h.finish(tester);
            final rating = grade == AnswerGrade.incorrect
                ? LearningRating.again
                : selected
                ? LearningRating.hard
                : LearningRating.good;
            final receipt = h.sessions.single.acceptedReviews.single;
            expect(receipt.event.rating, rating);
            expect(receipt.event.reviewedAt, instant);
            expect(
              (await tester.runAsync(
                () => h.f.learning.forEntry(h.f.entry.id),
              ))!.singleWhere((item) => item.id == receipt.next.id).cardJson,
              receipt.next.cardJson,
            );
            expect(
              await tester.runAsync(() => rows(h.f.db, 'regular_reviews')),
              hasLength(1),
            );
            expect(h.sessions.single.hard, isFalse);
            expect(hard, findsNothing);
            await grading.reveal(tester);
            oldChange(true);
            await tester.pumpAndSettle();
            expect(tester.widget<PikoCheckbox>(checkbox).value, isFalse);
            expect(h.sessions.single.acceptedReviews, hasLength(1));
          },
        );
      }
    }
  }

  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language 320px/200% full-label Hard target aligns exactly above Correct and has one keyboard checkbox action',
      (tester) async {
        final h = await grading.open(tester, language: language, scale: 2);
        tester.view.physicalSize = const Size(320, 900);
        await tester.pumpAndSettle();
        expect(hard, findsNothing);
        await grading.reveal(tester);
        await tester.ensureVisible(checkbox);
        await tester.pumpAndSettle();
        final before = await tester.runAsync(() => snapshot(h.f));
        final correct = tester.getRect(
          grading.gradeButton(AnswerGrade.correct),
        );
        final incorrect = tester.getRect(
          grading.gradeButton(AnswerGrade.incorrect),
        );
        final target = tester.getRect(checkbox);
        expect(target.left, correct.left);
        expect(target.right, correct.right);
        expect(target.width, correct.width);
        expect(
          correct.top - target.bottom,
          pikoDesign.dimension('components.reviewGrading.gap'),
        );
        expect(incorrect.width, correct.width);
        expect(incorrect.top, correct.top);
        expect(incorrect.bottom, correct.bottom);
        expect(incorrect.height, correct.height);
        expect(target.height, greaterThanOrEqualTo(44));
        expect(target.left, greaterThanOrEqualTo(0));
        expect(target.right, lessThanOrEqualTo(320));
        final label = PikoCopy(language).text('learn.hard');
        final semantics = tester.ensureSemantics();
        try {
          expect(
            tester.getSemantics(checkbox),
            matchesSemantics(
              label: label,
              hasCheckedState: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
            ),
          );
          expect(find.bySemanticsLabel(label), findsOneWidget);
          final visual = Rect.fromPoints(
            tester.getTopLeft(find.byType(Checkbox)),
            tester.getBottomRight(find.byType(Checkbox)),
          );
          expect(visual.size, const Size(24, 24));
          for (
            var index = 0;
            index < 5 &&
                tester.getSemantics(checkbox).flagsCollection.isFocused !=
                    Tristate.isTrue;
            index++
          ) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          }
          expect(
            tester.getSemantics(checkbox).flagsCollection.isFocused,
            Tristate.isTrue,
          );
          expect(tester.getRect(checkbox), target);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(h.sessions.single.hard, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(h.sessions.single.hard, isFalse);
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(h.sessions.single.hard, isTrue);
          expect(await tester.runAsync(() => snapshot(h.f)), before);
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  launch.testWidgets(
    'pending admitted grade disables Hard and refuses cached toggle before rebuild; accepted card resets',
    (tester) async {
      late GatedSource gated;
      final h = await grading.open(
        tester,
        configure: (h) {
          h.factory = (id, direction) async {
            gated = GatedSource(
              await h.f.learning.forCollection(
                collectionId: id,
                direction: direction,
              ),
            );
            h.gate = gated.gate;
            final session = await DueLearningSession.start(
              source: gated,
              cutoff: instant,
              clock: h.f.db.clock,
              onPendingWrites: h.drains.add,
            );
            h.sessions.add(session);
            return session;
          };
        },
      );
      await grading.reveal(tester);
      final retained = change(tester);
      retained(true);
      await tester.pumpAndSettle();
      final before = await tester.runAsync(() => snapshot(h.f));
      final grade = grading.callback(tester, AnswerGrade.correct);
      await tester.runAsync(() async {
        grade();
        await gated.entered.future;
      });
      retained(false);
      expect(h.sessions.single.hard, isTrue);
      await tester.pump();
      expect(h.sessions.single.isSubmitting, isTrue);
      expect(tester.widget<PikoCheckbox>(checkbox).onChanged, isNull);
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      gated.gate.complete();
      await h.finish(tester);
      expect(
        h.sessions.single.acceptedReviews.single.event.rating,
        LearningRating.hard,
      );
      expect(h.sessions.single.hard, isFalse);
      expect(hard, findsNothing);
    },
  );

  launch.testWidgets(
    'failed grade retains actual Hard checkbox selection and revealed answer for explicit retry',
    (tester) async {
      final h = await grading.open(tester);
      await grading.reveal(tester);
      await tester.tap(find.text(PikoCopy('en').text('learn.hard')));
      await tester.pumpAndSettle();
      final before = await tester.runAsync(() => snapshot(h.f));
      await tester.runAsync(
        () => h.f.db.customStatement(
          "CREATE TRIGGER hard_ui_fail AFTER INSERT ON regular_reviews BEGIN SELECT RAISE(FAIL, 'hard grade failed'); END",
        ),
      );
      await tester.tap(grading.gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(tester.widget<PikoCheckbox>(checkbox).value, isTrue);
      expect(tester.widget<PikoCheckbox>(checkbox).onChanged, isNotNull);
      expect(text(card, tester), ['One', 'Eins']);
      expect(
        find.text(PikoCopy('en').text('learn.gradeFailed')),
        findsOneWidget,
      );
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      await tester.runAsync(
        () => h.f.db.customStatement('DROP TRIGGER hard_ui_fail'),
      );
      await tester.tap(grading.gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(
        h.sessions.single.acceptedReviews.single.event.rating,
        LearningRating.hard,
      );
      expect(h.sessions.single.hard, isFalse);
    },
  );

  launch.testWidgets(
    'read failure/retry and changed stored text retire cached Hard toggles without grade or false selection',
    (tester) async {
      final stream = StreamController<VocabularyRecord?>.broadcast(sync: true);
      addTearDown(stream.close);
      final h = await grading.open(
        tester,
        configure: (h) {
          final observed = ObservedVocabulary(h.f.vocabulary);
          observed.supplied[h.f.entry.id] = stream.stream;
          h.gatedVocabulary = observed;
        },
      );
      stream.add(h.f.entry);
      await tester.pumpAndSettle();
      await grading.reveal(tester);
      final old = change(tester),
          before = await tester.runAsync(() => snapshot(h.f));
      stream.addError(StateError('read'));
      await tester.pumpAndSettle();
      expect(hard, findsNothing);
      old(true);
      expect(h.sessions.single.hard, isFalse);
      await tester.tap(launch.button(PikoCopy('en').text('action.retry')));
      await tester.pump();
      stream.add(h.f.entry);
      await tester.pumpAndSettle();
      old(true);
      expect(h.sessions.single.hard, isFalse);
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      final oldText = change(tester);
      final changed = await tester.runAsync(
        () => h.f.vocabulary.update(
          id: h.f.entry.id,
          targetText: 'Changed',
          nativeText: 'Geändert',
        ),
      );
      stream.add(changed);
      await tester.pumpAndSettle();
      oldText(true);
      expect(h.sessions.single.hard, isFalse);
      expect(
        await tester.runAsync(() => rows(h.f.db, 'regular_reviews')),
        isEmpty,
      );
      change(tester)(true);
      await tester.pumpAndSettle();
      expect(h.sessions.single.hard, isTrue);
    },
  );

  launch.testWidgets(
    'same-route repository replacement hides Hard and refuses old owner even after new reveal',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final h = launch.Harness(f);
      await h.mount(tester);
      final session = (await tester.runAsync(
        () => h.create(f.owner.id, LearningDirection.targetToNative),
      ))!;
      final holder = ValueNotifier<VocabularyRepository>(f.vocabulary);
      addTearDown(holder.dispose);
      final navigator = Navigator.of(
        tester.element(find.byType(CollectionDetail)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => ValueListenableBuilder<VocabularyRepository>(
              valueListenable: holder,
              builder: (_, repository, _) => ReviewSessionRoute(
                collection: f.owner,
                session: session,
                vocabularyRepository: repository,
              ),
            ),
          ),
        ),
      );
      await h.flush(tester);
      await grading.reveal(tester);
      final old = change(tester),
          before = await tester.runAsync(() => snapshot(f));
      final replacement = ObservedVocabulary(f.vocabulary)..fail = true;
      holder.value = replacement;
      await tester.pumpAndSettle();
      expect(hard, findsNothing);
      old(true);
      expect(session.hard, isFalse);
      replacement.fail = false;
      await tester.tap(launch.button(PikoCopy('en').text('action.retry')));
      await h.flush(tester);
      expect(hard, findsNothing);
      await grading.reveal(tester);
      old(true);
      expect(session.hard, isFalse);
      expect(await tester.runAsync(() => snapshot(f)), before);
      change(tester)(true);
      await tester.pumpAndSettle();
      expect(session.hard, isTrue);
    },
  );

  launch.testWidgets(
    'covered, synchronously stopped and disposed Hard callbacks are inert',
    (tester) async {
      final h = await grading.open(tester);
      await grading.reveal(tester);
      final old = change(tester),
          before = await tester.runAsync(() => snapshot(h.f));
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
      old(true);
      expect(h.sessions.single.hard, isFalse);
      navigator.pop();
      await tester.pumpAndSettle();
      final stopped = h.sessions.single.stop();
      old(true);
      expect(h.sessions.single.hard, isFalse);
      await stopped;
      await tester.pumpAndSettle();
      await tester.tap(launch.button('Exit review'));
      await h.finish(tester);
      old(true);
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      expect(tester.takeException(), isNull);
    },
  );
}
