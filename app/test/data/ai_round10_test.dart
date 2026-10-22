import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/ai/ai_wire.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/vocabulary_content.dart';

String uid(int i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';
AiRequest fixture({AiAction action = AiAction.generate, int count = 700}) =>
    AiRequest(
      id: uid(9999),
      action: action,
      goal: 'Everyday vocabulary',
      snapshot: AiSnapshot(
        collectionId: 'synthetic',
        targetLanguage: 'en',
        nativeLanguage: 'de',
        groups: [
          for (var g = 0; g < 3; g++)
            AiGroup(
              CategoryDimensionRecord(
                id: uid(g),
                collectionId: 'synthetic',
                name: 'Group $g',
                mode: CategoryMode.multiple,
                position: g,
              ),
              [
                CategoryValueRecord(
                  id: uid(g + 10),
                  dimensionId: uid(g),
                  name: 'Value $g',
                  position: 0,
                ),
              ],
            ),
        ],
        entries: [
          for (var i = 0; i < count; i++)
            AiEntry(
              VocabularyRecord(
                id: uid(i + 1000),
                collectionId: 'synthetic',
                targetText: i == 0 ? '@0' : 'word $i',
                nativeText: 'Wort $i',
                content: VocabularyContent(
                  hintText:
                      'Context identifies this particular vocabulary meaning.',
                ),
              ),
              {
                for (var g = 0; g < 3; g++) uid(g): {uid(g + 10)},
              },
            ),
        ],
      ),
    );
Map<String, Object?> answer(AiRequest r) => {
  'requestId': r.id,
  'complete': true,
  'groups': [],
  'values': [],
  'cards': [],
  'edits': [],
  'processedIds': [],
  'limitations': [],
};
void main() {
  test(
    'smaller portions keep immutable scope identities and full adoption guard',
    () {
      final base = fixture(action: AiAction.gaps, count: 3);
      final bound = AiOptions(
        contextSize: 1,
        contextIds: {uid(1001)},
      ).bind(base);
      expect(bound.snapshot.entries.single.record.id, uid(1001));
      expect(bound.fullContentKey, base.snapshot.contentKey);
      final review = AiOptions(
        reviewSize: 1,
        reviewedIds: {uid(1000)},
      ).bind(fixture(action: AiAction.review, count: 3));
      expect(review.snapshot.entries.single.record.id, uid(1001));
      expect(review.snapshot.entries.length, 1);
    },
  );
  test(
    'partial review cannot edit an entry outside reported processed scope',
    () {
      final r = fixture(action: AiAction.review, count: 2);
      expect(
        () => AiPlan.parse(r, {
          ...answer(r),
          'complete': false,
          'processedIds': [uid(1000)],
          'edits': [
            {
              'id': 'edit',
              'entryId': uid(1001),
              'field': 'hint',
              'value': 'unprocessed',
              'outcome': 'change',
              'reason': 'bad',
              'rule': 'hint',
            },
          ],
        }),
        throwsA(AiFailure.invalidResponse),
      );
    },
  );
  test(
    '700-word full inventory compacts below transport cap without lexical truncation',
    () {
      final r = fixture(), wire = AiWire(r);
      final before = utf8.encode(jsonEncode(r.toJson())).length,
          after = utf8.encode(jsonEncode(wire.body)).length;
      expect(before, greaterThan(192000));
      expect(after, lessThan(192000));
      final entries = (wire.body['context'] as Map)['entries'] as List;
      expect(entries.length, 700);
      expect(entries.first['target'], '@0');
      final restored = wire.result({
        ...answer(r),
        'processedIds': entries.map((e) => e['id']).toList(),
        'edits': [
          {
            'id': 'proposal',
            'entryId': entries.last['id'],
            'field': 'hint',
            'value': '@0',
            'outcome': 'change',
            'reason': 'meaning',
            'rule': 'hint',
          },
        ],
      });
      expect((restored['processedIds'] as List).last, uid(1699));
      expect((restored['edits'] as List).first['value'], '@0');
      // Synthetic measurements are safe diagnostic evidence, not phone latency.
      // ignore: avoid_print
      print('synthetic700 bytes before=$before after=$after');
    },
  );
  test(
    'review filters include inactive entries and preserve full snapshot guard',
    () {
      final base = fixture(action: AiAction.review, count: 2);
      final options = AiOptions(
        filters: {
          uid(0): {uid(10)},
        },
        reviewSize: 1,
        reviewOffset: 1,
      );
      final bound = options.bind(base);
      expect(bound.snapshot.entries.single.record.id, uid(1001));
      expect(bound.fullContentKey, base.snapshot.contentKey);
      expect((bound.toJson()['options'] as Map)['categoryMode'], 'improve');
    },
  );
  test(
    'disabled review fields and fill-missing reassignment reject proposals',
    () {
      final r = fixture(action: AiAction.review, count: 1);
      final disabled = const AiOptions(checks: {'categories'}).bind(r);
      expect(
        () => AiPlan.parse(disabled, {
          ...answer(disabled),
          'processedIds': [uid(1000)],
          'edits': [
            {
              'id': 'edit',
              'entryId': uid(1000),
              'field': 'hint',
              'value': 'different',
              'outcome': 'change',
              'reason': 'bad',
              'rule': 'hint',
            },
          ],
        }),
        throwsA(AiFailure.invalidResponse),
      );
      final missing = const AiOptions(categoryMode: 'missing').bind(r);
      expect(
        () => AiPlan.parse(missing, {
          ...answer(missing),
          'processedIds': [uid(1000)],
          'edits': [
            {
              'id': 'edit',
              'entryId': uid(1000),
              'field': 'assignments',
              'value': [],
              'outcome': 'change',
              'reason': 'bad',
              'rule': 'categories',
            },
          ],
        }),
        throwsA(AiFailure.invalidResponse),
      );
    },
  );
}
