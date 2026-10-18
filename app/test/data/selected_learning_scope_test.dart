import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/data/learning_item.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'speed_eligibility_test.dart' show completeSnapshot;

void main() {
  test(
    'F26 hidden selected UUIDs deduplicate, preserve directional due rules and independent Speed without writes',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      // Review a new item successfully, leaving its normal due date in the future.
      await f.review();
      final before = await completeSnapshot(f.db);
      final query = SqliteCollectionQueryService(f.db);
      final full = await query.query(
        collectionId: f.owner.id,
        at: instant,
        search: 'does not match',
      );
      expect(full.entries, isEmpty);
      final selected = full.selected({f.entry.id, f.other.id, 'deleted'});
      expect(selected.entries.map((e) => e.id), [f.entry.id]);
      expect(selected.allEntries.length, full.allEntries.length);
      expect(
        selected.directions[LearningDirection.targetToNative]!.dueCount,
        0,
      );
      expect(
        selected.directions[LearningDirection.nativeToTarget]!.dueCount,
        1,
      );
      for (final d in LearningDirection.values) {
        expect(selected.directions[d]!.newSpeedItems.map((i) => i.entryId), [
          f.entry.id,
        ]);
      }
      final zero = full.selected({});
      expect(zero.entries, isEmpty);
      expect(
        zero.directions.values.every(
          (d) => d.dueCount == 0 && d.newSpeedItems.isEmpty,
        ),
        true,
      );
      expect(await completeSnapshot(f.db), before);
    },
  );
}
