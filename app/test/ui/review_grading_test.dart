import 'dart:async';
import 'dart:ui' show Tristate;
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/core/clock.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;
import '../features/due_learning_session_test.dart' show GatedSource;
import '../support/mutable_clock.dart';
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show start, card, text, ObservedVocabulary;

Finder gradeButton(AnswerGrade grade) =>
    find.byKey(ValueKey('review-grade-${grade.name}'));
final actions = find.byKey(const ValueKey('review-grading'));
VoidCallback callback(WidgetTester tester, AnswerGrade grade) =>
    tester.widget<PikoButton>(gradeButton(grade)).onPressed!;

class TestClock implements PikoClock {
  TestClock(this.time);
  DateTime time;
  bool fails = false;
  int calls = 0;
  @override
  DateTime now() {
    calls++;
    if (fails) throw StateError('clock unavailable');
    return time;
  }
}

class OwnedDatabase extends PikoDatabase {
  OwnedDatabase(PikoClock clock)
    : super(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
        clock: clock,
      );
  final closed = Completer<void>();
  @override
  Future<void> close() async {
    await super.close();
    if (!closed.isCompleted) closed.complete();
  }
}

Future<launch.Harness> open(
  WidgetTester tester, {
  bool reverse = false,
  String language = 'en',
  double scale = 1,
  void Function(launch.Harness)? configure,
}) async {
  final f = launch.fixture();
  await tester.runAsync(f.initialize);
  await tester.runAsync(
    () => f.vocabulary.create(
      collectionId: f.owner.id,
      targetText: 'Next',
      nativeText: 'Weiter',
    ),
  );
  final h = launch.Harness(f)..locale.value = Locale(language);
  configure?.call(h);
  await h.mount(tester, scale: scale);
  await start(tester, h, reverse: reverse, language: language);
  return h;
}

void withClock(launch.Harness h, PikoClock clock) {
  h.factory = (id, direction) async {
    final session = await DueLearningSession.start(
      source: await h.f.learning.forCollection(
        collectionId: id,
        direction: direction,
      ),
      cutoff: instant,
      clock: clock,
      onPendingWrites: h.drains.add,
    );
    h.sessions.add(session);
    return session;
  };
}

Future<void> reveal(WidgetTester tester) async {
  expect(actions, findsNothing);
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
  expect(actions, findsOneWidget);
}

