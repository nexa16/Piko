import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/core/clock.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/review_due_membership.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';

const collection = CollectionRecord(
  id: 'c',
  name: 'Words',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);
CollectionQuerySnapshot snapshot({DateTime? boundary}) =>
    CollectionQuerySnapshot(
      collection: collection,
      allEntries: [],
      entries: [],
      categoryDimensions: [],
      categoryValues: {
        'd': [
          const CategoryValueRecord(
            id: 'v',
            dimensionId: 'd',
            name: 'Value',
            position: 0,
          ),
        ],
      },
      assignments: {},
      directions: {
        LearningDirection.targetToNative: CollectionDirectionSnapshot(
          newSpeedItems: [],
          review: ReviewDueMembershipSnapshot(
            memberships: [],
            nextChangeAt: boundary,
          ),
        ),
      },
    );

class Call {
  Call(this.search, this.filters);
  final String search;
  final Map<String, Set<String>> filters;
  final result = Completer<CollectionQuerySnapshot>();
}

class Query implements CollectionQueryService {
  final calls = <Call>[];
  @override
  Future<CollectionQuerySnapshot> query({
    required String collectionId,
    required DateTime at,
    Map<String, Set<String>> filters = const {},
    String search = '',
  }) {
    final call = Call(search, filters);
    calls.add(call);
    return call.result.future;
  }
}

class Clock implements PikoClock {
  DateTime value = DateTime.utc(2026, 10, 16);
  @override
  DateTime now() => value;
}

void main() {
  testWidgets(
    'latest query wins; loading and failures retain the last snapshot without claiming readiness',
    (tester) async {
      final query = Query(),
          scope = CollectionViewScope(),
          changes = StreamController<void>.broadcast();
      final pending = <Future<void>>[];
      final binding = CollectionQueryBinding(
        collectionId: 'c',
        service: query,
        scope: scope,
        invalidations: changes.stream,
        onPendingWrites: pending.add,
      );
      final first = snapshot(), newest = snapshot();
      query.calls[0].result.complete(first);
      await tester.pump();
      expect(binding.ready, isTrue);
      scope.setSearch('new');
      expect(binding.loading, isTrue);
      expect(binding.ready, isFalse);
      expect(binding.snapshot, same(first));
      scope.setSearch('newer');
      query.calls[2].result.complete(newest);
      await tester.pump();
      query.calls[1].result.completeError(StateError('late failure'));
      await tester.pump();
      expect(binding.snapshot, same(newest));
      expect(binding.error, isNull);
      changes.add(null);
      await tester.pump();
      query.calls.last.result.completeError(StateError('offline read failed'));
      await tester.pump();
      expect(binding.ready, isFalse);
      expect(binding.snapshot, same(newest));
      expect(binding.error, isA<StateError>());
      expect(query.calls.map((c) => c.search), ['', 'new', 'newer', 'newer']);
      binding.dispose();
      scope.dispose();
      await changes.close();
      await Future.wait(pending);
    },
  );

  testWidgets(
    'deleted constraints are pruned without clearing retained search or surviving filter values',
    (tester) async {
      final query = Query(),
          scope = CollectionViewScope(),
          changes = StreamController<void>.broadcast();
      scope.setSearch('Maße');
      scope.setFilters({
        'd': {'v', 'deleted'},
        'gone': {'old'},
      });
      final binding = CollectionQueryBinding(
        collectionId: 'c',
        service: query,
        scope: scope,
        invalidations: changes.stream,
      );
      query.calls[0].result.completeError(CollectionQueryFailure.invalidFilter);
      await tester.pump();
      expect(query.calls[1].search, '');
      expect(query.calls[1].filters, isEmpty);
      query.calls[1].result.complete(snapshot());
      await tester.pump();
      expect(scope.search, 'Maße');
      expect(scope.filters, {
        'd': {'v'},
      });
      expect(query.calls[2].search, 'Maße');
      query.calls[2].result.complete(snapshot());
      await tester.pump();
      expect(binding.ready, isTrue);
      binding.dispose();
      scope.dispose();
      await changes.close();
    },
  );

  testWidgets(
    'deadline and resume requery authoritative state; background invalidations do not start work',
    (tester) async {
      final query = Query(),
          scope = CollectionViewScope(),
          changes = StreamController<void>.broadcast(),
          clock = Clock();
      final binding = CollectionQueryBinding(
        collectionId: 'c',
        service: query,
        scope: scope,
        invalidations: changes.stream,
        clock: clock,
      );
      query.calls[0].result.complete(
        snapshot(boundary: clock.value.add(const Duration(seconds: 10))),
      );
      await tester.pump();
      clock.value = clock.value.add(const Duration(seconds: 9));
      await tester.pump(const Duration(seconds: 9));
      expect(query.calls.length, 1);
      clock.value = clock.value.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(query.calls.length, 2);
      binding.didChangeAppLifecycleState(AppLifecycleState.paused);
      query.calls[1].result.complete(snapshot());
      changes.add(null);
      await tester.pump();
      expect(query.calls.length, 2);
      binding.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(query.calls.length, 3);
      query.calls[2].result.complete(snapshot());
      await tester.pump();
      expect(binding.ready, isTrue);
      binding.dispose();
      scope.dispose();
      await changes.close();
    },
  );

  testWidgets(
    'disposal suppresses late notifications while registered reads finish safely',
    (tester) async {
      final query = Query(),
          scope = CollectionViewScope(),
          changes = StreamController<void>.broadcast();
      final pending = <Future<void>>[];
      final binding = CollectionQueryBinding(
        collectionId: 'c',
        service: query,
        scope: scope,
        invalidations: changes.stream,
        onPendingWrites: pending.add,
      );
      var notified = 0;
      binding.addListener(() => notified++);
      binding.dispose();
      query.calls.single.result.completeError(StateError('late'));
      await tester.pump();
      await Future.wait(pending);
      expect(notified, 0);
      scope.dispose();
      await changes.close();
    },
  );

  testWidgets(
    'count projection retains same-scope success/error but never borrows changed scope or late results',
    (tester) async {
      final query = Query(),
          scope = CollectionViewScope(),
          changes = StreamController<void>.broadcast();
      final binding = CollectionQueryBinding(
        collectionId: 'c',
        service: query,
        scope: scope,
        invalidations: changes.stream,
      );
      final first = snapshot(), current = snapshot();
      expect(binding.countSnapshot, isNull);
      query.calls[0].result.complete(first);
      await tester.pump();
      binding.refresh();
      expect(binding.countSnapshot, same(first));
      query.calls[1].result.completeError(StateError('read'));
      await tester.pump();
      expect(binding.countSnapshot, same(first));
      expect(binding.ready, isFalse);
      binding.refresh();
      scope.setSearch('different');
      expect(binding.countSnapshot, isNull);
      expect(
        binding.snapshot,
        same(first),
      ); // List anchoring has separate ownership.
      query.calls[3].result.complete(current);
      await tester.pump();
      query.calls[2].result.complete(first);
      await tester.pump();
      expect(binding.countSnapshot, same(current));
      scope.setFilters({
        'd': {'v'},
      });
      expect(binding.countSnapshot, isNull);
      query.calls.last.result.completeError(StateError('new scope failed'));
      await tester.pump();
      expect(binding.countSnapshot, isNull);
      expect(binding.error, isA<StateError>());
      binding.dispose();
      scope.dispose();
      await changes.close();
    },
  );
}
