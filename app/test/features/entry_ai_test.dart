import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/ai/ai_content.dart';
import 'package:piko/features/ai/entry_ai_controller.dart';
import 'package:piko/features/ai/supabase_ai_gateway.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/statistics_test.dart' show stored;

class HeldAiGateway implements AiContentGateway {
  @override
  bool configured = true;
  int connections = 0, disconnections = 0;
  final calls = <AiContentRequest>[];
  Completer<Object?>? response;
  @override
  Future<void> connect() async {
    connections++;
  }

  @override
  Future<void> disconnect() async {
    disconnections++;
  }

  @override
  Future<Object?> generate(AiContentRequest request) {
    calls.add(request);
    return (response = Completer<Object?>()).future;
  }

  void example() {
    final request = calls.last;
    response!.complete({
      'requestId': request.requestId,
      'task': request.task.name,
      'example': {
        'targetText': 'Le chat dort.',
        'nativeText': 'Die Katze schläft.',
      },
    });
  }

  void hint() {
    final request = calls.last;
    response!.complete({
      'requestId': request.requestId,
      'task': request.task.name,
      'hint': 'Ein Haustier, das miaut.',
    });
  }
}

void main() {
  late Fixture fixture;
  late EntrySessionController session;
  late HeldAiGateway gateway;
  late AiAccess access;
  late EntryAiController ai;
  setUp(() async {
    fixture = Fixture();
    await fixture.initialize();
    session = EntrySessionController(
      collectionId: fixture.owner.id,
      repository: fixture.vocabulary,
    );
    await session.initializeContentDefault();
    gateway = HeldAiGateway();
    access = AiAccess(gateway);
    ai = EntryAiController(
      session: session,
      access: access,
      targetLanguage: 'fr',
      nativeLanguage: 'de',
    );
  });
  tearDown(() async {
    ai.dispose();
    session.dispose();
    access.dispose();
    await fixture.db.close();
  });
  void pair() {
    session.setTargetText('chat');
    session.setNativeText('Katze');
  }

  test(
    'ordinary construction and partial input create no identity or request',
    () async {
      expect(gateway.connections, 0);
      await access.connect();
      session.setTargetText('chat');
      await ai.request(AiTask.example);
      expect(gateway.calls, isEmpty);
      expect(SupabaseAiGateway().configured, isFalse);
      expect(
        SupabaseAiGateway(
          url: 'https://example.supabase.co',
          publishableKey: 'sb_publishable_test',
        ).configured,
        isFalse,
      );
    },
  );
  test(
    'explicit preview/use does not save; confirmation persists ordinary content',
    () async {
      pair();
      await access.connect();
      final before = await stored(fixture.db);
      final pending = ai.request(AiTask.example);
      await ai.request(AiTask.example);
      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.toJson().keys.toSet(), {
        'requestId',
        'task',
        'targetLanguage',
        'nativeLanguage',
        'targetText',
        'nativeText',
      });
      gateway.example();
      await pending;
      expect(session.draft.content.examples, isEmpty);
      ai.use();
      ai.use();
      expect(session.draft.content.examples, hasLength(1));
      expect(
        (session.draft.targetText, session.draft.nativeText),
        ('chat', 'Katze'),
      );
      expect(await stored(fixture.db), before);
      final saved = await session.confirmAndNext();
      final reopened = await fixture.vocabulary.watchById(saved.id).first;
      expect(reopened!.content.examples.single.targetText, 'Le chat dort.');
      expect(session.draft.content.examples, isEmpty);
    },
  );
  for (final change in [
    'pair-back',
    'example-edit-back',
    'confirm',
    'cancel',
    'activate-saved',
    'disconnect',
  ]) {
    test('$change permanently invalidates a delayed result', () async {
      pair();
      await access.connect();
      final pending = ai.request(AiTask.example);
      switch (change) {
        case 'pair-back':
          session.setTargetText('chien');
          session.setTargetText('chat');
        case 'example-edit-back':
          session.setContent(const VocabularyContent(exampleTargetText: 'raw'));
          session.setContent(const VocabularyContent());
        case 'confirm':
          await session.confirmAndNext();
        case 'cancel':
          ai.cancel();
        case 'activate-saved':
          final saved = await session.confirmAndNext();
          session.selectSavedEntry(saved.id);
        case 'disconnect':
          await access.disconnect();
      }
      gateway.example();
      await pending;
      ai.use();
      expect(ai.suggestion, isNull);
      expect(session.draft.content.examples, isEmpty);
    });
  }
  test(
    'hint review preserves old hint/visibility; discard and explicit replacement',
    () async {
      pair();
      session.setContent(
        const VocabularyContent(
          hintText: 'old',
          hintVisibility: HintVisibility.hidden,
        ),
      );
      await access.connect();
      var pending = ai.request(AiTask.hint);
      gateway.hint();
      await pending;
      ai.cancel();
      expect(session.draft.content.hintText, 'old');
      pending = ai.request(AiTask.hint);
      gateway.hint();
      await pending;
      ai.use();
      expect(session.draft.content.hintText, 'Ein Haustier, das miaut.');
      expect(session.draft.content.hintVisibility, HintVisibility.hidden);
    },
  );
  test(
    'unrelated hint edit preserves example; task switch discards its preview; duplicate stays single',
    () async {
      pair();
      await access.connect();
      var pending = ai.request(AiTask.example);
      session.setContent(const VocabularyContent(hintText: 'manual hint'));
      gateway.example();
      await pending;
      ai.use();
      pending = ai.request(AiTask.example);
      gateway.example();
      await pending;
      ai.use();
      expect(session.draft.content.examples, hasLength(1));
      pending = ai.request(AiTask.example);
      gateway.example();
      await pending;
      pending = ai.request(AiTask.hint);
      expect(ai.suggestion, isNull);
      gateway.hint();
      await pending;
      expect(ai.suggestion, isA<AiHint>());
    },
  );
  test(
    'manual save does not wait for failed/cancelled AI and malformed output cannot apply',
    () async {
      pair();
      await access.connect();
      final pending = ai.request(AiTask.example);
      final saved = await session.confirmAndNext();
      expect(saved.targetText, 'chat');
      gateway.response!.completeError(AiFailure.limit);
      await pending;
      expect(ai.error, isNull);
      expect(session.draft.targetText, isEmpty);
      pair();
      final next = ai.request(AiTask.hint);
      gateway.response!.complete({
        'requestId': gateway.calls.last.requestId,
        'task': 'hint',
        'hint': 'x' * 2001,
      });
      await next;
      expect(ai.error, AiFailure.invalidResponse);
      ai.use();
      expect(session.draft.content.hintText, isNull);
    },
  );
  test('dispose suppresses delayed response without persistence', () async {
    pair();
    await access.connect();
    final pending = ai.request(AiTask.example);
    ai.dispose();
    gateway.example();
    await pending;
    ai = EntryAiController(
      session: session,
      access: access,
      targetLanguage: 'fr',
      nativeLanguage: 'de',
    );
    expect(ai.suggestion, isNull);
    expect(session.draft.content.examples, isEmpty);
  });
  test(
    'switching task during a held request invalidates it without another paid call',
    () async {
      pair();
      await access.connect();
      final pending = ai.request(AiTask.example);
      await ai.request(AiTask.hint);
      expect(ai.task, AiTask.hint);
      expect(ai.error, AiFailure.busy);
      expect(gateway.calls, hasLength(1));
      gateway.example();
      await pending;
      expect(ai.suggestion, isNull);
      final retry = ai.request(AiTask.hint);
      gateway.hint();
      await retry;
      expect(ai.suggestion, isA<AiHint>());
    },
  );
}
