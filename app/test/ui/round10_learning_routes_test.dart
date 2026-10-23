import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/speed_runtime.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;
import '../features/due_learning_session_test.dart' show addWords, source;

/// Shared host/native scenarios. Uses the actual viewport, production routes,
/// real SQLite repositories and runtime; never changes the device's database.
void registerRound10LearningRouteTests() {
  for (final speed in [false, true]) {
    testWidgets(
      speed
          ? 'Round10 real Speed Previous corrects during minigame'
          : 'Round10 real Long-term Skip preserves storage then Correct records Good',
      (tester) async {
        final f = Fixture();
        await tester.runAsync(() async {
          await f.initialize();
          await addWords(f, 1);
        });
        DueLearningSession? normal;
        SpeedLearningSession? quick;
        Future<void> flush() async {
          for (var i = 0; i < 3; i++) {
            await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
            await tester.pumpAndSettle();
          }
        }

        Future<void> tap(String key) async {
          final target = find.byKey(ValueKey(key));
          await tester.ensureVisible(target);
          await tester.tap(target);
          await flush();
        }

        try {
          await tester.runAsync(() async {
            if (speed) {
              quick =
                  await PikoSpeedRuntime(
                    learning: f.learning,
                    clock: f.db.clock,
                  ).prepareSelected(
                    collectionId: f.owner.id,
                    direction: LearningDirection.targetToNative,
                    orderedEntryIds: (await (await source(
                      f,
                    )).items()).map((item) => item.entryId).toList(),
                    poolSize: 2,
                  );
            } else {
              normal = await DueLearningSession.start(
                source: await source(f),
                cutoff: instant,
                clock: f.db.clock,
              );
            }
          });
          await tester.pumpWidget(
            PikoApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const ValueKey('launch-round10'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => speed
                            ? SpeedSessionRoute(
                                collection: f.owner,
                                session: quick!,
                                vocabularyRepository: f.vocabulary,
                              )
                            : ReviewSessionRoute(
                                collection: f.owner,
                                session: normal!,
                                vocabularyRepository: f.vocabulary,
                              ),
                      ),
                    ),
                    child: const Text('Launch'),
                  ),
                ),
              ),
            ),
          );
          await tap('launch-round10');
          if (speed) {
            await tap('review-prompt');
            await tap('speed-grade-incorrect');
            await tap('review-prompt');
            await tap('speed-grade-correct');
            expect(quick!.needsBreak, isTrue);
            expect(quick!.state!.numberGame, isNotNull);
            expect(
              await tester.runAsync(() => rows(f.db, 'statistics_activity')),
              hasLength(1),
            );
            await tap('speed-correct-previous');
            expect(quick!.isCorrecting, isTrue);
            await tap('speed-grade-incorrect');
            expect(quick!.state!.completedEntryIds, isEmpty);
            expect(quick!.state!.totalRetries, 0);
            expect(quick!.needsBreak, isFalse);
            expect(
              await tester.runAsync(() => rows(f.db, 'statistics_activity')),
              isEmpty,
            );
            expect(
              await tester.runAsync(() => rows(f.db, 'regular_reviews')),
              isEmpty,
            );
            await tap('speed-exit');
          } else {
            final first = normal!.current!.item.id;
            final before = await tester.runAsync(
              () => rows(f.db, 'learning_items'),
            );
            await tap('review-skip');
            expect(normal!.current!.item.id, isNot(first));
            expect(normal!.pendingItemCount, 2);
            expect(normal!.progress.totalRetries, 0);
            expect(
              await tester.runAsync(() => rows(f.db, 'learning_items')),
              before,
            );
            expect(
              await tester.runAsync(() => rows(f.db, 'regular_reviews')),
              isEmpty,
            );
            await tap('review-prompt');
            expect(find.byKey(const ValueKey('review-hard')), findsNothing);
            expect(find.byKey(const ValueKey('review-skip')), findsNothing);
            await tap('review-grade-correct');
            expect(
              normal!.acceptedReviews.single.event.rating,
              LearningRating.good,
            );
            expect(normal!.current!.item.id, first);
            expect(normal!.progress.totalRetries, 0);
            await tap('review-exit');
          }
          expect(tester.takeException(), isNull);
        } finally {
          await flush();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await normal?.awaitPending();
          await quick?.awaitPending();
          await tester.runAsync(f.db.close);
        }
      },
    );
  }
}

void main() => registerRound10LearningRouteTests();
