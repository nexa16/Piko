import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/core/clock.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';

import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

const fixturePrefix = 'piko-review-correction-verification-';
final fixtureInstant = DateTime.utc(2026, 10, 14, 9, 10, 11, 123, 456);

/// Mutable only so the test can cross the production ten-second retry wait
/// without sleeping. The session, repository and persisted timestamps all use
/// this injected database clock.
final class ReviewFixtureClock implements PikoClock {
  ReviewFixtureClock(DateTime initial) : _now = initial.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value.toUtc();
}

/// Every connection is explicitly injected from the newly created fixture
/// file. The production Piko database is never opened.
final class ReviewFixtureDatabase extends PikoDatabase {
  ReviewFixtureDatabase(File file, ReviewFixtureClock clock)
    : super(NativeDatabase(file), clock: clock);

  final closed = Completer<void>();
  bool _closing = false;

  @override
  Future<void> close() async {
    if (_closing) return closed.future;
    _closing = true;
    try {
      await super.close();
      closed.complete();
    } catch (error, stack) {
      closed.completeError(error, stack);
      rethrow;
    }
  }
}

Finder button(String label) => find.widgetWithText(PikoButton, label);
Finder get revealTarget => find.byKey(const ValueKey('review-reveal-target'));
Finder gradeButton(AnswerGrade grade) =>
    find.byKey(ValueKey('review-grade-${grade.name}'));

