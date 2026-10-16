import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/settings/app_language_controller.dart';
import 'package:piko/features/settings/settings_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'package:piko/ui/piko_theme.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../features/app_language_controller_test.dart' show HeldSettings;
import 'review_launch_test.dart' show ClosingDatabase;

Finder button(String key, [String locale = 'en']) =>
    find.widgetWithText(PikoButton, PikoCopy(locale).text(key));
final dropdown = find.byType(PikoDropdown<Locale>);

class Harness {
  final db = ClosingDatabase();
  late final f = Fixture(database: db);
  late final repository = HeldSettings(SqliteSettingsRepository(db));
  final first = InterfaceLocaleController(const Locale('de'));
  final second = InterfaceLocaleController(const Locale('de'));
  late final runtime = PikoRuntime(
    databaseFactory: () => db,
    settingsRepositoryFactory: (_) => repository,
  );
  InterfaceLocaleController? selected;
  Future<void> mount(WidgetTester tester, {bool wait = true}) async {
    selected ??= first;
    await tester.pumpWidget(PikoApp(localeController: selected, home: runtime));
    await tester.pump();
    if (wait) {
      while (find.byType(CollectionsHome).evaluate().isEmpty) {
        await flush(tester);
      }
    }
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();
  }

  Future<AppLanguageController> open(WidgetTester tester) async {
    await tester.tap(button('nav.settings', selected!.value.languageCode));
    await tester.pumpAndSettle();
    return tester
        .widget<SettingsRoute>(find.byType(SettingsRoute))
        .binding
        .value!;
  }

  Future<void> drain(
    WidgetTester tester,
    AppLanguageController controller,
  ) async {
    var done = false;
    unawaited(controller.awaitPending.then((_) => done = true));
    while (!done) {
      await flush(tester);
    }
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String name) async {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> cleanup(WidgetTester tester) async {
    if (repository.readGate?.isCompleted == false) {
      repository.readGate!.complete();
    }
    if (repository.writeGate?.isCompleted == false) {
      repository.writeGate!.complete();
    }
    if (db.closeCalls == 0) {
      await flush(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    // Pump fake-zone continuations before awaiting the native store close.
    while (!db.closed.isCompleted) {
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
    }
    first.dispose();
    second.dispose();
  }
}

void main() {
  testWidgets(
    'runtime loads retained locale before home; Settings is reachable right, live and language-only',
    (tester) async {
      final h = Harness();
      tester.view.physicalSize = const Size(392, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.runAsync(h.f.initialize);
        await tester.runAsync(() => h.repository.real.write('locale', 'de'));
        h.repository.readGate = Completer<void>();
        await h.mount(tester, wait: false);
        expect(find.byType(CollectionsHome), findsNothing);
        expect(
          find.text(const PikoCopy('de').text('settings.loading')),
          findsOneWidget,
        );
        h.repository.readGate!.complete();
        await h.flush(tester);
        while (find.byType(CollectionsHome).evaluate().isEmpty) {
          await h.flush(tester);
        }
        expect(h.first.value, const Locale('de'));
        final homeState = tester.state(find.byType(CollectionsHome));
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        final right = tester.getRect(button('nav.settings', 'de')).right;
        expect(
          right,
          closeTo(392 - pikoDesign.dimension('layout.mobilePadding'), .01),
        );
        final controller = await h.open(tester);
        expect(find.byType(PikoDropdown<Locale>), findsOneWidget);
        final options = tester.widget<PikoDropdown<Locale>>(dropdown).items;
        expect(options.map((option) => (option.child as Text).data), [
          'English',
          'Deutsch',
        ]);
        expect(find.byType(PikoHeading), findsOneWidget);
        await h.choose(tester, 'English');
        await h.drain(tester, controller);
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
          const Locale('en'),
        );
        expect(
          find.text(const PikoCopy('en').text('settings.language')),
          findsOneWidget,
        );
        expect(await tester.runAsync(() => h.repository.read('locale')), 'en');
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        await tester.tap(button('common.back'));
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(CollectionsHome)), same(homeState));
        expect(tester.takeException(), isNull);
      } finally {
        await h.cleanup(tester);
      }
    },
  );

  testWidgets(
    'bootstrap read failure exposes retry, not an empty home or missing preference',
    (tester) async {
      final h = Harness();
      h.repository.failRead = true;
      try {
        await h.mount(tester, wait: false);
        await h.flush(tester);
        expect(find.byType(CollectionsHome), findsNothing);
        expect(
          find.text(const PikoCopy('de').text('settings.loadFailed')),
          findsOneWidget,
        );
        h.repository.failRead = false;
        await tester.tap(button('action.retry', 'de'));
        await h.flush(tester);
        while (find.byType(CollectionsHome).evaluate().isEmpty) {
          await h.flush(tester);
        }
        expect(h.first.value, const Locale('en'));
        expect(tester.takeException(), isNull);
      } finally {
        await h.cleanup(tester);
      }
    },
  );

