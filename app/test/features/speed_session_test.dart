import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/speed/speed_session.dart';

SpeedSession start(Iterable<String> entries, {int poolSize = 5}) {
  return SpeedSession.start(
    collectionId: 'collection',
    direction: LearningDirection.targetToNative,
    eligibleEntryIds: entries,
    poolSize: poolSize,
  );
}

void main() {
  group('SPEED-001 initial ordered membership', () {
    test('35 words start with the first five and 30 waiting in order', () {
      final entries = List.generate(35, (index) => 'entry-$index');
      final session = start(entries);

      expect(session.poolSize, 5);
      expect(session.entryIds, entries);
      expect(session.pool, entries.take(5).toList());
      expect(session.waiting, entries.skip(5).toList());
    });

    test('short, exact and size-one launches do not grow the pool', () {
      expect(start(['a', 'b']).pool, ['a', 'b']);
      expect(start(['a', 'b']).waiting, isEmpty);
      expect(start(['a', 'b'], poolSize: 2).pool, ['a', 'b']);
      expect(start(['a', 'b'], poolSize: 2).waiting, isEmpty);
      expect(start(['a', 'b'], poolSize: 1).pool, ['a']);
      expect(start(['a', 'b'], poolSize: 1).waiting, ['b']);
      expect(start(['a'], poolSize: SpeedSession.maxPoolSize).pool, ['a']);
    });

    test('captures one Collection and its fixed launch direction', () {
      for (final direction in LearningDirection.values) {
        final session = SpeedSession.start(
          collectionId: 'other-collection',
          direction: direction,
          eligibleEntryIds: ['c', 'a', 'b'],
        );
        expect(session.collectionId, 'other-collection');
        expect(session.direction, direction);
        expect(session.pool, ['c', 'a', 'b']);
      }
    });

    test('captures input and exposes immutable membership lists', () {
      final entries = ['c', 'a', 'b'];
      final session = start(entries, poolSize: 2);
      entries
        ..clear()
        ..add('later');

      expect(session.entryIds, ['c', 'a', 'b']);
      expect(session.pool, ['c', 'a']);
      expect(session.waiting, ['b']);
      expect(() => session.entryIds.clear(), throwsUnsupportedError);
      expect(() => session.pool.add('later'), throwsUnsupportedError);
      expect(() => session.waiting[0] = 'later', throwsUnsupportedError);
    });

    test('rejects empty, duplicate or missing entry identities', () {
      for (final entries in <List<String>>[
        [],
        ['a', 'a'],
        ['a', ''],
      ]) {
        expect(() => start(entries), throwsArgumentError);
      }
    });

    test('requires a Collection identity and positive safe pool size', () {
      expect(
        () => SpeedSession.start(
          collectionId: '',
          direction: LearningDirection.nativeToTarget,
          eligibleEntryIds: ['a'],
        ),
        throwsArgumentError,
      );
      for (final size in [-1, 0, SpeedSession.maxPoolSize + 1]) {
        expect(() => start(['a'], poolSize: size), throwsArgumentError);
      }
    });
  });
}
