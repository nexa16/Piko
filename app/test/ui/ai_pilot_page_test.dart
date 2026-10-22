import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/features/ai/ai_page.dart';
import 'package:piko/features/ai/ai_pilot_control.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/ai_service_test.dart' show envelope, card;
import '../data/statistics_test.dart' show stored;
import 'ai_page_test.dart' show tapVisible;

class PilotFixtureProvider
    implements AiProvider, AiPilotAccess, CancelableAiProvider {
  final calls = <AiRequest>[], events = <String>[];
  bool consented = false,
      withdrawn = false,
      fail = false,
      delay = false,
      malformedWithdrawal = false;
  Completer<Map<String, Object?>>? pending;
  @override
  Future<Map<String, Object?>> generate(AiRequest r) async {
    if (!consented || withdrawn) throw AiFailure.accessDenied;
    calls.add(r);
    if (fail) throw AiFailure.network;
    if (delay) {
      pending = Completer<Map<String, Object?>>();
      return pending!.future;
    }
    return envelope(
      r,
      cards: [
        {
          ...card(
            'proposal',
            target: calls.length == 1 ? 'to learn' : 'to read',
            native: calls.length == 1 ? 'lernen' : 'lesen',
          ),
          'examples': [
            calls.length == 1
                ? {
                    'target': 'I learn French.',
                    'native': 'Ich lerne Französisch.',
                  }
                : {'target': 'I read a book.', 'native': 'Ich lese ein Buch.'},
          ],
        },
      ],
    );
  }

  @override
  Future<Map<String, Object?>> pilot(
    String operation, [
    Map<String, Object?> data = const {},
  ]) async {
    events.add(operation);
    if (operation == 'withdraw') {
      withdrawn = true;
      consented = false;
      return malformedWithdrawal
          ? {}
          : {
              'withdrawn': true,
              'livePayloadsDeleted': true,
              'backupExpiryDays': 7,
            };
    }
    if (withdrawn) throw AiFailure.accessDenied;
    if (operation == 'consent') {
      expect(data['version'], 'synthetic-r2');
      consented = true;
    }
    if (operation == 'adoption') {
      expect(data['selected'], ['proposal']);
      return {'recorded': true};
    }
    if (operation == 'feedback') return {'recorded': true};
    return {
      'version': 'synthetic-r2',
      'contact': 'Synthetic invitation contact',
      'processors': 'Synthetic local test; no provider calls',
      'endsAt': '2026-11-01T00:00:00Z',
      'consented': consented,
    };
  }

  @override
  void cancel(String id) {
    events.add('cancel');
  }

  @override
  void close() {}
}

