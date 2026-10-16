import 'dart:math';

/// One numbers break. It has no clock, score or vocabulary state.
final class SpeedNumbersGame {
  SpeedNumbersGame._(Iterable<int> positions, this._nextNumber)
    : positions = List.unmodifiable(positions);

  factory SpeedNumbersGame.start({Random? random}) {
    final positions = List.generate(10, (index) => index + 1)
      ..shuffle(random ?? Random());
    return SpeedNumbersGame._(positions, 1);
  }

  /// Stable shuffled positions for the lifetime of this one game.
  final List<int> positions;
  final int _nextNumber;

  int? get nextNumber => isComplete ? null : _nextNumber;
  int get completedCount => _nextNumber - 1;
  bool get isComplete => _nextNumber == 11;

  SpeedNumbersGame tap(int number) {
    if (isComplete || number != _nextNumber) return this;
    return SpeedNumbersGame._(positions, _nextNumber + 1);
  }
}
