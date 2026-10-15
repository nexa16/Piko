import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/review_due_membership.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner, one, two;
import 'collection_review_entry_points_test.dart' show Collections;

CollectionQuerySnapshot projection({
  List<VocabularyRecord> all = const [one, two],
  List<VocabularyRecord> visible = const [one, two],
  int forward = 0,
  int reverse = 0,
  bool pending = false,
}) => CollectionQuerySnapshot(
  collection: owner,
  allEntries: all,
  entries: visible,
  categoryDimensions: const [],
  categoryValues: const {},
  assignments: const {},
  directions: {
    for (final direction in LearningDirection.values)
      direction: CollectionDirectionSnapshot(
        review: ReviewDueMembershipSnapshot(
          memberships: [
            for (
              var index = 0;
              index <
                  (direction == LearningDirection.targetToNative
                      ? forward
                      : reverse);
              index++
            )
              ReviewDueMembership(
                entryId: 'due-$index',
                itemId: index,
                generation: 0,
                direction: direction,
                regularDue: true,
                eligibleRetry: false,
              ),
            if (pending)
              ReviewDueMembership(
                entryId: 'waiting',
                itemId: 90,
                generation: 0,
                direction: direction,
                regularDue: false,
                eligibleRetry: false,
              ),
          ],
          nextChangeAt: null,
        ),
        newSpeedItems: const [],
      ),
  },
);

class ProjectionService implements CollectionQueryService {
  ProjectionService(this.value);
  CollectionQuerySnapshot value;
  Object? error;
  Completer<CollectionQuerySnapshot>? gate;
  @override
  Future<CollectionQuerySnapshot> query({
    required String collectionId,
    required DateTime at,
    Map<String, Set<String>> filters = const {},
    String search = '',
  }) async {
    if (error != null) throw error!;
    final pending = gate;
    if (pending != null) return pending.future;
    return value;
  }
}

void main() {
  Future<CollectionQueryBinding> mount(
    WidgetTester tester,
    ProjectionService service, {
    LiveVocabulary? vocabulary,
  }) async {
    final scope = CollectionViewScope();
    final binding = CollectionQueryBinding(
      collectionId: owner.id,
      service: service,
      scope: scope,
      invalidations: const Stream<void>.empty(),
    );
    final repository = vocabulary ?? LiveVocabulary();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      binding.dispose();
      scope.dispose();
      await repository.close();
    });
    await tester.pumpWidget(
      PikoApp(
        home: CollectionDetail(
          repository: const Collections([owner]),
          collectionId: owner.id,
          vocabularyRepository: repository,
          queryBinding: binding,
          reviewSessionFactory: (_, _) async =>
              throw StateError('No session requested'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return binding;
  }

  testWidgets(
    'one projection supplies filtered row order and directional review actions',
    (tester) async {
      final binding = await mount(
        tester,
        ProjectionService(projection(visible: [two], forward: 2, reverse: 1)),
      );
      expect(find.byKey(const ValueKey('vocabulary-one')), findsNothing);
      expect(find.byKey(const ValueKey('vocabulary-two')), findsOneWidget);
      expect(find.text('FR → DE · 2 to review'), findsOneWidget);
      expect(find.text('DE → FR · 1 to review'), findsOneWidget);
      final first = tester.widget<PikoButton>(
        find.byKey(const ValueKey('collection-review-targetToNative')),
      );
      final second = tester.widget<PikoButton>(
        find.byKey(const ValueKey('collection-review-nativeToTarget')),
      );
      expect(first.variant, PikoButtonVariant.reviewPrimary);
      expect(second.variant, PikoButtonVariant.reviewSecondary);
      expect(binding.snapshot!.entries.single.id, two.id);
    },
  );

  testWidgets(
    'Home passes its Detail binding and filtered factory without changing Overview launch',
    (tester) async {
      final scope = CollectionViewScope();
      final binding = CollectionQueryBinding(
        collectionId: owner.id,
        service: ProjectionService(projection()),
        scope: scope,
        invalidations: const Stream<void>.empty(),
      );
      final vocabulary = LiveVocabulary();
      Future<DueLearningSession> overview(
        String _,
        LearningDirection _,
      ) async => throw StateError('overview');
      Future<DueLearningSession> detail(String _, LearningDirection _) async =>
          throw StateError('detail');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        binding.dispose();
        scope.dispose();
        await vocabulary.close();
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionsHome(
            repository: const Collections([owner]),
            vocabularyRepository: vocabulary,
            reviewSessionFactory: overview,
            detailReviewSessionFactory: detail,
            queryBindingFactory: (_) => binding,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final home = tester.widget<CollectionsHome>(find.byType(CollectionsHome));
      expect(home.reviewSessionFactory, same(overview));
      await tester.tap(find.byKey(ValueKey('collection-${owner.id}')));
      await tester.pumpAndSettle();
      final route = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      expect(route.queryBinding, same(binding));
      expect(route.reviewSessionFactory, same(detail));
    },
  );

  testWidgets(
    'empty, caught-up, filtered, pending and failed states remain distinct',
    (tester) async {
      final service = ProjectionService(projection(all: [], visible: []));
      final binding = await mount(tester, service);
      expect(find.text("Great work! You're all caught up."), findsNothing);
      service.value = projection();
      binding.refresh();
      await tester.pumpAndSettle();
      expect(find.text("Great work! You're all caught up."), findsOneWidget);
      binding.scope.setSearch('word');
      await tester.pumpAndSettle();
      expect(find.text("Great work! You're all caught up."), findsNothing);
      expect(
        find.text('Nothing to review in this selection right now.'),
        findsOneWidget,
      );
      service.value = projection(visible: []);
      binding.refresh();
      await tester.pumpAndSettle();
      expect(find.text('No vocabulary matches these filters.'), findsOneWidget);
      service.value = projection(pending: true);
      binding.refresh();
      await tester.pumpAndSettle();
      expect(find.text('A repetition is waiting for you.'), findsOneWidget);
      service.error = StateError('unavailable');
      binding.refresh();
      await tester.pumpAndSettle();
      expect(find.text("Great work! You're all caught up."), findsNothing);
      expect(
        find.byKey(const ValueKey('collection-review-targetToNative')),
        findsNothing,
      );
      service.error = null;
      service.gate = Completer<CollectionQuerySnapshot>();
      binding.refresh();
      await tester.pump();
      expect(find.text('A repetition is waiting for you.'), findsNothing);
      service.gate!.complete(projection());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'projection refresh and temporary filtering preserve an invalid raw editor',
    (tester) async {
      final vocabulary = LiveVocabulary();
      final service = ProjectionService(projection());
      final binding = await mount(tester, service, vocabulary: vocabulary);
      await tester.tap(find.byKey(const ValueKey('vocabulary-one')));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byKey(const ValueKey('inline-one-target')),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '  ');
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(field).controller;
      service.value = projection(visible: [two]);
      binding.scope.setSearch('school');
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      service.value = projection(visible: [two, one]);
      binding.scope.setSearch('');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller!.text, '  ');
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('vocabulary-two'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('vocabulary-one'))).dy,
        ),
      );
    },
  );
}
