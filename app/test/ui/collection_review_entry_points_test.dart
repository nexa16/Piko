import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/review_due_membership.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_review_count.dart';
import 'package:piko/features/collections/collection_review_entry_point.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';

import '../data/regular_reviews_test.dart' show Fixture, instant;
import '../support/collection_deletion_fixture.dart';
import '../support/mutable_clock.dart';
import 'review_no_due_test.dart' show snapshot;

const first = CollectionRecord(
  id: 'first',
  name: 'First words',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);
const second = CollectionRecord(
  id: 'second',
  name: 'Second words',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);

class Collections implements CollectionsRepository {
  const Collections(this.records);
  final List<CollectionRecord> records;

  @override
  Stream<List<CollectionRecord>> watchAll() => Stream.value(records);
  @override
  Stream<CollectionRecord?> watchById(String id) =>
      Stream.value(records.where((record) => record.id == id).firstOrNull);
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      throw UnimplementedError();
}

class Vocabulary implements VocabularyRepository {
  const Vocabulary();
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) => throw UnimplementedError();
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) => throw UnimplementedError();
  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) => throw UnimplementedError();
  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) => throw UnimplementedError();
  @override
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) =>
      Stream.value(const []);
  @override
  Stream<VocabularyRecord?> watchById(String id) => Stream.value(null);
}

ReviewDueMembership due(
  String collectionId,
  int index, {
  LearningDirection direction = LearningDirection.targetToNative,
}) => ReviewDueMembership(
  entryId: '$collectionId-entry-$index',
  itemId: collectionId.hashCode + index,
  generation: 0,
  direction: direction,
  regularDue: true,
  eligibleRetry: false,
);

