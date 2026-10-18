import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/features/speed/speed_numbers_break.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';

import '../data/regular_reviews_test.dart' show Fixture, instant;
import '../data/speed_eligibility_test.dart' show completeSnapshot;
import '../support/mutable_clock.dart';
import 'collection_review_runtime_test.dart' show RuntimeDatabase, pumpRuntime;

Future<void> settle(
  WidgetTester tester,
  RuntimeDatabase db,
  bool Function() ready,
) async {
  for (var attempt = 0; attempt < 24; attempt++) {
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();
    if (ready()) return;
  }
  fail('Runtime Speed flow did not reach the expected state');
}

Finder speedAction(LearningDirection direction) =>
    find.byKey(ValueKey('collection-speed-${direction.name}'));

void main() {
  for (final errors in [false, true]) {
    testWidgets(
      'SPEED-006 real runtime ${errors ? "errored reverse completion preserves full Long-term state" : "zero-error completion preserves full FSRS"} through binding invalidation',
      (tester) async {
        final clock = MutablePikoClock(instant);
        final db = RuntimeDatabase(clock);
        final f = Fixture(database: db);
        await tester.runAsync(f.initialize);
        // This test exercises both directional completion boundaries explicitly;
        // fresh/migrated preference defaults have their own acceptance coverage.
        await tester.runAsync(
          () => SqliteSettingsRepository(
            db,
          ).write(PreferredDirection.settingKey, PreferredDirection.both.name),
        );
        final direction = errors
            ? LearningDirection.nativeToTarget
            : LearningDirection.targetToNative;
        final opposite = errors
            ? LearningDirection.targetToNative
            : LearningDirection.nativeToTarget;
        var prematureRelease = false;
        var invalidationsDuringRound = 0;
        VoidCallback? removeObservers;
        try {
          await pumpRuntime(tester, db, f);
          final home = tester.widget<CollectionsHome>(
            find.byType(CollectionsHome),
          );
          final binding = home.queryBindingFactory!(f.owner.id);
          final ownerCard = find.byKey(ValueKey('collection-${f.owner.id}'));
          await tester.tap(
            find.descendant(of: ownerCard, matching: find.text(f.owner.name)),
          );
          await settle(
            tester,
            db,
            () => binding.ready && speedAction(direction).evaluate().isNotEmpty,
          );
          await tester.scrollUntilVisible(
            find.byType(CollectionVocabulary),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          final vocabulary = tester.widget<CollectionVocabulary>(
            find.byType(CollectionVocabulary),
          );
          final barrier = vocabulary.writeBarrier!;
          final prior = (await tester.runAsync(() => f.current(null, errors)))!;
          final oppositeBefore = (await tester.runAsync(
            () => f.current(null, !errors),
          ))!;
          final before = (await tester.runAsync(() => completeSnapshot(db)))!;
          final copy = PikoCopy('en');
          await tester.ensureVisible(speedAction(direction));
          await tester.tap(speedAction(direction));
          await settle(
            tester,
            db,
            () => find.byType(SpeedSetupDialog).evaluate().isNotEmpty,
          );
          expect(barrier.frozen, isTrue);
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('speed-fixed-direction')),
                )
                .data,
            errors ? 'DE → FR' : 'FR → DE',
          );
          await tester.enterText(
            find.byKey(const ValueKey('speed-pool-size')),
            '1',
          );
          final start = find.widgetWithText(
            PikoButton,
            copy.text('learn.startSpeed'),
          );
          await tester.ensureVisible(start);
          await tester.tap(start);
          await settle(
            tester,
            db,
            () =>
                find.byType(SpeedSessionRoute).evaluate().isNotEmpty &&
                find
                    .byKey(const ValueKey('review-prompt'))
                    .evaluate()
                    .isNotEmpty,
          );
          final route = tester.widget<SpeedSessionRoute>(
            find.byType(SpeedSessionRoute),
          );
          final session = route.session;
          expect(session.state!.entryIds, [f.entry.id]);
          expect(session.state!.direction, direction);
          void observeBarrier() {
            if (!barrier.frozen && !session.isStopped) prematureRelease = true;
          }

          void observeQuery() {
            if (binding.loading && !session.isStopped) {
              invalidationsDuringRound++;
              expectSync(barrier.frozen, isTrue);
            }
          }

          barrier.addListener(observeBarrier);
          binding.addListener(observeQuery);
          removeObservers = () {
            barrier.removeListener(observeBarrier);
            binding.removeListener(observeQuery);
          };
          final grades = errors
              ? [
                  SpeedAnswer.incorrect,
                  SpeedAnswer.correct,
                  SpeedAnswer.correct,
                ]
              : [SpeedAnswer.correct];
          for (var index = 0; index < grades.length; index++) {
            final handle = session.current!;
            final prompt = find.byKey(const ValueKey('review-prompt'));
            await tester.ensureVisible(prompt);
            await tester.tap(prompt);
            await tester.pumpAndSettle();
            expect(session.revealed, isTrue);
            expect(await tester.runAsync(() => completeSnapshot(db)), before);
            if (errors) clock.advance(Duration(seconds: index == 2 ? 3 : 1));
            final grade = find.byKey(
              ValueKey('speed-grade-${grades[index].name}'),
            );
            await tester.ensureVisible(grade);
            await tester.tap(grade);
            if (index < grades.length - 1) {
              await settle(
                tester,
                db,
                () =>
                    !identical(session.current, handle) &&
                    prompt.evaluate().isNotEmpty,
              );
              expect(session.state!.completedEntryIds, isEmpty);
              expect(await tester.runAsync(() => completeSnapshot(db)), before);
              expect(find.byType(SpeedNumbersBreak), findsNothing);
              expectSync(barrier.frozen, isTrue);
            }
          }
          await settle(
            tester,
            db,
            () =>
                find.byType(SpeedSessionRoute).evaluate().isEmpty &&
                binding.ready,
          );
          expect(session.isStopped, isTrue);
          expect(session.state, isNull);
          expect(find.byType(CollectionDetail), findsOneWidget);
          expect(find.byType(ReviewSummaryDialog), findsNothing);
          expect(find.byType(SpeedNumbersBreak), findsNothing);
          expect(speedAction(direction), findsNothing);
          expect(speedAction(opposite), findsOneWidget);
          expect(
            binding.snapshot!.directions[direction]!.newSpeedItems,
            isEmpty,
          );
          expect(
            binding.snapshot!.directions[opposite]!.newSpeedItems.length,
            1,
          );
          expect(prematureRelease, isFalse);
          expect(invalidationsDuringRound, greaterThan(0));
          expect(barrier.frozen, isFalse);
          expect(
            tester
                .widget<PikoButton>(
                  find.widgetWithText(PikoButton, copy.text('action.new')),
                )
                .onPressed,
            isNotNull,
          );
          final after = (await tester.runAsync(() => completeSnapshot(db)))!;
          final studied = (await tester.runAsync(
            () => f.current(null, errors),
          ))!;
          final other = (await tester.runAsync(
            () => f.current(null, !errors),
          ))!;
          expect(studied.speedCompleted, isTrue);
          expect(other.cardJson, oppositeBefore.cardJson);
          expect(other.generation, oppositeBefore.generation);
          expect(other.reviewRevision, oppositeBefore.reviewRevision);
          expect(other.speedCompleted, oppositeBefore.speedCompleted);
          expect(studied.generation, prior.generation);
          expect(studied.reviewRevision, prior.reviewRevision);
          expect(studied.formatVersion, prior.formatVersion);
          expect(studied.cardJson, prior.cardJson);
          for (final table in before.keys.where(
            (table) => table != 'learning_items',
          )) {
            expect(after[table], before[table], reason: '$table remains exact');
          }
          final beforeItems = (before['learning_items']! as List).cast<Map>();
          final afterItems = (after['learning_items']! as List).cast<Map>();
          expect(afterItems, [
            for (final row in beforeItems)
              row['id'] != studied.id ? row : {...row, 'speed_completed': 1},
          ]);
        } finally {
          removeObservers?.call();
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await tester.runAsync(() => db.closed.future);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
