import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/shared/catalogs.dart';
import '../data/regular_reviews_test.dart' show instant;
import '../features/retry_learning_session_test.dart'
    show ControlledRetrySource;
import '../support/mutable_clock.dart';
import 'review_launch_test.dart' as launch;
import 'review_no_due_test.dart' show snapshot;
import 'review_prompt_test.dart' show card;

void main() {
  launch.testWidgets('RETRY-005 only an actual failed selection offers Retry', (
    tester,
  ) async {
    final f = launch.fixture();
    await tester.runAsync(f.initialize);
    await tester.runAsync(() => f.review(rating: LearningRating.again));
    final h = launch.Harness(f);
    late ControlledRetrySource source;
    h.factory = (id, direction) async {
      source = ControlledRetrySource(
        await f.learning.forCollection(collectionId: id, direction: direction),
      );
      final session = await DueLearningSession.start(
        source: source,
        cutoff: instant,
        clock: f.db.clock,
        onPendingWrites: h.drains.add,
      );
      h.sessions.add(session);
      return session;
    };
    await h.mount(tester);
    await h.open(tester);
    final copy = PikoCopy('en');
    await tester.tap(launch.button(copy.text('learn.start')));
    await h.finish(tester);
    expect(
      find.text(copy.text('learn.retryCountdown', {'seconds': 10})),
      findsOneWidget,
    );
    expect(launch.button(copy.text('action.retry')), findsNothing);
    final before = await tester.runAsync(() => snapshot(f));
    source.failRefresh = true;
    (f.db.clock as MutablePikoClock).advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));
    await h.finish(tester);
    expect(h.sessions.single.selectionFailed, isTrue);
    expect(find.text(copy.text('learn.retryLoadFailed')), findsOneWidget);
    expect(launch.button(copy.text('action.retry')), findsOneWidget);
    expect(card, findsNothing);
    source.failRefresh = false;
    await tester.tap(launch.button(copy.text('action.retry')));
    await h.finish(tester);
    await h.flush(tester);
    expect(h.sessions.single.selectionFailed, isFalse);
    expect(h.sessions.single.currentIsRetry, isTrue);
    expect(launch.button(copy.text('action.retry')), findsNothing);
    expect(card, findsOneWidget);
    expect(await tester.runAsync(() => snapshot(f)), before);
    expect(h.sessions.single.lastAnswer, isNull);
    expect(h.sessions.single.progress.completed, 0);
    expect(tester.takeException(), isNull);
  });
}
