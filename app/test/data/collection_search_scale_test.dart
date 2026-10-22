import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'regular_reviews_test.dart' show Fixture, instant;

void main() {
  for (final size in [600, 5000]) {
    test(
      'search projects $size words with exact matching and learning counts',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        await f.db.transaction(() async {
          for (var i = 1; i < size; i++) {
            await f.vocabulary.create(
              collectionId: f.owner.id,
              targetText: 'Scale word $i',
              nativeText: 'Skalierung $i',
            );
          }
        });
        final query = SqliteCollectionQueryService(f.db);
        for (final search in [
          'Scale',
          'Scale word 4999',
          'no such vocabulary',
        ]) {
          final watch = Stopwatch()..start();
          final result = await query.query(
            collectionId: f.owner.id,
            at: instant,
            search: search,
          );
          watch.stop();
          // Diagnostic timing, not a brittle machine-dependent pass threshold.
          // ignore: avoid_print
          print(
            'search-scale words=$size query="$search" elapsedMs=${watch.elapsedMilliseconds}',
          );
          expect(result.allEntries, hasLength(size));
          final expected = search == 'Scale'
              ? size - 1
              : search == 'Scale word 4999' && size == 5000
              ? 1
              : 0;
          expect(result.entries, hasLength(expected));
          for (final direction in result.directions.values) {
            expect(direction.dueCount, expected);
            expect(direction.newSpeedItems, hasLength(expected));
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
