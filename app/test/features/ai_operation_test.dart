import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/features/ai/ai_operation_controller.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/ai_service_test.dart' show envelope, card;
import '../data/statistics_test.dart' show stored;

class DelayedProvider implements AiProvider {
  final calls = <AiRequest>[];
  final replies = <Completer<Map<String, Object?>>>[];
  @override
  Future<Map<String, Object?>> generate(AiRequest r) {
    calls.add(r);
    final reply = Completer<Map<String, Object?>>();
    replies.add(reply);
    return reply.future;
  }

  @override
  void close() {}
}

Future<void> reachProvider(DelayedProvider p) async {
  for (var i = 0; i < 100 && p.calls.isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(p.calls.length, 1);
}

void main() {
  test(
    'explicit single flight, cancel and late reply never write or revive proposals',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = DelayedProvider();
      final owner = AiOperationController(
        service: SqliteAiService(f.db, enabled: true),
        provider: p,
        collectionId: f.owner.id,
      );
      addTearDown(owner.dispose);
      final before = await stored(f.db),
          first = owner.start(action: AiAction.generate, goal: 'Hotel B1');
      await reachProvider(p);
      await owner.start(action: AiAction.generate, goal: 'Another');
      expect(p.calls.length, 1);
      owner.cancel();
      p.replies.single.complete(
        envelope(p.calls.single, cards: [card('late')]),
      );
      await first;
      expect(owner.plan, isNull);
      expect(await stored(f.db), before);
      expect(owner.requesting, isFalse);
    },
  );
  test(
    'input/context edit invalidates pending reply, dispose prevents late publication',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = DelayedProvider();
      final owner = AiOperationController(
        service: SqliteAiService(f.db, enabled: true),
        provider: p,
        collectionId: f.owner.id,
      );
      final before = await stored(f.db);
      final started = owner.start(action: AiAction.generate, goal: 'Hotel');
      await reachProvider(p);
      owner.invalidate();
      p.replies.single.complete(envelope(p.calls.single, cards: [card('old')]));
      await started;
      expect(owner.plan, isNull);
      owner.dispose();
      expect(await stored(f.db), before);
    },
  );
  test(
    'only selected adoption writes; failure retains proposal and selection, explicit retry revalidates',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = DelayedProvider(),
          service = SqliteAiService(f.db, enabled: true);
      final owner = AiOperationController(
        service: service,
        provider: p,
        collectionId: f.owner.id,
      );
      addTearDown(owner.dispose);
      final started = owner.start(action: AiAction.generate, goal: 'Topic');
      await reachProvider(p);
      p.replies.single.complete(envelope(p.calls.single, cards: [card('a')]));
      await started;
      expect(owner.selected, isEmpty);
      expect(owner.canApply, isFalse);
      owner.choose('a', true);
      expect(owner.canApply, isTrue);
      await f.db.customStatement(
        "CREATE TRIGGER fail_ai BEFORE INSERT ON vocabulary_entries BEGIN SELECT RAISE(ABORT,'synthetic'); END",
      );
      final before = await stored(f.db);
      await expectLater(owner.apply(), throwsA(anything));
      expect(await stored(f.db), before);
      expect(owner.selected, {'a'});
      expect(owner.plan, isNotNull);
      expect(owner.applying, isFalse);
      await f.db.customStatement('DROP TRIGGER fail_ai');
      await owner.apply();
      expect(owner.applied, isTrue);
      expect(owner.canApply, isFalse);
      expect(p.calls.length, 1);
    },
  );
  test(
    'disabled requests never dispatch provider even via directly restored operation',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = DelayedProvider();
      final owner = AiOperationController(
        service: SqliteAiService(f.db, enabled: false),
        provider: p,
        collectionId: f.owner.id,
      );
      addTearDown(owner.dispose);
      await owner.start(action: AiAction.generate, goal: 'Topic');
      expect(owner.error, AiFailure.disabled);
      expect(p.calls, isEmpty);
      expect(owner.plan, isNull);
    },
  );
}
