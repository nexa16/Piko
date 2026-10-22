import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/speed_runtime.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant, rows;

void main() {
  for (final speed in [false, true]) {
    for (final direction in LearningDirection.values) {
      testWidgets(
        '${speed ? 'Speed' : 'Normal'} $direction revealed editing preserves grade state, guards exit, and skips only committed deactivation',
        (tester) async {
          final f = Fixture();
          await tester.runAsync(f.initialize);
          DueLearningSession? normal;
          SpeedLearningSession? quick;
          final drains = <Future<void>>[];
          Future<void> flush() async {
            for (var i = 0; i < 3; i++) {
              await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
              await tester.pumpAndSettle();
            }
          }

          try {
            await tester.runAsync(() async {
              if (speed) {
                quick =
                    await PikoSpeedRuntime(
                      learning: f.learning,
                      clock: f.db.clock,
                      onPendingWrites: drains.add,
                    ).prepare(
                      collectionId: f.owner.id,
                      direction: direction,
                      visibleEntryIds: {f.entry.id},
                      poolSize: 1,
                    );
              } else {
                normal = await DueLearningSession.start(
                  source: await f.learning.forCollection(
                    collectionId: f.owner.id,
                    direction: direction,
                  ),
                  cutoff: instant,
                  clock: f.db.clock,
                  onPendingWrites: drains.add,
                );
              }
            });
            final categories = SqliteCategoriesRepository(f.db);
            await tester.pumpWidget(
              PikoApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => speed
                              ? SpeedSessionRoute(
                                  collection: f.owner,
                                  session: quick!,
                                  vocabularyRepository: f.vocabulary,
                                  categoriesRepository: categories,
                                  onPendingWrites: drains.add,
                                )
                              : ReviewSessionRoute(
                                  collection: f.owner,
                                  session: normal!,
                                  vocabularyRepository: f.vocabulary,
                                  categoriesRepository: categories,
                                  onPendingWrites: drains.add,
                                ),
                        ),
                      ),
                      child: const Text('Launch'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Launch'));
            await flush();
            final handle = speed ? quick!.current : normal!.current;
            if (!speed) normal!.setHard(normal!.current!, true);
            await tester.tap(find.byKey(const ValueKey('review-prompt-text')));
            await tester.pumpAndSettle();
            final before = await tester.runAsync(
              () => rows(f.db, 'learning_items'),
            );
            await tester.tap(
              find.byKey(const ValueKey('learning-edit-answer')),
            );
            await flush();
            expect(
              find.byKey(const ValueKey('learning-answer-editor')),
              findsOneWidget,
            );
            expect(
              find.byKey(ValueKey('inline-menu-${f.entry.id}')),
              findsNothing,
            );
            final target = find.byKey(ValueKey('inline-${f.entry.id}-target'));
            await tester.enterText(target, '  Revised  ');
            await flush();
            await tester.tap(
              find.byKey(ValueKey('inline-complete-${f.entry.id}')),
            );
            await flush();
            expect(
              find.byKey(const ValueKey('review-answer-text')),
              findsOneWidget,
            );
            expect(speed ? quick!.current : normal!.current, same(handle));
            if (!speed) expect(normal!.hard, isFalse);
            expect(
              await tester.runAsync(() => rows(f.db, 'learning_items')),
              before,
            );
            await tester.tap(
              find.byKey(const ValueKey('learning-edit-answer')),
            );
            await flush();
            await tester.runAsync(
              () => f.db.customStatement(
                "CREATE TRIGGER round5_fail_edit BEFORE UPDATE ON vocabulary_entries BEGIN SELECT RAISE(ABORT, 'synthetic'); END",
              ),
            );
            await tester.enterText(target, 'Raw retry');
            await flush();
            final exitOnFailure = find.byKey(
              ValueKey(speed ? 'speed-exit' : 'review-exit'),
            );
            await tester.ensureVisible(exitOnFailure);
            await tester.tap(exitOnFailure);
            await flush();
            expect(
              find.byKey(const ValueKey('learning-answer-editor')),
              findsOneWidget,
            );
            expect(
              (await tester.runAsync(
                () => f.vocabulary.watchById(f.entry.id).first,
              ))!.targetText,
              'Revised',
            );
            await tester.runAsync(
              () => f.db.customStatement('DROP TRIGGER round5_fail_edit'),
            );
            await tester.ensureVisible(find.text('Try again'));
            await tester.tap(find.text('Try again'));
            await flush();
            expect(
              (await tester.runAsync(
                () => f.vocabulary.watchById(f.entry.id).first,
              ))!.targetText,
              'Raw retry',
            );
            await tester.enterText(target, '   ');
            await flush();
            final active = find.byKey(ValueKey('inline-active-${f.entry.id}'));
            await tester.ensureVisible(active);
            await tester.tap(active);
            await flush();
            expect(
              (await tester.runAsync(
                () => f.vocabulary.watchById(f.entry.id).first,
              ))!.active,
              isTrue,
            );
            final exit = find.byKey(
              ValueKey(speed ? 'speed-exit' : 'review-exit'),
            );
            await tester.ensureVisible(exit);
            await tester.tap(exit);
            await flush();
            expect(
              find.byKey(const ValueKey('learning-answer-editor')),
              findsOneWidget,
            );
            final input = find.descendant(
              of: target,
              matching: find.byType(EditableText),
            );
            expect(tester.widget<EditableText>(input).controller.text, '   ');
            await tester.ensureVisible(target);
            await tester.enterText(target, 'Revised');
            await flush();
            expect(
              (await tester.runAsync(
                () => f.vocabulary.watchById(f.entry.id).first,
              ))!.active,
              isFalse,
            );
            expect(find.byType(ReviewSummaryDialog), findsNothing);
            expect(
              await tester.runAsync(() => rows(f.db, 'learning_items')),
              before,
            );
            expect(
              await tester.runAsync(() => rows(f.db, 'regular_reviews')),
              isEmpty,
            );
            expect(
              await tester.runAsync(() => rows(f.db, 'scope_answer_ordinals')),
              isEmpty,
            );
            if (!speed) {
              expect(normal!.current, isNull);
              expect(normal!.progress.total, 0);
              expect(normal!.endedByExclusion, isTrue);
            } else {
              expect(find.byType(SpeedSessionRoute), findsNothing);
            }
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await flush();
            normal?.dispose();
            quick?.dispose();
            await tester.runAsync(f.db.close);
          }
        },
      );
    }
  }
}