  testWidgets(
    'real SQLite failed save rolls visible locale back and retries same requested language',
    (tester) async {
      final h = Harness();
      try {
        await h.mount(tester);
        final controller = await h.open(tester);
        await tester.runAsync(
          () => h.db.customStatement(
            "CREATE TRIGGER reject_locale BEFORE INSERT ON app_settings WHEN NEW.key='locale' BEGIN SELECT RAISE(FAIL,'language save'); END",
          ),
        );
        await h.choose(tester, 'Deutsch');
        await h.drain(tester, controller);
        expect(h.first.value, const Locale('en'));
        expect(
          find.text(const PikoCopy('en').text('settings.saveFailed')),
          findsOneWidget,
        );
        await tester.runAsync(
          () => h.db.customStatement('DROP TRIGGER reject_locale'),
        );
        await tester.tap(button('action.retry'));
        await h.drain(tester, controller);
        expect(h.first.value, const Locale('de'));
        expect(await tester.runAsync(() => h.repository.read('locale')), 'de');
        expect(tester.takeException(), isNull);
      } finally {
        await h.cleanup(tester);
      }
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'open route rebind waits old admitted write ($fails), stale choice inert',
      (tester) async {
        final h = Harness();
        try {
          await h.mount(tester);
          final old = await h.open(tester);
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          final oldCallback = tester
              .widget<PikoDropdown<Locale>>(dropdown)
              .onChanged!;
          h.repository.writeGate = Completer<void>();
          h.repository.failWrite = fails;
          oldCallback(const Locale('de'));
          await tester.pumpAndSettle();
          expect(h.repository.writes, 1);
          expect(
            tester.widget<PikoDropdown<Locale>>(dropdown).onChanged,
            isNull,
          );
          oldCallback(const Locale('en'));
          expect(h.repository.writes, 1);
          h.selected = h.second;
          await h.mount(tester, wait: false);
          expect(find.byType(SettingsRoute), findsOneWidget);
          expect(dropdown, findsNothing);
          oldCallback(const Locale('de'));
          expect(h.repository.writes, 1);
          h.repository.writeGate!.complete();
          await h.drain(tester, old);
          final current = tester
              .widget<SettingsRoute>(find.byType(SettingsRoute))
              .binding
              .value!;
          await h.drain(tester, current);
          expect(current, isNot(same(old)));
          expect(h.second.value.languageCode, fails ? 'en' : 'de');
          expect(dropdown, findsOneWidget);
          expect(
            tester.state<NavigatorState>(find.byType(Navigator)),
            same(navigator),
          );
          h.first.value = const Locale('en'); // Injection remains caller-owned.
          expect(tester.takeException(), isNull);
        } finally {
          await h.cleanup(tester);
        }
      },
    );
  }

  testWidgets(
    'replacement read failure on open route reports loading error and actual Retry recovers',
    (tester) async {
      final h = Harness();
      try {
        await h.mount(tester);
        await h.open(tester);
        h.repository.failRead = true;
        h.selected = h.second;
        await h.mount(tester, wait: false);
        await h.flush(tester);
        expect(
          find.text(const PikoCopy('de').text('settings.loadFailed')),
          findsOneWidget,
        );
        expect(
          find.text(const PikoCopy('de').text('settings.saveFailed')),
          findsNothing,
        );
        expect(dropdown, findsNothing);
        h.repository.failRead = false;
        await tester.tap(button('action.retry', 'de'));
        await h.flush(tester);
        final current = tester
            .widget<SettingsRoute>(find.byType(SettingsRoute))
            .binding
            .value!;
        await h.drain(tester, current);
        expect(dropdown, findsOneWidget);
        expect(h.second.value, const Locale('en'));
        expect(tester.takeException(), isNull);
      } finally {
        await h.cleanup(tester);
      }
    },
  );

