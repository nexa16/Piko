import 'dart:math';

enum SpeedBreakKind { numbers, letters }

/// One ordering break. Ordinals map to 1–10 or A–J without learning state.
final class SpeedNumbersGame {
  SpeedNumbersGame._(Iterable<int> positions, this._nextNumber, this.kind)
    : positions = List.unmodifiable(positions);

  factory SpeedNumbersGame.start({
    Random? random,
    SpeedBreakKind kind = SpeedBreakKind.numbers,
  }) {
    final positions = List.generate(10, (index) => index + 1)
      ..shuffle(random ?? Random());
    return SpeedNumbersGame._(positions, 1, kind);
  }

  /// Stable shuffled positions for the lifetime of this one game.
  final List<int> positions;
  final int _nextNumber;
  final SpeedBreakKind kind;

  String label(int ordinal) => kind == SpeedBreakKind.numbers
      ? '$ordinal'
      : String.fromCharCode(64 + ordinal);

  int? get nextNumber => isComplete ? null : _nextNumber;
  int get completedCount => _nextNumber - 1;
  bool get isComplete => _nextNumber == 11;

  SpeedNumbersGame tap(int number) {
    if (isComplete || number != _nextNumber) return this;
    return SpeedNumbersGame._(positions, _nextNumber + 1, kind);
  }
}
