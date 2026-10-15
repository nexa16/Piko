import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/core/clock.dart';
import 'package:piko/core/learning_day.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/main.dart';

const fixturePrefix = 'piko-retry-expiry-android-';
final createdAt = DateTime.utc(2026, 10, 14, 3);

final class RetryExpiryClock implements PikoClock {
  RetryExpiryClock(DateTime initial) : _now = initial.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value.toUtc();
}

Future<Map<String, Object?>> snapshot(PikoDatabase db) => db.transaction(
  () async => {
    for (final table in db.allTables)
      table.actualTableName:
          (await db
                  .customSelect(
                    'SELECT rowid AS stored_rowid, * FROM '
                    '${table.actualTableName} ORDER BY rowid',
                  )
                  .get())
              .map((row) => row.data)
              .toList(),
  },
);

Future<List<Map<String, Object?>>> rows(PikoDatabase db, String table) async =>
    (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
        .map((row) => row.data)
        .toList();

Future<DueLearningSession> openSession(
  PikoDatabase db,
  String collectionId,
  RetryExpiryClock clock,
) async => DueLearningSession.start(
  source: await SqliteLearningRepository(db).forCollection(
    collectionId: collectionId,
    direction: LearningDirection.targetToNative,
  ),
  cutoff: clock.now(),
  clock: clock,
  presentationActive: false,
);

Future<void> stop(DueLearningSession? session) async {
  await session?.stop();
  session?.dispose();
}

/// RETRY-004 Android evidence for the device's existing GMT normal-day rules.
/// This fixture never changes timezone. Synthetic host tests retain ownership of
/// DST/23-hour/25-hour coverage; this is deliberately not Android DST proof.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android GMT local04 expiry preserves same-day retry state and expires without success',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp(fixturePrefix);
      final file = File('${directory.path}/test.sqlite');
      final clock = RetryExpiryClock(createdAt);
      PikoDatabase? db;
      DueLearningSession? session;
      try {
        // A neutral injected home guarantees this fixture never opens the
        // production runtime database.
        await tester.pumpWidget(const PikoApp(home: Scaffold()));

        const calendar = DeviceLearningDayCalendar();
        final localCreated = calendar.localDateTime(createdAt);
        expect(localCreated.timeZoneOffset, Duration.zero);
        expect(localCreated.hour, 3);
        final originalExpiry = LearningDay.nextBoundaryUtc(createdAt);
        expect(
          originalExpiry,
          calendar.localFourUtc(
            localCreated.year,
            localCreated.month,
            localCreated.day,
          ),
        );
        final localExpiry = calendar.localDateTime(originalExpiry);
        expect(localExpiry.timeZoneOffset, Duration.zero);
        expect(localExpiry.year, localCreated.year);
        expect(localExpiry.month, localCreated.month);
        expect(localExpiry.day, localCreated.day);
        expect(localExpiry.hour, 4);
        expect(localExpiry.minute, 0);

        db = PikoDatabase(NativeDatabase(file), clock: clock);
        final collection = await SqliteCollectionsRepository(db).create(
          name: 'Retry expiry Android',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final entry = await SqliteVocabularyRepository(db).create(
          collectionId: collection.id,
          targetText: 'matin',
          nativeText: 'Morgen',
        );
        final learning = SqliteLearningRepository(db);
        final initialItem = (await learning.forEntry(entry.id)).singleWhere(
          (item) => item.direction == LearningDirection.targetToNative,
        );
        session = await openSession(db, collection.id, clock);
        expect(session.progress.total, 1);
        expect(session.progress.completed, 0);
        expect(session.progress.firstTryCorrect, 0);
        expect(session.pendingItemCount, 1);
        final receipt =
            (await session.submitAnswerNow(
                  session.current!,
                  AnswerGrade.incorrect,
                ))!
                as RegularReviewReceipt;
        final originalRound = receipt.retryNext!;
        final armedRound = session.waitMutations.single.next;
        expect(originalRound.expiresAt, originalExpiry);
        expect(armedRound.expiresAt, originalExpiry);
        expect(
          armedRound.waitEligibleAt,
          createdAt.add(const Duration(seconds: 10)),
        );
        expect(armedRound.errorCount, 1);
        expect(armedRound.dueOrdinal, originalRound.dueOrdinal);
        expect(armedRound.dueOrdinal - receipt.scopeNext!.ordinal, 20);
        expect(armedRound.revision, originalRound.revision + 1);
        expect(session.current, isNull);
        expect(session.hasPendingRetryWork, isTrue);
        expect(session.progress.total, 1);
        expect(session.progress.completed, 0);
        expect(session.progress.firstTryCorrect, 0);
        expect(session.pendingItemCount, 1);
        final afterAgainItem = (await learning.forEntry(entry.id)).singleWhere(
          (item) => item.direction == LearningDirection.targetToNative,
        );
        final afterAgainHistory = await learning.reviewsForItem(initialItem.id);
        expect(afterAgainItem.cardJson, isNot(initialItem.cardJson));
        expect(afterAgainItem.reviewRevision, initialItem.reviewRevision + 1);
        expect(afterAgainHistory, hasLength(1));
        expect(afterAgainHistory.single.id, receipt.event.id);
        expect(afterAgainHistory.single.rating, LearningRating.again);
        final armedSnapshot = await snapshot(db);
        await stop(session);
        session = null;
        await db.close();
        db = null;

        // Reopening five seconds later preserves the original remaining wait,
        // answered-question gap and current-round fields without rearming.
        clock.set(createdAt.add(const Duration(seconds: 5)));
        db = PikoDatabase(NativeDatabase(file), clock: clock);
        session = await openSession(db, collection.id, clock);
        expect(session.current, isNull);
        expect(session.hasPendingRetryWork, isTrue);
        expect(session.waitMutations, isEmpty);
        expect(session.progress.total, 1);
        expect(session.progress.completed, 0);
        expect(session.progress.firstTryCorrect, 0);
        expect(session.pendingItemCount, 1);
        final sameDaySource = await SqliteLearningRepository(db).forCollection(
          collectionId: collection.id,
          direction: LearningDirection.targetToNative,
        );
        final sameDayState = await sameDaySource.retryState(at: clock.now());
        expect(sameDayState.rounds, hasLength(1));
        expect(sameDayState.rounds.single.sameStateAs(armedRound), isTrue);
        expect(
          sameDayState.rounds.single.dueOrdinal - sameDayState.scope.ordinal,
          20,
        );
        expect(
          sameDayState.rounds.single.waitEligibleAt!.difference(clock.now()),
          const Duration(seconds: 5),
        );
        expect(await snapshot(db), armedSnapshot);
        await stop(session);
        session = null;
        await db.close();
        db = null;

        // One microsecond before local 04:00, the original round is still the
        // displayed eligible retry with unchanged FSRS/history/counters.
        clock.set(originalExpiry.subtract(const Duration(microseconds: 1)));
        db = PikoDatabase(NativeDatabase(file), clock: clock);
        session = await openSession(db, collection.id, clock);
        expect(session.currentIsRetry, isTrue);
        expect(session.current!.item.id, originalRound.itemId);
        expect(session.progress.total, 1);
        expect(session.progress.completed, 0);
        expect(session.progress.firstTryCorrect, 0);
        expect(session.pendingItemCount, 1);
        final justBeforeProgress = session.progress;
        final justBeforeHandle = session.current!;
        expect(await snapshot(db), armedSnapshot);

        // Exact local 04:00 is expired, not a successful retry answer. Cleanup
        // removes only current-round state and cannot change history or FSRS.
        clock.set(originalExpiry);
        expect(
          await session.submitAnswerNow(justBeforeHandle, AnswerGrade.correct),
          isNull,
        );
        expect(session.current, isNull);
        expect(session.hasPendingRetryWork, isFalse);
        expect(session.lastAnswer, isNull);
        expect(session.lastProgressChange, isNull);
        expect(session.acceptedReviews, isEmpty);
        expect(session.progress, same(justBeforeProgress));
        expect(session.progress.total, 1);
        expect(session.progress.completed, 0);
        expect(session.progress.firstTryCorrect, 0);
        expect(session.pendingItemCount, 0);
        final expiredSnapshot = await snapshot(db);
        for (final table in armedSnapshot.keys) {
          if (table != 'retry_obligations') {
            expect(expiredSnapshot[table], armedSnapshot[table]);
          }
        }
        expect(expiredSnapshot['retry_obligations'], isEmpty);
        final expiredLearning = SqliteLearningRepository(db);
        final expiredItem = (await expiredLearning.forEntry(entry.id))
            .singleWhere(
              (item) => item.direction == LearningDirection.targetToNative,
            );
        final expiredHistory = await expiredLearning.reviewsForItem(
          initialItem.id,
        );
        expect(expiredItem.cardJson, afterAgainItem.cardJson);
        expect(expiredItem.reviewRevision, afterAgainItem.reviewRevision);
        expect(expiredHistory, hasLength(1));
        expect(expiredHistory.single.id, receipt.event.id);
        expect(expiredHistory.single.rating, LearningRating.again);
        final scope = (await rows(db, 'scope_answer_ordinals')).single;
        expect(scope['ordinal'], 1);
        expect(scope['revision'], 1);
        await stop(session);
        session = null;
        await db.close();
        db = null;

        // A backward clock after committed expiry cannot resurrect the round.
        clock.set(createdAt);
        db = PikoDatabase(NativeDatabase(file), clock: clock);
        session = await openSession(db, collection.id, clock);
        expect(session.hasPendingRetryWork, isFalse);
        expect(session.currentIsRetry, isFalse);
        expect(await rows(db, 'retry_obligations'), isEmpty);
        expect(await snapshot(db), expiredSnapshot);
        expect(tester.takeException(), isNull);
      } finally {
        await stop(session);
        await db?.close();
        await tester.pumpWidget(const SizedBox());
        // The gate uses --no-uninstall. Delete only this exact owned fixture;
        // production storage and the device timezone are never touched.
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith(fixturePrefix)) {
          throw StateError('Refusing cleanup outside owned retry fixture');
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
