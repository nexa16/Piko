import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'speed_session_test.dart' show start;

SpeedSession answer(SpeedSession session, SpeedAnswer answer) =>
    session.answer(entryId: session.currentEntryId!, answer: answer);

SpeedSession completeNumbersBreak(SpeedSession session) {
  var next = session.beginBreak(random: Random(42));
  for (var number = 1; number <= 10; number++) {
    next = next.tapNumber(number);
  }
  return next;
}

void main() {
  group('SPEED-007 one complete pass between short-pool breaks', () {
    test(
      '39 words finish without a game before the final four first turns',
      () {
        final entries = List.generate(39, (index) => 'word-${index + 1}');
        var session = start(entries);
        for (final id in entries.take(35)) {
          expect(session.needsBreak, isFalse);
          expect(session.currentEntryId, id);
          session = answer(session, SpeedAnswer.correct);
          expect(session.completion!.entryId, id);
          expect(session.completion!.errors, 0);
        }
        expect(session.completedEntryIds.length, 35);
        expect(session.waiting, isEmpty);
        expect(session.pool, entries.skip(35).toList());
        expect(session.pass, session.pool);
        expect(session.rotation, 8);
        for (final id in entries.skip(35)) {
          expect(session.needsBreak, isFalse);
          expect(session.currentEntryId, id);
          session = answer(session, SpeedAnswer.correct);
        }
        expect(session.completedEntryIds, entries.toSet());
        expect(session.isComplete, isTrue);
        expect(session.needsBreak, isFalse);
        expect(session.currentEntryId, isNull);
      },
    );

    for (var replacements = 1; replacements < 5; replacements++) {
      test(
        '$replacements unseen replacements get a full pass before a game',
        () {
          final entries = List.generate(
            5 + replacements,
            (index) => 'word-$index',
          );
          var session = start(entries);
          final firstPass = session.pass;
          for (final id in entries.take(5)) {
            expect(session.currentEntryId, id);
            expect(session.pass, firstPass);
            session = answer(session, SpeedAnswer.correct);
          }
          final remaining = entries.skip(5).toList();
          expect(session.needsBreak, isFalse);
          expect(session.pass, remaining);
          expect(session.waiting, isEmpty);
          expect(session.rotation, 2);
          for (final id in remaining) {
            expect(session.currentEntryId, id);
            expect(session.needsBreak, isFalse);
            session = answer(session, SpeedAnswer.incorrect);
            expect(session.completion, isNull);
          }
          expect(session.needsBreak, isTrue);
          expect(session.currentEntryId, isNull);
          final beforeGame = session;
          session = completeNumbersBreak(session);
          expect(session.itemProgress, beforeGame.itemProgress);
          expect(session.completedEntryIds, beforeGame.completedEntryIds);
          expect(session.pass, remaining);
          expect(session.rotation, 3);
          for (final id in remaining) {
            expect(session.needsBreak, isFalse);
            expect(session.currentEntryId, id);
            session = answer(session, SpeedAnswer.correct);
            expect(session.completion, isNull);
          }
          expect(session.needsBreak, isTrue);
          session = completeNumbersBreak(session);
          for (final id in remaining) {
            expect(session.needsBreak, isFalse);
            expect(session.currentEntryId, id);
            session = answer(session, SpeedAnswer.correct);
            expect(session.completion!.entryId, id);
            expect(session.completion!.errors, 1);
          }
          expect(session.completedEntryIds, entries.toSet());
          expect(session.isComplete, isTrue);
          expect(session.needsBreak, isFalse);
        },
      );
    }

    test(
      'unseen replacements retain their slots beside an attempted survivor',
      () {
        var session = start(['a', 'b', 'c', 'd', 'e', 'f', 'g']);
        for (var index = 0; index < 4; index++) {
          session = answer(session, SpeedAnswer.correct);
        }
        session = answer(session, SpeedAnswer.incorrect);
        expect(session.waiting, isEmpty);
        expect(session.needsBreak, isFalse);
        expect(session.pass, ['f', 'g', 'e']);
        for (final id in ['f', 'g', 'e']) {
          expect(session.needsBreak, isFalse);
          expect(session.currentEntryId, id);
          session = answer(session, SpeedAnswer.incorrect);
        }
        expect(session.itemProgress['f']!.errors, 1);
        expect(session.itemProgress['g']!.errors, 1);
        expect(session.itemProgress['e']!.errors, 2);
        expect(session.needsBreak, isTrue);
        session = completeNumbersBreak(session);
        expect(session.pass, ['f', 'g', 'e']);
        for (final id in ['f', 'g', 'e']) {
          expect(session.needsBreak, isFalse);
          expect(session.currentEntryId, id);
          session = answer(session, SpeedAnswer.incorrect);
        }
        expect(session.needsBreak, isTrue);
      },
    );

    test('initially short asks every word before its first break', () {
      var session = start(['a', 'b', 'c']);
      expect(session.needsBreak, isFalse);
      for (final id in ['a', 'b', 'c']) {
        expect(session.currentEntryId, id);
        expect(session.needsBreak, isFalse);
        session = answer(session, SpeedAnswer.incorrect);
      }
      expect(session.needsBreak, isTrue);
      expect(session.currentEntryId, isNull);
      expect(session.rotation, 1);
      expect(session.turnIndex, 3);
      expect(
        () => session.answer(entryId: 'a', answer: SpeedAnswer.correct),
        throwsStateError,
      );
    });

    test(
      'shrinking mid-pass still asks every pending word before one game',
      () {
        var session = start(['a', 'b', 'c', 'd', 'e']);
        session = answer(session, SpeedAnswer.correct);
        session = answer(session, SpeedAnswer.correct);
        expect(session.pool, ['c', 'd', 'e']);
        for (final id in ['c', 'd', 'e']) {
          expect(session.currentEntryId, id);
          expect(session.needsBreak, isFalse);
          session = answer(session, SpeedAnswer.incorrect);
        }
        expect(session.needsBreak, isTrue);
        final beforeGame = session;
        session = completeNumbersBreak(session);
        expect(session.pass, ['c', 'd', 'e']);
        expect(session.rotation, 2);
        expect(session.itemProgress, beforeGame.itemProgress);
        expect(session.completedEntryIds, beforeGame.completedEntryIds);
        expect(session.completion, isNull);
        for (final id in ['c', 'd', 'e']) {
          expect(session.needsBreak, isFalse);
          expect(session.currentEntryId, id);
          session = answer(session, SpeedAnswer.correct);
        }
        expect(session.needsBreak, isTrue);
        expect(session.pool, ['c', 'd', 'e']);
      },
    );

    test(
      'waiting replacements keep full rotations until the pool really shrinks',
      () {
        var session = start(['a', 'b', 'c'], poolSize: 2);
        session = answer(session, SpeedAnswer.correct);
        expect(session.pool, ['c', 'b']);
        expect(session.currentEntryId, 'b');
        session = answer(session, SpeedAnswer.incorrect);
        expect(session.needsBreak, isFalse);
        expect(session.pass, ['c', 'b']);
        session = answer(session, SpeedAnswer.correct);
        expect(session.pool, ['b']);
        expect(session.needsBreak, isFalse);
        expect(session.currentEntryId, 'b');
        session = answer(session, SpeedAnswer.correct);
        expect(session.needsBreak, isTrue);
      },
    );

    test(
      'accepted shrinking example asks 4,3,3,1,1 words with four breaks',
      () {
        var session = start(['a', 'b', 'c', 'd']);
        const correct = SpeedAnswer.correct, incorrect = SpeedAnswer.incorrect;
        final passes = [
          [correct, incorrect, incorrect, incorrect],
          [correct, incorrect, correct],
          [correct, correct, correct],
          [correct],
          [correct],
        ];
        var games = 0;
        for (var index = 0; index < passes.length; index++) {
          expect(session.pass.length, passes[index].length);
          for (final grade in passes[index]) {
            expect(session.needsBreak, isFalse);
            session = answer(session, grade);
          }
          if (index < passes.length - 1) {
            expect(session.needsBreak, isTrue);
            session = completeNumbersBreak(session);
            games++;
          }
        }
        expect(games, 4);
        expect(session.isComplete, isTrue);
        expect(session.needsBreak, isFalse);
        expect(session.currentEntryId, isNull);
        expect(session.completedEntryIds, {'a', 'b', 'c', 'd'});
      },
    );

    test(
      'one word needing five attempts has exactly four intervening games',
      () {
        var session = start(['a']);
        final grades = [
          SpeedAnswer.incorrect,
          SpeedAnswer.incorrect,
          SpeedAnswer.correct,
          SpeedAnswer.correct,
          SpeedAnswer.correct,
        ];
        var games = 0;
        for (var index = 0; index < grades.length; index++) {
          expect(session.currentEntryId, 'a');
          session = answer(session, grades[index]);
          if (index < grades.length - 1) {
            expect(session.needsBreak, isTrue);
            session = completeNumbersBreak(session);
            games++;
          }
        }
        expect(games, 4);
        expect(session.isComplete, isTrue);
        expect(session.needsBreak, isFalse);
        expect(session.itemProgress['a']!.errors, 2);
      },
    );

    test('N=1 never gates repetition or waiting replacements with games', () {
      var session = start(['a', 'b'], poolSize: 1);
      for (final grade in [
        SpeedAnswer.incorrect,
        SpeedAnswer.incorrect,
        SpeedAnswer.correct,
        SpeedAnswer.correct,
        SpeedAnswer.correct,
        SpeedAnswer.correct,
      ]) {
        session = answer(session, grade);
        expect(session.needsBreak, isFalse);
      }
      expect(session.isComplete, isTrue);
      expect(session.completedEntryIds, {'a', 'b'});
    });

    test('no final game or completion outside a pending break', () {
      var session = start(['a', 'b']);
      expect(() => session.beginBreak(), throwsStateError);
      session = answer(session, SpeedAnswer.correct);
      expect(session.needsBreak, isFalse);
      expect(() => session.beginBreak(), throwsStateError);
      session = answer(session, SpeedAnswer.correct);
      expect(session.isComplete, isTrue);
      expect(session.needsBreak, isFalse);
      expect(() => session.beginBreak(), throwsStateError);
    });
  });
}
