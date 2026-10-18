import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'regular_reviews_test.dart' show Fixture;
import 'statistics_test.dart' show stored;

Map<String, Object?> envelope(
  AiRequest r, {
  List<Object?> cards = const [],
  List<Object?> edits = const [],
  List<Object?> groups = const [],
  List<Object?> values = const [],
  bool complete = true,
}) => {
  'requestId': r.id,
  'complete': complete,
  'groups': groups,
  'values': values,
  'cards': cards,
  'edits': edits,
  'processedIds': r.snapshot.entries.map((e) => e.record.id).toList(),
  'limitations': complete
      ? []
      : ['Only part of the requested scope was processed.'],
};
Map<String, Object?> card(
  String id, {
  String target = 'to learn',
  String native = 'lernen',
  Map<String, Object?> assignments = const {},
}) => {
  'id': id,
  'target': target,
  'native': native,
  'hint': null,
  'examples': [
    {'target': 'I learn French.', 'native': 'Ich lerne FranzÃ¶sisch.'},
  ],
  'assignments': assignments,
  'reason': 'An independent lexical verb.',
};
Map<String, Object?> edit(
  String id,
  String entry,
  String field,
  Object? value, {
  String outcome = 'change',
}) => {
  'id': id,
  'entryId': entry,
  'field': field,
  'value': value,
  'outcome': outcome,
  'reason': 'Distinguish the intended meaning.',
  'rule': 'AI-CARD-001',
};
Future<Fixture> fixture() async {
  final f = Fixture();
  await f.initialize();
  addTearDown(f.db.close);
  return f;
}

