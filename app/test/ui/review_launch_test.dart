import 'dart:async';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as test_api;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_field.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;
import '../support/mutable_clock.dart';
import '../support/entry_deletion_fixture.dart' show GatedEntryRepository;
import '../features/due_learning_session_test.dart' show GatedSource;

Finder button(String label) => find.widgetWithText(PikoButton, label);
Finder dropdown = find.byType(DropdownButton<LearningDirection>);
final close = find.byTooltip('Close');

Harness? activeHarness;
Future<void> Function(WidgetTester)? extraCleanup;
// Finish captured fake-zone work before leaving the widget test body. Native
// SQLite work stays in runAsync; teardown must not reawait dead fake-zone futures.
void testWidgets(String description, WidgetTesterCallback body) {
  test_api.testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await activeHarness?.cleanup(tester);
      activeHarness = null;
      await extraCleanup?.call(tester);
      extraCleanup = null;
    }
  });
}

class LiveRepository implements CollectionsRepository {
  LiveRepository(this.real);
  final CollectionsRepository real;
  final changes = StreamController<CollectionRecord?>.broadcast(sync: true);
  @override
  Stream<CollectionRecord?> watchById(String id) async* {
    yield await real.watchById(id).first;
    yield* changes.stream;
  }

  @override
  Stream<List<CollectionRecord>> watchAll() => real.watchAll();
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => real.create(
    name: name,
    targetLanguage: targetLanguage,
    nativeLanguage: nativeLanguage,
  );
  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      real.rename(id: id, name: name);
  @override
  Future<void> delete(String id) => real.delete(id);
}