  testWidgets(
    'runtime shutdown drains admitted language write before closing SQLite',
    (tester) async {
      final h = Harness();
      try {
        await h.mount(tester);
        final controller = await h.open(tester);
        h.repository.writeGate = Completer<void>();
        tester.widget<PikoDropdown<Locale>>(dropdown).onChanged!(
          const Locale('de'),
        );
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(h.db.closeCalls, 0);
        h.repository.writeGate!.complete();
        var drained = false;
        unawaited(controller.awaitPending.then((_) => drained = true));
        while (!drained || !h.db.closed.isCompleted) {
          await tester.pump();
          await tester.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
          });
        }
        expect(h.db.closeCalls, 1);
        expect(h.repository.writes, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await h.cleanup(tester);
      }
    },
  );

  testWidgets(
    'rapid controller replacements keep transitive old write admission and stable route',
    (tester) async {
      final h = Harness();
      final third = InterfaceLocaleController();
      try {
        await h.mount(tester);
        final original = await h.open(tester);
        h.repository.writeGate = Completer<void>();
        tester.widget<PikoDropdown<Locale>>(dropdown).onChanged!(
          const Locale('de'),
        );
        await tester.pump();
        h.selected = h.second;
        await h.mount(tester, wait: false);
        h.selected = third;
        await h.mount(tester, wait: false);
        final current = tester
            .widget<SettingsRoute>(find.byType(SettingsRoute))
            .binding
            .value!;
        expect(current.ready, isFalse);
        expect(h.db.closeCalls, 0);
        h.repository.writeGate!.complete();
        await h.drain(tester, original);
        await h.drain(tester, current);
        expect(third.value, const Locale('de'));
        expect(dropdown, findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await h.cleanup(tester);
        third.dispose();
      }
    },
  );

  testWidgets(
    'live persisted language keeps actual inline raw draft and revealed review handle/Hard state',
    (tester) async {
      final h = Harness();
      try {
        await tester.runAsync(h.f.initialize);
        await h.mount(tester);
        final language = await h.open(tester);
        final binding = tester
            .widget<SettingsRoute>(find.byType(SettingsRoute))
            .binding;
        await tester.tap(button('common.back'));
        await tester.pumpAndSettle();
        final home = tester.widget<CollectionsHome>(
          find.byType(CollectionsHome),
        );
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => CollectionDetail(
                repository: home.repository,
                collectionId: h.f.owner.id,
                vocabularyRepository: home.vocabularyRepository,
                vocabularyMutationsFactory: home.vocabularyMutationsFactory,
                onPendingVocabularyWrites: home.onPendingVocabularyWrites,
                reviewSessionFactory: home.reviewSessionFactory,
                entrySessionFactory: home.entrySessionFactory,
              ),
            ),
          ),
        );
        await h.flush(tester);
        final vocabularyRow = find.byKey(
          ValueKey('vocabulary-${h.f.entry.id}'),
        );
        for (
          var pass = 0;
          pass < 20 && vocabularyRow.evaluate().isEmpty;
          pass++
        ) {
          await h.flush(tester);
        }
        expect(vocabularyRow, findsOneWidget);
        await tester.tap(vocabularyRow);
        await h.flush(tester);
        for (
          var pass = 0;
          pass < 20 && find.byType(TextField).evaluate().isEmpty;
          pass++
        ) {
          await h.flush(tester);
        }
        final field = find.descendant(
          of: find.byKey(ValueKey('inline-${h.f.entry.id}-target')),
          matching: find.byType(TextField),
        );
        final native = find.descendant(
          of: find.byKey(ValueKey('inline-${h.f.entry.id}-native')),
          matching: find.byType(TextField),
        );
        expect(field, findsOneWidget);
        expect(native, findsOneWidget);
        await tester.enterText(field, ' ');
        await tester.pumpAndSettle();
        final input = tester.widget<TextField>(field).controller!;
        input.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsRoute(binding: binding),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await h.choose(tester, 'Deutsch');
        await h.drain(tester, language);
        await tester.tap(button('common.back', 'de'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller, same(input));
        expect(input.text, ' ');
        expect(
          input.selection,
          const TextSelection(baseOffset: 0, extentOffset: 1),
        );
        expect(
          (await tester.runAsync(
            () => h.f.vocabulary.watchById(h.f.entry.id).first,
          ))!.targetText,
          'One',
        );
        navigator.pop();
        await tester.pumpAndSettle();
        final session = (await tester.runAsync(
          () => home.reviewSessionFactory!(
            h.f.owner.id,
            LearningDirection.targetToNative,
          ),
        ))!;
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => ReviewSessionRoute(
                collection: h.f.owner,
                session: session,
                vocabularyRepository: home.vocabularyRepository!,
              ),
            ),
          ),
        );
        await h.flush(tester);
        for (
          var pass = 0;
          pass < 20 && find.text('One').evaluate().isEmpty;
          pass++
        ) {
          await h.flush(tester);
        }
        expect(find.text('One'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('review-prompt')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PikoCheckbox));
        await tester.pumpAndSettle();
        final handle = session.current;
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsRoute(binding: binding),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await h.choose(tester, 'English');
        await h.drain(tester, language);
        await tester.tap(button('common.back'));
        await tester.pumpAndSettle();
        expect(session.current, same(handle));
        expect(session.hard, isTrue);
        expect(find.byKey(const ValueKey('review-grading')), findsOneWidget);
        expect(find.text('Eins'), findsOneWidget);
        expect(session.acceptedReviews, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await h.cleanup(tester);
      }
    },
  );
}
