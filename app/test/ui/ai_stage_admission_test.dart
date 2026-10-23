import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/ai/ai_page.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/statistics_test.dart' show stored;
import 'ai_related_hints_test.dart' show HintProvider;
import 'ai_page_test.dart' show tapVisible;

/// Real request/validation/storage boundary with only the stage-validation read
/// held. This does not synthesize a controller plan or mimic its admission logic.
class HeldApplicableService implements AiContentService {
  HeldApplicableService(this.real);
  final SqliteAiService real;
  Completer<void>? gate;
  int heldCalls = 0, applyCalls = 0;
  @override
  bool get enabled => real.enabled;
  @override
  Future<AiSnapshot> snapshot(String id) => real.snapshot(id);
  @override
  Future<AiRequest> request({
    required String collectionId,
    required AiAction action,
    String goal = '',
    bool comprehensiveLevel = false,
    bool allowGroups = true,
    bool allowValues = true,
    AiEntry? anchor,
    Set<String>? targets,
  }) => real.request(
    collectionId: collectionId,
    action: action,
    goal: goal,
    comprehensiveLevel: comprehensiveLevel,
    allowGroups: allowGroups,
    allowValues: allowValues,
    anchor: anchor,
    targets: targets,
  );
  @override
  Future<bool> applicable(AiRequest request, {AiEntry? currentDraft}) async {
    final pending = gate;
    if (pending != null) {
      heldCalls++;
      await pending.future;
    }
    return real.applicable(request, currentDraft: currentDraft);
  }

  @override
  Future<AiAdoption> apply(
    AiPlan plan,
    Set<String> selected, {
    bool allowPartial = false,
    AiEntry? newAnchor,
    bool makeHintVisibilityDefault = false,
    void Function()? beforeCommit,
  }) {
    applyCalls++;
    return real.apply(
      plan,
      selected,
      allowPartial: allowPartial,
      newAnchor: newAnchor,
      makeHintVisibilityDefault: makeHintVisibilityDefault,
      beforeCommit: beforeCommit,
    );
  }
}