class Harness {
  Harness(this.f) : repository = f.collections;
  final Fixture f;
  GatedEntryRepository? gatedVocabulary;
  CollectionsRepository repository;
  final locale = InterfaceLocaleController();
  final revision = ValueNotifier(0);
  final drains = <Future<void>>[];
  final sessions = <DueLearningSession>[];
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;
  final selections = <LearningDirection>[];
  late ReviewSessionFactory factory = create;
  Future<DueLearningSession> create(
    String id,
    LearningDirection direction,
  ) async {
    calls++;
    selections.add(direction);
    await gate?.future;
    if (fail) throw StateError('prepare');
    final source = await f.learning.forCollection(
      collectionId: id,
      direction: direction,
    );
    final session = await DueLearningSession.start(
      source: source,
      cutoff: instant,
      onPendingWrites: drains.add,
    );
    sessions.add(session);
    return session;
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump();
    var complete = false;
    Object? failure;
    unawaited(
      Future.wait(drains.toList()).then<void>(
        (_) => complete = true,
        onError: (Object error, StackTrace _) {
          failure = error;
          complete = true;
        },
      ),
    );
    while (!complete) {
      await flush(tester);
    }
    if (failure != null) throw failure!;
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    activeHarness = this;
    tester.view.physicalSize = const Size(392, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PikoApp(
        localeController: locale,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: ValueListenableBuilder<int>(
              valueListenable: revision,
              builder: (_, _, _) => CollectionDetail(
                repository: repository,
                collectionId: f.owner.id,
                reviewSessionFactory: factory,
                vocabularyRepository: gatedVocabulary ?? f.vocabulary,
                onPendingVocabularyWrites: drains.add,
              ),
            ),
          ),
        ),
      ),
    );
    await flush(tester);
  }

  Future<void> cleanup(WidgetTester tester) async {
    for (final gate
        in gatedVocabulary?.updateGates.values ?? <Completer<void>>[]) {
      if (!gate.isCompleted) gate.complete();
    }
    if (gate != null && !gate!.isCompleted) gate!.complete();
    await tester.pump();
    await finish(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await flush(tester);
    locale.dispose();
    revision.dispose();
    await tester.runAsync(f.db.close);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(
      button(locale.value.languageCode == 'de' ? 'Wiederholen' : 'Review'),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reverse(WidgetTester tester) async {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DE → FR').last);
    await tester.pumpAndSettle();
  }
}

Fixture fixture() => Fixture(
  database: PikoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    clock: MutablePikoClock(instant),
  ),
);

class ClosingDatabase extends PikoDatabase {
  ClosingDatabase()
    : super(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
  int closeCalls = 0;
  final closed = Completer<void>();
  @override
  Future<void> close() async {
    closeCalls++;
    await super.close();
    if (!closed.isCompleted) closed.complete();
  }
}

void main() {
  testWidgets(
    'not-ready Collection disables setup Start and stale callback; recovery keeps choice and can launch',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final live = LiveRepository(f.collections);
      addTearDown(live.changes.close);
      final h = Harness(f)..repository = live;
      await h.mount(tester);
      await h.open(tester);
      await h.reverse(tester);
      final stale = tester
          .widget<PikoButton>(button('Start review'))
          .onPressed!;
      live.changes.addError(StateError('read'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PikoButton>(button('Start review')).onPressed,
        isNull,
      );
      stale();
      await tester.pumpAndSettle();
      expect(h.calls, 0);
      expect(h.drains, isEmpty);
      live.changes.add(f.owner);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PikoButton>(button('Start review')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<DropdownButton<LearningDirection>>(dropdown).value,
        LearningDirection.nativeToTarget,
      );
      await tester.tap(button('Start review'));
      await h.finish(tester);
      expect(h.selections.single, LearningDirection.nativeToTarget);
      expect(find.byType(ReviewSessionRoute), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'popup focuses direction and keyboard chooses reverse then explicitly starts',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f);
      await h.mount(tester);
      await h.open(tester);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<
              DropdownButton<LearningDirection>
            >(),
        isNotNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DropdownButton<LearningDirection>>(dropdown).value,
        LearningDirection.nativeToTarget,
      );
      expect(h.calls, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await h.finish(tester);
      expect(h.selections.single, LearningDirection.nativeToTarget);
      expect(find.byType(ReviewSessionRoute), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final direction in LearningDirection.values) {
    testWidgets(
      'explicit $direction launches real fixed scoped session without grading',
      (tester) async {
        final f = fixture();
        await tester.runAsync(f.initialize);
        final h = Harness(f);
        await h.mount(tester);
        final before = await tester.runAsync(
          () => rows(f.db, 'learning_items'),
        );
        await h.open(tester);
        expect(h.calls, 0);
        expect(
          tester
              .widget<DropdownButton<LearningDirection>>(dropdown)
              .items!
              .map((item) => item.value),
          LearningDirection.values,
        );
        if (direction == LearningDirection.nativeToTarget) {
          await h.reverse(tester);
        }
        await tester.tap(button('Start review'));
        await h.finish(tester);
        expect(h.calls, 1);
        final route = tester.widget<ReviewSessionRoute>(
          find.byType(ReviewSessionRoute),
        );
        expect(route.collection.id, f.owner.id);
        expect(route.session.direction, direction);
        expect(route.session.members, hasLength(1));
        expect(route.session.members.single.entryId, f.entry.id);
        expect(route.session.members.single.direction, direction);
        expect(find.byType(PikoDropdown<LearningDirection>), findsNothing);
        expect(
          find.text(
            direction == LearningDirection.nativeToTarget
                ? 'DE → FR'
                : 'FR → DE',
          ),
          findsOneWidget,
        );
        expect(
          await tester.runAsync(() => rows(f.db, 'learning_items')),
          before,
        );
        expect(
          await tester.runAsync(() => rows(f.db, 'regular_reviews')),
          isEmpty,
        );
        await tester.tap(button('Back'));
        await h.finish(tester);
        expect(route.session.isStopped, isTrue);
        expect(find.byType(ReviewSessionRoute), findsNothing);
        expect(find.byType(CollectionDetail), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final dismiss in ['X', 'Escape', 'backdrop']) {
    testWidgets(
      '$dismiss dismisses choice without preparing a session or writing',
      (tester) async {
        final f = fixture();
        await tester.runAsync(f.initialize);
        final h = Harness(f);
        await h.mount(tester);
        await h.open(tester);
        if (dismiss == 'X') {
          await tester.tap(close);
        } else if (dismiss == 'Escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tapAt(const Offset(2, 2));
        }
        await tester.pumpAndSettle();
        expect(h.calls, 0);
        expect(find.byType(ReviewDirectionDialog), findsNothing);
        expect(
          tester.widget<PikoButton>(button('Review')).onPressed,
          isNotNull,
        );
        expect(
          await tester.runAsync(() => rows(f.db, 'regular_reviews')),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'selection survives locale and enlarged German popup is reachable with keyboard semantics',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f);
      await h.mount(tester, scale: 2);
      await h.open(tester);
      await h.reverse(tester);
      h.locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(
        tester.widget<DropdownButton<LearningDirection>>(dropdown).value,
        LearningDirection.nativeToTarget,
      );
      expect(find.text('Lernrichtung wählen'), findsOneWidget);
      expect(find.text('Bevorzugte Richtung'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(dropdown).label, contains('DE → FR'));
      semantics.dispose();
      await tester.ensureVisible(button('Wiederholung starten'));
      expect(
        tester.getSize(button('Wiederholung starten')).height,
        greaterThanOrEqualTo(44),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.tap(button('Wiederholung starten'));
      await h.finish(tester);
      expect(h.selections.single, LearningDirection.nativeToTarget);
      expect(find.text('DE → FR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failure retries selected direction; pending selection and repeated Start are frozen',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f)..fail = true;
      await h.mount(tester);
      await h.open(tester);
      await h.reverse(tester);
      await tester.tap(button('Start review'));
      await h.finish(tester);
      expect(
        find.text("Couldn't prepare review. Please try again."),
        findsOneWidget,
      );
      expect(
        tester.widget<DropdownButton<LearningDirection>>(dropdown).value,
        LearningDirection.nativeToTarget,
      );
      h.fail = false;
      h.gate = Completer<void>();
      final staleStart = tester
          .widget<PikoButton>(button('Start review'))
          .onPressed!;
      staleStart();
      staleStart();
      await tester.pumpAndSettle();
      expect(h.calls, 2);
      expect(
        tester.widget<PikoButton>(button('Start review')).onPressed,
        isNull,
      );
      expect(
        tester.widget<DropdownButton<LearningDirection>>(dropdown).onChanged,
        isNull,
      );
      h.gate!.complete();
      await h.finish(tester);
      expect(h.sessions, hasLength(1));
      expect(h.sessions.single.direction, LearningDirection.nativeToTarget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dismiss pending preparation cleans late session and re-enables Collection actions',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f)..gate = Completer<void>();
      await h.mount(tester);
      await h.open(tester);
      await tester.tap(button('Start review'));
      await tester.pumpAndSettle();
      expect(h.calls, 1);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(tester.widget<PikoButton>(button('Review')).onPressed, isNotNull);
      h.gate!.complete();
      await h.finish(tester);
      expect(h.sessions.single.isStopped, isTrue);
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'covered preparation cleans late session then uncovered popup can retry',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f)..gate = Completer<void>();
      await h.mount(tester);
      await h.open(tester);
      await tester.tap(button('Start review'));
      await tester.pumpAndSettle();
      final navigator = Navigator.of(
        tester.element(find.byType(ReviewDirectionDialog)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('cover')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      h.gate!.complete();
      await h.finish(tester);
      expect(find.text('cover'), findsOneWidget);
      expect(h.sessions.single.isStopped, isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<PikoButton>(button('Start review')).onPressed,
        isNotNull,
      );
      await tester.tap(button('Start review'));
      await h.finish(tester);
      expect(h.calls, 2);
      expect(find.byType(ReviewSessionRoute), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'same-ID repository replacement invalidates old setup while late session cleans up',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f)..gate = Completer<void>();
      await h.mount(tester);
      await h.open(tester);
      await tester.tap(button('Start review'));
      await tester.pumpAndSettle();
      final replacement = LiveRepository(f.collections);
      addTearDown(replacement.changes.close);
      h.repository = replacement;
      h.revision.value++;
      await h.flush(tester);
      h.gate!.complete();
      await h.finish(tester);
      expect(h.sessions.single.isStopped, isTrue);
      expect(find.byType(ReviewDirectionDialog), findsNothing);
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(tester.widget<PikoButton>(button('Review')).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'temporary stream error/recovery keeps setup owned and releases busy barrier after dismissal',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final live = LiveRepository(f.collections);
      addTearDown(live.changes.close);
      final h = Harness(f)
        ..repository = live
        ..gate = Completer<void>();
      await h.mount(tester);
      await h.open(tester);
      await tester.tap(button('Start review'));
      await tester.pumpAndSettle();
      live.changes.addError(StateError('read'));
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      live.changes.add(f.owner);
      await tester.pumpAndSettle();
      h.gate!.complete();
      await h.finish(tester);
      expect(h.sessions.single.isStopped, isTrue);
      expect(tester.widget<PikoButton>(button('Review')).onPressed, isNotNull);
      await h.open(tester);
      await tester.tap(button('Start review'));
      await h.finish(tester);
      expect(find.byType(ReviewSessionRoute), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'actual runtime close waits for gated preparation and late-session cleanup after unmount',
    (tester) async {
      final db = ClosingDatabase();
      final f = Fixture(database: db);
      await tester.runAsync(f.initialize);
      final gate = Completer<void>();
      final prepared = <DueLearningSession>[];
      extraCleanup = (tester) async {
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
              onPendingVocabularyWrites: home.onPendingVocabularyWrites,
              reviewSessionFactory: (id, direction) async {
                await gate.future;
                final session = await home.reviewSessionFactory!(id, direction);
                prepared.add(session);
                return session;
              },
            ),
          ),
        ),
      );
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      await tester.tap(button('Review'));
      await tester.pumpAndSettle();
      await tester.tap(button('Start review'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(db.closeCalls, 0);
      gate.complete();
      await tester.pump();
      await tester.runAsync(() => db.closed.future);
      await tester.pump();
      expect(prepared.single.isStopped, isTrue);
      expect(db.closeCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'accepted inline autosave drains before due preparation; invalid raw draft is retained',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final gated = GatedEntryRepository(f.vocabulary);
      final h = Harness(f)..gatedVocabulary = gated;
      final stored = <VocabularyRecord>[];
      h.factory = (id, direction) async {
        stored.add((await f.vocabulary.watchById(f.entry.id).first)!);
        return h.create(id, direction);
      };
      await h.mount(tester);
      await tester.tap(find.byKey(ValueKey('vocabulary-${f.entry.id}')));
      await h.flush(tester);
      Finder field(bool target) => find.descendant(
        of: find.byKey(
          ValueKey('inline-${f.entry.id}-${target ? "target" : "native"}'),
        ),
        matching: find.byType(TextField),
      );
      gated.updateGates[f.entry.id] = Completer<void>();
      await tester.enterText(field(true), 'Accepted word');
      await tester.pump();
      await tester.enterText(field(false), '');
      await tester.pump();
      final raw = tester.widget<TextField>(field(false)).controller!;
      await tester.ensureVisible(button('Review'));
      await h.open(tester);
      await tester.tap(button('Start review'));
      await tester.pumpAndSettle();
      expect(h.calls, 0);
      expect(stored, isEmpty);
      gated.updateGates[f.entry.id]!.complete();
      await h.flush(tester);
      await h.finish(tester);
      expect(stored.single.targetText, 'Accepted word');
      expect(stored.single.nativeText, 'Eins');
      expect(h.sessions.single.members.single.entryId, f.entry.id);
      await tester.tap(button('Back'));
      await h.finish(tester);
      expect(
        identical(tester.widget<TextField>(field(false)).controller, raw),
        isTrue,
      );
      expect(raw.text, '');
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'session Back during admitted grade drains receipt; covered completion never pops cover and Back retries',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final gated = GatedSource(
        (await tester.runAsync(
          () => f.learning.forCollection(
            collectionId: f.owner.id,
            direction: LearningDirection.nativeToTarget,
          ),
        ))!,
      );
      final session = (await tester.runAsync(
        () => DueLearningSession.start(source: gated, cutoff: instant),
      ))!;
      extraCleanup = (tester) async {
        if (!gated.gate.isCompleted) gated.gate.complete();
        await tester.pump();
        await tester.runAsync(session.awaitPending);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        session.dispose();
        await tester.runAsync(f.db.close);
      };
      await tester.pumpWidget(
        const PikoApp(home: Scaffold(body: Text('home'))),
      );
      final navigator = Navigator.of(tester.element(find.text('home')));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) =>
                ReviewSessionRoute(collection: f.owner, session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      late Future<dynamic> submitted;
      await tester.runAsync(() async {
        submitted = session.submit(
          session.current!,
          AnswerGrade.correct,
          reviewedAt: instant,
        );
        await gated.entered.future;
      });
      await tester.tap(button('Back'));
      await tester.pumpAndSettle();
      expect(tester.widget<PikoButton>(button('Back')).onPressed, isNull);
      expect(session.isStopped, isTrue);
      await navigator.maybePop();
      await tester.pump();
      expect(find.byType(ReviewSessionRoute), findsOneWidget);
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('cover')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      gated.gate.complete();
      await tester.pump();
      final receipt = await tester.runAsync(() => submitted);
      await tester.runAsync(session.awaitPending);
      await tester.pumpAndSettle();
      expect(find.text('cover'), findsOneWidget);
      expect(session.acceptedReviews.single, same(receipt));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(tester.widget<PikoButton>(button('Back')).onPressed, isNotNull);
      await tester.tap(button('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewSessionRoute), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(
        (await tester.runAsync(() => rows(f.db, 'regular_reviews')))!,
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'review factory replacement preserves same-Collection raw rename and inline draft',
    (tester) async {
      final f = fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f);
      await h.mount(tester);
      await tester.tap(find.byKey(ValueKey('vocabulary-${f.entry.id}')));
      await h.flush(tester);
      final native = find.descendant(
        of: find.byKey(ValueKey('inline-${f.entry.id}-native')),
        matching: find.byType(TextField),
      );
      await tester.enterText(native, '');
      await tester.pump();
      final raw = tester.widget<TextField>(native).controller!;
      await tester.tap(find.byKey(const ValueKey('collection-rename')));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('collection-name'));
      await tester.enterText(name, '  Raw name  ');
      final rename = tester.widget<TextField>(name).controller!;
      rename.selection = const TextSelection(baseOffset: 2, extentOffset: 5);
      final value = rename.value;
      h.factory = (id, direction) => h.create(id, direction);
      h.revision.value++;
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).controller, same(rename));
      expect(rename.value, value);
      expect(tester.widget<TextField>(native).controller, same(raw));
      expect(raw.text, '');
      expect(
        await tester.runAsync(() => rows(f.db, 'regular_reviews')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
