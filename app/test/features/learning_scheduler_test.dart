import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/learning_scheduler.dart';

LearningItemRecord item(
  fsrs.Card card, {
  String entryId = 'entry-a',
  LearningDirection direction = LearningDirection.targetToNative,
}) => LearningItemRecord(
  id: card.cardId,
  entryId: entryId,
  direction: direction,
  cardJson: LearningCardCodec.encode(card),
  formatVersion: LearningCardCodec.version,
);

LearningItemRecord altered(
  LearningItemRecord before, {
  int? id,
  String? entryId,
  int? version,
  String? json,
}) => LearningItemRecord(
  id: id ?? before.id,
  entryId: entryId ?? before.entryId,
  direction: before.direction,
  cardJson: json ?? before.cardJson,
  formatVersion: version ?? before.formatVersion,
);

void main() {
  final at = DateTime.utc(2026, 10, 14, 12, 34, 56, 789, 123);
  final reference = fsrs.Scheduler(
    desiredRetention: 0.9,
    learningSteps: const [],
    relearningSteps: const [],
    enableFuzzing: false,
  );
  final scheduler = LearningScheduler();
  test(
    'pure schedule preserves generation and optimistic review revision metadata',
    () {
      final before = LearningItemRecord(
        id: 77,
        entryId: 'entry',
        direction: LearningDirection.nativeToTarget,
        cardJson: LearningCardCodec.encode(fsrs.Card(cardId: 77, due: at)),
        formatVersion: LearningCardCodec.version,
        generation: 9,
        reviewRevision: 12,
      );
      final result = scheduler.review(
        before,
        rating: LearningRating.good,
        reviewedAt: at,
      );
      expect(result.prior.generation, 9);
      expect(result.next.generation, 9);
      expect(result.prior.reviewRevision, 12);
      expect(result.next.reviewRevision, 12);
    },
  );
  final rated = {
    LearningRating.again: fsrs.Rating.again,
    LearningRating.hard: fsrs.Rating.hard,
    LearningRating.good: fsrs.Rating.good,
  };
  final scenarios = <String, fsrs.Card>{
    'new': fsrs.Card(cardId: 1, due: at),
    'review on due day': fsrs.Card(
      cardId: 2,
      state: fsrs.State.review,
      stability: 5.25,
      difficulty: 4.75,
      due: at,
      lastReview: at.subtract(const Duration(days: 5)),
    ),
    'same instant': fsrs.Card(
      cardId: 3,
      state: fsrs.State.review,
      stability: 5.25,
      difficulty: 4.75,
      due: at.add(const Duration(days: 5)),
      lastReview: at,
    ),
    'same day': fsrs.Card(
      cardId: 4,
      state: fsrs.State.review,
      stability: 5.25,
      difficulty: 4.75,
      due: at.add(const Duration(days: 5)),
      lastReview: at.subtract(const Duration(hours: 3)),
    ),
    'before 24 hours': fsrs.Card(
      cardId: 5,
      state: fsrs.State.review,
      stability: 5.25,
      difficulty: 4.75,
      due: at,
      lastReview: at
          .subtract(const Duration(hours: 24))
          .add(const Duration(microseconds: 1)),
    ),
    'at 24 hours': fsrs.Card(
      cardId: 6,
      state: fsrs.State.review,
      stability: 5.25,
      difficulty: 4.75,
      due: at,
      lastReview: at.subtract(const Duration(hours: 24)),
    ),
    'long lapse': fsrs.Card(
      cardId: 7,
      state: fsrs.State.review,
      stability: 19.5,
      difficulty: 7.25,
      due: at.subtract(const Duration(days: 365)),
      lastReview: at.subtract(const Duration(days: 730)),
    ),
    'legacy learning step': fsrs.Card(
      cardId: 8,
      state: fsrs.State.learning,
      step: 4,
      stability: 1.5,
      difficulty: 7.25,
      due: at,
      lastReview: at.subtract(const Duration(minutes: 5)),
    ),
    'legacy relearning': fsrs.Card(
      cardId: 9,
      state: fsrs.State.relearning,
      step: 4,
      stability: 2.5,
      difficulty: 7.25,
      due: at,
      lastReview: at.subtract(const Duration(days: 2)),
    ),
  };

  for (final scenario in scenarios.entries) {
    for (final rating in rated.entries) {
      test(
        '${scenario.key} ${rating.key.name} matches complete pinned-library output',
        () {
          final before = item(scenario.value);
          final exactJson = before.cardJson;
          final direct = reference.reviewCard(
            before.card,
            rating.value,
            reviewDateTime: at,
          );
          final result = scheduler.review(
            before,
            rating: rating.key,
            reviewedAt: at,
          );
          expect(result.next.card.toMap(), direct.card.toMap());
          expect(result.next.cardJson, LearningCardCodec.encode(direct.card));
          expect(identical(result.prior, before), isTrue);
          expect(result.prior.cardJson, exactJson);
          expect(result.prior.formatVersion, before.formatVersion);
          expect(result.next.id, before.id);
          expect(result.next.entryId, before.entryId);
          expect(result.next.direction, before.direction);
          expect(result.next.formatVersion, before.formatVersion);
          expect(result.rating, rating.key);
          expect(result.reviewedAt, at);
          expect(direct.reviewLog.rating, rating.value);
          expect(direct.reviewLog.reviewDateTime, at);
          expect(result.next.card.lastReview, at);
          expect(result.next.card.state, fsrs.State.review);
          expect(result.next.card.step, isNull);
          expect(
            result.next.card.due.difference(at).inDays,
            greaterThanOrEqualTo(1),
          );
          expect(before.cardJson, exactJson);
        },
      );
    }
  }

  test(
    'empty steps disable minute scheduling; defaults retain weights and maximum interval',
    () {
      expect(reference.parameters, fsrs.defaultParameters);
      expect(reference.maximumInterval, 36500);
      for (final rating in rated.keys) {
        final result = scheduler.review(
          item(scenarios['new']!),
          rating: rating,
          reviewedAt: at,
        );
        expect(
          result.next.card.due.difference(at).inDays,
          greaterThanOrEqualTo(1),
        );
      }
      final extreme = item(
        fsrs.Card(
          cardId: 10,
          state: fsrs.State.review,
          stability: 1000000,
          difficulty: 1,
          due: at,
          lastReview: at,
        ),
      );
      final result = scheduler.review(
        extreme,
        rating: LearningRating.good,
        reviewedAt: at,
      );
      expect(result.next.card.due, at.add(const Duration(days: 36500)));
    },
  );

  test('same-day boundary follows library branch without custom rounding', () {
    final early = scheduler.review(
      item(scenarios['before 24 hours']!),
      rating: LearningRating.good,
      reviewedAt: at,
    );
    final late = scheduler.review(
      item(scenarios['at 24 hours']!),
      rating: LearningRating.good,
      reviewedAt: at,
    );
    expect(early.next.card.stability, isNot(late.next.card.stability));
    expect(early.next.card.lastReview, at);
    expect(late.next.card.lastReview, at);
  });

  test(
    'fuzz disabled gives identical state repeatedly and across independent adapters',
    () {
      final before = item(scenarios['review on due day']!);
      final expected = scheduler.review(
        before,
        rating: LearningRating.good,
        reviewedAt: at,
      );
      for (var count = 0; count < 25; count++) {
        expect(
          scheduler
              .review(before, rating: LearningRating.good, reviewedAt: at)
              .next
              .cardJson,
          expected.next.cardJson,
        );
        expect(
          LearningScheduler()
              .review(before, rating: LearningRating.good, reviewedAt: at)
              .next
              .cardJson,
          expected.next.cardJson,
        );
      }
    },
  );

  test(
    'prior exact JSON formatting and independent direction state survive card clone mutation',
    () {
      final card = scenarios['review on due day']!;
      final original = item(card);
      final rawJson = const JsonEncoder.withIndent('  ').convert(card.toMap());
      final before = altered(original, json: rawJson);
      final reverse = item(
        fsrs.Card(
          cardId: 22,
          state: fsrs.State.review,
          stability: 50.5,
          difficulty: 9.25,
          due: at.add(const Duration(days: 30)),
          lastReview: at.subtract(const Duration(days: 30)),
        ),
        direction: LearningDirection.nativeToTarget,
      );
      final untouched = reverse.cardJson;
      final result = scheduler.review(
        before,
        rating: LearningRating.hard,
        reviewedAt: at,
      );
      before.card.stability = 999;
      result.prior.card.difficulty = 1;
      result.next.card.stability = 999;
      result.next.card.due = DateTime.utc(2000);
      reverse.card.difficulty = 1;
      expect(result.prior.cardJson, rawJson);
      expect(before.card.toMap(), card.toMap());
      expect(result.next.card.stability, isNot(999));
      expect(result.next.card.due.isAfter(at), isTrue);
      expect(reverse.cardJson, untouched);
      final opposite = scheduler.review(
        reverse,
        rating: LearningRating.again,
        reviewedAt: at,
      );
      expect(opposite.next.id, 22);
      expect(opposite.next.entryId, before.entryId);
      expect(opposite.next.direction, LearningDirection.nativeToTarget);
      expect(result.next.direction, LearningDirection.targetToNative);
      expect(result.next.cardJson, isNot(opposite.next.cardJson));
    },
  );

  test(
    'explicit time retained without due gating; non-UTC and backward review rejected',
    () {
      final before = item(scenarios['same instant']!);
      final same = scheduler.review(
        before,
        rating: LearningRating.again,
        reviewedAt: at,
      );
      expect(same.reviewedAt, at);
      expect(same.next.card.lastReview, at);
      expect(
        () => scheduler.review(
          before,
          rating: LearningRating.good,
          reviewedAt: DateTime(2026, 10, 14),
        ),
        throwsArgumentError,
      );
      expect(
        () => scheduler.review(
          before,
          rating: LearningRating.good,
          reviewedAt: at.subtract(const Duration(microseconds: 1)),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'corrupt identity, version and memory state fail closed without changing prior',
    () {
      final before = item(scenarios['new']!);
      final invalid = [
        altered(before, id: 0),
        altered(before, id: 2),
        altered(before, entryId: ''),
        altered(before, entryId: '  '),
        altered(before, version: 2),
        altered(before, json: '{}'),
        altered(before, json: '{'),
        for (final patch in [
          {'state': 4},
          {'step': -1},
          {'state': 2, 'step': null},
          {'stability': 1.5},
          {'difficulty': 11},
          {'due': 'not-time'},
          {'lastReview': at.toIso8601String()},
          {'extra': true},
        ])
          altered(before, json: jsonEncode({...before.card.toMap(), ...patch})),
      ];
      for (final corrupt in invalid) {
        final json = corrupt.cardJson;
        expect(
          () => scheduler.review(
            corrupt,
            rating: LearningRating.good,
            reviewedAt: at,
          ),
          throwsFormatException,
        );
        expect(corrupt.cardJson, json);
      }
      expect(LearningRating.values, [
        LearningRating.again,
        LearningRating.hard,
        LearningRating.good,
      ]);
    },
  );
}
