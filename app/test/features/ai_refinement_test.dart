import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/features/ai/ai_operation_controller.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/ai_service_test.dart' show envelope, card;
import '../data/statistics_test.dart' show stored;
import 'ai_operation_test.dart' show DelayedProvider, reachProvider;
import 'ai_continuation_test.dart' show nextCall;

void main() {
  for (final instruction in [
    null,
    'More words',
    'Fewer words',
    'Focus on food',
    'Correct spelling',
  ]) {
    test(
      'replacement $instruction keeps prior preview until review and clears choices before adoption',
      () async {
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final p = DelayedProvider();
        final c = AiOperationController(
          service: SqliteAiService(f.db, enabled: true),
          provider: p,
          collectionId: f.owner.id,
        );
        addTearDown(c.dispose);
        final before = await stored(f.db);
        final initial = c.start(action: AiAction.generate, goal: 'Hotel B1');
        await reachProvider(p);
        p.replies[0].complete(envelope(p.calls[0], cards: [card('a')]));
        await initial;
        c.choose('a', true);
        final old = c.plan;
        final pending = c.replaceGeneration(instruction: instruction);
        await nextCall(p, 2);
        expect(c.plan, same(old));
        expect(c.selected, {'a'});
        expect(c.canApply, false);
        final request = p.calls[1];
        expect(request.goal, 'Hotel B1');
        expect(request.snapshot, same(p.calls[0].snapshot));
        expect(request.previous, isNull);
        expect(request.followUp!['parentRequestId'], p.calls[0].id);
        expect(request.followUp!['rootRequestId'], p.calls[0].id);
        expect(
          request.followUp!['kind'],
          instruction == null ? 'regenerate' : 'refine',
        );
        expect(request.followUp!.containsKey('result'), instruction != null);
        p.replies[1].complete(
          envelope(
            request,
            cards: [card('a', target: 'to read', native: 'lesen')],
          ),
        );
        await pending;
        expect(c.plan, same(old));
        expect(c.replacement!.cards.single.target, 'to read');
        expect(c.canApply, false);
        expect(await stored(f.db), before);
        await c.acceptReplacement();
        expect(c.selected, isEmpty);
        expect(c.canApply, false);
        expect(c.plan!.cards.single.target, 'to read');
        expect(c.replacement, isNull);
        c.choose('a', true);
        await c.apply();
        expect(c.applied, true);
        expect(p.calls.length, 2);
        await c.replaceGeneration(instruction: 'More');
        expect(p.calls.length, 2);
      },
    );
  }
  test(
    'failure, canceled late result, rejection and stale candidate preserve previous content and learning',
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
          initial = owner.start(action: AiAction.gaps);
      await reachProvider(p);
      p.replies[0].complete(envelope(p.calls[0], cards: [card('old')]));
      await initial;
      owner.choose('old', true);
      final old = owner.plan;
      final failed = owner.replaceGeneration(instruction: 'More');
      await nextCall(p, 2);
      p.replies[1].completeError(AiFailure.limit);
      await failed;
      expect(owner.plan, same(old));
      expect(owner.selected, {'old'});
      expect(owner.error, AiFailure.limit);
      final canceled = owner.replaceGeneration();
      await nextCall(p, 3);
      owner.stopWaiting();
      p.replies[2].complete(envelope(p.calls[2], cards: [card('late')]));
      await canceled;
      expect(owner.plan, same(old));
      expect(owner.replacement, isNull);
      expect(owner.selected, {'old'});
      final next = owner.replaceGeneration(instruction: 'Fewer');
      await nextCall(p, 4);
      p.replies[3].complete(envelope(p.calls[3], cards: [card('candidate')]));
      await next;
      owner.keepPrevious();
      expect(owner.plan, same(old));
      expect(owner.selected, {'old'});
      expect(await stored(f.db), before);
      final stale = owner.replaceGeneration();
      await nextCall(p, 5);
      await f.db.customStatement(
        "UPDATE vocabulary_entries SET target_text='synthetic changed' WHERE collection_id='${f.owner.id}'",
      );
      p.replies[4].complete(envelope(p.calls[4], cards: [card('stale')]));
      await stale;
      expect(owner.plan, same(old));
      expect(owner.replacement, isNull);
      expect(owner.error, AiFailure.stale);
      expect(owner.canApply, false);
    },
  );
}