class StageHarness {
  final fixture = Fixture(), provider = HintProvider();
  late final service = HeldApplicableService(
    SqliteAiService(fixture.db, enabled: true),
  );
  late NavigatorState navigator;
  MaterialPageRoute<Object?>? hintRoute;
  int draftExited = 0;
  final results = <Object?>[];
  final copy = PikoCopy('en');
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => fixture.db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
    }
  }

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(fixture.initialize);
    final anchor = AiEntry(
      VocabularyRecord(
        id: 'draft-synthetic',
        collectionId: fixture.owner.id,
        targetText: 'One',
        nativeText: 'Erste',
      ),
      {},
    );
    await tester.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                navigator = Navigator.of(context);
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: Column(
                        children: [
                          const Text('Unsaved vocabulary draft'),
                          TextButton(
                            onPressed: () async {
                              final route = hintRoute =
                                  MaterialPageRoute<Object?>(
                                    builder: (_) => AiPage(
                                      service: service,
                                      provider: provider,
                                      collectionId: fixture.owner.id,
                                      collectionName: 'Synthetic',
                                      anchor: anchor,
                                      stageOnly: true,
                                      initialAction: AiAction.hints,
                                    ),
                                  );
                              results.add(await navigator.push<Object?>(route));
                            },
                            child: const Text('Open Hints'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                draftExited++;
              },
              child: const Text('Open draft'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open draft'));
    await flush(tester);
    await tester.tap(find.text('Open Hints'));
    await flush(tester);
    await tapVisible(
      tester,
      find.byWidgetPredicate(
        (w) => w is PikoCheckbox && w.label == copy.text('ai.consent'),
      ),
    );
    await tapVisible(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is PikoIconButton && w.semanticLabel == copy.text('common.close'),
      ),
    );
    await tapVisible(tester, find.byKey(const ValueKey('ai-start')));
    await flush(tester);
    expect(provider.calls, hasLength(1));
    await tapVisible(
      tester,
      find.byKey(ValueKey('ai-select-hint-${fixture.entry.id}')),
    );
    expect(
      tester
          .widget<PikoButton>(find.byKey(const ValueKey('ai-apply')))
          .onPressed,
      isNotNull,
    );
  }

  VoidCallback stage(WidgetTester tester) => tester
      .widget<PikoButton>(find.byKey(const ValueKey('ai-apply')))
      .onPressed!;
  void hold() => service.gate = Completer<void>();
  void release() {
    final pending = service.gate;
    service.gate = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> close(WidgetTester tester) async {
    release();
    await flush(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(fixture.db.close);
  }
}

void main() {
  testWidgets(
    'held stage validation admits one snapshot and never pops the unsaved draft twice',
    (tester) async {
      final h = StageHarness();
      try {
        await h.open(tester);
        final before = await tester.runAsync(() => stored(h.fixture.db));
        h.hold();
        final callback = h.stage(tester);
        callback();
        callback();
        await tester.pump();
        expect(h.service.heldCalls, 1);
        expect(
          tester
              .widget<PikoButton>(find.byKey(const ValueKey('ai-apply')))
              .onPressed,
          isNull,
        );
        h.release();
        await h.flush(tester);
        expect(h.results, hasLength(1));
        final staged = h.results.single as AiStagedHints;
        expect(staged.selected, {'hint-${h.fixture.entry.id}'});
        expect(staged.allowPartial, isFalse);
        expect(h.draftExited, 0);
        expect(find.text('Unsaved vocabulary draft'), findsOneWidget);
        expect(h.service.applyCalls, 0);
        expect(h.provider.calls, hasLength(1));
        expect(await tester.runAsync(() => stored(h.fixture.db)), before);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );
  testWidgets(
    'covered stage route never pops the newer route when validation completes',
    (tester) async {
      final h = StageHarness();
      try {
        await h.open(tester);
        h.hold();
        h.stage(tester)();
        await tester.pump();
        unawaited(
          h.navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Newer route')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        h.release();
        await h.flush(tester);
        expect(find.text('Newer route'), findsOneWidget);
        expect(h.results, isEmpty);
        expect(h.draftExited, 0);
        h.navigator.pop();
        await h.flush(tester);
        expect(find.byType(AiPage), findsOneWidget);
        expect(h.stage(tester), isNotNull);
        expect(h.service.applyCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );
  testWidgets('disposed stage route ignores held validation completion', (
    tester,
  ) async {
    final h = StageHarness();
    try {
      await h.open(tester);
      h.hold();
      h.stage(tester)();
      await tester.pump();
      h.navigator.removeRoute(h.hintRoute!);
      await tester.pumpAndSettle();
      h.release();
      await h.flush(tester);
      expect(h.results, [null]);
      expect(h.draftExited, 0);
      expect(find.text('Unsaved vocabulary draft'), findsOneWidget);
      expect(h.service.applyCalls, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await h.close(tester);
    }
  });
  testWidgets(
    'cached request edit invalidates the plan while stage validation is held',
    (tester) async {
      final h = StageHarness();
      try {
        await h.open(tester);
        final change = tester
            .widget<PikoCheckbox>(
              find.byWidgetPredicate(
                (w) =>
                    w is PikoCheckbox &&
                    w.label == 'One — Erste',
              ),
            )
            .onChanged!;
        h.hold();
        h.stage(tester)();
        change(false);
        await tester.pump();
        h.release();
        await h.flush(tester);
        expect(h.results, isEmpty);
        expect(h.draftExited, 0);
        expect(find.byType(AiPage), findsOneWidget);
        expect(find.text(h.copy.text('ai.error.stale')), findsOneWidget);
        expect(
          tester
              .widget<PikoButton>(find.byKey(const ValueKey('ai-apply')))
              .onPressed,
          isNull,
        );
        expect(h.service.applyCalls, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
  );
}
