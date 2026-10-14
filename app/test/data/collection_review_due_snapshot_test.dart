import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/learning_scheduler.dart';

import 'regular_reviews_test.dart' show Fixture, instant, rows;

void main() {
  test(
    'future regular card changes membership exactly at its due instant',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.db.close);
      await fixture.initialize();
      final source = await fixture.learning.forCollection(
        collectionId: fixture.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final item = (await source.items()).single;
      final due = instant.add(const Duration(minutes: 5));
      await fixture.learning.saveCard(item.id, item.card..due = due);

      final before = await source.dueMemberships(at: instant);
      expect(before, isEmpty);
      expect(before.nextChangeAt, due);

      final exact = await source.dueMemberships(at: due);
      expect(exact, hasLength(1));
      expect(exact.single.regularDue, isTrue);
      expect(exact.single.eligibleRetry, isFalse);
      expect(exact.nextChangeAt, isNull);
    },
  );

  test(
    'retry wait and expiry are passive exact boundaries without row cleanup',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.db.close);
      await fixture.initialize();
      final source = await fixture.learning.forCollection(
        collectionId: fixture.owner.id,
        direction: LearningDirection.targetToNative,
      );
      final round = (await fixture.review(
        rating: LearningRating.again,
      )).retryNext!;
      final blockedAt = instant.add(const Duration(seconds: 2));
      final armed = (await source.armBlockedWaits(
        expectedRounds: [round],
        remainingRegular: const [],
        at: blockedAt,
      )).state.rounds.single;
      final stored = await rows(fixture.db, 'retry_obligations');

      final waiting = await source.dueMemberships(at: blockedAt);
      expect(waiting, hasLength(1));
      expect(waiting.single.regularDue, isFalse);
      expect(waiting.single.eligibleRetry, isFalse);
      expect(waiting.nextChangeAt, armed.waitEligibleAt);

      final eligible = await source.dueMemberships(at: armed.waitEligibleAt!);
      expect(eligible.single.regularDue, isFalse);
      expect(eligible.single.eligibleRetry, isTrue);
      expect(eligible.nextChangeAt, armed.expiresAt);

      final expired = await source.dueMemberships(at: armed.expiresAt);
      expect(expired.every((membership) => !membership.eligibleRetry), isTrue);
      expect(await rows(fixture.db, 'retry_obligations'), stored);
    },
  );
}
