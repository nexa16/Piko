import 'package:flutter/material.dart';
import 'package:piko/data/retry_answer.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:flutter_test/flutter_test.dart';
import '../data/regular_reviews_test.dart' show instant, rows;
import '../features/retry_learning_session_test.dart'
    show ControlledRetrySource;
import '../support/mutable_clock.dart';
import 'review_launch_test.dart' as launch;
import 'review_grading_test.dart' as grading;
import 'review_prompt_test.dart' show start, card, text;

void main() {
  launch.testWidgets(
    'real route grades 20 subsequent questions then prioritizes retry; selected Hard success changes no FSRS/history',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      for (var index = 0; index < 21; index++) {
        await tester.runAsync(
          () => f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'Other $index',
            nativeText: 'Anders $index',
          ),
        );
      }
      final h = launch.Harness(f);
      await h.mount(tester);
      await start(tester, h);
      final session = h.sessions.single, first = session.current!.item;
      await grading.reveal(tester);
      await tester.tap(grading.gradeButton(AnswerGrade.incorrect));
      await h.finish(tester);
      final target = (await tester.runAsync(
        () => f.learning.forEntry(f.entry.id),
      ))!.singleWhere((item) => item.id == first.id);
      for (var index = 0; index < 20; index++) {
        expect(session.currentIsRetry, isFalse);
        expect(session.current!.item.id, isNot(first.id));
        expect(grading.actions, findsNothing);
        await grading.reveal(tester);
        await tester.tap(grading.gradeButton(AnswerGrade.correct));
        await h.finish(tester);
        if (index < 19) expect(session.currentIsRetry, isFalse);
      }
      expect(session.currentIsRetry, isTrue);
      expect(session.current!.item.id, first.id);
      expect(session.unreviewedMembers, hasLength(1));
      expect(grading.actions, findsNothing);
      final retired = session.current!;
      await grading.reveal(tester);
      expect(text(card, tester), ['One', 'Eins']);
      expect(find.byType(PikoCheckbox), findsNothing);
      await tester.pumpAndSettle();
      expect(session.hard, isFalse);
      await tester.tap(grading.gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(session.lastAnswer, isA<RetryAnswerReceipt>());
      expect(
        (session.lastAnswer! as RetryAnswerReceipt).rating,
        LearningRating.good,
      );
      expect(session.acceptedReviews, hasLength(21));
      expect(session.currentIsRetry, isFalse);
      expect(session.current!.item.id, isNot(first.id));
      expect(session.hard, isFalse);
      expect(grading.actions, findsNothing);
      expect(
        (await tester.runAsync(
          () => f.learning.forEntry(f.entry.id),
        ))!.singleWhere((item) => item.id == first.id).cardJson,
        target.cardJson,
      );
      expect(
        await tester.runAsync(() => f.learning.reviewsForItem(first.id)),
        hasLength(1),
      );
      expect(
        await tester.runAsync(() => rows(f.db, 'retry_obligations')),
        isEmpty,
      );
      final counter = (await tester.runAsync(
        () => rows(f.db, 'scope_answer_ordinals'),
      ))!.single;
      expect(counter['ordinal'], 22);
      expect(
        await session.submitAnswer(
          retired,
          AnswerGrade.correct,
          reviewedAt: instant,
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  launch.testWidgets(
    'route read recovery after committed Good works with no pending rounds and never repeats answer/count',
    (tester) async {
      late ControlledRetrySource source;
      final h = await grading.open(
        tester,
        configure: (h) {
          h.factory = (id, direction) async {
            source = ControlledRetrySource(
              await h.f.learning.forCollection(
                collectionId: id,
                direction: direction,
              ),
            );
            final session = await DueLearningSession.start(
              source: source,
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
      final stale = grading.callback(tester, AnswerGrade.correct);
      source.failRefresh = true;
      stale();
      await h.finish(tester);
      final copy = const PikoCopy('en');
      expect(h.sessions.single.hasPendingRetryWork, isFalse);
      expect(find.text(copy.text('learn.retryLoadFailed')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
      final counter = await tester.runAsync(
        () => rows(h.f.db, 'scope_answer_ordinals'),
      );
      final history = await tester.runAsync(
        () => rows(h.f.db, 'regular_reviews'),
      );
      source.failRefresh = false;
      await tester.tap(launch.button(copy.text('action.retry')));
      await h.finish(tester);
      await h.flush(tester);
      expect(text(card, tester), ['Next']);
      expect(h.sessions.single.acceptedReviews, hasLength(1));
      stale();
      await h.finish(tester);
      expect(
        await tester.runAsync(() => rows(h.f.db, 'scope_answer_ordinals')),
        counter,
      );
      expect(
        await tester.runAsync(() => rows(h.f.db, 'regular_reviews')),
        history,
      );
      expect(tester.takeException(), isNull);
    },
  );
  launch.testWidgets(
    'actual displayed retry expiry removes unanswered card without false success/no-due or count; summary dismissal returns safely',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final round = (await tester.runAsync(
        () => f.review(rating: LearningRating.again),
      ))!.retryNext!;
      await tester.runAsync(
        () => f.makeRetryEligible(round),
      ); // Explicit eligibility fixture; earned gap tested above.
      final h = launch.Harness(f);
      await h.mount(tester);
      await start(tester, h);
      final session = h.sessions.single;
      expect(session.currentIsRetry, isTrue);
      final counter = await tester.runAsync(
        () => rows(f.db, 'scope_answer_ordinals'),
      );
      final cards = await tester.runAsync(() => rows(f.db, 'learning_items'));
      final history = await tester.runAsync(
        () => rows(f.db, 'regular_reviews'),
      );
      await grading.reveal(tester);
      (f.db.clock as MutablePikoClock).set(round.expiresAt);
      await tester.tap(grading.gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(session.current, isNull);
      expect(session.acceptedReviews, isEmpty);
      expect(session.lastAnswer, isNull);
      expect(card, findsNothing);
      expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
      expect(
        await tester.runAsync(() => rows(f.db, 'retry_obligations')),
        isEmpty,
      );
      expect(
        await tester.runAsync(() => rows(f.db, 'scope_answer_ordinals')),
        counter,
      );
      expect(await tester.runAsync(() => rows(f.db, 'learning_items')), cards);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        history,
      );
      expect(find.byType(ReviewSummaryDialog), findsOneWidget);
      expect(session.progress.completed, 0);
      expect(session.progress.firstTryCorrect, 0);
      final close = find.descendant(
        of: find.byType(ReviewSummaryDialog),
        matching: find.byTooltip(const PikoCopy('en').text('common.close')),
      );
      expect(close.hitTestable(), findsOneWidget);
      await tester.tap(close);
      await h.finish(tester);
      expect(session.isStopped, isTrue);
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(await tester.runAsync(() => rows(f.db, 'learning_items')), cards);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        history,
      );
      expect(
        await tester.runAsync(() => rows(f.db, 'scope_answer_ordinals')),
        counter,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