void main() {
  test('disabled service cannot prepare or adopt requests', () async {
    final f = await fixture();
    final s = SqliteAiService(f.db);
    await expectLater(
      s.request(
        collectionId: f.owner.id,
        action: AiAction.generate,
        goal: 'Topic',
      ),
      throwsA(AiFailure.disabled),
    );
  });
  test(
    'generation is read only; selected atomic adoption creates fresh learning and consumes response',
    () async {
      final f = await fixture();
      await f.review();
      final s = SqliteAiService(f.db, enabled: true);
      final before = await stored(f.db),
          r = await s.request(
            collectionId: f.owner.id,
            action: AiAction.generate,
            goal: 'Languages',
          );
      final plan = AiPlan.parse(
        r,
        envelope(
          r,
          cards: [
            card('a'),
            card('b', target: 'book', native: 'Buch'),
          ],
        ),
      );
      expect(await stored(f.db), before);
      await s.apply(plan, {'a'});
      final after = await stored(f.db);
      for (final table in [
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
        'collections',
      ]) {
        expect(after[table], before[table]);
      }
      final words = await f.vocabulary.watchByCollection(f.owner.id).first;
      expect(words.length, 2);
      expect(words.last.id, isNot(f.entry.id));
      expect(words.last.content.examples.length, 1);
      expect((await f.learning.forEntry(words.last.id)).length, 2);
      expect(
        (after['learning_items'] as List).take(4),
        before['learning_items'],
      );
      await expectLater(s.apply(plan, {'a'}), throwsA(AiFailure.consumed));
    },
  );
  test(
    'stale content blocks all writes; later learning alone stays applicable and is preserved',
    () async {
      final f = await fixture();
      final service = SqliteAiService(f.db, enabled: true),
          r = await SqliteAiService(
            f.db,
            enabled: true,
          ).request(collectionId: f.owner.id, action: AiAction.review);
      final plan = AiPlan.parse(
        r,
        envelope(r, edits: [edit('hint', f.entry.id, 'hint', 'Number one')]),
      );
      await f.review();
      final learned = (await stored(f.db))['learning_items'];
      await service.apply(plan, {'hint'});
      expect((await stored(f.db))['learning_items'], learned);
      final r2 = await service.request(
        collectionId: f.owner.id,
        action: AiAction.generate,
        goal: 'Topic',
      );
      final p2 = AiPlan.parse(r2, envelope(r2, cards: [card('new')]));
      await f.vocabulary.update(
        id: f.entry.id,
        targetText: 'Changed',
        nativeText: 'Eins',
      );
      final before = await stored(f.db);
      await expectLater(service.apply(p2, {'new'}), throwsA(AiFailure.stale));
      expect(await stored(f.db), before);
    },
  );
  test(
    'definition dependencies, occupied Single and saved Source are protected with full rollback',
    () async {
      final f = await fixture();
      final cats = SqliteCategoriesRepository(f.db),
          service = SqliteAiService(f.db, enabled: true);
      final group = await cats.createDimension(
        collectionId: f.owner.id,
        name: 'Word type',
        mode: CategoryMode.single,
      );
      final noun = await cats.createValue(dimensionId: group.id, name: 'Noun'),
          verb = await cats.createValue(dimensionId: group.id, name: 'Verb');
      await cats.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          group.id: {noun.id},
        },
      );
      final r = await service.request(
        collectionId: f.owner.id,
        action: AiAction.generate,
        goal: 'Topic',
      );
      final plan = AiPlan.parse(
        r,
        envelope(
          r,
          groups: [
            {
              'id': 'newGroup',
              'name': 'New group',
              'mode': 'multiple',
              'reason': 'Useful',
            },
          ],
          values: [
            {
              'id': 'newValue',
              'groupId': 'newGroup',
              'name': 'New value',
              'reason': 'Useful',
            },
          ],
          cards: [
            card(
              'new',
              assignments: {
                'newGroup': ['newValue'],
              },
            ),
          ],
          edits: [
            edit('occupied', f.entry.id, 'assignments', {
              group.id: [verb.id],
            }),
          ],
        ),
      );
      final before = await stored(f.db);
      await expectLater(
        service.apply(plan, {'new'}),
        throwsA(AiFailure.dependency),
      );
      expect(await stored(f.db), before);
      await expectLater(
        service.apply(plan, {'newGroup', 'newValue', 'new', 'occupied'}),
        throwsA(AiFailure.dependency),
      );
      expect(await stored(f.db), before);
      await service.apply(plan, {'newGroup', 'newValue', 'new'});
      expect((await cats.dimensions(f.owner.id)).length, 2);
    },
  );
  test(
    'collision anywhere or failed persistence rolls back definitions, content and learning allocators',
    () async {
      final f = await fixture();
      final service = SqliteAiService(f.db, enabled: true),
          r = await SqliteAiService(f.db, enabled: true).request(
            collectionId: f.owner.id,
            action: AiAction.generate,
            goal: 'Topic',
          );
      final p = AiPlan.parse(
        r,
        envelope(
          r,
          cards: [
            card('a'),
            card('duplicate', target: ' ONE ', native: 'eins'),
          ],
        ),
      );
      final before = await stored(f.db);
      await expectLater(
        service.apply(p, {'a', 'duplicate'}),
        throwsA(AiFailure.collision),
      );
      expect(await stored(f.db), before);
      await expectLater(
        service.apply(p, {
          'a',
        }, beforeCommit: () => throw StateError('Synthetic commit failure')),
        throwsA(isA<StateError>()),
      );
      expect(await stored(f.db), before);
      await service.apply(p, {'a'});
      expect(
        (await f.vocabulary.watchByCollection(f.owner.id).first).length,
        2,
      );
    },
  );
  test(
    'related group is direct same target OR native, includes inactive, never transitive or foreign',
    () async {
      final f = await fixture();
      await f.vocabulary.update(
        id: f.entry.id,
        targetText: 'bank',
        nativeText: 'Bank',
      );
      final river = await f.vocabulary.createWithContent(
        collectionId: f.owner.id,
        targetText: 'BANK',
        nativeText: 'Ufer',
        assignments: {},
        content: const VocabularyContent(),
        active: false,
      );
      final bench = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'bench',
        nativeText: 'Bank',
      );
      await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'shore',
        nativeText: 'Ufer',
      );
      await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'bank account',
        nativeText: 'Bankkonto',
      );
      final service = SqliteAiService(f.db, enabled: true),
          snap = await SqliteAiService(
            f.db,
            enabled: true,
          ).snapshot(f.owner.id);
      final anchor = snap.entries.singleWhere((e) => e.record.id == f.entry.id);
      final r = await service.request(
        collectionId: f.owner.id,
        action: AiAction.hints,
        anchor: anchor,
        targets: {bench.id},
      );
      expect(r.snapshot.entries.map((e) => e.record.id).toSet(), {
        f.entry.id,
        river.id,
        bench.id,
      });
      final invalid = envelope(
        r,
        edits: [edit('a', f.entry.id, 'hint', 'Wrong target')],
      );
      expect(
        () => AiPlan.parse(r, invalid),
        throwsA(AiFailure.invalidResponse),
      );
    },
  );
  test(
    'new anchor and saved group Hints commit together; cancel, collision and storage failure write nothing',
    () async {
      final f = await fixture();
      await f.vocabulary.update(
        id: f.entry.id,
        targetText: 'bank',
        nativeText: 'Bank',
      );
      final service = SqliteAiService(f.db, enabled: true);
      final anchor = AiEntry(
        VocabularyRecord(
          id: 'draft-operation',
          collectionId: f.owner.id,
          targetText: 'bank',
          nativeText: 'Ufer',
        ),
        {},
      );
      final r = await service.request(
        collectionId: f.owner.id,
        action: AiAction.hints,
        anchor: anchor,
      );
      final p = AiPlan.parse(
        r,
        envelope(
          r,
          edits: [
            edit('new', anchor.record.id, 'hint', 'Flussrand'),
            edit('old', f.entry.id, 'hint', 'Geldinstitut'),
          ],
        ),
      );
      final before = await stored(f.db);
      expect(await stored(f.db), before);
      await expectLater(
        service.apply(p, {'new', 'old'}),
        throwsA(AiFailure.stale),
      );
      expect(await stored(f.db), before);
      await expectLater(
        service.apply(
          p,
          {'new', 'old'},
          newAnchor: anchor,
          beforeCommit: () => throw StateError('Failure'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await stored(f.db), before);
      final saved = await service.apply(p, {'new', 'old'}, newAnchor: anchor);
      expect(saved!.content.hintText, 'Flussrand');
      expect(saved.id, isNot(anchor.record.id));
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.content.hintText,
        'Geldinstitut',
      );
    },
  );
  test(
    'partial review requires explicit partial adoption; complete coverage cannot be invented',
    () async {
      final f = await fixture();
      final s = SqliteAiService(f.db, enabled: true),
          r = await SqliteAiService(
            f.db,
            enabled: true,
          ).request(collectionId: f.owner.id, action: AiAction.review);
      final raw = envelope(
        r,
        edits: [edit('hint', f.entry.id, 'hint', 'One')],
        complete: false,
      );
      final p = AiPlan.parse(r, raw);
      await expectLater(s.apply(p, {'hint'}), throwsA(AiFailure.dependency));
      await s.apply(p, {'hint'}, allowPartial: true);
      final invalid = envelope(r);
      invalid['processedIds'] = [];
      expect(
        () => AiPlan.parse(r, invalid),
        throwsA(AiFailure.invalidResponse),
      );
    },
  );
  test(
    'transport context contains no learning, history, activity or other Collection; normal generation has no model-facing count',
    () async {
      final f = await fixture();
      final r = await SqliteAiService(f.db, enabled: true).request(
        collectionId: f.owner.id,
        action: AiAction.generate,
        goal: 'Hotel B1',
      );
      final text = jsonEncode(r.toJson());
      expect(text, contains(f.entry.id));
      expect(text, isNot(contains(f.other.id)));
      for (final forbidden in [
        'cardCeiling',
        'maximumCards',
        'targetCount',
        'learning',
        'history',
        'statistics',
        'active',
        'addedAt',
      ]) {
        expect(text, isNot(contains(forbidden)));
      }
    },
  );
}
