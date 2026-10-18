import 'dart:async';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../support/collection_deletion_fixture.dart';

class RenameRepository implements CollectionsRepository {
  RenameRepository(this.real);
  final CollectionsRepository real;
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;
  @override
  Future<CollectionRecord> rename({
    required String id,
    required String name,
  }) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('Name storage failed');
    return real.rename(id: id, name: name);
  }

  @override
  Future<void> delete(String id) => real.delete(id);
  @override
  Stream<List<CollectionRecord>> watchAll() => real.watchAll();
  @override
  Stream<CollectionRecord?> watchById(String id) => real.watchById(id);
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => real.create(
    name: name,
    targetLanguage: targetLanguage,
    nativeLanguage: nativeLanguage,
  );
}

class ClosingNameDatabase extends PikoDatabase {
  ClosingNameDatabase()
    : super(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
  int closeCalls = 0;
  final closed = Completer<void>();
  List<String> finalNames = [];
  @override
  Future<void> close() async {
    closeCalls++;
    finalNames = (await select(
      collections,
    ).get()).map((row) => row.name).toList();
    await super.close();
    closed.complete();
  }
}

final rename = find.byKey(const ValueKey('collection-rename'));
final name = find.byKey(const ValueKey('collection-name'));
final save = find.byKey(const ValueKey('collection-name-save'));
final cancel = find.byKey(const ValueKey('collection-name-cancel'));
Finder button(String label) =>
    find.byWidgetPredicate((w) => w is PikoButton && w.label == label);
Future<void> flush(WidgetTester tester, CollectionDeletionFixture f) async {
  await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

class RenameHarness {
  RenameHarness(this.f) : repository = RenameRepository(f.collections);
  final CollectionDeletionFixture f;
  final RenameRepository repository;
  final locale = ValueNotifier('en');
  late final identity = ValueNotifier(f.owner.id);
  final pending = <Future<void>>[];
  int entriesOpened = 0;
  void register(Future<void> work) {
    pending.add(work.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  }

  late final detail = ValueListenableBuilder<String>(
    valueListenable: identity,
    builder: (_, id, _) => CollectionDetail(
      repository: repository,
      collectionId: id,
      vocabularyRepository: f.repository,
      onPendingVocabularyWrites: register,
      entrySessionFactory: (_) {
        entriesOpened++;
        throw StateError(
          'Entry route should be disabled while rename is pending',
        );
      },
    ),
  );
  Future<void> mount(
    WidgetTester tester, {
    double width = 760,
    double scale = 1,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      if (repository.gate != null && !repository.gate!.isCompleted) {
        repository.gate!.complete();
      }
      for (final gate in f.repository.updateGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      await flush(tester, f);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      identity.dispose();
      locale.dispose();
      await tester.runAsync(f.dispose);
    });
    await tester.pumpWidget(
      ValueListenableBuilder<String>(
        valueListenable: locale,
        builder: (_, language, _) => PikoApp(
          locale: Locale(language),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: detail,
            ),
          ),
        ),
      ),
    );
    await flush(tester, f);
  }
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language rename keyboard, localized semantics, empty validation, cancel and trimmed duplicate save',
      (tester) async {
        final f = CollectionDeletionFixture();
        await tester.runAsync(f.initialize);
        await tester.runAsync(
          () => f.collections.create(
            name: 'Shared',
            targetLanguage: f.owner.targetLanguage,
            nativeLanguage: f.owner.nativeLanguage,
          ),
        );
        final h = RenameHarness(f)..locale.value = language;
        await h.mount(tester);
        final semantics = tester.ensureSemantics();
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(
              language == 'en' ? 'Rename collection' : 'Sammlung umbenennen',
            ),
          ),
          matchesSemantics(
            label: language == 'en'
                ? 'Rename collection'
                : 'Sammlung umbenennen',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        await tester.tap(rename);
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(name);
        expect(field.focusNode!.hasFocus, isTrue);
        expect(
          field.controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5),
        );
        expect(
          find.bySemanticsLabel(
            language == 'en' ? 'Collection name' : 'Name der Sammlung',
          ),
          findsOneWidget,
        );
        for (final action in [save, cancel]) {
          expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        }
        expect(
          tester.widget<PikoIconButton>(save).semanticLabel,
          language == 'en' ? 'Save name' : 'Namen speichern',
        );
        expect(
          tester.widget<PikoIconButton>(cancel).semanticLabel,
          language == 'en' ? 'Cancel' : 'Abbrechen',
        );
        await tester.enterText(name, '   ');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(h.repository.calls, 0);
        expect(
          find.text(
            language == 'en'
                ? 'Enter a collection name.'
                : 'Gib einen Namen für die Sammlung ein.',
          ),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(name, findsNothing);
        expect(h.repository.calls, 0);
        expect(
          tester.widget<PikoIconButton>(rename).focusNode!.hasFocus,
          isTrue,
        );
        await tester.tap(rename);
        await tester.pumpAndSettle();
        await tester.enterText(name, 'Unused');
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(h.repository.calls, 0);
        expect(find.text('Words'), findsOneWidget);
        await tester.tap(rename);
        await tester.pumpAndSettle();
        await tester.enterText(name, '  Shared  ');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await flush(tester, f);
        expect(h.repository.calls, 1);
        expect(name, findsNothing);
        expect(find.text('Shared'), findsOneWidget);
        expect(
          tester.widget<PikoIconButton>(rename).focusNode!.hasFocus,
          isTrue,
        );
        expect(
          (await tester.runAsync(
            () => f.collections.watchById(f.owner.id).first,
          ))!.name,
          'Shared',
        );
        expect(
          (await tester.runAsync(
            () => f.real.watchByCollection(f.owner.id).first,
          ))!.length,
          3,
        );
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'pending save is single flight; failed storage retains raw selection and refocuses for retry',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final h = RenameHarness(f);
      await h.mount(tester);
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.enterText(name, '  Retain raw  ');
      final field = tester.widget<TextField>(name),
          controller = tester.widget<TextField>(name).controller!;
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 8,
      );
      final original = controller.value;
      final submit = tester.widget<PikoIconButton>(save).onPressed!;
      final abandon = tester.widget<PikoIconButton>(cancel).onPressed!;
      h.repository.gate = Completer<void>();
      h.repository.fail = true;
      submit();
      submit();
      abandon();
      await tester.pumpAndSettle();
      expect(h.repository.calls, 1);
      expect(h.pending, hasLength(1));
      expect(tester.widget<TextField>(name).enabled, isFalse);
      expect(tester.widget<PikoIconButton>(cancel).onPressed, isNull);
      expect(
        tester
            .widget<PikoIconButton>(
              find.byKey(const ValueKey('collection-menu')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.widget<PikoButton>(button('New')).onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(name, findsOneWidget);
      h.repository.gate!.complete();
      await flush(tester, f);
      expect(
        identical(tester.widget<TextField>(name).controller, controller),
        isTrue,
      );
      expect(controller.value, original);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        find.text("Couldn't save this name. Please try again."),
        findsOneWidget,
      );
      h.locale.value = 'de';
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Dieser Name konnte nicht gespeichert werden. Bitte versuche es erneut.',
        ),
        findsOneWidget,
      );
      expect(controller.value, original);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        (await tester.runAsync(
          () => f.collections.watchById(f.owner.id).first,
        ))!.name,
        'Words',
      );
      h.repository.gate = null;
      h.repository.fail = false;
      await tester.tap(save);
      await flush(tester, f);
      expect(find.text('Retain raw'), findsOneWidget);
      expect(h.repository.calls, 2);
      expect(h.entriesOpened, 0);
    },
  );

  testWidgets(
    'real SQLite rename failure rolls back and check retries unchanged input',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final h = RenameHarness(f);
      await h.mount(tester);
      await tester.runAsync(
        () => f.db.customStatement(
          "CREATE TRIGGER reject_rename AFTER UPDATE OF name ON collections BEGIN SELECT RAISE(FAIL, 'blocked'); END",
        ),
      );
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.enterText(name, '  Retry  ');
      await tester.tap(save);
      await flush(tester, f);
      expect(
        find.text("Couldn't save this name. Please try again."),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(name).controller!.text, '  Retry  ');
      expect(
        (await tester.runAsync(
          () => f.collections.watchById(f.owner.id).first,
        ))!.name,
        'Words',
      );
      await tester.runAsync(
        () => f.db.customStatement('DROP TRIGGER reject_rename'),
      );
      await tester.tap(save);
      await flush(tester, f);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'locale and metadata updates preserve each active name and vocabulary editor',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final h = RenameHarness(f);
      await h.mount(tester);
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.enterText(name, '  Own draft  ');
      final controller = tester.widget<TextField>(name).controller!;
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 5,
      );
      final raw = controller.value;
      h.locale.value = 'de';
      await tester.runAsync(
        () => f.collections.rename(id: f.owner.id, name: 'External metadata'),
      );
      await flush(tester, f);
      expect(controller.value, raw);
      expect(tester.widget<TextField>(name).controller, same(controller));
      await tester.tap(save);
      await flush(tester, f);
      expect(find.text('Own draft'), findsOneWidget);
      final id = f.entries.first.id;
      await tester.tap(find.byKey(ValueKey('vocabulary-$id')));
      await flush(tester, f);
      final target = find.descendant(
        of: find.byKey(ValueKey('inline-$id-target')),
        matching: find.byType(TextField),
      );
      final vocabularyController = tester.widget<TextField>(target).controller!;
      f.repository.updateGates[id] = Completer<void>();
      await tester.enterText(target, 'Pending word');
      await tester.pump();
      h.locale.value = 'en';
      await tester.runAsync(
        () => f.collections.rename(id: f.owner.id, name: 'Updated metadata'),
      );
      await flush(tester, f);
      expect(
        tester.widget<TextField>(target).controller,
        same(vocabularyController),
      );
      expect(vocabularyController.text, 'Pending word');
      f.repository.updateGates[id]!.complete();
      await flush(tester, f);
      expect(
        (await tester.runAsync(() => f.real.watchById(id).first))!.targetText,
        'Pending word',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacement ignores stale save results and focus; accepted old identity still drains',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final other = (await tester.runAsync(
        () => f.collections.create(
          name: 'Other',
          targetLanguage: f.owner.targetLanguage,
          nativeLanguage: f.owner.nativeLanguage,
        ),
      ))!;
      final h = RenameHarness(f);
      await h.mount(tester);
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.enterText(name, 'Accepted old');
      h.repository.gate = Completer<void>();
      await tester.tap(save);
      await tester.pumpAndSettle();
      h.identity.value = other.id;
      await flush(tester, f);
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.enterText(name, 'New raw');
      final newController = tester.widget<TextField>(name).controller!;
      h.repository.gate!.complete();
      await flush(tester, f);
      expect(newController.text, 'New raw');
      expect(name, findsOneWidget);
      expect(tester.widget<TextField>(name).focusNode!.hasFocus, isTrue);
      expect(
        (await tester.runAsync(
          () => f.collections.watchById(f.owner.id).first,
        ))!.name,
        'Accepted old',
      );
      expect(
        (await tester.runAsync(
          () => f.collections.watchById(other.id).first,
        ))!.name,
        'Other',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final outcome in ['success', 'failure']) {
    testWidgets(
      'covered route and disposal suppress late $outcome focus/navigation while accepted rename drains',
      (tester) async {
        final f = CollectionDeletionFixture();
        await tester.runAsync(f.initialize);
        final h = RenameHarness(f);
        await h.mount(tester);
        await tester.tap(rename);
        await tester.pumpAndSettle();
        await tester.enterText(name, 'Accepted');
        h.repository.gate = Completer<void>();
        h.repository.fail = outcome == 'failure';
        await tester.tap(save);
        await tester.pumpAndSettle();
        final owner = ModalRoute.of(
          tester.element(find.byType(CollectionDetail)),
        )!;
        final navigator = owner.navigator!, coverFocus = FocusNode();
        addTearDown(coverFocus.dispose);
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: TextField(focusNode: coverFocus, autofocus: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(coverFocus.hasFocus, isTrue);
        h.repository.gate!.complete();
        await flush(tester, f);
        expect(coverFocus.hasFocus, isTrue);
        expect(navigator.canPop(), isTrue);
        navigator.removeRoute(owner);
        await tester.pumpAndSettle();
        expect(coverFocus.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
        expect(h.pending, hasLength(1));
        await tester.runAsync(() => Future.wait(h.pending));
      },
    );
  }

  testWidgets(
    'dispose during pending rename retains registered work without late controller or focus effects',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final h = RenameHarness(f);
      await h.mount(tester);
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.enterText(name, 'After disposal');
      h.repository.gate = Completer<void>();
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(h.pending, hasLength(1));
      h.repository.gate!.complete();
      await tester.runAsync(() => Future.wait(h.pending));
      await tester.pump();
      expect(
        (await tester.runAsync(
          () => f.collections.watchById(f.owner.id).first,
        ))!.name,
        'After disposal',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '392px German 200% long title wraps; menu remains right and rename targets stay keyboard reachable',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final long = 'SehrLangeSammlungOhneLeerzeichen' * 5;
      await tester.runAsync(
        () => f.collections.rename(id: f.owner.id, name: long),
      );
      final h = RenameHarness(f)..locale.value = 'de';
      await h.mount(tester, width: 392, scale: 2, keyboard: 300);
      final deletion = find.byKey(const ValueKey('collection-menu'));
      expect(tester.getRect(deletion).right, closeTo(392 - 18, 0.1));
      expect(
        tester.getRect(deletion).left,
        greaterThan(
          tester
              .getRect(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is PikoIconButton &&
                      widget.semanticLabel == 'Zurück',
                ),
              )
              .left,
        ),
      );
      expect(tester.getSize(find.text(long)).height, greaterThan(44));
      await tester.ensureVisible(rename);
      await tester.pumpAndSettle();
      await tester.tap(rename);
      await tester.pumpAndSettle();
      for (final control in [name, save, cancel]) {
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        expect(tester.getRect(control).right, lessThanOrEqualTo(392));
        expect(tester.getRect(control).bottom, lessThanOrEqualTo(700));
        expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual runtime close waits for accepted rename after complete UI disposal',
    (tester) async {
      final db = ClosingNameDatabase();
      final collections = SqliteCollectionsRepository(db);
      final owner = (await tester.runAsync(
        () => collections.create(
          name: 'Before',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        ),
      ))!;
      await tester.pumpWidget(
        PikoApp(home: PikoRuntime(databaseFactory: () => db)),
      );
      await tester.pumpAndSettle();
      final home = tester.widget<CollectionsHome>(find.byType(CollectionsHome));
      final repository = RenameRepository(collections)
        ..gate = Completer<void>();
      final navigator = Navigator.of(
        tester.element(find.byType(CollectionsHome)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => CollectionDetail(
              repository: repository,
              collectionId: owner.id,
              onPendingVocabularyWrites: home.onPendingVocabularyWrites,
            ),
          ),
        ),
      );
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.enterText(name, 'Drained name');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(db.closeCalls, 0);
      repository.gate!.complete();
      await tester.runAsync(() => db.closed.future);
      await tester.pump();
      expect(db.closeCalls, 1);
      expect(db.finalNames, ['Drained name']);
      expect(tester.takeException(), isNull);
    },
  );
}
