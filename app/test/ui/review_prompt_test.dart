import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/review_prompt_card.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;
import '../support/entry_deletion_fixture.dart' show GatedEntryRepository;
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;

class ObservedVocabulary extends GatedEntryRepository {
  ObservedVocabulary(super.real);
  int reads = 0;
  bool fail = false;
  final supplied = <String, Stream<VocabularyRecord?>>{};
  @override
  Stream<VocabularyRecord?> watchById(String id) {
    reads++;
    return supplied[id] ??
        (fail ? Stream.error(StateError('read')) : super.watchById(id));
  }
}

final card = find.byKey(const ValueKey('review-prompt'));
Future<void> start(
  WidgetTester tester,
  launch.Harness h, {
  bool reverse = false,
  String language = 'en',
}) async {
  await h.open(tester);
  if (reverse) await h.reverse(tester);
  await tester.tap(launch.button(PikoCopy(language).text('learn.start')));
  await h.finish(tester);
  await h.flush(tester);
}

List<String> text(Finder within, WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: within, matching: find.byType(Text)))
    .map((widget) => widget.data!)
    .toList();

void main() {
  for (final reverse in [false, true]) {
    launch.testWidgets(
      'actual ${reverse ? "native" : "target"} prompt has only stored text, no redundant labels or tag UI',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(
          () => f.vocabulary.update(
            id: f.entry.id,
            targetText: 'Question',
            nativeText: 'Answer',
          ),
        );
        final h = launch.Harness(f);
        await h.mount(tester);
        final before = await tester.runAsync(() => snapshot(f));
        await start(tester, h, reverse: reverse);
        expect(card, findsOneWidget);
        expect(text(card, tester), [reverse ? 'Answer' : 'Question']);
        expect(
          find.descendant(of: card, matching: find.byType(Chip)),
          findsNothing,
        );
        expect(
          find.descendant(of: card, matching: find.byType(PikoButton)),
          findsNothing,
        );
        expect(h.sessions.single.current!.item.entryId, f.entry.id);
        expect(await tester.runAsync(() => snapshot(f)), before);
        final semantics = tester.ensureSemantics();
        try {
          expect(
            tester
                .getSemantics(
                  find.descendant(of: card, matching: find.byType(Text)),
                )
                .flagsCollection
                .isHeader,
            isFalse,
          );
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  launch.testWidgets(
    'real accepted advance selects next entry and never retains previous prompt snapshot',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final next = (await tester.runAsync(
        () => f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Next',
          nativeText: 'Weiter',
        ),
      ))!;
      final h = launch.Harness(f);
      await h.mount(tester);
      await start(tester, h);
      expect(text(card, tester), ['One']);
      final session = h.sessions.single;
      await tester.runAsync(
        () => session.submit(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        ),
      );
      await tester.pump();
      await h.flush(tester);
      expect(session.current!.item.entryId, next.id);
      expect(text(card, tester), ['Next']);
      expect(find.text('One'), findsNothing);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'locale rebuild retains subscription; real vocabulary edits update text without FSRS writes',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final observed = ObservedVocabulary(f.vocabulary);
      final h = launch.Harness(f)..gatedVocabulary = observed;
      await h.mount(tester);
      await start(tester, h);
      final reads = observed.reads;
      final learning = await tester.runAsync(
        () => rows(f.db, 'learning_items'),
      );
      h.locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(observed.reads, reads);
      expect(text(card, tester), ['One']);
      await tester.runAsync(
        () => f.vocabulary.update(
          id: f.entry.id,
          targetText: 'Updated actual word',
          nativeText: 'Eins',
        ),
      );
      await h.flush(tester);
      expect(text(card, tester), ['Updated actual word']);
      expect(
        await tester.runAsync(() => rows(f.db, 'learning_items')),
        learning,
      );
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'storage stream failure removes prompt; guarded retry recovers and old callbacks cannot re-read after retry/disposal',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final observed = ObservedVocabulary(f.vocabulary)..fail = true;
      final h = launch.Harness(f)..gatedVocabulary = observed;
      await h.mount(tester);
      await start(tester, h);
      expect(card, findsNothing);
      expect(
        find.text("Couldn't load vocabulary. Please try again."),
        findsOneWidget,
      );
      final stale = tester
          .widget<PikoButton>(
            launch.button(PikoCopy('en').text('action.retry')),
          )
          .onPressed!;
      observed.fail = false;
      await tester.tap(launch.button(PikoCopy('en').text('action.retry')));
      await h.flush(tester);
      expect(text(card, tester), ['One']);
      final reads = observed.reads;
      stale();
      await tester.pumpAndSettle();
      expect(observed.reads, reads);
      await tester.tap(launch.button('Exit review'));
      await h.finish(tester);
      stale();
      await tester.pumpAndSettle();
      expect(observed.reads, reads);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'current-handle change retires failed-card Retry callback without re-reading next prompt',
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
      final observed = ObservedVocabulary(f.vocabulary)..fail = true;
      final h = launch.Harness(f)..gatedVocabulary = observed;
      await h.mount(tester);
      await start(tester, h);
      final stale = tester
          .widget<PikoButton>(
            launch.button(PikoCopy('en').text('action.retry')),
          )
          .onPressed!;
      observed.fail = false;
      final session = h.sessions.single;
      await tester.runAsync(
        () => session.submit(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        ),
      );
      await tester.pump();
      await h.flush(tester);
      expect(text(card, tester), ['Next']);
      final reads = observed.reads;
      stale();
      await tester.pumpAndSettle();
      expect(observed.reads, reads);
      expect(text(card, tester), ['Next']);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'same prompt State text-repository replacement resets failed state and rejects old Retry',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final old = ObservedVocabulary(f.vocabulary)..fail = true;
      final next = ObservedVocabulary(f.vocabulary);
      final holder = ValueNotifier<VocabularyRepository>(old);
      final coordinator = RegularGradingCoordinator(repository: f.learning);
      final handle = coordinator.activate((await tester.runAsync(f.current))!)!;
      launch.extraCleanup = (tester) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        holder.dispose();
        coordinator.dispose();
        await tester.runAsync(f.db.close);
      };
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: ValueListenableBuilder<VocabularyRepository>(
              valueListenable: holder,
              builder: (_, repository, _) => ReviewPromptCard(
                handle: handle,
                repository: repository,
                collectionId: f.owner.id,
                direction: handle.item.direction,
                canReveal: (handle) =>
                    identical(coordinator.current, handle) &&
                    !coordinator.isSubmitting,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stale = tester
          .widget<PikoButton>(
            launch.button(PikoCopy('en').text('action.retry')),
          )
          .onPressed!;
      holder.value = next;
      await tester.pump();
      expect(card, findsNothing);
      await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      expect(text(card, tester), ['One']);
      final reads = next.reads;
      stale();
      await tester.pumpAndSettle();
      expect(next.reads, reads);
      expect(text(card, tester), ['One']);
      expect(tester.takeException(), isNull);
    },
  );

  launch.testWidgets(
    'runtime close cancels pending first vocabulary emission without late UI errors',
    (tester) async {
      final db = launch.ClosingDatabase();
      final f = Fixture(database: db);
      await tester.runAsync(f.initialize);
      final gate = Completer<void>(), read = Completer<void>();
      final observed = ObservedVocabulary(f.vocabulary);
      observed.supplied[f.entry.id] = f.vocabulary
          .watchById(f.entry.id)
          .asyncMap((entry) async {
            if (!read.isCompleted) read.complete();
            await gate.future;
            return entry;
          });
      launch.extraCleanup = (tester) async {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(() => db.closed.future);
      };
      await tester.pumpWidget(
        PikoApp(home: PikoRuntime(databaseFactory: () => db)),
      );
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      final home = tester.widget<CollectionsHome>(find.byType(CollectionsHome));
      final navigator = Navigator.of(
        tester.element(find.byType(CollectionsHome)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => CollectionDetail(
              repository: f.collections,
              collectionId: f.owner.id,
              vocabularyRepository: observed,
              reviewSessionFactory: home.reviewSessionFactory,
              onPendingVocabularyWrites: home.onPendingVocabularyWrites,
            ),
          ),
        ),
      );
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      await tester.tap(launch.button('Review'));
      await tester.pumpAndSettle();
      await tester.tap(launch.button('Start review'));
      await tester.pump();
      for (var index = 0; index < 4 && !read.isCompleted; index++) {
        await tester.runAsync(() => db.customSelect('SELECT 1').get());
        await tester.pumpAndSettle();
      }
      expect(read.isCompleted, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewSessionRoute), findsOneWidget);
      expect(find.byType(ReviewPromptCard), findsOneWidget);
      expect(card, findsNothing);
      expect(find.text(PikoCopy('en').text('vocab.loading')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(() => db.closed.future);
      expect(db.closeCalls, 1);
      gate.complete();
      await tester.pump();
      expect(find.byType(ReviewPromptCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final foreign in [false, true]) {
    launch.testWidgets(
      '${foreign ? "foreign owner" : "deleted current entry"} never substitutes a sample or no-due prompt',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        final observed = ObservedVocabulary(f.vocabulary);
        final h = launch.Harness(f)..gatedVocabulary = observed;
        await h.mount(tester);
        await start(tester, h);
        expect(text(card, tester), ['One']);
        if (foreign) {
          // A record emitted by an injected text owner still must match the
          // captured session's entry and Collection before it can be displayed.
          observed.supplied[f.entry.id] = Stream.value(
            VocabularyRecord(
              id: f.entry.id,
              collectionId: f.kept.id,
              targetText: 'Foreign',
              nativeText: 'Fremd',
            ),
          );
          observed.fail = true;
          // Replace only the route's stream owner by reloading a current card via
          // the new owner in a fresh launch; ownership remains checked at display.
          await tester.tap(launch.button('Exit review'));
          await h.finish(tester);
          await start(tester, h);
        } else {
          await tester.runAsync(
            () => (f.db.delete(
              f.db.vocabularyEntries,
            )..where((row) => row.id.equals(f.entry.id))).go(),
          );
          await h.flush(tester);
        }
        expect(card, findsNothing);
        expect(find.text('Foreign'), findsNothing);
        expect(find.byKey(const ValueKey('review-no-due')), findsNothing);
        expect(
          find.text("Couldn't load vocabulary. Please try again."),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  launch.testWidgets(
    'text dependency replacement invalidates pending setup and disposes late original session',
    (tester) async {
      final f = launch.fixture();
      await tester.runAsync(f.initialize);
      final old = ObservedVocabulary(f.vocabulary),
          next = ObservedVocabulary(f.vocabulary);
      final h = launch.Harness(f)
        ..gatedVocabulary = old
        ..gate = Completer<void>();
      await h.mount(tester);
      await h.open(tester);
      await tester.tap(launch.button('Start review'));
      await tester.pumpAndSettle();
      h.gatedVocabulary = next;
      h.revision.value++;
      await h.flush(tester);
      h.gate!.complete();
      await h.finish(tester);
      expect(h.sessions.single.isStopped, isTrue);
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(old.reads, 0);
      await start(tester, h);
      expect(next.reads, 1);
      expect(text(card, tester), ['One']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'de']) {
    launch.testWidgets(
      '$language actual 392px/200% long prompt wraps and Exit stays reachable without card headings',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        final long = 'UnbrokenVocabularyWord' * 8;
        await tester.runAsync(
          () => f.vocabulary.update(
            id: f.entry.id,
            targetText: long,
            nativeText: 'Eins',
          ),
        );
        final h = launch.Harness(f)..locale.value = Locale(language);
        await h.mount(tester, scale: 2);
        await start(tester, h, language: language);
        expect(text(card, tester), [long]);
        expect(MediaQuery.textScalerOf(tester.element(card)).scale(37), 74);
        expect(tester.getRect(card).right, lessThanOrEqualTo(392));
        expect(
          tester.getSize(card).height,
          greaterThanOrEqualTo(
            pikoDesign.dimension('components.learningCard.minHeight'),
          ),
        );
        expect(tester.getSize(find.text(long)).height, greaterThan(74));
        final prompt = tester.widget<Text>(find.text(long));
        expect(
          prompt.style!.fontSize,
          pikoDesign.dimension('components.learningCard.promptSize'),
        );
        expect(
          prompt.style!.fontWeight,
          pikoDesign.weight('components.learningCard.promptWeight'),
        );
        await tester.ensureVisible(
          launch.button(PikoCopy(language).text('learn.exit')),
        );
        await tester.tap(launch.button(PikoCopy(language).text('learn.exit')));
        await h.finish(tester);
        expect(find.byType(ReviewSessionRoute), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
