import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/speed_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant;
import '../features/due_learning_session_test.dart' show source;

void main() {
  for (final speed in [false, true]) {
    for (final affected in [false, true]) {
      testWidgets(
        '${speed ? 'Speed' : 'Long-term'} saved-answer reset affected=$affected retires only affected captured direction',
        (tester) async {
          final f = Fixture();
          await tester.runAsync(f.initialize);
          DueLearningSession? normal;
          SpeedLearningSession? quick;
          Future<void> flush() async {
            for (var i = 0; i < 4; i++) {
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
                    ).prepare(
                      collectionId: f.owner.id,
                      direction: LearningDirection.targetToNative,
                      visibleEntryIds: {f.entry.id},
                      poolSize: 1,
                    );
              } else {
                normal = await DueLearningSession.start(
                  source: await source(f),
                  cutoff: instant,
                  clock: f.db.clock,
                );
              }
            });
            final original = speed ? quick!.current : normal!.current;
            await tester.pumpWidget(
              PikoApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      key: const ValueKey('launch-reset'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => speed
                              ? SpeedSessionRoute(
                                  collection: f.owner,
                                  session: quick!,
                                  vocabularyRepository: f.vocabulary,
                                  learningReset: f.learning,
                                )
                              : ReviewSessionRoute(
                                  collection: f.owner,
                                  session: normal!,
                                  vocabularyRepository: f.vocabulary,
                                  learningReset: f.learning,
                                ),
                        ),
                      ),
                      child: const Text('Launch'),
                    ),
                  ),
                ),
              ),
            );
            await tap('launch-reset');
            await tap('review-prompt');
            await tap('learning-edit-answer');
            await tap('vocabulary-reset-${f.entry.id}');
            await tap(
              'reset-direction-${affected ? 'nativeToTarget' : 'targetToNative'}',
            );
            final confirm = find.byWidgetPredicate(
              (widget) =>
                  widget is PikoButton &&
                  widget.label == PikoCopy('en').text('vocab.resetLearning'),
            );
            await tester.ensureVisible(confirm);
            await tester.tap(confirm);
            await flush();
            if (affected) {
              expect(speed ? quick!.isStopped : normal!.isStopped, isTrue);
              expect(
                find.byType(speed ? SpeedSessionRoute : ReviewSessionRoute),
                findsNothing,
              );
            } else {
              expect(speed ? quick!.isStopped : normal!.isStopped, isFalse);
              expect(speed ? quick!.current : normal!.current, same(original));
              expect(
                find.byKey(const ValueKey('learning-answer-editor')),
                findsOneWidget,
              );
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
}
