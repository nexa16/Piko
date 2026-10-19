import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/features/ai/ai_page.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/ai_service_test.dart' show envelope, card;
import '../data/statistics_test.dart' show stored;

class FakeProvider implements AiProvider {
  int calls = 0;
  bool fail = false;
  @override
  Future<Map<String, Object?>> generate(AiRequest r) async {
    calls++;
    if (fail) throw AiFailure.network;
    return envelope(r, cards: [card('new-card')]);
  }

  @override
  void close() {}
}

Future<void> tapVisible(WidgetTester t, Finder f) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  if (t.binding is LiveTestWidgetsFlutterBinding) {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    DateTime? stable;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await t.pump();
      if (t.view.viewInsets.bottom == 0) {
        stable ??= DateTime.now();
        if (DateTime.now().difference(stable) >=
            const Duration(milliseconds: 200))
          break;
      } else {
        stable = null;
      }
    }
    expect(
      t.view.viewInsets.bottom,
      0,
      reason: 'Native IME hidden before revealing a control',
    );
  }
  await Scrollable.ensureVisible(t.element(f), alignment: .5);
  await t.pumpAndSettle();
  expect(f.hitTestable(), findsOneWidget);
  await t.tap(f, warnIfMissed: true);
  await t.pumpAndSettle();
}

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      'AI $locale 320dp/200% explicit preview/selective apply and no secret error fallback',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(320, 800);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final p = FakeProvider(), copy = PikoCopy(locale);
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
                collectionName: 'Synthetic',
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final before = await stored(f.db);
        final goal = find.byKey(const ValueKey('ai-goal'));
        await t.ensureVisible(goal);
        await t.enterText(goal, 'Hotel B1');
        await t.pumpAndSettle();
        expect(p.calls, 0);
        final consent = find.byWidgetPredicate(
          (w) => w is PikoCheckbox && w.label == copy.text('ai.consent'),
        );
        await tapVisible(t, consent);
        p.fail = true;
        await tapVisible(t, find.byKey(const ValueKey('ai-start')));
        expect(find.text(copy.text('ai.error.network')), findsOneWidget);
        expect((t.widget<TextField>(goal)).controller!.text, 'Hotel B1');
        expect(await stored(f.db), before);
        p.fail = false;
        await tapVisible(t, find.byKey(const ValueKey('ai-start')));
        expect(p.calls, 2);
        expect(await stored(f.db), before);
        final apply = find.byKey(const ValueKey('ai-apply'));
        expect(t.widget<PikoButton>(apply).onPressed, isNull);
        final choice = find.byKey(const ValueKey('ai-select-new-card'));
        await tapVisible(t, choice);
        expect(t.widget<PikoButton>(apply).onPressed, isNotNull);
        await t.tap(apply);
        await t.pumpAndSettle();
        expect(find.text(copy.text('ai.applied')), findsOneWidget);
        expect(
          (await f.vocabulary.watchByCollection(f.owner.id).first).length,
          2,
        );
        expect(t.takeException(), isNull);
        await t.pump();
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'disabled direct AI route shows no controls and cannot dispatch',
    (t) async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = FakeProvider();
      await t.pumpWidget(
        PikoApp(
          home: AiPage(
            service: SqliteAiService(f.db, enabled: false),
            provider: p,
            collectionId: f.owner.id,
            collectionName: 'Synthetic',
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-start')), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(p.calls, 0);
    },
  );
}
