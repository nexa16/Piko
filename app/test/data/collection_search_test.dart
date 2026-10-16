import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'speed_eligibility_test.dart' show completeSnapshot;

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  test('search matches case-insensitive substrings in either language with NFC and trimmed query', () async {
    final f = await fixture(), query = SqliteCollectionQueryService(f.db);
    final accented = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'École française', nativeText: 'Französische Schule');
    final before = await completeSnapshot(f.db);
    for (final search in ['ÉCOLE', 'E\u0301COLE', '  ÇAISE  ', 'ÖSISCHE', 'schul']) {
      final result = await query.query(collectionId: f.owner.id, at: instant, search: search);
      expect(result.entries.map((entry) => entry.id), [accented.id]);
      expect(result.allEntries, hasLength(2));
    }
    expect((await query.query(collectionId: f.owner.id, at: instant, search: 'in')).entries.single.id, f.entry.id);
    expect((await query.query(collectionId: f.owner.id, at: instant, search: ' \n ')).entries, hasLength(2));
    expect(await completeSnapshot(f.db), before);
  });

  test('search never folds sharp S to ss, removes accents or introduces fuzzy matches', () async {
    final f = await fixture(), query = SqliteCollectionQueryService(f.db);
    final sharp = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'Straße', nativeText: 'street');
    final ss = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'Strasse', nativeText: 'road');
    await f.vocabulary.create(collectionId: f.owner.id, targetText: 'École', nativeText: 'Schule');
    final before = await completeSnapshot(f.db);
    expect((await query.query(collectionId: f.owner.id, at: instant, search: 'STRAẞE')).entries.single.id, sharp.id);
    expect((await query.query(collectionId: f.owner.id, at: instant, search: 'STRASSE')).entries.single.id, ss.id);
    for (final search in ['ecole', 'strase', 'schulr']) {
      expect((await query.query(collectionId: f.owner.id, at: instant, search: search)).entries, isEmpty);
    }
    expect(await completeSnapshot(f.db), before);
  });

  test('search combines with category OR/AND and returns the exact ordered directional review and Speed subsets', () async {
    final f = await fixture(), query = SqliteCollectionQueryService(f.db);
    final first = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'Alpha one', nativeText: 'Erste');
    final second = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'Alpha two', nativeText: 'Zweite');
    final hidden = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'Beta one', nativeText: 'Dritte');
    final categories = SqliteCategoriesRepository(f.db);
    final dimension = await categories.createDimension(collectionId: f.owner.id, name: 'Topic', mode: CategoryMode.single);
    final food = await categories.createValue(dimensionId: dimension.id, name: 'Food');
    final travel = await categories.createValue(dimensionId: dimension.id, name: 'Travel');
    for (final entry in [first, hidden]) {
      await categories.replaceAssignments(entryId: entry.id, assignments: {dimension.id: {food.id}});
    }
    await categories.replaceAssignments(entryId: second.id, assignments: {dimension.id: {travel.id}});
    await f.review(word: first, rating: LearningRating.good);
    final before = await completeSnapshot(f.db);
    final result = await query.query(collectionId: f.owner.id, at: instant, search: 'ALPHA', filters: {dimension.id: {travel.id, food.id}});
    expect(result.entries.map((entry) => entry.id), [first.id, second.id]);
    final forward = result.directions[LearningDirection.targetToNative]!;
    final reverse = result.directions[LearningDirection.nativeToTarget]!;
    expect(forward.review.map((item) => item.entryId), [second.id]);
    expect(forward.dueCount, 1);
    expect(forward.newSpeedItems.map((item) => item.entryId), [second.id]);
    expect(reverse.review.map((item) => item.entryId), [first.id, second.id]);
    expect(reverse.dueCount, 2);
    expect(reverse.newSpeedItems.map((item) => item.entryId), [first.id, second.id]);
    final foodOnly = await query.query(collectionId: f.owner.id, at: instant, search: 'alpha', filters: {dimension.id: {food.id}});
    expect(foodOnly.entries.single.id, first.id);
    expect(await completeSnapshot(f.db), before);
  });

  test('no matches preserve all data; independent search/filter clearing produces the appropriate subset', () async {
    final f = await fixture(), query = SqliteCollectionQueryService(f.db);
    final word = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'World', nativeText: 'Welt');
    final categories = SqliteCategoriesRepository(f.db);
    final dimension = await categories.createDimension(collectionId: f.owner.id, name: 'Topic', mode: CategoryMode.single);
    final value = await categories.createValue(dimensionId: dimension.id, name: 'Selected');
    await categories.replaceAssignments(entryId: word.id, assignments: {dimension.id: {value.id}});
    final before = await completeSnapshot(f.db);
    final filters = {dimension.id: {value.id}};
    final absent = await query.query(collectionId: f.owner.id, at: instant, search: 'One', filters: filters);
    expect(absent.entries, isEmpty);
    expect(absent.allEntries, hasLength(2));
    expect(absent.directions.values.every((direction) => direction.dueCount == 0 && direction.newSpeedItems.isEmpty), isTrue);
    expect((await query.query(collectionId: f.owner.id, at: instant, search: '', filters: filters)).entries.single.id, word.id);
    expect((await query.query(collectionId: f.owner.id, at: instant, search: 'One')).entries.single.id, f.entry.id);
    expect(await completeSnapshot(f.db), before);
  });

  test('search-hidden earlier deadlines do not schedule visible availability invalidation', () async {
    final f = await fixture(), query = SqliteCollectionQueryService(f.db);
    final hidden = await f.vocabulary.create(collectionId: f.owner.id, targetText: 'Hidden', nativeText: 'Versteckt');
    for (final item in await f.learning.forEntry(f.entry.id)) {
      await f.learning.saveCard(item.id, item.card..due = instant.add(const Duration(minutes: 10)));
    }
    for (final item in await f.learning.forEntry(hidden.id)) {
      await f.learning.saveCard(item.id, item.card..due = instant.add(const Duration(minutes: 1)));
    }
    final before = await completeSnapshot(f.db);
    final selected = await query.query(collectionId: f.owner.id, at: instant, search: 'One');
    expect(selected.nextChangeAt, instant.add(const Duration(minutes: 10)));
    expect((await query.query(collectionId: f.owner.id, at: instant)).nextChangeAt, instant.add(const Duration(minutes: 1)));
    expect(await completeSnapshot(f.db), before);
  });
}