void main() {
  testWidgets(
    'withdrawal is never announced as deleted after incomplete server acknowledgment',
    (t) async {
      final p = PilotFixtureProvider()..malformedWithdrawal = true,
          copy = PikoCopy('en');
      var ready = true;
      await t.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiPilotControl(
                provider: p,
                onReady: (v) => ready = v,
                onWithdraw: () => ready = false,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapVisible(t, find.byKey(const ValueKey('ai-pilot-withdraw')));
      expect(ready, false);
      expect(find.text(copy.text('ai.pilotWithdrawn')), findsNothing);
      expect(find.text(copy.text('ai.withdrawPending')), findsOneWidget);
      p.malformedWithdrawal = false;
      await tapVisible(t, find.byKey(const ValueKey('ai-pilot-withdraw')));
      expect(find.text(copy.text('ai.pilotWithdrawn')), findsOneWidget);
    },
  );

  for (final locale in ['en', 'de']) {
    testWidgets(
      'pilot $locale 320dp/200% consent, preserved failed/canceled preview, explicit replacement and adoption',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(320, 800);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final p = PilotFixtureProvider(), copy = PikoCopy(locale);
        await t.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2),
              ),
              child: AiPage(
                service: SqliteAiService(f.db, enabled: true),
                provider: p,
                collectionId: f.owner.id,
                collectionName: 'Synthetic pilot',
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final before = await stored(f.db),
            goal = find.byKey(const ValueKey('ai-goal'));
        await t.ensureVisible(goal);
        await t.enterText(goal, 'Hotel B1');
        await t.pumpAndSettle();
        expect(p.events, isEmpty);
        expect(p.calls, isEmpty);
        await tapVisible(
          t,
          find.byWidgetPredicate(
            (w) => w is PikoCheckbox && w.label == copy.text('ai.consent'),
          ),
        );
        expect(
          t
              .widget<PikoButton>(find.byKey(const ValueKey('ai-start')))
              .onPressed,
          isNull,
        );
        await tapVisible(t, find.byKey(const ValueKey('ai-pilot-notice')));
        expect(p.calls, isEmpty);
        await tapVisible(t, find.byKey(const ValueKey('ai-pilot-consent')));
        await tapVisible(t, find.byWidgetPredicate((w)=>w is PikoIconButton && w.semanticLabel==copy.text('common.close')));
        await tapVisible(t, find.byKey(const ValueKey('ai-start')));
        expect(
          t.getTopLeft(find.byKey(const ValueKey('ai-feedback'))).dy,
          greaterThan(
            t.getTopLeft(find.byKey(const ValueKey('ai-select-proposal'))).dy,
          ),
          reason: 'Read the generated content before optional feedback',
        );
        await tapVisible(t, find.byKey(const ValueKey('ai-select-proposal')));
        final refine = find.byKey(const ValueKey('ai-refinement'));
        await t.ensureVisible(refine);
        await t.enterText(refine, 'Fewer words; correct spelling');
        await t.pumpAndSettle();
        p.fail = true;
        await tapVisible(t, find.byKey(const ValueKey('ai-refine')));
        expect(find.text('to learn — lernen'), findsOneWidget);
        expect(
          t
              .widget<PikoCheckbox>(
                find.byKey(const ValueKey('ai-select-proposal')),
              )
              .value,
          true,
        );
        p.fail = false;
        p.delay = true;
        await tapVisible(t, find.byKey(const ValueKey('ai-regenerate')));
        await tapVisible(t, find.byKey(const ValueKey('ai-stop-waiting')));
        p.pending!.complete(envelope(p.calls.last, cards: [card('late')]));
        await t.pumpAndSettle();
        expect(find.text('to learn — lernen'), findsOneWidget);
        expect(find.byKey(const ValueKey('ai-select-late')), findsNothing);
        p.delay = false;
        await tapVisible(t, find.byKey(const ValueKey('ai-refine')));
        expect(find.text('to read — lesen'), findsOneWidget);
        expect(
          t
              .widget<PikoButton>(find.byKey(const ValueKey('ai-apply')))
              .onPressed,
          isNull,
        );
        await tapVisible(t, find.byKey(const ValueKey('ai-keep-previous')));
        expect(find.text('to learn — lernen'), findsOneWidget);
        await tapVisible(t, find.byKey(const ValueKey('ai-regenerate')));
        await tapVisible(t, find.byKey(const ValueKey('ai-use-replacement')));
        expect(
          t
              .widget<PikoCheckbox>(
                find.byKey(const ValueKey('ai-select-proposal')),
              )
              .value,
          false,
        );
        expect(await stored(f.db), before);
        await tapVisible(t, find.byKey(const ValueKey('ai-select-proposal')));
        await tapVisible(t, find.byKey(const ValueKey('ai-apply')));
        expect(p.events.where((e) => e == 'adoption').length, 1);
        expect(t.takeException(), isNull);
        // A subsequent withdrawal removes service access, while the saved app data stays.
        final saved = await stored(f.db);
        await tapVisible(t, find.byWidgetPredicate((w)=>w is PikoButton && w.label==copy.text('ai.accessSettings')));
        await tapVisible(t, find.byKey(const ValueKey('ai-pilot-withdraw')));
        expect(p.withdrawn, true);
        expect(await stored(f.db), saved);
        expect(t.takeException(), isNull);
      },
    );
  }
}