void main() {
  for (final reverse in [false, true]) {
    for (final grade in AnswerGrade.values) {
      launch.testWidgets(
        '${reverse ? "native" : "target"} ${grade.name} actual grade uses fresh UTC and exact SQLite event/card; ${grade == AnswerGrade.correct ? "keyboard" : "tap"} advances to hidden next card',
        (tester) async {
          final h = await open(tester, reverse: reverse), f = h.f;
          final before = await tester.runAsync(() => snapshot(f));
          final beforeItems = await tester.runAsync(
            () => rows(f.db, 'learning_items'),
          );
          expect(actions, findsNothing);
          final prior = h.sessions.single.current!.item;
          await reveal(tester);
          expect(await tester.runAsync(() => snapshot(f)), before);
          final at = instant.add(const Duration(minutes: 7, microseconds: 21));
          (f.db.clock as MutablePikoClock).set(at);
          final semantics = tester.ensureSemantics();
          try {
            final node = tester.getSemantics(gradeButton(grade));
            expect(node.flagsCollection.isButton, isTrue);
            expect(node.label, PikoCopy('en').text('action.${grade.name}'));
            if (grade == AnswerGrade.correct) {
              for (
                var index = 0;
                index < 5 &&
                    tester
                            .getSemantics(gradeButton(grade))
                            .flagsCollection
                            .isFocused !=
                        Tristate.isTrue;
                index++
              ) {
                await tester.sendKeyEvent(LogicalKeyboardKey.tab);
                await tester.pump();
              }
              expect(
                tester
                    .getSemantics(gradeButton(grade))
                    .flagsCollection
                    .isFocused,
                Tristate.isTrue,
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            } else {
              await tester.tap(gradeButton(grade));
            }
            await h.finish(tester);
            final rating = grade == AnswerGrade.incorrect
                ? LearningRating.again
                : LearningRating.good;
            final receipt = h.sessions.single.acceptedReviews.single;
            expect(receipt.event.rating, rating);
            expect(receipt.event.reviewedAt, at);
            expect(receipt.event.reviewedAt.isUtc, isTrue);
            expect(receipt.event.itemId, prior.id);
            expect(receipt.prior.cardJson, prior.cardJson);
            expect(
              receipt.next.cardJson,
              LearningScheduler()
                  .review(prior, rating: rating, reviewedAt: at)
                  .next
                  .cardJson,
            );
            final stored = await tester.runAsync(
              () => f.learning.forEntry(f.entry.id),
            );
            final changed = stored!.singleWhere((item) => item.id == prior.id);
            expect(changed.cardJson, receipt.next.cardJson);
            expect(changed.reviewRevision, prior.reviewRevision + 1);
            final afterItems = await tester.runAsync(
              () => rows(f.db, 'learning_items'),
            );
            expect(
              afterItems!.where((row) => row['id'] != prior.id).toList(),
              beforeItems!.where((row) => row['id'] != prior.id).toList(),
            );
            expect(
              await tester.runAsync(() => rows(f.db, 'regular_reviews')),
              hasLength(1),
            );
            expect(text(card, tester), [reverse ? 'Weiter' : 'Next']);
            expect(actions, findsNothing);
          } finally {
            semantics.dispose();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  launch.testWidgets(
    'pending equal actions are disabled; duplicate callback and Exit drain one actual accepted review without grading remainder',
    (tester) async {
      late GatedSource gated;
      final h = await open(
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
      await reveal(tester);
      final before = await tester.runAsync(() => snapshot(h.f));
      final retained = callback(tester, AnswerGrade.correct);
      await tester.runAsync(() async {
        retained();
        retained();
        await gated.entered.future;
      });
      await tester.pump();
      expect(h.sessions.single.isSubmitting, isTrue);
      expect(actions, findsOneWidget);
      for (final grade in AnswerGrade.values) {
        expect(tester.widget<PikoButton>(gradeButton(grade)).onPressed, isNull);
      }
      expect(
        find.text(PikoCopy('en').text('learn.gradeSaving')),
        findsOneWidget,
      );
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      await tester.tap(launch.button('Exit review'));
      await tester.pump();
      expect(find.byType(ReviewSessionRoute), findsOneWidget);
      retained();
      gated.gate.complete();
      await h.finish(tester);
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(h.sessions.single.acceptedReviews, hasLength(1));
      expect(h.sessions.single.unreviewedMembers, hasLength(1));
      expect(
        await tester.runAsync(() => rows(h.f.db, 'regular_reviews')),
        hasLength(1),
      );
      final untouched = h.sessions.single.unreviewedMembers.single;
      expect(
        (await tester.runAsync(
          () => h.f.learning.forEntry(untouched.entryId),
        ))!.singleWhere((item) => item.id == untouched.id).cardJson,
        untouched.cardJson,
      );
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'SQLite failure preserves revealed answer and Hard; choosing grade again retries exact transaction',
    (tester) async {
      final h = await open(tester), f = h.f, session = h.sessions.single;
      await reveal(tester);
      session.setHard(session.current!, true);
      await tester.pump();
      final before = await tester.runAsync(() => snapshot(f));
      await tester.runAsync(
        () => f.db.customStatement(
          "CREATE TRIGGER ui_grade_fail AFTER UPDATE ON learning_items BEGIN SELECT RAISE(FAIL, 'grade failed'); END",
        ),
      );
      await tester.tap(gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(session.error, isNotNull);
      expect(session.hard, isTrue);
      expect(text(card, tester), ['One', 'Eins']);
      expect(
        find.text(PikoCopy('en').text('learn.gradeFailed')),
        findsOneWidget,
      );
      expect(
        tester.widget<PikoButton>(gradeButton(AnswerGrade.correct)).onPressed,
        isNotNull,
      );
      expect(await tester.runAsync(() => snapshot(f)), before);
      await tester.runAsync(
        () => f.db.customStatement('DROP TRIGGER ui_grade_fail'),
      );
      await tester.tap(gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(session.acceptedReviews.single.event.rating, LearningRating.hard);
      expect(session.hard, isFalse);
      expect(text(card, tester), ['Next']);
      expect(actions, findsNothing);
    },
  );

  launch.testWidgets(
    'throwing runtime clock shows scoped failure; retry normalizes fresh local instant and stale callback never consults clock',
    (tester) async {
      final clock = TestClock(instant)..fails = true;
      final h = await open(tester, configure: (h) => withClock(h, clock));
      await reveal(tester);
      final originalHandle = h.sessions.single.current!;
      final retained = callback(tester, AnswerGrade.correct);
      final before = await tester.runAsync(() => snapshot(h.f));
      await tester.tap(gradeButton(AnswerGrade.correct));
      await tester.pumpAndSettle();
      expect(clock.calls, 1);
      expect(h.sessions.single.isSubmitting, isFalse);
      expect(text(card, tester), ['One', 'Eins']);
      expect(
        find.text(PikoCopy('en').text('learn.gradeFailed')),
        findsOneWidget,
      );
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      clock.fails = false;
      clock.time = instant.add(const Duration(hours: 2)).toLocal();
      await tester.tap(gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(
        h.sessions.single.acceptedReviews.single.event.reviewedAt,
        clock.time.toUtc(),
      );
      expect(
        h.sessions.single.acceptedReviews.single.event.reviewedAt.isUtc,
        isTrue,
      );
      final calls = clock.calls;
      retained();
      await tester.pump();
      expect(clock.calls, calls);
      expect(
        await h.sessions.single.submitNow(originalHandle, AnswerGrade.correct),
        isNull,
      );
      final next = h.sessions.single.current!;
      await h.sessions.single.stop();
      expect(
        await h.sessions.single.submitNow(next, AnswerGrade.correct),
        isNull,
      );
      expect(clock.calls, calls);
      expect(
        await tester.runAsync(() => rows(h.f.db, 'regular_reviews')),
        hasLength(1),
      );
    },
  );

  launch.testWidgets(
    'read error removes grade actions; old exact-text callback cannot grade after recovery or live vocabulary replacement',
    (tester) async {
      final stream = StreamController<VocabularyRecord?>.broadcast(sync: true);
      addTearDown(stream.close);
      late ObservedVocabulary observed;
      final h = await open(
        tester,
        configure: (h) {
          observed = ObservedVocabulary(h.f.vocabulary);
          observed.supplied[h.f.entry.id] = stream.stream;
          h.gatedVocabulary = observed;
        },
      );
      stream.add(h.f.entry);
      await tester.pumpAndSettle();
      await reveal(tester);
      final before = await tester.runAsync(() => snapshot(h.f));
      final old = callback(tester, AnswerGrade.correct);
      stream.addError(StateError('read failed'));
      await tester.pumpAndSettle();
      expect(actions, findsNothing);
      old();
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      await tester.tap(launch.button(PikoCopy('en').text('action.retry')));
      await tester.pump();
      stream.add(h.f.entry);
      await tester.pumpAndSettle();
      expect(actions, findsOneWidget);
      old(); // Retry created a new owned read revision.
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      final sameHandleOld = callback(tester, AnswerGrade.correct);
      final changed = await tester.runAsync(
        () => h.f.vocabulary.update(
          id: h.f.entry.id,
          targetText: 'Changed',
          nativeText: 'Geändert',
        ),
      );
      stream.add(changed);
      await tester.pumpAndSettle();
      sameHandleOld();
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => rows(h.f.db, 'regular_reviews')),
        isEmpty,
      );
      expect(text(card, tester), ['Changed', 'Geändert']);
      await tester.tap(gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(h.sessions.single.acceptedReviews, hasLength(1));
    },
  );

  launch.testWidgets(
    'cached grade rejects accepted advance before route rebuild and cannot grade next hidden member',
    (tester) async {
      final h = await open(tester);
      await reveal(tester);
      final retained = callback(tester, AnswerGrade.incorrect);
      final session = h.sessions.single;
      await tester.runAsync(
        () => session.submit(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        ),
      );
      retained();
      await h.finish(tester);
      expect(session.acceptedReviews, hasLength(1));
      expect(session.acceptedReviews.single.event.rating, LearningRating.good);
      expect(text(card, tester), ['Next']);
      expect(actions, findsNothing);
      expect(
        await tester.runAsync(() => rows(h.f.db, 'regular_reviews')),
        hasLength(1),
      );
    },
  );

  launch.testWidgets(
    'covered and disposed grade callbacks leave exact storage unchanged',
    (tester) async {
      final h = await open(tester);
      await reveal(tester);
      final retained = callback(tester, AnswerGrade.incorrect);
      final before = await tester.runAsync(() => snapshot(h.f));
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
      retained();
      await tester.pumpAndSettle();
      expect(find.text('cover'), findsOneWidget);
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.tap(launch.button('Exit review'));
      await h.finish(tester);
      retained();
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => snapshot(h.f)), before);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'same route text-owner replacement hides answer/actions and rejects cached original grade',
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
      await reveal(tester);
      final retained = callback(tester, AnswerGrade.correct);
      final before = await tester.runAsync(() => snapshot(f));
      final replacement = ObservedVocabulary(f.vocabulary)..fail = true;
      holder.value = replacement;
      await tester.pumpAndSettle();
      expect(actions, findsNothing);
      expect(card, findsNothing);
      retained();
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => snapshot(f)), before);
      replacement.fail = false;
      await tester.tap(launch.button(PikoCopy('en').text('action.retry')));
      await h.flush(tester);
      expect(actions, findsNothing);
      expect(text(card, tester), ['One']);
      await reveal(tester);
      retained();
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => snapshot(f)), before);
      await tester.tap(gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      expect(session.acceptedReviews, hasLength(1));
    },
  );

  launch.testWidgets(
    'actual PikoRuntime factory supplies database clock for fresh UI grade and owns close',
    (tester) async {
      final clock = MutablePikoClock(instant),
          db = OwnedDatabase(MutablePikoClock(instant));
      // Use precisely the runtime-owned database's clock, not the fixture helper.
      final f = Fixture(database: db);
      await tester.runAsync(f.initialize);
      try {
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        await tester.runAsync(() => db.customSelect('SELECT 1').get());
        await tester.pumpAndSettle();
        final home = tester.widget<CollectionsHome>(
          find.byType(CollectionsHome),
        );
        final navigator = Navigator.of(
          tester.element(find.byType(CollectionsHome)),
        );
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => CollectionDetail(
                repository: f.collections,
                collectionId: f.owner.id,
                vocabularyRepository: f.vocabulary,
                reviewSessionFactory: home.reviewSessionFactory,
                onPendingVocabularyWrites: home.onPendingVocabularyWrites,
              ),
            ),
          ),
        );
        Future<void> flush() async {
          await tester.runAsync(() => db.customSelect('SELECT 1').get());
          await tester.pumpAndSettle();
        }

        await flush();
        await tester.tap(launch.button('Review'));
        await tester.pumpAndSettle();
        await tester.tap(launch.button('Start review'));
        await tester.pump();
        for (var index = 0; index < 8 && card.evaluate().isEmpty; index++) {
          await flush();
        }
        expect(card, findsOneWidget);
        final session = tester
            .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
            .session;
        await reveal(tester);
        clock.advance(const Duration(minutes: 13));
        (db.clock as MutablePikoClock).set(clock.now());
        await tester.ensureVisible(gradeButton(AnswerGrade.correct));
        await tester.tap(gradeButton(AnswerGrade.correct));
        var drained = false;
        unawaited(session.awaitPending().then((_) => drained = true));
        while (!drained) {
          await flush();
        }
        expect(session.acceptedReviews.single.event.reviewedAt, clock.now());
        expect(
          (await tester.runAsync(
            () => f.learning.reviewsForItem(session.members.single.id),
          ))!.single.reviewedAt,
          clock.now(),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(() => db.closed.future);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language 392px/200% revealed grading has equal red-left green-right targets and localized semantics',
      (tester) async {
        final h = await open(tester, language: language, scale: 2);
        await reveal(tester);
        final left = tester.getRect(gradeButton(AnswerGrade.incorrect));
        final right = tester.getRect(gradeButton(AnswerGrade.correct));
        expect(left.width, closeTo(right.width, 0.01));
        expect(left.left, lessThan(right.left));
        expect(
          right.left - left.right,
          pikoDesign.dimension('components.reviewGrading.gap'),
        );
        expect(left.height, greaterThanOrEqualTo(48));
        expect(right.height, greaterThanOrEqualTo(48));
        expect(left.left, greaterThanOrEqualTo(0));
        expect(right.right, lessThanOrEqualTo(392));
        final semantics = tester.ensureSemantics();
        try {
          for (final grade in AnswerGrade.values) {
            final node = tester.getSemantics(gradeButton(grade));
            expect(node.label, PikoCopy(language).text('action.${grade.name}'));
            expect(node.flagsCollection.isButton, isTrue);
            final materialButton = tester.widget<TextButton>(
              find.descendant(
                of: gradeButton(grade),
                matching: find.byType(TextButton),
              ),
            );
            expect(
              materialButton.style!.backgroundColor!.resolve({}),
              pikoDesign.color(
                grade == AnswerGrade.incorrect ? 'danger' : 'success',
              ),
            );
            expect(
              materialButton.style!.textStyle!.resolve({})!.fontSize,
              pikoDesign.dimension('typography.label'),
            );
          }
          expect(find.byType(Checkbox), findsOneWidget);
          expect(
            find.text(PikoCopy(language).text('learn.hard')),
            findsOneWidget,
          );
          await tester.ensureVisible(gradeButton(AnswerGrade.incorrect));
          await tester.tap(gradeButton(AnswerGrade.incorrect));
          await h.finish(tester);
          expect(
            h.sessions.single.acceptedReviews.single.event.rating,
            LearningRating.again,
          );
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  launch.testWidgets(
    'previous-review action is distinct from Exit and disappears as soon as the current answer is revealed',
    (tester) async {
      final h = await open(tester);
      await reveal(tester);
      await tester.tap(gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      final previous = find.byKey(const ValueKey('review-correct-previous'));
      expect(previous, findsOneWidget);
      expect(
        launch.button(PikoCopy('en').text('learn.exit')),
        findsOneWidget,
      );
      final stale = tester.widget<PikoButton>(previous).onPressed!;
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(previous, findsNothing);
      stale();
      await tester.pump();
      expect(h.sessions.single.isCorrecting, isFalse);
      expect(actions, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'previous-review presentation shows prior answer and grade, then replacement returns to the unanswered card',
    (tester) async {
      final h = await open(tester), session = h.sessions.single;
      await reveal(tester);
      await tester.tap(gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      final accepted = session.acceptedReviews.single;
      final unanswered = session.current!;
      await tester.tap(find.byKey(const ValueKey('review-correct-previous')));
      await tester.pumpAndSettle();
      expect(session.isCorrecting, isTrue);
      expect(session.current!.item.id, accepted.prior.id);
      expect(find.byKey(const ValueKey('review-answer-text')), findsOneWidget);
      expect(
        find.textContaining(PikoCopy('en').text('learn.correcting')),
        findsOneWidget,
      );
      expect(
        find.textContaining(PikoCopy('en').text('action.correct')),
        findsWidgets,
      );
      expect(
        launch.button(PikoCopy('en').text('learn.exit')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('review-correct-previous')),
        findsNothing,
      );
      await tester.tap(gradeButton(AnswerGrade.incorrect));
      await h.finish(tester);
      expect(session.isCorrecting, isFalse);
      expect(session.current, same(unanswered));
      expect(find.byKey(const ValueKey('review-answer-text')), findsNothing);
      expect(
        find.byKey(const ValueKey('review-correct-previous')),
        findsOneWidget,
      );
      final replacement = session.acceptedReviews.single;
      expect(replacement.event.id, accepted.event.id);
      expect(replacement.event.reviewedAt, accepted.event.reviewedAt);
      expect(replacement.event.rating, LearningRating.again);
      expect(session.progress.completed, 0);
      expect(session.progress.firstTryCorrect, 0);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'natural completion shows the exact session summary and safe dismissal returns to the Collection',
    (tester) async {
      final h = await open(tester), copy = PikoCopy('en');
      for (var index = 0; index < 2; index++) {
        await reveal(tester);
        await tester.tap(gradeButton(AnswerGrade.correct));
        await h.finish(tester);
      }
      expect(find.text(copy.text('summary.title')), findsOneWidget);
      expect(
        find.text(copy.text('learn.summaryEncouragement')),
        findsOneWidget,
      );
      expect(find.text('2'), findsNWidgets(2));
      expect(h.sessions.single.progress.completed, 2);
      expect(h.sessions.single.progress.firstTryCorrect, 2);
      final close = find.byWidgetPredicate(
        (widget) =>
            widget is PikoIconButton &&
            widget.semanticLabel == copy.text('common.close'),
      );
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(find.byType(CollectionDetail), findsOneWidget);
      expect(h.sessions.single.isStopped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'previous-review control matches the binding arrow and danger-outline trial',
    (tester) async {
      final h = await open(tester);
      await reveal(tester);
      await tester.tap(gradeButton(AnswerGrade.correct));
      await h.finish(tester);
      final finder = find.byKey(const ValueKey('review-correct-previous'));
      final button = tester.widget<PikoButton>(finder);
      expect(button.variant, PikoButtonVariant.dangerOutline);
      expect(button.icon, isA<PikoIcon>());
      expect((button.icon! as PikoIcon).name, PikoIconName.arrowLeft);
      final material = tester.widget<TextButton>(
        find.descendant(of: finder, matching: find.byType(TextButton)),
      );
      expect(
        material.style!.foregroundColor!.resolve(<WidgetState>{}),
        pikoDesign.color('danger'),
      );
      expect(
        material.style!.side!.resolve(<WidgetState>{})!.color,
        pikoDesign.color('danger'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
