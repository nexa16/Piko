import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'speed_session_test.dart' show start;

SpeedSession grade(SpeedSession session, SpeedAnswer answer) =>
    session.answer(entryId: session.currentEntryId!, answer: answer);

void main() {
  group('SPEED-003 explicit answers and capped consecutive streak', () {
    test('an error-free item completes on its first Correct', () {
      final initial = start(['a']);
      final next = grade(initial, SpeedAnswer.correct);

      expect(next.isComplete, isTrue);
      expect(next.itemProgress['a']!.errors, 0);
      expect(next.itemProgress['a']!.correctStreak, 1);
      expect(next.itemProgress['a']!.requiredCorrectStreak, 1);
      expect(next.completion!.entryId, 'a');
      expect(next.completion!.errors, 0);
      expect(initial.completion, isNull);
      expect(initial.itemProgress['a']!.correctStreak, 0);
    });

    test('each error raises the required consecutive rights up to four', () {
      for (var errors = 1; errors <= 6; errors++) {
        var session = start(['a'], poolSize: 1);
        for (var index = 0; index < errors; index++) {
          session = grade(session, SpeedAnswer.incorrect);
          expect(session.completion, isNull);
        }
        final required = errors >= 3 ? 4 : errors + 1;
        expect(session.itemProgress['a']!.requiredCorrectStreak, required);
        for (var index = 1; index < required; index++) {
          session = grade(session, SpeedAnswer.correct);
          expect(session.itemProgress['a']!.correctStreak, index);
          expect(session.isComplete, isFalse);
          expect(session.completion, isNull);
        }
        session = grade(session, SpeedAnswer.correct);
        expect(session.isComplete, isTrue);
        expect(session.itemProgress['a']!.errors, errors);
        expect(session.completion!.errors, errors);
      }
    });

    test('Incorrect resets only that item streak and retains total errors', () {
      var session = start(['a'], poolSize: 1);
      session = grade(session, SpeedAnswer.incorrect);
      session = grade(session, SpeedAnswer.correct);
      expect(session.itemProgress['a']!.correctStreak, 1);
      session = grade(session, SpeedAnswer.incorrect);
      expect(session.itemProgress['a']!.errors, 2);
      expect(session.itemProgress['a']!.correctStreak, 0);
      expect(session.itemProgress['a']!.requiredCorrectStreak, 3);
      session = grade(session, SpeedAnswer.correct);
      session = grade(session, SpeedAnswer.correct);
      expect(session.isComplete, isFalse);
      session = grade(session, SpeedAnswer.correct);
      expect(session.isComplete, isTrue);
      expect(session.completion!.errors, 2);
    });

    test(
      'counters are per item; Correct below threshold stays in rotation',
      () {
        var session = start(['a', 'b', 'c'], poolSize: 2);
        session = grade(session, SpeedAnswer.incorrect);
        session = grade(session, SpeedAnswer.correct);
        expect(session.completion!.entryId, 'b');
        expect(session.pool, ['a', 'c']);
        expect(session.currentEntryId, 'a');
        session = grade(session, SpeedAnswer.correct);
        expect(session.completion, isNull);
        expect(session.pool, ['a', 'c']);
        expect(session.currentEntryId, 'c');
        expect(session.itemProgress['a']!.errors, 1);
        expect(session.itemProgress['a']!.correctStreak, 1);
        expect(session.itemProgress['b']!.errors, 0);
        expect(session.itemProgress['b']!.isComplete, isTrue);
        expect(session.itemProgress['c']!.correctStreak, 0);
      },
    );

    test(
      'reads cannot change counters and progress snapshots are immutable',
      () {
        final initial = start(['a', 'b']);
        final next = grade(initial, SpeedAnswer.incorrect);
        expect(initial.currentEntryId, 'a');
        expect(initial.itemProgress['a']!.errors, 0);
        expect(next.currentEntryId, 'b');
        expect(next.itemProgress['a']!.errors, 1);
        expect(
          () => next.itemProgress['a'] = const SpeedItemProgress(),
          throwsUnsupportedError,
        );
        expect(() => next.itemProgress.clear(), throwsUnsupportedError);
        expect(next.itemProgress['b']!.errors, 0);
        expect(next.itemProgress['b']!.correctStreak, 0);
      },
    );
  });
}
