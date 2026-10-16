import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/speed/speed_learning_session.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'speed_session_test.dart' show start;

Future<bool> answer(SpeedLearningSession session, SpeedAnswer answer) {
  final handle = session.current!;
  session.reveal(handle);
  return session.submitAnswer(handle, answer);
}

void main() {
  group('SPEED-008 in-process lifecycle and durable item completion', () {
    test(
      'reveal does not advance; unfinished attempts and Exit never write',
      () async {
        final writes = <SpeedCompletion>[];
        final session = SpeedLearningSession(
          initial: start(['a', 'b']),
          commitCompletion: (completion) async => writes.add(completion),
        );
        addTearDown(session.dispose);
        final initial = session.state;
        final handle = session.current!;
        expect(session.reveal(handle), isTrue);
        expect(session.state, same(initial));
        expect(session.current, same(handle));
        expect(writes, isEmpty);
        expect(
          await session.submitAnswer(handle, SpeedAnswer.incorrect),
          isTrue,
        );
        expect(session.state!.itemProgress['a']!.errors, 1);
        expect(writes, isEmpty);
        await session.stop();
        expect(session.state, isNull);
        expect(session.current, isNull);
        expect(session.revealed, isFalse);
        expect(session.isStopped, isTrue);
        expect(writes, isEmpty);
        expect(
          await session.submitAnswer(handle, SpeedAnswer.correct),
          isFalse,
        );
      },
    );

    test(
      'completion awaits storage and rejects duplicate, stale and hidden grades',
      () async {
        final gate = Completer<void>();
        final writes = <SpeedCompletion>[];
        final drains = <Future<void>>[];
        final session = SpeedLearningSession(
          initial: start(['a'], poolSize: 1),
          commitCompletion: (completion) {
            writes.add(completion);
            return gate.future;
          },
          onPendingWrites: drains.add,
        );
        addTearDown(session.dispose);
        final first = session.current!;
        expect(await session.submitAnswer(first, SpeedAnswer.correct), isFalse);
        await answer(session, SpeedAnswer.incorrect);
        expect(session.current!.entryId, first.entryId);
        expect(session.current, isNot(same(first)));
        expect(session.reveal(first), isFalse);
        expect(await session.submitAnswer(first, SpeedAnswer.correct), isFalse);
        await answer(session, SpeedAnswer.correct);
        final handle = session.current!;
        session.reveal(handle);
        final before = session.state;
        final pending = session.submitAnswer(handle, SpeedAnswer.correct);
        expect(session.isSubmitting, isTrue);
        expect(session.state, same(before));
        expect(session.current, same(handle));
        expect(session.revealed, isTrue);
        expect(session.isComplete, isFalse);
        expect(writes.single.errors, 1);
        expect(drains, hasLength(1));
        expect(session.reveal(handle), isFalse);
        expect(
          await session.submitAnswer(handle, SpeedAnswer.correct),
          isFalse,
        );
        gate.complete();
        expect(await pending, isTrue);
        await Future.wait(drains);
        expect(session.isSubmitting, isFalse);
        expect(session.isComplete, isTrue);
        expect(session.current, isNull);
        expect(writes, hasLength(1));
      },
    );

    test(
      'failed completion retains the exact revealed turn and counters for retry',
      () async {
        var attempts = 0;
        final failure = StateError('storage unavailable');
        final session = SpeedLearningSession(
          initial: start(['a', 'b']),
          commitCompletion: (_) async {
            attempts++;
            if (attempts == 1) throw failure;
          },
        );
        addTearDown(session.dispose);
        final handle = session.current!;
        session.reveal(handle);
        final before = session.state;
        await expectLater(
          session.submitAnswer(handle, SpeedAnswer.correct),
          throwsA(same(failure)),
        );
        expect(session.error, same(failure));
        expect(session.current, same(handle));
        expect(session.state, same(before));
        expect(session.state!.itemProgress['a']!.correctStreak, 0);
        expect(session.revealed, isTrue);
        expect(session.isSubmitting, isFalse);
        expect(await session.submitAnswer(handle, SpeedAnswer.correct), isTrue);
        expect(session.error, isNull);
        expect(session.current!.entryId, 'b');
        expect(session.state!.completedEntryIds, {'a'});
        expect(attempts, 2);
        expect(
          await session.submitAnswer(handle, SpeedAnswer.correct),
          isFalse,
        );
      },
    );

    test(
      'background retains the live round; a new session starts fresh',
      () async {
        var activeRoute = true;
        final session = SpeedLearningSession(
          initial: start(['a'], poolSize: 1),
          commitCompletion: (_) async {},
          isPresentationCurrent: () => activeRoute,
        );
        addTearDown(session.dispose);
        await answer(session, SpeedAnswer.incorrect);
        final handle = session.current!;
        session.reveal(handle);
        final before = session.state;
        session.setPresentationActive(false);
        expect(
          await session.submitAnswer(handle, SpeedAnswer.correct),
          isFalse,
        );
        expect(session.reveal(handle), isFalse);
        expect(session.state, same(before));
        session.setPresentationActive(true);
        expect(session.current, same(handle));
        expect(session.revealed, isTrue);
        activeRoute = false;
        expect(
          await session.submitAnswer(handle, SpeedAnswer.correct),
          isFalse,
        );
        activeRoute = true;
        expect(await session.submitAnswer(handle, SpeedAnswer.correct), isTrue);
        final restarted = SpeedLearningSession(
          initial: start(['a'], poolSize: 1),
          commitCompletion: (_) async {},
        );
        addTearDown(restarted.dispose);
        expect(restarted.state!.itemProgress['a']!.errors, 0);
        expect(restarted.state!.itemProgress['a']!.correctStreak, 0);
        expect(restarted.revealed, isFalse);
        expect(restarted.reveal(session.current!), isFalse);
      },
    );

    test(
      'Exit drains accepted completion without resurrecting discarded work',
      () async {
        final gate = Completer<void>();
        final writes = <SpeedCompletion>[];
        final session = SpeedLearningSession(
          initial: start(['a', 'b']),
          commitCompletion: (completion) async {
            await gate.future;
            writes.add(completion);
          },
        );
        addTearDown(session.dispose);
        var notices = 0;
        session.addListener(() => notices++);
        final pending = answer(session, SpeedAnswer.correct);
        var drained = false;
        final stop = session.stop().then((_) => drained = true);
        final atStop = notices;
        await Future<void>.value();
        expect(drained, isFalse);
        expect(session.state, isNull);
        expect(session.current, isNull);
        gate.complete();
        expect(await pending, isTrue);
        await stop;
        expect(writes.single.entryId, 'a');
        expect(session.state, isNull);
        expect(session.current, isNull);
        expect(session.isComplete, isFalse);
        expect(session.isSubmitting, isFalse);
        expect(notices, atStop);
        expect(session.beginBreak(), isFalse);
      },
    );

    test(
      'disposal leaves accepted work drainable with no late notifications',
      () async {
        final gate = Completer<void>();
        final session = SpeedLearningSession(
          initial: start(['a']),
          commitCompletion: (_) => gate.future,
        );
        var notices = 0;
        session.addListener(() => notices++);
        final pending = answer(session, SpeedAnswer.correct);
        session.dispose();
        final atDispose = notices;
        final drain = session.awaitPending();
        gate.complete();
        expect(await pending, isTrue);
        await drain;
        expect(notices, atDispose);
        expect(session.state, isNull);
        expect(session.error, isNull);
      },
    );

    test(
      'numbers break retains state through background and cannot write learning',
      () async {
        final writes = <SpeedCompletion>[];
        final session = SpeedLearningSession(
          initial: start(['a', 'b']),
          commitCompletion: (completion) async => writes.add(completion),
        );
        addTearDown(session.dispose);
        expect(session.beginBreak(), isFalse);
        await answer(session, SpeedAnswer.incorrect);
        await answer(session, SpeedAnswer.incorrect);
        expect(session.needsBreak, isTrue);
        expect(session.current, isNull);
        session.beginBreak(random: Random(42));
        final gameHandle = session.currentBreak!;
        session.tapNumber(gameHandle, 1);
        final before = session.state;
        session.setPresentationActive(false);
        expect(session.tapNumber(gameHandle, 2), isFalse);
        expect(session.beginBreak(random: Random(7)), isFalse);
        session.setPresentationActive(true);
        expect(session.state, same(before));
        expect(session.beginBreak(random: Random(7)), isTrue);
        expect(session.state, same(before));
        expect(session.tapNumber(gameHandle, 5), isFalse);
        for (var number = 2; number <= 10; number++) {
          expect(session.tapNumber(gameHandle, number), isTrue);
        }
        expect(session.needsBreak, isFalse);
        expect(session.state!.pass, ['a', 'b']);
        expect(session.state!.itemProgress, before!.itemProgress);
        expect(session.current!.entryId, 'a');
        expect(session.revealed, isFalse);
        expect(writes, isEmpty);
        expect(session.currentBreak, isNull);
        expect(session.tapNumber(gameHandle, 1), isFalse);
        await answer(session, SpeedAnswer.correct);
        await answer(session, SpeedAnswer.correct);
        session.beginBreak(random: Random(7));
        expect(session.currentBreak, isNot(same(gameHandle)));
        expect(session.tapNumber(gameHandle, 1), isFalse);
        expect(session.state!.numberGame!.nextNumber, 1);
      },
    );

    test(
      'registration failure prevents storage and leaves the turn retryable',
      () async {
        var registrations = 0, writes = 0;
        final session = SpeedLearningSession(
          initial: start(['a']),
          commitCompletion: (_) async {
            writes++;
          },
          onPendingWrites: (_) {
            registrations++;
            if (registrations == 1) throw StateError('runtime unavailable');
          },
        );
        addTearDown(session.dispose);
        final handle = session.current!;
        session.reveal(handle);
        await expectLater(
          session.submitAnswer(handle, SpeedAnswer.correct),
          throwsStateError,
        );
        expect(writes, 0);
        expect(session.current, same(handle));
        expect(session.revealed, isTrue);
        expect(session.state!.completedEntryIds, isEmpty);
        expect(await session.submitAnswer(handle, SpeedAnswer.correct), isTrue);
        expect(writes, 1);
      },
    );

    test(
      'a failed write after Exit cannot restore errors or a presentation',
      () async {
        final gate = Completer<void>();
        final session = SpeedLearningSession(
          initial: start(['a']),
          commitCompletion: (_) => gate.future,
        );
        addTearDown(session.dispose);
        final pending = answer(session, SpeedAnswer.correct);
        final failed = expectLater(pending, throwsStateError);
        final stop = session.stop();
        gate.completeError(StateError('write rejected'));
        await failed;
        await stop;
        expect(session.state, isNull);
        expect(session.current, isNull);
        expect(session.error, isNull);
      },
    );
  });
}
