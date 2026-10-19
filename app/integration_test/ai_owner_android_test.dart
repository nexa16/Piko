import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/features/ai/ai_page.dart';
import 'package:piko/platform/ai_credential_vault.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import '../test/ui/ai_page_test.dart' as page;
import '../test/ui/ai_related_hints_test.dart' as hints;
import '../test/features/ai_entry_session_test.dart' as joint;
import '../test/features/ai_continuation_test.dart' as portions;
import 'support/round2_catalogue_fixture.dart' show CatalogueConfiguration;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  page.main();
  hints.main();
  joint.main();
  portions.main();
  testWidgets(
    'owner AI actual Android vault, compile gate, native IME/Back and capture',
    (t) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/ai-owner-${config.runId}');
      if (await dir.exists()) throw StateError('Unique owned run required');
      await dir.create();
      var passed = false;
      final states = <String>[];
      Future<void> phase(String name, {Offset? at}) async {
        final binding = t.binding as LiveTestWidgetsFlutterBinding;
        final old = binding.shouldPropagateDevicePointerEvents,
            policy = binding.framePolicy;
        binding.shouldPropagateDevicePointerEvents = true;
        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
        try {
          final ratio = View.of(
            t.element(find.byType(AiPage)),
          ).devicePixelRatio;
          await File('${dir.path}/phase.json').writeAsString(
            jsonEncode({
              'phase': name,
              'run': config.runId,
              if (at != null) 'x': (at.dx * ratio).round(),
              if (at != null) 'y': (at.dy * ratio).round(),
            }),
            flush: true,
          );
          final ack = File('${dir.path}/ack-$name'),
              deadline = DateTime.now().add(const Duration(seconds: 45));
          while (!await ack.exists() && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await t.pump();
          }
          expect(
            await ack.exists(),
            isTrue,
            reason: 'Native $name acknowledgment',
          );
          states.add(name);
        } finally {
          binding.shouldPropagateDevicePointerEvents = old;
          binding.framePolicy = policy;
        }
      }

      try {
        final vault = AndroidAiCredentialVault(
          namespace: 'test-${config.runId}',
        );
        expect(await vault.read(), isNull);
        await vault.write('synthetic-session-${config.runId}');
        expect(await vault.read(), 'synthetic-session-${config.runId}');
        await vault.write('synthetic-replacement-${config.runId}');
        expect(await vault.read(), 'synthetic-replacement-${config.runId}');
        await vault.delete();
        expect(await vault.read(), isNull);
        await expectLater(
          const AndroidAiCredentialVault(
            namespace: 'invalid-test-space',
          ).read(),
          throwsA(isA<PlatformException>()),
        );
        states.add('native-keystore-roundtrip-own-namespace-only');
        final f = Fixture();
        await f.initialize();
        final provider = page.FakeProvider();
        await t.pumpWidget(
          PikoApp(
            locale: Locale(config.locale),
            home: PikoRuntime(
              databaseFactory: () => f.db,
              aiProvider: provider,
            ),
          ),
        );
        await t.pumpAndSettle();
        // The ordinary runtime must not send background work in either build.
        expect(provider.calls, 0);
        if (!pikoAiEnabled) {
          expect(find.byKey(const ValueKey('ai-start')), findsNothing);
          states.add('compile-gate-off-runtime-no-dispatch');
        } else {
          states.add('compile-gate-on-runtime-no-background-dispatch');
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        final g = Fixture();
        await g.initialize();
        await t.pumpWidget(
          PikoApp(
            locale: Locale(config.locale),
            home: AiPage(
              service: SqliteAiService(g.db, enabled: pikoAiEnabled),
              provider: provider,
              collectionId: g.owner.id,
              collectionName: 'Synthetic Android',
            ),
          ),
        );
        await t.pumpAndSettle();
        if (pikoAiEnabled) {
          final goal = find.byKey(const ValueKey('ai-goal'));
          await t.ensureVisible(goal);
          await t.pumpAndSettle();
          await phase('ime-back', at: t.getCenter(goal));
          await t.pumpAndSettle();
          expect((t.widget<TextField>(goal)).controller!.text, 'Hotel');
          expect(find.byType(AiPage), findsOneWidget);
          expect(MediaQuery.viewInsetsOf(t.element(goal)).bottom, 0);
          expect(provider.calls, 0);
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
          t
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await t.pumpAndSettle();
          await phase('capture-ai-request');
          final copy = PikoCopy(config.locale);
          await page.tapVisible(
            t,
            find.byWidgetPredicate(
              (w) => w is PikoCheckbox && w.label == copy.text('ai.consent'),
            ),
          );
          await page.tapVisible(t, find.byKey(const ValueKey('ai-start')));
          expect(provider.calls, 1);
          await t.ensureVisible(
            find.byKey(const ValueKey('ai-select-new-card')),
          );
          await t.pumpAndSettle();
          await phase('capture-ai-preview');
        } else {
          expect(find.byType(TextField), findsNothing);
          expect(provider.calls, 0);
          await phase('capture-ai-off');
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        await g.db.close();
        expect(t.takeException(), isNull);
        passed = true;
      } finally {
        await File('${dir.path}/manifest.json').writeAsString(
          jsonEncode({
            'passed': passed,
            'sourceCommit': config.commit,
            'locale': config.locale,
            'gateEnabled': pikoAiEnabled,
            'normalDatabaseOpened': false,
            'liveAuthOrProviderCalls': 0,
            'states': states,
          }),
          flush: true,
        );
      }
    },
  );
}
