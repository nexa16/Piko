import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';

import 'review_correction_android_test.dart' as correction;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

const fixturePrefix = 'piko-review-resume-verification-';
final fixtureInstant = DateTime.utc(2026, 10, 14, 10, 20, 30);

Finder button(String label) => find.widgetWithText(PikoButton, label);

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

Future<void> launchTargetToNative(WidgetTester tester, PikoCopy copy) async {
  await correction.tapVisible(
    tester,
    find.byKey(const ValueKey('collection-review-card')),
  );
  final dropdown = find.byType(DropdownButton<LearningDirection>);
  await correction.waitUntil(
    tester,
    () => dropdown.evaluate().isNotEmpty,
    description: 'review direction dropdown',
  );
  expect(
    tester.widget<DropdownButton<LearningDirection>>(dropdown).value,
    LearningDirection.targetToNative,
  );
  await correction.tapVisible(tester, button(copy.text('learn.start')));
  await correction.waitUntil(
    tester,
    () => find.byType(ReviewSessionRoute).evaluate().isNotEmpty,
    description: 'review route',
  );
}

Future<void> answer(WidgetTester tester, AnswerGrade grade) async {
  await correction.reveal(tester);
  await correction.tapVisible(tester, correction.gradeButton(grade));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android real UI Exit and relaunch retain retry gap/wait and prioritize eligible retry without another review write',
    (tester) async {
      expect(binding.registerTestTextInput, isFalse);
      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp(fixturePrefix);
      final file = File('${directory.path}/test.sqlite');
      final clock = correction.ReviewFixtureClock(fixtureInstant);
      final db = correction.ReviewFixtureDatabase(file, clock);
      var runtimeMounted = false;
      final semantics = tester.ensureSemantics();
      try {
        final collection = await SqliteCollectionsRepository(db).create(
          name: 'Review resume Android',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final vocabulary = SqliteVocabularyRepository(db);
        final entries = <({String target, String native})>[
          (target: 'Premier', native: 'Erster'),
          (target: 'Deuxième', native: 'Zweiter'),
          (target: 'Troisième', native: 'Dritter'),
          (target: 'Quatrième', native: 'Vierter'),
        ];
        final storedEntries = <VocabularyRecord>[];
        for (final entry in entries) {
          storedEntries.add(
            await vocabulary.create(
              collectionId: collection.id,
              targetText: entry.target,
              nativeText: entry.native,
            ),
          );
        }
        final learning = SqliteLearningRepository(db);
        Future<LearningItemRecord> selected(String entryId) async =>
            (await learning.forEntry(entryId)).singleWhere(
              (item) => item.direction == LearningDirection.targetToNative,
            );

        runtimeMounted = true;
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        final copy = await hydratedRuntimeCopy(tester);
        await correction.tapVisible(
          tester,
          find.byKey(ValueKey('collection-${collection.id}')),
        );
        expect(find.byType(CollectionDetail), findsOneWidget);
        await launchTargetToNative(tester, copy);

        // Incorrect creates the real reinforcement obligation. Three accepted
        // regular answers earn only three of its twenty required answer gaps.
        expect(find.text('Premier'), findsOneWidget);
        await answer(tester, AnswerGrade.incorrect);
        for (final target in ['Deuxième', 'Troisième', 'Quatrième']) {
          await correction.waitUntil(
            tester,
            () => find.text(target).evaluate().isNotEmpty,
            description: '$target regular question',
          );
          await answer(tester, AnswerGrade.correct);
        }
        await correction.waitUntil(tester, () async {
          final retryRows = await correction.rows(db, 'retry_obligations');
          return retryRows.length == 1 &&
              retryRows.single['wait_eligible_at'] != null;
        }, description: 'armed retry wait after captured regular work');

        final source = await learning.forCollection(
          collectionId: collection.id,
          direction: LearningDirection.targetToNative,
        );
        final armed = await source.retryState(at: clock.now());
        expect(armed.rounds, hasLength(1));
        final round = armed.rounds.single;
        expect(round.itemId, (await selected(storedEntries.first.id)).id);
        expect(round.dueOrdinal - armed.scope.ordinal, 17);
        expect(
          round.waitEligibleAt,
          fixtureInstant.add(const Duration(seconds: 10)),
        );
        final waitingSession = tester
            .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
            .session;
        expect(waitingSession.current, isNull);
        expect(waitingSession.hasPendingRetryWork, isTrue);
        expect(waitingSession.unreviewedMembers, isEmpty);
        expect(find.text(copy.text('learn.retryWaiting')), findsOneWidget);

        final beforeExit = await snapshot(db);
        await correction.tapVisible(tester, find.byTooltip(copy.text('learn.exit')));
        await correction.waitUntil(
          tester,
          () => find.byType(CollectionDetail).evaluate().isNotEmpty,
          description: 'Collection Detail after explicit Exit',
        );
        expect(await snapshot(db), beforeExit);

        // Five seconds later, storage still owns the exact partially earned
        // gap and original deadline. Exit neither rearms nor grades anything.
        clock.set(fixtureInstant.add(const Duration(seconds: 5)));
        final halfway = await source.retryState(at: clock.now());
        expect(halfway.rounds.single.sameStateAs(round), isTrue);
        expect(halfway.scope.sameStateAs(armed.scope), isTrue);
        expect(halfway.rounds.single.dueOrdinal - halfway.scope.ordinal, 17);
        expect(
          halfway.rounds.single.waitEligibleAt!.difference(clock.now()),
          const Duration(seconds: 5),
        );
        expect(await snapshot(db), beforeExit);

        // Fresh regular work competes on relaunch. At the original deadline,
        // the eligible captured retry must be presented before that new card.
        final fresh = await vocabulary.create(
          collectionId: collection.id,
          targetText: 'Cinquième',
          nativeText: 'Fünfter',
        );
        await tester.pumpAndSettle();
        final freshBefore = await selected(fresh.id);
        final beforeRelaunch = await snapshot(db);
        clock.set(round.waitEligibleAt!);
        await launchTargetToNative(tester, copy);
        final resumed = tester
            .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
            .session;
        expect(resumed.currentIsRetry, isTrue);
        expect(resumed.current!.item.id, round.itemId);
        expect(resumed.unreviewedMembers, hasLength(1));
        expect(resumed.unreviewedMembers.single.id, freshBefore.id);
        expect(find.text('Premier'), findsOneWidget);
        expect(find.text('Cinquième'), findsNothing);
        expect(await snapshot(db), beforeRelaunch);

        // Leaving the eligible retry unanswered is also write-free: no second
        // FSRS transition, regular event, successful retry, or gap mutation.
        await correction.tapVisible(tester, find.byTooltip(copy.text('learn.exit')));
        await correction.waitUntil(
          tester,
          () => find.byType(CollectionDetail).evaluate().isNotEmpty,
          description: 'Collection Detail after resumed Exit',
        );
        expect(await snapshot(db), beforeRelaunch);
        for (var index = 0; index < storedEntries.length; index++) {
          final item = await selected(storedEntries[index].id);
          final history = await learning.reviewsForItem(item.id);
          expect(history, hasLength(1));
          expect(
            history.single.rating,
            index == 0 ? LearningRating.again : LearningRating.good,
          );
          expect(item.reviewRevision, 1);
        }
        expect(await learning.reviewsForItem(freshBefore.id), isEmpty);
        expect((await source.retryState(at: clock.now())).rounds, hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
        if (runtimeMounted) {
          await db.closed.future.timeout(const Duration(seconds: 10));
        } else {
          await db.close();
        }
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith(fixturePrefix)) {
          throw StateError('Refusing cleanup outside owned resume fixture');
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
