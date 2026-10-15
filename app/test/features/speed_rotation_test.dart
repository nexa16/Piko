import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'speed_session_test.dart' show start;

SpeedSession advance(SpeedSession session, {bool completed = false}) {
  return session.answer(
    entryId: session.currentEntryId!,
    answer: completed ? SpeedAnswer.correct : SpeedAnswer.incorrect,
  );
}

void main() {
  group('SPEED-002 deterministic rotation and refill', () {
    test(
      'a full pool repeats only after N answered turns, without shuffling',
      () {
        var session = start(['a', 'b', 'c', 'd', 'e', 'f']);
        final turns = <String>[];
        for (var index = 0; index < 11; index++) {
          turns.add(session.currentEntryId!);
          session = advance(session);
        }
        expect(turns, ['a', 'b', 'c', 'd', 'e', 'a', 'b', 'c', 'd', 'e', 'a']);
        expect(session.pool, ['a', 'b', 'c', 'd', 'e']);
        expect(session.waiting, ['f']);
        expect(session.completedEntryIds, isEmpty);
      },
    );

    test(
      'refills all five slots but defers every replacement to next pass',
      () {
        final entries = List.generate(35, (index) => 'word-$index');
        var session = start(entries);
        final firstPass = session.pass;
        for (var index = 0; index < 5; index++) {
          expect(session.currentEntryId, entries[index]);
          expect(session.pass, firstPass);
          session = advance(session, completed: true);
        }
        expect(session.rotation, 2);
        expect(session.turnIndex, 0);
        expect(session.currentEntryId, 'word-5');
        expect(session.pool, entries.skip(5).take(5).toList());
        expect(session.pass, session.pool);
        expect(session.waiting, entries.skip(10).toList());
        expect(session.completedEntryIds, entries.take(5).toSet());
        expect(firstPass, entries.take(5).toList());
      },
    );

    test(
      'mixed completion retains slot order for survivors and replacements',
      () {
        var session = start(['a', 'b', 'c', 'd', 'e'], poolSize: 3);
        session = advance(session, completed: true);
        expect(session.pool, ['d', 'b', 'c']);
        expect(session.currentEntryId, 'b');
        session = advance(session);
        session = advance(session, completed: true);
        expect(session.pool, ['d', 'b', 'e']);
        expect(session.pass, ['d', 'b', 'e']);
        expect(session.currentEntryId, 'd');
        expect(session.waiting, isEmpty);
      },
    );

    test(
      'shrinking a pool never skips another word from the captured pass',
      () {
        var session = start(['a', 'b', 'c']);
        session = advance(session, completed: true);
        expect(session.pool, ['b', 'c']);
        expect(session.pass, ['a', 'b', 'c']);
        expect(session.currentEntryId, 'b');
        session = advance(session);
        expect(session.currentEntryId, 'c');
        session = advance(session, completed: true);
        expect(session.needsBreak, isTrue);
        session = session.completeBreak();
        expect(session.pass, ['b']);
        expect(session.currentEntryId, 'b');
        expect(session.completedEntryIds, {'a', 'c'});
      },
    );

    test('all 35 selected words complete exactly once without filler', () {
      final entries = List.generate(35, (index) => 'word-$index');
      var session = start(entries);
      final turns = <String>[];
      while (!session.isComplete) {
        turns.add(session.currentEntryId!);
        session = advance(session, completed: true);
      }
      expect(turns, entries);
      expect(session.pool, isEmpty);
      expect(session.waiting, isEmpty);
      expect(session.currentEntryId, isNull);
      expect(session.completedEntryIds, entries.toSet());
    });

    test('size one repeats itself or admits the next waiting word', () {
      var session = start(['a', 'b'], poolSize: 1);
      session = advance(session);
      expect(session.currentEntryId, 'a');
      expect(session.rotation, 2);
      session = advance(session, completed: true);
      expect(session.currentEntryId, 'a');
      expect(session.rotation, 3);
      session = advance(session, completed: true);
      expect(session.currentEntryId, 'b');
      expect(session.rotation, 4);
      expect(session.waiting, isEmpty);
    });

    test('rejects foreign and finished turns without mutating prior state', () {
      final initial = start(['a', 'b'], poolSize: 1);
      expect(
        () => initial.answer(entryId: 'b', answer: SpeedAnswer.correct),
        throwsStateError,
      );
      final next = advance(initial, completed: true);
      expect(initial.pool, ['a']);
      expect(initial.waiting, ['b']);
      expect(initial.completedEntryIds, isEmpty);
      expect(next.pool, ['b']);
      expect(() => next.pass.clear(), throwsUnsupportedError);
      expect(() => next.completedEntryIds.add('b'), throwsUnsupportedError);
      final finished = advance(next, completed: true);
      expect(
        () => finished.answer(entryId: 'b', answer: SpeedAnswer.correct),
        throwsStateError,
      );
    });
  });
}