Future<void> settleReads(WidgetTester tester) async {
  await tester.runAsync(() async {});
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'detail count consumes both passive SQLite directions without changing storage',
    (tester) async {
      final f = Fixture(
        database: PikoDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
          clock: MutablePikoClock(instant),
        ),
      );
      await tester.runAsync(f.initialize);
      final started = Completer<void>(), loaded = Completer<void>();
      Future<List<ReviewDueMembership>> load({
        required String collectionId,
        required DateTime at,
      }) async {
        if (!started.isCompleted) started.complete();
        try {
          final groups = await Future.wait(
            LearningDirection.values.map((direction) async {
              final gateway = await f.learning.forCollection(
                collectionId: collectionId,
                direction: direction,
              );
              return gateway.dueMemberships(at: at);
            }),
          );
          return List.unmodifiable(groups.expand((group) => group));
        } finally {
          if (!loaded.isCompleted) loaded.complete();
        }
      }

      try {
        final before = await tester.runAsync(() => snapshot(f));
        await tester.pumpWidget(
          PikoApp(
            home: CollectionDetail(
              repository: f.collections,
              collectionId: f.owner.id,
              vocabularyRepository: f.vocabulary,
              reviewMembershipLoader: load,
              reviewCountPolicy: CollectionReviewCountPolicy.distinctVocabulary,
              reviewCountClock: f.db.clock,
              reviewSessionFactory: (id, direction) async =>
                  throw StateError('Start was not requested'),
            ),
          ),
        );
        // First complete the Collection watch and rebuild the detail route;
        // only that rebuild constructs the count widget and starts its reads.
        await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
        await tester.pumpAndSettle();
        expect(started.isCompleted, isTrue);
        await tester.runAsync(() => loaded.future);
        await tester.pumpAndSettle();

        expect(find.text('FR → DE · 1 to review'), findsOneWidget);
        expect(find.text('DE → FR · 1 to review'), findsOneWidget);
        expect(await tester.runAsync(() => snapshot(f)), before);
        expect(f.db.clock.now(), instant);
      } finally {
        // Drain Drift's widget-owned stream closure before the test framework's
        // pending-timer invariant runs; addTearDown would be too late.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.db.close);
      }
    },
  );

  testWidgets(
    'Home has actual Collection-specific review controls and no global summary',
    (tester) async {
      var factoryCalls = 0;
      Future<List<ReviewDueMembership>> load({
        required String collectionId,
        required DateTime at,
      }) async => [
        due(collectionId, 1),
        due(collectionId, 2, direction: LearningDirection.nativeToTarget),
      ];
      await tester.pumpWidget(
        PikoApp(
          home: CollectionsHome(
            repository: const Collections([first, second]),
            vocabularyRepository: const Vocabulary(),
            reviewMembershipLoader: load,
            reviewCountPolicy: CollectionReviewCountPolicy.dueDirectionCards,
            reviewSessionFactory: (id, direction) async {
              factoryCalls++;
              throw StateError('Start was not requested');
            },
          ),
        ),
      );
      await settleReads(tester);

      expect(find.text('Ready to review'), findsNothing);
      expect(find.text('Review'), findsNWidgets(2));
      expect(find.text('2'), findsNWidgets(2));
      final firstCard = find.byKey(const ValueKey('collection-first'));
      final quick = find.descendant(
        of: firstCard,
        matching: find.byKey(const ValueKey('collection-review-quick')),
      );
      await tester.tap(quick);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewDirectionDialog), findsOneWidget);
      expect(find.byType(CollectionDetail), findsNothing);
      expect(factoryCalls, 0);
    },
  );

  testWidgets(
    'detail uses full-width directional actions and launches without setup',
    (tester) async {
      Future<List<ReviewDueMembership>> load({
        required String collectionId,
        required DateTime at,
      }) async => [
        due(collectionId, 1),
        due(collectionId, 1, direction: LearningDirection.nativeToTarget),
      ];
      LearningDirection? selected;
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: const Collections([first]),
            collectionId: first.id,
            vocabularyRepository: const Vocabulary(),
            reviewMembershipLoader: load,
            reviewCountPolicy: CollectionReviewCountPolicy.distinctVocabulary,
            reviewSessionFactory: (id, direction) async {
              selected = direction;
              throw StateError('preparation failure');
            },
          ),
        ),
      );
      await settleReads(tester);

      final card = find.byKey(
        const ValueKey('collection-review-targetToNative'),
      );
      expect(find.text('FR → DE · 1 to review'), findsOneWidget);
      expect(find.text('DE → FR · 1 to review'), findsOneWidget);
      expect(
        tester.getSize(card).width,
        tester
            .getSize(find.byKey(const ValueKey('review-launch-slot-first-0-0')))
            .width,
      );
      expect(
        tester.getSize(card).height,
        greaterThanOrEqualTo(pikoDesign.dimension('components.buttons.height')),
      );
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewDirectionDialog), findsNothing);
      expect(selected, LearningDirection.targetToNative);
    },
  );

  testWidgets('Home refreshes the Collection count after detail returns', (
    tester,
  ) async {
    var reads = 0;
    Future<List<ReviewDueMembership>> load({
      required String collectionId,
      required DateTime at,
    }) async {
      reads++;
      return List.generate(reads, (index) => due(collectionId, index));
    }

    await tester.pumpWidget(
      PikoApp(
        home: CollectionsHome(
          repository: const Collections([first]),
          vocabularyRepository: const Vocabulary(),
          reviewMembershipLoader: load,
          reviewCountPolicy: CollectionReviewCountPolicy.distinctVocabulary,
          reviewSessionFactory: (id, direction) async =>
              throw StateError('Start was not requested'),
        ),
      ),
    );
    await settleReads(tester);
    expect(reads, 1);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text(first.name));
    await settleReads(tester);
    expect(find.byType(CollectionDetail), findsOneWidget);
    expect(reads, 2);

    Navigator.of(tester.element(find.byType(CollectionDetail))).pop();
    await settleReads(tester);
    expect(find.byType(CollectionsHome), findsOneWidget);
    expect(reads, 3);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets(
    'quick controls keep normal geometry and enlarged German content readable',
    (tester) async {
      tester.view.physicalSize = const Size(392, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<List<ReviewDueMembership>> load({
        required String collectionId,
        required DateTime at,
      }) async => List.generate(
        collectionId == first.id ? 9 : 99,
        (index) => due(collectionId, index),
      );
      Future<void> mount(double scale) async {
        await tester.pumpWidget(
          PikoApp(
            locale: const Locale('de'),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: CollectionsHome(
                  repository: const Collections([first, second]),
                  vocabularyRepository: const Vocabulary(),
                  reviewMembershipLoader: load,
                  reviewCountPolicy:
                      CollectionReviewCountPolicy.distinctVocabulary,
                  reviewSessionFactory: (id, direction) async =>
                      throw StateError('Start was not requested'),
                ),
              ),
            ),
          ),
        );
        await settleReads(tester);
      }

      await mount(1);
      final quick = find.byKey(const ValueKey('collection-review-quick'));
      expect(quick, findsNWidgets(2));
      expect(tester.getSize(quick.at(0)), tester.getSize(quick.at(1)));
      expect(
        tester.getSize(quick.first).width,
        pikoDesign.dimension('components.collectionReview.quickWidth'),
      );
      expect(
        tester.getSize(quick.first).height,
        greaterThanOrEqualTo(pikoDesign.dimension('controls.largeHeight')),
      );

      // The accepted font's intrinsic line height may grow the control beyond
      // its minimum. Normal-size content must still be wholly inside it.
      for (final action in [quick.at(0), quick.at(1)]) {
        final box = tester.getRect(action);
        final texts = find.descendant(of: action, matching: find.byType(Text));
        for (final text in texts.evaluate()) {
          final label = tester.getRect(find.byWidget(text.widget));
          expect(label.left, greaterThanOrEqualTo(box.left));
          expect(label.right, lessThanOrEqualTo(box.right));
          expect(label.top, greaterThanOrEqualTo(box.top));
          expect(label.bottom, lessThanOrEqualTo(box.bottom));
        }
      }

      await mount(2);
      for (final action in [quick.at(0), quick.at(1)]) {
        await tester.ensureVisible(action);
        final box = tester.getRect(action);
        final label = tester.getRect(
          find.descendant(of: action, matching: find.byType(Text)).first,
        );
        expect(label.left, greaterThanOrEqualTo(box.left));
        expect(label.right, lessThanOrEqualTo(box.right));
        expect(label.top, greaterThanOrEqualTo(box.top));
        expect(label.bottom, lessThanOrEqualTo(box.bottom));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('five-digit quick count grows without clipping its content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(392, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<List<ReviewDueMembership>> load({
      required String collectionId,
      required DateTime at,
    }) async => List.generate(12345, (index) => due(collectionId, index));
    await tester.pumpWidget(
      PikoApp(
        locale: const Locale('de'),
        home: CollectionsHome(
          repository: const Collections([first]),
          vocabularyRepository: const Vocabulary(),
          reviewMembershipLoader: load,
          reviewCountPolicy: CollectionReviewCountPolicy.distinctVocabulary,
          reviewSessionFactory: (id, direction) async =>
              throw StateError('Start was not requested'),
        ),
      ),
    );
    await settleReads(tester);

    final action = find.byKey(const ValueKey('collection-review-quick'));
    final actionRect = tester.getRect(action);
    expect(
      actionRect.width,
      pikoDesign.dimension('components.collectionReview.quickWidth'),
    );
    expect(
      actionRect.height,
      greaterThan(pikoDesign.dimension('controls.largeHeight')),
    );
    final texts = find.descendant(of: action, matching: find.byType(Text));
    for (var index = 0; index < texts.evaluate().length; index++) {
      final textRect = tester.getRect(texts.at(index));
      expect(textRect.left, greaterThanOrEqualTo(actionRect.left));
      expect(textRect.right, lessThanOrEqualTo(actionRect.right));
      expect(textRect.top, greaterThanOrEqualTo(actionRect.top));
      expect(textRect.bottom, lessThanOrEqualTo(actionRect.bottom));
    }
    expect(find.text('12345'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible count refreshes on resume without creating a session', (
    tester,
  ) async {
    var reads = 0, factories = 0;
    Future<List<ReviewDueMembership>> load({
      required String collectionId,
      required DateTime at,
    }) async {
      reads++;
      return [due(collectionId, reads)];
    }

    await tester.pumpWidget(
      PikoApp(
        home: CollectionsHome(
          repository: const Collections([first]),
          vocabularyRepository: const Vocabulary(),
          reviewMembershipLoader: load,
          reviewCountPolicy: CollectionReviewCountPolicy.distinctVocabulary,
          reviewSessionFactory: (id, direction) async {
            factories++;
            throw StateError('not launched');
          },
        ),
      ),
    );
    await settleReads(tester);
    expect(reads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleReads(tester);
    expect(reads, 2);
    expect(factories, 0);
  });

  testWidgets('count refreshes after returning from an accepted review', (
    tester,
  ) async {
    final f = Fixture(
      database: PikoDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
        clock: MutablePikoClock(instant),
      ),
    );
    await tester.runAsync(f.initialize);
    var reads = 0;
    Future<List<ReviewDueMembership>> load({
      required String collectionId,
      required DateTime at,
    }) async {
      reads++;
      return List.generate(reads, (index) => due(collectionId, index));
    }

    try {
      await tester.pumpWidget(
        PikoApp(
          home: Center(
            child: CollectionReviewEntryPoint(
              collection: f.owner,
              loader: load,
              policy: CollectionReviewCountPolicy.distinctVocabulary,
              factory: (collectionId, direction) async {
                final source = await f.learning.forCollection(
                  collectionId: collectionId,
                  direction: direction,
                );
                return DueLearningSession.start(
                  source: source,
                  cutoff: instant,
                  clock: f.db.clock,
                );
              },
              vocabularyRepository: f.vocabulary,
              beforeLaunch: () async {},
              onPendingWrites: null,
              onBusyChanged: (_) {},
              presentation: ReviewLaunchPresentation.collectionCard,
              clock: f.db.clock,
            ),
          ),
        ),
      );
      await settleReads(tester);
      expect(reads, 1);
      expect(find.text('FR → DE · 1 to review'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('collection-review-targetToNative')),
      );
      await tester.pump();
      await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      expect(find.byType(ReviewSessionRoute), findsOneWidget);

      Navigator.of(tester.element(find.byType(ReviewSessionRoute))).pop();
      await tester.pump();
      await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      expect(reads, 3); // Opening revalidates after draining accepted writes.
      expect(find.text('FR → DE · 3 to review'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(f.db.close);
    }
  });

  testWidgets('detail refreshes count after delete and Undo complete', (
    tester,
  ) async {
    final f = CollectionDeletionFixture();
    await tester.runAsync(f.initialize);
    var reads = 0;
    Future<List<ReviewDueMembership>> load({
      required String collectionId,
      required DateTime at,
    }) async {
      reads++;
      return [due(collectionId, reads)];
    }

    try {
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: f.collections,
            collectionId: f.owner.id,
            vocabularyRepository: f.repository,
            vocabularyMutationsFactory: (_) => f.mutations,
            reviewMembershipLoader: load,
            reviewCountPolicy: CollectionReviewCountPolicy.distinctVocabulary,
            reviewCountClock: f.clock,
            reviewSessionFactory: (id, direction) async =>
                throw StateError('Start was not requested'),
          ),
        ),
      );
      await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      expect(reads, 1);

      final entryId = f.entries.first.id;
      final card = find.byKey(ValueKey('vocabulary-$entryId'));
      await tester.drag(card, const Offset(-150, 0));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('vocabulary-row-$entryId'));
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is PikoButton && widget.label == 'Delete vocabulary',
          ),
        ),
      );
      await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      expect(reads, 2);

      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is PikoButton && widget.label == 'Undo',
        ),
      );
      await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      expect(reads, 3);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(f.db.close);
    }
  });
}