Future<void> waitUntil(
  WidgetTester tester,
  FutureOr<bool> Function() ready, {
  String description = 'review fixture state',
}) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (await ready()) return;
  }
  throw StateError('Timed out waiting for $description');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await waitUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    description: '$finder',
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<List<Map<String, Object?>>> rows(PikoDatabase db, String table) async =>
    (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
        .map((row) => row.data)
        .toList();

Future<List<Map<String, Object?>>> directionState(
  PikoDatabase db,
  String collectionId,
  LearningDirection direction,
) async =>
    (await db
            .customSelect(
              'SELECT l.id,l.entry_id,l.direction,l.format_version,l.card_json,'
              'l.generation,l.review_revision FROM learning_items l '
              'JOIN vocabulary_entries v ON v.id=l.entry_id '
              'WHERE v.collection_id=? AND l.direction=? ORDER BY l.id',
              variables: [
                Variable<String>(collectionId),
                Variable<String>(direction.name),
              ],
            )
            .get())
        .map((row) => row.data)
        .toList();

Future<void> startReview(
  WidgetTester tester,
  PikoCopy copy,
  LearningDirection direction,
) async {
  await tapVisible(tester, button(copy.text('action.review')));
  final dropdown = find.byType(DropdownButton<LearningDirection>);
  await waitUntil(
    tester,
    () => dropdown.evaluate().isNotEmpty,
    description: 'direction dropdown',
  );
  if (direction == LearningDirection.nativeToTarget) {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DE → FR').last);
    await tester.pumpAndSettle();
  }
  expect(
    tester.widget<DropdownButton<LearningDirection>>(dropdown).value,
    direction,
  );
  await tapVisible(tester, button(copy.text('learn.start')));
  await waitUntil(
    tester,
    () => find.byType(ReviewSessionRoute).evaluate().isNotEmpty,
    description: 'review route',
  );
}

Future<void> reveal(WidgetTester tester) => tapVisible(tester, revealTarget);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final configuration in [
    (locale: 'en', direction: LearningDirection.targetToNative),
    (locale: 'de', direction: LearningDirection.nativeToTarget),
  ]) {
    testWidgets(
      'Android ${configuration.locale} real review correction, retry wait and summary survive file reopen',
      (tester) async {
        expect(binding.registerTestTextInput, isFalse);
        final support = await getApplicationSupportDirectory();
        final directory = await support.createTemp(fixturePrefix);
        final file = File('${directory.path}/test.sqlite');
        final clock = ReviewFixtureClock(fixtureInstant);
        final db = ReviewFixtureDatabase(file, clock);
        PikoDatabase? reopened;
        var runtimeMounted = false;
        final semantics = tester.ensureSemantics();
        try {
          final collection = await SqliteCollectionsRepository(db).create(
            name: 'Review Android ${configuration.locale}',
            targetLanguage: VocabularyLanguage.french,
            nativeLanguage: VocabularyLanguage.german,
          );
          final vocabulary = SqliteVocabularyRepository(db);
          final first = await vocabulary.create(
            collectionId: collection.id,
            targetText: 'Bonsoir',
            nativeText: 'Guten Abend',
          );
          final second = await vocabulary.create(
            collectionId: collection.id,
            targetText: 'Chat',
            nativeText: 'Katze',
          );
          await SqliteSettingsRepository(
            db,
          ).write('locale', configuration.locale);
          final learning = SqliteLearningRepository(db);
          Future<LearningItemRecord> selected(String entryId) async =>
              (await learning.forEntry(entryId)).singleWhere(
                (item) => item.direction == configuration.direction,
              );
          final firstBefore = await selected(first.id);
          final secondBefore = await selected(second.id);
          final opposite =
              configuration.direction == LearningDirection.targetToNative
              ? LearningDirection.nativeToTarget
              : LearningDirection.targetToNative;
          final oppositeBefore = await directionState(
            db,
            collection.id,
            opposite,
          );

          runtimeMounted = true;
          await tester.pumpWidget(
            PikoApp(home: PikoRuntime(databaseFactory: () => db)),
          );
          final copy = await hydratedRuntimeCopy(tester);
          expect(copy.locale, configuration.locale);
          await tapVisible(
            tester,
            find.byKey(ValueKey('collection-${collection.id}')),
          );
          expect(find.byType(CollectionDetail), findsOneWidget);
          await startReview(tester, copy, configuration.direction);
          expect(
            find.text(
              configuration.direction == LearningDirection.targetToNative
                  ? 'FR → DE'
                  : 'DE → FR',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              configuration.direction == LearningDirection.targetToNative
                  ? 'Bonsoir'
                  : 'Guten Abend',
            ),
            findsOneWidget,
          );

          // A real Hard grade changes the selected directional FSRS card and
          // appends exactly one regular-review event.
          await reveal(tester);
          expect(
            find.text(
              configuration.direction == LearningDirection.targetToNative
                  ? 'Guten Abend'
                  : 'Bonsoir',
            ),
            findsOneWidget,
          );
          await tapVisible(tester, find.byType(PikoCheckbox));
          await tapVisible(tester, gradeButton(AnswerGrade.correct));
          await waitUntil(
            tester,
            () async =>
                (await learning.reviewsForItem(firstBefore.id)).length == 1,
            description: 'first persisted Hard review',
          );
          final hardItem = await selected(first.id);
          final hardHistory = await learning.reviewsForItem(firstBefore.id);
          expect(hardItem.cardJson, isNot(firstBefore.cardJson));
          expect(hardItem.reviewRevision, firstBefore.reviewRevision + 1);
          expect(hardItem.card.lastReview, fixtureInstant);
          expect(hardHistory.single.rating, LearningRating.hard);
          final originalEventId = hardHistory.single.id;
          final originalEventAt = hardHistory.single.reviewedAt;

          // Correct only that immediately previous Hard grade to Good. The
          // revealed prior answer keeps the same event identity and UTC time.
          await tapVisible(
            tester,
            find.byKey(const ValueKey('review-correct-previous')),
          );
          expect(
            find.byKey(const ValueKey('review-answer-text')),
            findsOneWidget,
          );
          expect(find.textContaining(copy.text('learn.hard')), findsWidgets);
          await tapVisible(tester, find.byType(PikoCheckbox));
          await tapVisible(tester, gradeButton(AnswerGrade.correct));
          await waitUntil(tester, () async {
            final history = await learning.reviewsForItem(firstBefore.id);
            return history.length == 1 &&
                history.single.rating == LearningRating.good;
          }, description: 'same-event corrected Good review');
          final correctedItem = await selected(first.id);
          final correctedHistory = await learning.reviewsForItem(
            firstBefore.id,
          );
          expect(correctedHistory.single.id, originalEventId);
          expect(correctedHistory.single.reviewedAt, originalEventAt);
          expect(correctedItem.reviewRevision, hardItem.reviewRevision + 1);
          expect(
            find.text(
              configuration.direction == LearningDirection.targetToNative
                  ? 'Chat'
                  : 'Katze',
            ),
            findsOneWidget,
          );

          // The second regular answer is Incorrect. Exhausting regular work
          // arms the real ten-second persisted wait instead of showing retry
          // immediately or manufacturing completion.
          await reveal(tester);
          await tapVisible(tester, gradeButton(AnswerGrade.incorrect));
          await waitUntil(tester, () async {
            final retryRows = await rows(db, 'retry_obligations');
            return retryRows.length == 1 &&
                retryRows.single['wait_eligible_at'] != null;
          }, description: 'armed persisted retry wait');
          expect(revealTarget, findsNothing);
          expect(find.text(copy.text('summary.title')), findsNothing);
          final afterAgain = await selected(second.id);
          final afterAgainHistory = await learning.reviewsForItem(
            secondBefore.id,
          );
          expect(afterAgain.cardJson, isNot(secondBefore.cardJson));
          expect(afterAgainHistory.single.rating, LearningRating.again);
          final retryRow = (await rows(db, 'retry_obligations')).single;
          final waitAt = DateTime.parse(
            retryRow['wait_eligible_at']! as String,
          ).toUtc();
          final wait = waitAt.difference(clock.now());
          expect(wait, const Duration(seconds: 10));
          clock.set(waitAt);
          await tester.pump(wait);
          await waitUntil(
            tester,
            () => revealTarget.evaluate().isNotEmpty,
            description: 'eligible retry card',
          );
          expect(
            find.text(
              configuration.direction == LearningDirection.targetToNative
                  ? 'Chat'
                  : 'Katze',
            ),
            findsOneWidget,
          );

          // Successful Hard reinforcement completes the round but deliberately
          // leaves the regular FSRS card and history unchanged.
          await reveal(tester);
          await tapVisible(tester, find.byType(PikoCheckbox));
          await tapVisible(tester, gradeButton(AnswerGrade.correct));
          await waitUntil(
            tester,
            () => find.text(copy.text('summary.title')).evaluate().isNotEmpty,
            description: 'completion summary',
          );
          final afterRetry = await selected(second.id);
          expect(afterRetry.cardJson, afterAgain.cardJson);
          expect(afterRetry.reviewRevision, afterAgain.reviewRevision);
          final afterRetryHistory = await learning.reviewsForItem(
            secondBefore.id,
          );
          expect(afterRetryHistory, hasLength(1));
          expect(afterRetryHistory.single.id, afterAgainHistory.single.id);
          expect(
            afterRetryHistory.single.reviewedAt,
            afterAgainHistory.single.reviewedAt,
          );
          expect(afterRetryHistory.single.rating, LearningRating.again);
          expect(await rows(db, 'retry_obligations'), isEmpty);
          expect(
            tester
                .getSemantics(find.byKey(const ValueKey('summary-completed')))
                .label,
            '2 ${copy.text('summary.completed')}',
          );
          expect(
            tester
                .getSemantics(find.byKey(const ValueKey('summary-first-try')))
                .label,
            '1 ${copy.text('summary.firstTryCorrect')}',
          );
          expect(
            await directionState(db, collection.id, opposite),
            oppositeBefore,
          );

          final close = find.byWidgetPredicate(
            (widget) =>
                widget is PikoIconButton &&
                widget.semanticLabel == copy.text('common.close'),
          );
          await tapVisible(tester, close);
          expect(find.byType(ReviewSessionRoute), findsNothing);
          expect(find.byType(CollectionDetail), findsOneWidget);
          expect(tester.takeException(), isNull);

          // The runtime drains and closes its injected fixture before reopen.
          await tester.pumpWidget(const SizedBox());
          await db.closed.future.timeout(const Duration(seconds: 10));
          runtimeMounted = false;
          reopened = PikoDatabase(NativeDatabase(file), clock: clock);
          final reopenedLearning = SqliteLearningRepository(reopened);
          final firstReopened = (await reopenedLearning.forEntry(
            first.id,
          )).singleWhere((item) => item.direction == configuration.direction);
          final secondReopened = (await reopenedLearning.forEntry(
            second.id,
          )).singleWhere((item) => item.direction == configuration.direction);
          final firstReopenedHistory = await reopenedLearning.reviewsForItem(
            firstReopened.id,
          );
          final secondReopenedHistory = await reopenedLearning.reviewsForItem(
            secondReopened.id,
          );
          expect(firstReopened.cardJson, correctedItem.cardJson);
          expect(firstReopened.reviewRevision, correctedItem.reviewRevision);
          expect(firstReopenedHistory, hasLength(1));
          expect(firstReopenedHistory.single.id, originalEventId);
          expect(firstReopenedHistory.single.reviewedAt, originalEventAt);
          expect(firstReopenedHistory.single.rating, LearningRating.good);
          expect(secondReopened.cardJson, afterAgain.cardJson);
          expect(secondReopened.reviewRevision, afterAgain.reviewRevision);
          expect(secondReopenedHistory, hasLength(1));
          expect(secondReopenedHistory.single.rating, LearningRating.again);
          expect(await rows(reopened, 'retry_obligations'), isEmpty);
          expect(
            await directionState(reopened, collection.id, opposite),
            oppositeBefore,
          );
          final scope = (await rows(reopened, 'scope_answer_ordinals')).single;
          expect(scope['direction'], configuration.direction.name);
          expect(scope['ordinal'], 3);
          expect(scope['revision'], 4);
          await reopened.close();
          reopened = null;
        } finally {
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
          if (runtimeMounted) {
            await db.closed.future.timeout(const Duration(seconds: 10));
          } else {
            await db.close();
          }
          await reopened?.close();
          // Run through the repository's baseline/no-uninstall Android gate.
          // Cleanup owns only this newly created fixture directory.
          if (directory.parent.absolute.path != support.absolute.path ||
              !directory.uri.pathSegments
                  .where((part) => part.isNotEmpty)
                  .last
                  .startsWith(fixturePrefix)) {
            throw StateError('Refusing cleanup outside owned review fixture');
          }
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
