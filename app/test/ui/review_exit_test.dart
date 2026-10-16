import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';
import '../data/regular_reviews_test.dart' show instant;
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;

void main() {
  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language icon-only semantic/keyboard Exit preserves submitted event and every unanswered item',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(
          () => f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'Three',
            nativeText: 'Drei',
          ),
        );
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester, scale: 2);
        await h.open(tester);
        final copy = PikoCopy(language);
        await tester.tap(launch.button(copy.text('learn.start')));
        await h.finish(tester);
        final session = h.sessions.single;
        final receipt = await tester.runAsync(
          () => session.submit(
            session.current!,
            AnswerGrade.incorrect,
            reviewedAt: instant,
          ),
        );
        await tester.pumpAndSettle();
        final beforeExit = await tester.runAsync(() => snapshot(f));
        expect(session.unreviewedMembers, hasLength(1));
        expect(launch.button(copy.text('learn.exit')), findsOneWidget);
        final exit = find.byKey(const ValueKey('review-exit'));
        expect(find.text(copy.text('learn.exit')), findsNothing);
        expect(find.byTooltip(copy.text('learn.exit')), findsOneWidget);
        final size = tester.getSize(exit);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(pikoDesign.dimension('controls.largeHeight')));
        expect(size.height, greaterThanOrEqualTo(pikoDesign.dimension('controls.largeHeight')));
        final icon = find.descendant(of: exit, matching: find.byType(PikoIcon));
        expect(tester.widget<PikoIcon>(icon).name, PikoIconName.arrowLeft);
        // A real prior answer is now correctable, independently of Exit.
        expect(launch.button(copy.text('learn.correctPrevious')), findsOneWidget);
        expect(launch.button(copy.text('common.back')), findsNothing);
        final semantics = tester.ensureSemantics();
        try {
          final node = tester.getSemantics(exit);
          expect(node.label, contains(copy.text('learn.exit')));
          expect(node.flagsCollection.isButton, isTrue);
        } finally {
          semantics.dispose();
        }
        final stale = tester
            .widget<PikoButton>(launch.button(copy.text('learn.exit')))
            .onPressed!;
        Focus.of(tester.element(icon)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await h.finish(tester);
        expect(session.isStopped, isTrue);
        expect(session.acceptedReviews.single, same(receipt));
        expect(find.byType(ReviewSessionRoute), findsNothing);
        expect(
          tester
              .widget<CollectionDetail>(find.byType(CollectionDetail))
              .collectionId,
          f.owner.id,
        );
        expect(await tester.runAsync(() => snapshot(f)), beforeExit);
        stale();
        await tester.pumpAndSettle();
        expect(find.byType(CollectionDetail), findsOneWidget);
        expect(await tester.runAsync(() => snapshot(f)), beforeExit);
        expect(tester.takeException(), isNull);
      },
    );
  }

  launch.testWidgets(
    'system Back shares guarded Exit and never grades the unanswered current member',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final h = launch.Harness(f);
      await h.mount(tester);
      await h.open(tester);
      await tester.tap(launch.button('Start review'));
      await h.finish(tester);
      final session = h.sessions.single;
      final before = await tester.runAsync(() => snapshot(f));
      final navigator = Navigator.of(
        tester.element(find.byType(ReviewSessionRoute)),
      );
      await navigator.maybePop();
      await h.finish(tester);
      expect(session.isStopped, isTrue);
      expect(session.acceptedReviews, isEmpty);
      expect(session.unreviewedMembers, hasLength(1));
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(
        tester
            .widget<CollectionDetail>(find.byType(CollectionDetail))
            .collectionId,
        f.owner.id,
      );
      expect(await tester.runAsync(() => snapshot(f)), before);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'covered stale Exit callback cannot stop underlying session or pop unrelated route',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final h = launch.Harness(f);
      await h.mount(tester);
      await h.open(tester);
      await tester.tap(launch.button('Start review'));
      await h.finish(tester);
      final session = h.sessions.single;
      final before = await tester.runAsync(() => snapshot(f));
      final stale = tester
          .widget<PikoButton>(launch.button('Exit review'))
          .onPressed!;
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
      expect(find.text('cover'), findsOneWidget);
      expect(session.isStopped, isFalse);
      expect(session.current, isNotNull);
      expect(await tester.runAsync(() => snapshot(f)), before);
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.tap(launch.button('Exit review'));
      await h.finish(tester);
      expect(session.isStopped, isTrue);
      expect(find.byType(CollectionDetail), findsOneWidget);
      expect(await tester.runAsync(() => snapshot(f)), before);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'same route State replacement rejects old Exit callback without ending new session',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final source = (await tester.runAsync(
        () => f.learning.forCollection(
          collectionId: f.owner.id,
          direction: LearningDirection.targetToNative,
        ),
      ))!;
      final old = (await tester.runAsync(
        () => DueLearningSession.start(source: source, cutoff: instant),
      ))!;
      final next = (await tester.runAsync(
        () => DueLearningSession.start(source: source, cutoff: instant),
      ))!;
      final holder = ValueNotifier(old);
      launch.extraCleanup = (tester) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        old.dispose();
        next.dispose();
        holder.dispose();
        await tester.runAsync(f.db.close);
      };
      await tester.pumpWidget(
        const PikoApp(home: Scaffold(body: Text('home'))),
      );
      final navigator = Navigator.of(tester.element(find.text('home')));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => ValueListenableBuilder<DueLearningSession>(
              valueListenable: holder,
              builder: (_, session, _) => ReviewSessionRoute(
                collection: f.owner,
                session: session,
                vocabularyRepository: f.vocabulary,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stale = tester
          .widget<PikoButton>(launch.button('Exit review'))
          .onPressed!;
      final before = await tester.runAsync(() => snapshot(f));
      holder.value = next;
      await tester.pumpAndSettle();
      expect(old.isStopped, isTrue);
      expect(next.isStopped, isFalse);
      stale();
      await tester.pumpAndSettle();
      expect(next.isStopped, isFalse);
      expect(find.byType(ReviewSessionRoute), findsOneWidget);
      expect(await tester.runAsync(() => snapshot(f)), before);
      await tester.tap(launch.button('Exit review'));
      await tester.pumpAndSettle();
      expect(next.isStopped, isTrue);
      expect(find.text('home'), findsOneWidget);
      expect(await tester.runAsync(() => snapshot(f)), before);
      expect(tester.takeException(), isNull);
    },
  );
}
