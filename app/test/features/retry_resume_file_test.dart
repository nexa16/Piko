import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant;
import '../data/retry_gap_migration_test.dart' show gateway, storedSnapshot;
import '../support/mutable_clock.dart';

void main() {
  test(
    'reopened actual session retains unelapsed wait with regular work; matured wait takes priority without restoring an old sequence',
    () async {
      final directory = await Directory.systemTemp.createTemp('piko-resume-');
      final file = File('${directory.path}/resume.sqlite'),
          clock = MutablePikoClock(instant);
      PikoDatabase? openDb;
      DueLearningSession? session;
      try {
        final db = PikoDatabase(NativeDatabase(file), clock: clock);
        openDb = db;
        final f = Fixture(database: db);
        await f.initialize();
        final forward = (await f.review(
          rating: LearningRating.again,
        )).retryNext!;
        await f.review(reverse: true, rating: LearningRating.again);
        session = await DueLearningSession.start(
          source: await gateway(db, f.owner.id),
          cutoff: clock.now(),
          clock: clock,
          presentationActive: false,
        );
        final armed = session.waitMutations.single.next;
        expect(armed.id, forward.id);
        await session.stop();
        session.dispose();
        session = null;
        final other = await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Unanswered',
          nativeText: 'Unbeantwortet',
        );
        final before = await storedSnapshot(db), ownerId = f.owner.id;
        await db.close();
        openDb = null;
        clock.advance(const Duration(seconds: 9));
        final reopened = PikoDatabase(NativeDatabase(file), clock: clock);
        openDb = reopened;
        session = await DueLearningSession.start(
          source: await gateway(reopened, ownerId),
          cutoff: clock.now(),
          clock: clock,
          presentationActive: false,
        );
        expect(session.currentIsRetry, isFalse);
        expect(session.current!.item.entryId, other.id);
        expect(session.waitMutations, isEmpty);
        expect(
          (await (await gateway(
            reopened,
            ownerId,
          )).retryState(at: clock.now())).rounds.single.sameStateAs(armed),
          isTrue,
        );
        expect(await storedSnapshot(reopened), before);
        await session.stop();
        session.dispose();
        session = null;
        await reopened.close();
        openDb = null;
        clock.set(armed.waitEligibleAt!);
        final matured = PikoDatabase(NativeDatabase(file), clock: clock);
        openDb = matured;
        session = await DueLearningSession.start(
          source: await gateway(matured, ownerId),
          cutoff: clock.now(),
          clock: clock,
          presentationActive: false,
        );
        expect(session.currentIsRetry, isTrue);
        expect(session.current!.item.id, armed.itemId);
        expect(session.unreviewedMembers.single.entryId, other.id);
        expect(session.waitMutations, isEmpty);
        expect(session.lastAnswer, isNull);
        expect(await storedSnapshot(matured), before);
      } finally {
        await session?.stop();
        session?.dispose();
        await openDb?.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'reopened session at original04 removes only scoped expired obligation without success; backwards reopen cannot revive it',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-expired-resume-',
      );
      final file = File('${directory.path}/resume.sqlite'),
          clock = MutablePikoClock(instant);
      PikoDatabase? openDb;
      DueLearningSession? session;
      try {
        final db = PikoDatabase(NativeDatabase(file), clock: clock);
        openDb = db;
        final f = Fixture(database: db);
        await f.initialize();
        final forward = (await f.review(
          rating: LearningRating.again,
        )).retryNext!;
        await f.review(reverse: true, rating: LearningRating.again);
        session = await DueLearningSession.start(
          source: await gateway(db, f.owner.id),
          cutoff: instant,
          clock: clock,
          presentationActive: false,
        );
        await session.stop();
        session.dispose();
        session = null;
        final before = await storedSnapshot(db), ownerId = f.owner.id;
        final expected = {
          ...before,
          'retry_obligations': [
            for (final row in (before['retry_obligations'] as List).cast<Map>())
              if (row['id'] != forward.id) row,
          ],
        };
        await db.close();
        openDb = null;
        clock.set(forward.expiresAt);
        final reopened = PikoDatabase(NativeDatabase(file), clock: clock);
        openDb = reopened;
        session = await DueLearningSession.start(
          source: await gateway(reopened, ownerId),
          cutoff: clock.now(),
          clock: clock,
          presentationActive: false,
        );
        expect(session.current, isNull);
        expect(session.hasPendingRetryWork, isFalse);
        expect(session.lastAnswer, isNull);
        expect(session.acceptedReviews, isEmpty);
        expect(await storedSnapshot(reopened), expected);
        await session.stop();
        session.dispose();
        session = null;
        await reopened.close();
        openDb = null;
        clock.set(instant);
        final backwards = PikoDatabase(NativeDatabase(file), clock: clock);
        openDb = backwards;
        session = await DueLearningSession.start(
          source: await gateway(backwards, ownerId),
          cutoff: instant,
          clock: clock,
          presentationActive: false,
        );
        expect(session.current, isNull);
        expect(session.hasPendingRetryWork, isFalse);
        expect(await storedSnapshot(backwards), expected);
      } finally {
        await session?.stop();
        session?.dispose();
        await openDb?.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
