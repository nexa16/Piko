import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/review_due_membership.dart';
import 'package:piko/features/collections/collection_review_count.dart';

import '../support/mutable_clock.dart';

class BoundaryTimer implements Timer {
  BoundaryTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool active = true;

  void fire() {
    if (!active) return;
    active = false;
    callback();
  }

  @override
  void cancel() => active = false;

  @override
  bool get isActive => active;

  @override
  int get tick => active ? 0 : 1;
}

ReviewDueMembership membership({
  required String entry,
  required int item,
  required LearningDirection direction,
  bool regularDue = false,
  bool eligibleRetry = false,
}) => ReviewDueMembership(
  entryId: entry,
  itemId: item,
  generation: 0,
  direction: direction,
  regularDue: regularDue,
  eligibleRetry: eligibleRetry,
);

void main() {
  test(
    'both explicit count policies deduplicate only their selected identity',
    () {
      final records = [
        membership(
          entry: 'one',
          item: 1,
          direction: LearningDirection.targetToNative,
          regularDue: true,
        ),
        membership(
          entry: 'one',
          item: 2,
          direction: LearningDirection.nativeToTarget,
          eligibleRetry: true,
        ),
        membership(
          entry: 'one',
          item: 2,
          direction: LearningDirection.nativeToTarget,
          eligibleRetry: true,
        ),
        membership(
          entry: 'future',
          item: 3,
          direction: LearningDirection.targetToNative,
        ),
      ];

      expect(
        aggregateCollectionReviewCount(
          records,
          CollectionReviewCountPolicy.distinctVocabulary,
        ),
        1,
      );
      expect(
        aggregateCollectionReviewCount(
          records,
          CollectionReviewCountPolicy.dueDirectionCards,
        ),
        2,
      );
    },
  );

  test(
    'latest passive snapshot wins and receives the explicit UTC instant',
    () async {
      final now = DateTime.utc(2026, 10, 14, 9);
      final first = Completer<List<ReviewDueMembership>>();
      final second = Completer<List<ReviewDueMembership>>();
      final calls = <DateTime>[];
      var invocation = 0;
      final count = CollectionReviewCount(
        collectionId: 'owner',
        policy: CollectionReviewCountPolicy.dueDirectionCards,
        clock: MutablePikoClock(now),
        loader: ({required collectionId, required at}) {
          expect(collectionId, 'owner');
          calls.add(at);
          return invocation++ == 0 ? first.future : second.future;
        },
      );
      addTearDown(count.dispose);

      final oldRefresh = count.refresh();
      final currentRefresh = count.refresh();
      second.complete([
        membership(
          entry: 'one',
          item: 1,
          direction: LearningDirection.targetToNative,
          regularDue: true,
        ),
      ]);
      await currentRefresh;
      expect(count.value, 1);
      first.complete(const []);
      await oldRefresh;
      expect(count.value, 1);
      expect(calls, [now, now]);
      expect(calls.every((instant) => instant.isUtc), isTrue);
    },
  );

  test(
    'failure retains no invented initial count and supports explicit retry',
    () async {
      var fail = true;
      final count = CollectionReviewCount(
        collectionId: 'owner',
        policy: CollectionReviewCountPolicy.distinctVocabulary,
        loader: ({required collectionId, required at}) async {
          if (fail) throw StateError('read');
          return [
            membership(
              entry: 'one',
              item: 1,
              direction: LearningDirection.targetToNative,
              eligibleRetry: true,
            ),
          ];
        },
      );
      addTearDown(count.dispose);

      await count.refresh();
      expect(count.value, isNull);
      expect(count.error, isA<StateError>());
      fail = false;
      await count.refresh();
      expect(count.value, 1);
      expect(count.error, isNull);
    },
  );

  test(
    'next passive boundary refreshes and publishes the fresh count',
    () async {
      final now = DateTime.utc(2026, 10, 14, 9);
      final boundary = now.add(const Duration(seconds: 10));
      final clock = MutablePikoClock(now);
      final timers = <BoundaryTimer>[];
      final published = Completer<void>();
      var reads = 0;
      final count = CollectionReviewCount(
        collectionId: 'owner',
        policy: CollectionReviewCountPolicy.distinctVocabulary,
        clock: clock,
        timerFactory: (duration, callback) {
          final timer = BoundaryTimer(duration, callback);
          timers.add(timer);
          return timer;
        },
        loader: ({required collectionId, required at}) async {
          reads++;
          if (reads == 1) {
            expect(at, now);
            return ReviewDueMembershipSnapshot(
              memberships: const [],
              nextChangeAt: boundary,
            );
          }
          expect(at, boundary);
          return ReviewDueMembershipSnapshot(
            memberships: [
              membership(
                entry: 'one',
                item: 1,
                direction: LearningDirection.targetToNative,
                regularDue: true,
              ),
            ],
            nextChangeAt: null,
          );
        },
      );
      count.addListener(() {
        if (!count.loading && count.value == 1 && !published.isCompleted) {
          published.complete();
        }
      });
      addTearDown(count.dispose);

      await count.refresh();
      expect(count.value, 0);
      expect(timers.single.duration, const Duration(seconds: 10));
      clock.set(boundary);
      timers.single.fire();
      await published.future;
      expect(reads, 2);
      expect(count.value, 1);
      expect(timers, hasLength(1));
    },
  );

  test(
    'manual refresh replaces its boundary timer and dispose cancels it',
    () async {
      final now = DateTime.utc(2026, 10, 14, 9);
      final clock = MutablePikoClock(now);
      final timers = <BoundaryTimer>[];
      var reads = 0;
      final count = CollectionReviewCount(
        collectionId: 'owner',
        policy: CollectionReviewCountPolicy.distinctVocabulary,
        clock: clock,
        timerFactory: (duration, callback) {
          final timer = BoundaryTimer(duration, callback);
          timers.add(timer);
          return timer;
        },
        loader: ({required collectionId, required at}) async {
          reads++;
          return ReviewDueMembershipSnapshot(
            memberships: const [],
            nextChangeAt: now.add(Duration(seconds: reads * 10)),
          );
        },
      );

      await count.refresh();
      expect(timers.single.isActive, isTrue);
      await count.refresh();
      expect(timers, hasLength(2));
      expect(timers.first.isActive, isFalse);
      expect(timers.last.duration, const Duration(seconds: 20));
      count.dispose();
      expect(timers.last.isActive, isFalse);
    },
  );
}
