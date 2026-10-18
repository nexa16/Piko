import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/speed/speed_numbers_game.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'speed_session_test.dart' show start;

void main() {
  test(
    'SPEED-014 letters share deterministic order and reject wrong ordinals',
    () {
      var game = SpeedNumbersGame.start(
        random: Random(42),
        kind: SpeedBreakKind.letters,
      );
      expect(
        game.positions,
        SpeedNumbersGame.start(random: Random(42)).positions,
      );
      expect(game.positions.map(game.label).toSet(), {
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
      });
      for (var ordinal = 1; ordinal <= 10; ordinal++) {
        expect(game.tap(ordinal + 1), same(game));
        expect(game.label(game.nextNumber!), String.fromCharCode(64 + ordinal));
        game = game.tap(ordinal);
        expect(game.kind, SpeedBreakKind.letters);
      }
      expect(game.isComplete, isTrue);
    },
  );

  test(
    'SPEED-014 completed breaks alternate, survive exclusion and reset per launch',
    () {
      var session = start(['a', 'b']);
      for (var round = 0; round < 3; round++) {
        for (final id in ['a', 'b']) {
          session = session.answer(entryId: id, answer: SpeedAnswer.incorrect);
        }
        final progress = session.itemProgress;
        session = session.beginBreak(random: Random(42));
        expect(
          session.numberGame!.kind,
          round.isEven ? SpeedBreakKind.numbers : SpeedBreakKind.letters,
        );
        expect(session.completedBreaks, round);
        expect(session.excluding({'unrelated'}), same(session));
        expect(session.beginBreak(), same(session));
        for (var ordinal = 1; ordinal <= 10; ordinal++) {
          session = session.tapNumber(ordinal);
        }
        expect(session.itemProgress, progress);
        expect(session.completion, isNull);
        expect(session.completedBreaks, round + 1);
      }
      final fresh = start([
        'c',
      ]).answer(entryId: 'c', answer: SpeedAnswer.incorrect).beginBreak();
      expect(fresh.numberGame!.kind, SpeedBreakKind.numbers);
      session = session.answer(entryId: 'a', answer: SpeedAnswer.incorrect);
      session = session
          .answer(entryId: 'b', answer: SpeedAnswer.incorrect)
          .beginBreak();
      final game = session.numberGame;
      session = session.excluding({'a'});
      expect(session.numberGame, same(game));
      expect(session.completedBreaks, 3);
      expect(session.excluding({'b'}).numberGame, isNull);
    },
  );

  group('SPEED-012 shuffled ascending numbers game', () {
    test('captures exactly 1–10 in stable shuffled, immutable positions', () {
      final game = SpeedNumbersGame.start(random: Random(42));
      expect(game.positions.toSet(), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10});
      expect(game.positions, hasLength(10));
      expect(game.positions, isNot(List.generate(10, (index) => index + 1)));
      expect(
        SpeedNumbersGame.start(random: Random(42)).positions,
        game.positions,
      );
      expect(() => game.positions.clear(), throwsUnsupportedError);
      final next = game.tap(1);
      expect(next.positions, game.positions);
      expect(game.nextNumber, 1);
      expect(next.nextNumber, 2);
    });

    test('wrong, repeated and out-of-range taps never advance', () {
      var game = SpeedNumbersGame.start(random: Random(7));
      for (var expected = 1; expected <= 10; expected++) {
        for (final wrong in [0, -1, 11, expected - 1, expected + 1]) {
          expect(game.tap(wrong), same(game));
          expect(game.nextNumber, expected);
        }
        game = game.tap(expected);
        expect(game.completedCount, expected);
      }
      expect(game.isComplete, isTrue);
      expect(game.nextNumber, isNull);
      expect(game.tap(10), same(game));
      expect(game.tap(1), same(game));
    });

    test(
      'the tenth correct number automatically opens the complete next pass',
      () {
        var session = start(['a', 'b', 'c']);
        for (final id in ['a', 'b', 'c']) {
          session = session.answer(entryId: id, answer: SpeedAnswer.incorrect);
        }
        expect(session.needsBreak, isTrue);
        expect(session.numberGame, isNull);
        expect(() => session.tapNumber(1), throwsStateError);
        final before = session;
        session = session.beginBreak(random: Random(42));
        expect(session.beginBreak(random: Random(7)), same(session));
        expect(session.tapNumber(10), same(session));
        for (var number = 1; number <= 9; number++) {
          session = session.tapNumber(number);
          expect(session.needsBreak, isTrue);
          expect(session.currentEntryId, isNull);
          expect(session.itemProgress, before.itemProgress);
        }
        session = session.tapNumber(10);
        expect(session.needsBreak, isFalse);
        expect(session.numberGame, isNull);
        expect(session.pass, ['a', 'b', 'c']);
        expect(session.currentEntryId, 'a');
        expect(session.rotation, 2);
        expect(session.itemProgress, before.itemProgress);
        expect(session.completedEntryIds, before.completedEntryIds);
        expect(session.completion, isNull);
        for (final id in ['a', 'b', 'c']) {
          expect(session.currentEntryId, id);
          expect(session.needsBreak, isFalse);
          session = session.answer(entryId: id, answer: SpeedAnswer.correct);
        }
        expect(session.needsBreak, isTrue);
        expect(() => session.tapNumber(10), throwsStateError);
      },
    );

    test('game transitions never reissue an item completion intent', () {
      var session = start(['a', 'b']);
      session = session.answer(entryId: 'a', answer: SpeedAnswer.incorrect);
      session = session.answer(entryId: 'b', answer: SpeedAnswer.correct);
      expect(session.completion!.entryId, 'b');
      final progress = session.itemProgress;
      session = session.beginBreak(random: Random(9));
      for (var number = 1; number <= 10; number++) {
        expect(session.completion, isNull);
        session = session.tapNumber(number);
        expect(session.itemProgress, progress);
        expect(session.completedEntryIds, {'b'});
      }
      expect(session.completion, isNull);
      expect(session.currentEntryId, 'a');
    });

    test(
      'no numbers game is admitted during vocabulary or after completion',
      () {
        var session = start(['a']);
        expect(() => session.beginBreak(), throwsStateError);
        expect(() => session.tapNumber(1), throwsStateError);
        session = session.answer(entryId: 'a', answer: SpeedAnswer.correct);
        expect(() => session.beginBreak(), throwsStateError);
        expect(() => session.tapNumber(10), throwsStateError);
      },
    );
  });
}
