import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/ai/ai_page.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:piko/ui/components/piko_preference_picker.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/ai_service_test.dart' show envelope, card;
import '../data/statistics_test.dart' show stored;

class FakeProvider implements AiProvider {
  int calls = 0;
  bool fail = false;
  bool partial = false;
  AiRequest? last;
  @override
  Future<Map<String, Object?>> generate(AiRequest r) async {
    calls++;
    last = r;
    if (fail) throw AiFailure.network;
    if (r.action == AiAction.review) return envelope(r);
    return envelope(r, cards: [card('new-card')], complete: !partial);
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
            const Duration(milliseconds: 200)) {
          break;
        }
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

void main({bool nativeViewport = false}) {
  testWidgets(
    'review filters include inactive matches, reset per visit and keep saved level',
    (t) async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.collections.setLevel(id: f.owner.id, level: 'B2');
      final categories = SqliteCategoriesRepository(f.db);
      final group = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'My filter',
        mode: CategoryMode.multiple,
      );
      final value = await categories.createValue(
        dimensionId: group.id,
        name: 'Included',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          group.id: {value.id},
        },
      );
      final inactive = await f.vocabulary.createWithContent(
        collectionId: f.owner.id,
        targetText: 'Inactive',
        nativeText: 'Inaktiv',
        assignments: {
          group.id: {value.id},
        },
        content: const VocabularyContent(),
        active: false,
      );
      await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Other',
        nativeText: 'Andere',
      );
      final p = FakeProvider(), copy = PikoCopy('en');
      Widget page(int visit) => PikoApp(
        home: AiPage(
          key: ValueKey(visit),
          service: SqliteAiService(f.db, enabled: true),
          provider: p,
          collectionId: f.owner.id,
          collectionName: 'Synthetic',
          initialAction: AiAction.review,
          categoriesRepository: categories,
        ),
      );
      Future<void> consent() async {
        await t.pumpAndSettle();
        await tapVisible(t, find.byKey(const ValueKey('ai-consent')));
        await tapVisible(
          t,
          find.byWidgetPredicate(
            (w) =>
                w is PikoIconButton &&
                w.semanticLabel == copy.text('common.close'),
          ),
        );
      }

      await t.pumpWidget(page(1));
      await consent();
      expect(find.text('${copy.text('ai.reviewCount')}: 3'), findsOneWidget);
      final levelPicker = find.byWidgetPredicate(
        (w) =>
            w is PikoPreferencePicker<String> &&
            w.label == copy.text('collection.level'),
      );
      expect(t.widget<PikoPreferencePicker<String>>(levelPicker).value, 'B2');
      t.widget<PikoPreferencePicker<String>>(levelPicker).onChanged!('C1');
      await t.pumpAndSettle();
      expect(
        (await (f.db.select(
          f.db.collections,
        )..where((row) => row.id.equals(f.owner.id))).getSingle()).level,
        'B2',
      );
      expect(find.text('One'), findsNothing);
      expect(find.text('Inactive'), findsNothing);
      await tapVisible(
        t,
        find.widgetWithText(PikoButton, copy.text('action.filters')),
      );
      expect(
        find.byKey(const ValueKey('filter-values-scroll')),
        findsOneWidget,
      );
      await tapVisible(t, find.byKey(ValueKey('filter-value-${value.id}')));
      await tapVisible(
        t,
        find.widgetWithText(PikoButton, copy.text('r2.apply')),
      );
      expect(find.text('${copy.text('ai.reviewCount')}: 2'), findsOneWidget);
      await tapVisible(t, find.byKey(const ValueKey('ai-start')));
      expect(p.last!.snapshot.entries.map((e) => e.record.id).toSet(), {
        f.entry.id,
        inactive.id,
      });
      expect(p.last!.options!.level, 'C1');
      await t.pumpWidget(page(2));
      await consent();
      expect(find.text('${copy.text('ai.reviewCount')}: 3'), findsOneWidget);
      expect(t.widget<PikoPreferencePicker<String>>(levelPicker).value, 'B2');
      expect(p.calls, 1);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'comprehensive portions require disposition and another explicit paid start',
    (t) async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = FakeProvider()..partial = true, copy = PikoCopy('en');
      await t.pumpWidget(
        PikoApp(
          home: AiPage(
            service: SqliteAiService(f.db, enabled: true),
            provider: p,
            collectionId: f.owner.id,
            collectionName: 'Synthetic',
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapVisible(t, find.byKey(const ValueKey('ai-consent')));
      await tapVisible(
        t,
        find.byWidgetPredicate(
          (w) =>
              w is PikoIconButton &&
              w.semanticLabel == copy.text('common.close'),
        ),
      );
      t
          .widget<PikoPreferencePicker<String>>(
            find.byWidgetPredicate(
              (w) =>
                  w is PikoPreferencePicker<String> &&
                  w.label == copy.text('ai.action'),
            ),
          )
          .onChanged!('comprehensive');
      await t.pumpAndSettle();
      t
          .widget<PikoPreferencePicker<String>>(
            find.byWidgetPredicate(
              (w) =>
                  w is PikoPreferencePicker<String> &&
                  w.label == copy.text('ai.targetLevel'),
            ),
          )
          .onChanged!('B1');
      await t.pumpAndSettle();
      final before = await stored(f.db);
      await tapVisible(t, find.byKey(const ValueKey('ai-start')));
      expect(p.calls, 1);
      expect(p.last!.comprehensiveLevel, isTrue);
      expect(p.last!.options!.level, 'A1');
      expect(p.last!.goal, isEmpty);
      expect(find.byKey(const ValueKey('ai-continue')), findsNothing);
      expect(find.text(copy.text('ai.anotherPortion')), findsNothing);
      await tapVisible(
        t,
        find.widgetWithText(PikoButton, copy.text('ai.discard')),
      );
      expect(p.calls, 1);
      expect(await stored(f.db), before);
      await tapVisible(
        t,
        find.widgetWithText(PikoButton, copy.text('ai.anotherPortion')),
      );
      expect(p.calls, 1);
      await tapVisible(
        t,
        find.widgetWithText(PikoButton, copy.text('ai.nextLevel')),
      );
      expect(find.text(copy.text('ai.anotherPortion')), findsNothing);
      expect(find.text(copy.text('ai.nextLevel')), findsNothing);
      await tapVisible(t, find.byKey(const ValueKey('ai-start')));
      expect(p.calls, 2);
      expect(p.last!.options!.level, 'A2');
      expect(await stored(f.db), before);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );
  for (final locale in ['en', 'de']) {
    testWidgets(
      'AI $locale 320dp/200% explicit preview/selective apply and no secret error fallback',
      (t) async {
        if (!nativeViewport) {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(320, 800);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.view.resetPhysicalSize);
        }
        final f = Fixture();
        await f.initialize();
        addTearDown(f.db.close);
        final p = FakeProvider(), copy = PikoCopy(locale);
        await t.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    nativeViewport && locale == 'en' ? 1 : 2,
                  ),
                ),
                child: AiPage(
                  service: SqliteAiService(f.db, enabled: true),
                  provider: p,
                  collectionId: f.owner.id,
                  collectionName: 'Synthetic',
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final before = await stored(f.db);
        final consent = find.byWidgetPredicate(
          (w) => w is PikoCheckbox && w.label == copy.text('ai.consent'),
        );
        await tapVisible(t, consent);
        await tapVisible(
          t,
          find.byWidgetPredicate(
            (w) =>
                w is PikoIconButton &&
                w.semanticLabel == copy.text('common.close'),
          ),
        );
        final goal = find.byKey(const ValueKey('ai-goal'));
        await t.ensureVisible(goal);
        await t.enterText(goal, 'Hotel B1');
        await t.pumpAndSettle();
        expect(p.calls, 0);
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
