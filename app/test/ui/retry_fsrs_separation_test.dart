import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/retry_answer.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import '../data/regular_reviews_test.dart' show rows;
import '../support/mutable_clock.dart';
import 'review_launch_test.dart' as launch;
import 'review_grading_test.dart' as grading;
import 'review_prompt_test.dart' show card;
import 'review_no_due_test.dart' show snapshot;

void main() {
  for (final reverse in [false, true]) {
    for (final hard in [false, true]) {
      launch.testWidgets(
        '${reverse ? "native→target" : "target→native"} repeated Incorrect reinforcement then ${hard ? "Hard" : "Good"} retains exact first FSRS/history; next due answer is regular',
        (tester) async {
          final f = launch.fixture();
          await tester.runAsync(f.initialize);
          final h = launch.Harness(f), clock = f.db.clock as MutablePikoClock;
          // Same fresh-cutoff source as the runtime, not the launch harness's fixed cutoff.
          h.factory = (id, direction) async {
            final source = await f.learning.forCollection(
              collectionId: id,
              direction: direction,
            );
            final session = await DueLearningSession.start(
              source: source,
              cutoff: clock.now(),
              clock: clock,
              onPendingWrites: h.drains.add,
              presentationActive: false,
            );
            h.sessions.add(session);
            return session;
          };
          await h.mount(tester);
          final copy = PikoCopy('en');
          Future<void> open() async {
            await h.open(tester);
            if (reverse) await h.reverse(tester);
            await tester.tap(launch.button(copy.text('learn.start')));
            await h.finish(tester);
          }

          Future<void> exit() async {
            if (find.byType(ReviewSummaryDialog).evaluate().isNotEmpty) {
              final close = find.descendant(
                of: find.byType(ReviewSummaryDialog),
                matching: find.byTooltip(copy.text('common.close')),
              );
              expect(close.hitTestable(), findsOneWidget);
              await tester.tap(close);
            } else {
              final exit = launch.button(
                copy.text(
                  h.sessions.last.hasInitialWork ? 'learn.exit' : 'common.back',
                ),
              );
              expect(exit.hitTestable(), findsOneWidget);
              await tester.tap(exit);
            }
            await h.finish(tester);
            expect(h.sessions.last.isStopped, isTrue);
          }

          Future<void> wake() async {
            clock.advance(const Duration(seconds: 10));
            await tester.pump(const Duration(seconds: 10));
            await h.finish(tester);
            await h.flush(tester);
          }

          await open();
          final session = h.sessions.single,
              before = session.current!.item,
              reviewedAt = clock.now();
          final official = fsrs.Scheduler(
            desiredRetention: .9,
            learningSteps: const [],
            relearningSteps: const [],
            enableFuzzing: false,
          );
          final expectedFirst = LearningCardCodec.encode(
            official
                .reviewCard(
                  before.card,
                  fsrs.Rating.again,
                  reviewDateTime: reviewedAt,
                )
                .card,
          );
          await grading.reveal(tester);
          await tester.tap(grading.gradeButton(AnswerGrade.incorrect));
          await h.finish(tester);
          final regular = session.acceptedReviews.single;
          expect(regular.prior.cardJson, before.cardJson);
          expect(regular.next.cardJson, expectedFirst);
          expect(regular.next.reviewRevision, before.reviewRevision + 1);
          final cards = await tester.runAsync(
                () => rows(f.db, 'learning_items'),
              ),
              history = await tester.runAsync(
                () => rows(f.db, 'regular_reviews'),
              );
          expect(history, hasLength(1));
          expect(session.current, isNull);
          for (var attempt = 0; attempt < 2; attempt++) {
            await wake();
            expect(session.currentIsRetry, isTrue);
            expect(session.current!.item.cardJson, expectedFirst);
            expect(
              session.current!.item.reviewRevision,
              regular.next.reviewRevision,
            );
            expect(grading.actions, findsNothing);
            await grading.reveal(tester);
            if (attempt == 0) {
              final stored = await tester.runAsync(() => snapshot(f));
              await tester.tap(find.byType(PikoCheckbox));
              await tester.pumpAndSettle();
              expect(session.hard, isTrue);
              expect(await tester.runAsync(() => snapshot(f)), stored);
            }
            await tester.tap(grading.gradeButton(AnswerGrade.incorrect));
            await h.finish(tester);
            final retry = session.lastAnswer! as RetryAnswerReceipt;
            expect(retry.rating, LearningRating.again);
            expect(retry.prior.cardJson, expectedFirst);
            expect(retry.next.cardJson, expectedFirst);
            expect(retry.retryNext!.errorCount, attempt + 2);
            expect(
              retry.retryNext!.dueOrdinal - retry.scopeNext.ordinal,
              attempt == 0 ? 10 : 5,
            );
            expect(retry.retryNext!.expiresAt, regular.retryNext!.expiresAt);
            expect(session.acceptedReviews, [regular]);
            expect(session.current, isNull);
            expect(session.hard, isFalse);
            expect(
              await tester.runAsync(() => rows(f.db, 'learning_items')),
              cards,
            );
            expect(
              await tester.runAsync(() => rows(f.db, 'regular_reviews')),
              history,
            );
            expect(
              await tester.runAsync(() => rows(f.db, 'retry_obligations')),
              hasLength(1),
            );
          }
          await wake();
          await grading.reveal(tester);
          if (hard) {
            await tester.tap(find.byType(PikoCheckbox));
            await tester.pumpAndSettle();
          }
          await tester.tap(grading.gradeButton(AnswerGrade.correct));
          await h.finish(tester);
          final success = session.lastAnswer! as RetryAnswerReceipt;
          expect(
            success.rating,
            hard ? LearningRating.hard : LearningRating.good,
          );
          expect(success.retryNext, isNull);
          expect(success.next.cardJson, expectedFirst);
          expect(session.acceptedReviews, [regular]);
          expect(session.hasPendingRetryWork, isFalse);
          expect(session.current, isNull);
          expect(
            await tester.runAsync(() => rows(f.db, 'learning_items')),
            cards,
          );
          expect(
            await tester.runAsync(() => rows(f.db, 'regular_reviews')),
            history,
          );
          expect(
            await tester.runAsync(() => rows(f.db, 'retry_obligations')),
            isEmpty,
          );
          final ordinal = (await tester.runAsync(
            () => rows(f.db, 'scope_answer_ordinals'),
          ))!.single;
          expect(
            ordinal['ordinal'],
            4,
          ); // One regular + three accepted retries, not a learned statistic.
          expect(
            ordinal['direction'],
            reverse ? 'nativeToTarget' : 'targetToNative',
          );
          expect(
            f.db.allTables.map((table) => table.actualTableName).toSet(),
            {
              'collections',
              'vocabulary_entries',
              'learning_items',
              'regular_reviews',
              'retry_obligations',
              'scope_answer_ordinals',
              'app_settings',
              'learning_identity_sequence',
              'vocabulary_order_sequence',
              'category_dimensions',
              'category_values',
              'vocabulary_category_assignments',
            },
          ); // Only current retry state exists, never an attempt-history table.
          await exit();
          clock.set(
            regular.next.card.due.subtract(const Duration(microseconds: 1)),
          );
          await open();
          expect(h.sessions.last.current, isNull);
          expect(card, findsNothing);
          expect(find.byKey(const ValueKey('review-no-due')), findsOneWidget);
          expect(
            await tester.runAsync(() => rows(f.db, 'regular_reviews')),
            history,
          );
          await exit();
          clock.set(regular.next.card.due);
          await open();
          final nextSession = h.sessions.last,
              nextItem = nextSession.current!.item;
          expect(nextSession.currentIsRetry, isFalse);
          expect(nextItem.id, before.id);
          expect(nextItem.cardJson, expectedFirst);
          final expectedNext = LearningCardCodec.encode(
            official
                .reviewCard(
                  nextItem.card,
                  fsrs.Rating.good,
                  reviewDateTime: clock.now(),
                )
                .card,
          );
          await grading.reveal(tester);
          await tester.tap(grading.gradeButton(AnswerGrade.correct));
          await h.finish(tester);
          final nextRegular = nextSession.lastAnswer! as RegularReviewReceipt;
          expect(nextRegular.next.cardJson, expectedNext);
          expect(
            nextRegular.next.reviewRevision,
            regular.next.reviewRevision + 1,
          );
          final events = (await tester.runAsync(
            () => f.learning.reviewsForItem(before.id),
          ))!;
          expect(events, hasLength(2));
          expect(events.first.id, regular.event.id);
          expect(events.last.id, nextRegular.event.id);
          expect(events.last.rating, LearningRating.good);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
