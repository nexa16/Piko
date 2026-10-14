import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;
import 'review_launch_test.dart' as launch;

final empty = find.byKey(const ValueKey('review-no-due'));
Future<List<Object?>> snapshot(Fixture f) => Future.wait([
  for (final table in [
    'collections',
    'vocabulary_entries',
    'learning_items',
    'regular_reviews',
    'app_settings',
    'learning_identity_sequence',
    'vocabulary_order_sequence',
  ])
    rows(f.db, table),
]);

Future<void> futureItems(Fixture f, {bool reverseOnly = false}) async {
  final items = await f.learning.forEntry(f.entry.id);
  for (final item in items.where(
    (item) =>
        !reverseOnly || item.direction == LearningDirection.nativeToTarget,
  )) {
    await f.learning.saveCard(
      item.id,
      item.card..due = instant.add(const Duration(days: 7)),
    );
  }
}

Future<void> start(
  WidgetTester tester,
  launch.Harness h, [
  String language = 'en',
]) async {
  await h.open(tester);
  await tester.tap(launch.button(PikoCopy(language).text('learn.start')));
  await h.finish(tester);
}

void main() {
  launch.testWidgets(
    'empty actual Collection shows honest selected-scope empty view; Back/relaunch preserve exact storage',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      await tester.runAsync(
        () => (f.db.delete(
          f.db.vocabularyEntries,
        )..where((row) => row.collectionId.equals(f.owner.id))).go(),
      );
      final h = launch.Harness(f);
      await h.mount(tester);
      final before = await tester.runAsync(() => snapshot(f));
      for (var repeat = 0; repeat < 2; repeat++) {
        await start(tester, h);
        expect(empty, findsOneWidget);
        expect(find.text('Nothing due right now'), findsOneWidget);
        expect(find.text('FR → DE'), findsOneWidget);
        expect(h.sessions.last.members, isEmpty);
        expect(find.byType(DropdownButton), findsNothing);
        expect(find.widgetWithText(PikoButton, 'Correct'), findsNothing);
        expect(find.widgetWithText(PikoButton, 'Incorrect'), findsNothing);
        expect(find.text('One'), findsNothing);
        expect(launch.button('Back'), findsOneWidget);
        await tester.tap(launch.button('Back'));
        await h.finish(tester);
        expect(h.sessions.last.isStopped, isTrue);
        expect(find.byType(ReviewSessionRoute), findsNothing);
        expect(
          tester.widget<PikoButton>(launch.button('Review')).onPressed,
          isNotNull,
        );
        expect(await tester.runAsync(() => snapshot(f)), before);
      }
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'all future due cards show empty without rewriting complete directional state',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      await tester.runAsync(() => futureItems(f));
      final h = launch.Harness(f);
      await h.mount(tester);
      final before = await tester.runAsync(() => snapshot(f));
      await start(tester, h);
      expect(empty, findsOneWidget);
      expect(h.sessions.single.members, isEmpty);
      expect(await tester.runAsync(() => snapshot(f)), before);
      await tester.tap(launch.button('Back'));
      await h.finish(tester);
      expect(await tester.runAsync(() => snapshot(f)), before);
    },
  );

  launch.testWidgets(
    'selected reverse is empty while forward remains due; returning can launch the other direction honestly',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      await tester.runAsync(() => futureItems(f, reverseOnly: true));
      final h = launch.Harness(f);
      await h.mount(tester);
      final before = await tester.runAsync(() => snapshot(f));
      await h.open(tester);
      await h.reverse(tester);
      await tester.tap(launch.button('Start review'));
      await h.finish(tester);
      expect(empty, findsOneWidget);
      expect(find.text('DE → FR'), findsOneWidget);
      await tester.tap(launch.button('Back'));
      await h.finish(tester);
      await start(tester, h);
      expect(empty, findsNothing);
      expect(find.text('FR → DE'), findsOneWidget);
      expect(h.sessions.last.members, hasLength(1));
      expect(h.sessions.last.members.single.entryId, f.entry.id);
      expect(await tester.runAsync(() => snapshot(f)), before);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language empty view wraps at 392px/200% with one reachable Back and canonical description',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(() => futureItems(f));
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester, scale: 2);
        await start(tester, h, language);
        final copy = PikoCopy(language);
        expect(MediaQuery.textScalerOf(tester.element(empty)).scale(15), 30);
        final heading = find.text(copy.text('learn.noDueTitle'));
        final body = find.text(copy.text('learn.noDueBody'));
        final bodyWidget = tester.widget<Text>(body);
        expect(
          bodyWidget.style!.fontSize,
          pikoDesign.dimension('components.emptyState.descriptionSize'),
        );
        expect(
          bodyWidget.style!.height,
          pikoDesign.dimension('components.emptyState.descriptionLineHeight'),
        );
        expect(bodyWidget.style!.color, pikoDesign.color('muted'));
        expect(tester.getSize(body).height, greaterThan(48));
        expect(tester.getRect(empty).left, greaterThanOrEqualTo(0));
        expect(tester.getRect(empty).right, lessThanOrEqualTo(392));
        final semantics = tester.ensureSemantics();
        try {
          expect(tester.getSemantics(heading).flagsCollection.isHeader, isTrue);
        } finally {
          semantics.dispose();
        }
        await tester.ensureVisible(launch.button(copy.text('common.back')));
        expect(
          tester.getSize(launch.button(copy.text('common.back'))).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(launch.button(copy.text('common.back')));
        await h.finish(tester);
        expect(find.byType(ReviewSessionRoute), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final corrupt in [false, true]) {
    launch.testWidgets(
      '${corrupt ? "corrupt card" : "missing Collection"} stays preparation failure, never no-due',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        final live = launch.LiveRepository(f.collections);
        addTearDown(live.changes.close);
        final h = launch.Harness(f)..repository = live;
        await h.mount(tester);
        await h.open(tester);
        if (corrupt) {
          await tester.runAsync(
            () =>
                (f.db.update(
                  f.db.learningItems,
                )..where((row) => row.entryId.equals(f.entry.id))).write(
                  const LearningItemsCompanion(cardJson: Value('invalid')),
                ),
          );
        } else {
          // Cached Collection metadata cannot turn authoritative lookup failure
          // into a successful empty source.
          await tester.runAsync(() => f.collections.delete(f.owner.id));
        }
        final before = await tester.runAsync(() => snapshot(f));
        await tester.tap(launch.button('Start review'));
        await h.finish(tester);
        expect(
          find.text("Couldn't prepare review. Please try again."),
          findsOneWidget,
        );
        expect(find.byType(ReviewSessionRoute), findsNothing);
        expect(empty, findsNothing);
        expect(await tester.runAsync(() => snapshot(f)), before);
        expect(h.sessions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  launch.testWidgets(
    'exhausting nonempty regular membership never becomes initial no-due',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final h = launch.Harness(f);
      await h.mount(tester);
      await start(tester, h);
      final session = h.sessions.single;
      await tester.runAsync(
        () => session.submit(
          session.current!,
          AnswerGrade.incorrect,
          reviewedAt: instant,
        ),
      );
      await tester.pumpAndSettle();
      h.locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(session.regularItemsExhausted, isTrue);
      expect(session.members, hasLength(1));
      expect(empty, findsNothing);
      expect(find.text('Gerade nichts fällig'), findsNothing);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
