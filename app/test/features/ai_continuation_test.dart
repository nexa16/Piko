import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/features/ai/ai_operation_controller.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/ai_service_test.dart' show envelope, card;
import '../data/statistics_test.dart' show stored;
import 'ai_operation_test.dart' show DelayedProvider, reachProvider;

Future<void> nextCall(DelayedProvider p, int count) async {
  for (var i = 0; i < 100 && p.calls.length < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(p.calls.length, count);
}

void main() {
  test(
    'explicit portions preserve snapshot, prior proposals and choices, then adopt together once',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = DelayedProvider(), s = SqliteAiService(f.db, enabled: true);
      final owner = AiOperationController(
        service: s,
        provider: p,
        collectionId: f.owner.id,
      );
      addTearDown(owner.dispose);
      final before = await stored(f.db);
      final first = owner.start(action: AiAction.generate, goal: 'Topic');
      await reachProvider(p);
      p.replies[0].complete(
        envelope(p.calls[0], cards: [card('a')], complete: false),
      );
      await first;
      owner.choose('a', true);
      expect(owner.canApply, isFalse);
      expect(owner.canContinue, isTrue);
      final second = owner.continueGeneration();
      await nextCall(p, 2);
      expect(identical(p.calls[0].snapshot, p.calls[1].snapshot), isTrue);
      expect(p.calls[1].id, isNot(p.calls[0].id));
      final transmitted = jsonDecode(jsonEncode(p.calls[1].toJson())) as Map;
      expect(transmitted['previous']['cards'][0]['id'], 'a');
      expect(transmitted['previous']['cards'][0]['assignments'], isList);
      expect(transmitted.containsKey('cardCeiling'), isFalse);
      p.replies[1].complete(
        envelope(
          p.calls[1],
          cards: [card('b', target: 'to read', native: 'lesen')],
        ),
      );
      await second;
      expect(owner.plan!.cards.map((c) => c.id), ['a', 'b']);
      expect(owner.selected, {'a'});
      expect(owner.canContinue, isFalse);
      expect(await stored(f.db), before);
      owner.choose('b', true);
      await owner.apply();
      expect(owner.applied, isTrue);
      expect(p.calls.length, 2);
    },
  );
  test(
    'failed portion retains preview; changed inventory blocks continuation before network',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = DelayedProvider(), s = SqliteAiService(f.db, enabled: true);
      final owner = AiOperationController(
        service: s,
        provider: p,
        collectionId: f.owner.id,
      );
      addTearDown(owner.dispose);
      final first = owner.start(action: AiAction.generate, goal: 'Topic');
      await reachProvider(p);
      p.replies[0].complete(
        envelope(p.calls[0], cards: [card('a')], complete: false),
      );
      await first;
      owner.choose('a', true);
      final second = owner.continueGeneration();
      await nextCall(p, 2);
      p.replies[1].completeError(AiFailure.network);
      await second;
      expect(owner.plan!.cards.single.id, 'a');
      expect(owner.selected, {'a'});
      await f.db.customStatement(
        "UPDATE vocabulary_entries SET target_text='synthetic changed' WHERE collection_id='${f.owner.id}'",
      );
      await owner.continueGeneration();
      expect(owner.error, AiFailure.stale);
      expect(p.calls.length, 2);
    },
  );
  test(
    'accumulation rejects repeated IDs and cumulative topic overflow instead of truncation',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final s = SqliteAiService(f.db, enabled: true);
      final r = await s.request(
        collectionId: f.owner.id,
        action: AiAction.generate,
        goal: 'Topic',
      );
      final initial = AiPlan.parse(
        r,
        envelope(
          r,
          cards: [for (var i = 0; i < 199; i++) card('c$i')],
          complete: false,
        ),
      );
      final next = AiRequest(
        id: 'next',
        action: r.action,
        snapshot: r.snapshot,
        previous: initial.toJson(),
      );
      expect(
        () => AiPlan.accumulate(next, envelope(next, cards: [card('c0')])),
        throwsA(AiFailure.invalidResponse),
      );
      expect(
        () => AiPlan.accumulate(
          next,
          envelope(next, cards: [card('new1'), card('new2')]),
        ),
        throwsA(AiFailure.limit),
      );
    },
  );
}
