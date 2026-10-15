import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/components/piko_field.dart';

const owner = CollectionRecord(
  id: 'owner',
  name: 'Entries',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);

class ScreenRepository implements VocabularyRepository {
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) => throw UnimplementedError(
    'Entry-stack fixture does not open inline editors.',
  );
  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) => throw UnimplementedError(
    'Entry-stack fixture does not discard inline edits.',
  );
  Completer<VocabularyRecord>? pending;
  bool failUpdate = false;
  Completer<VocabularyRecord>? pendingEdit;
  int sequence = 0;
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) async => pending != null
      ? await pending!.future
      : VocabularyRecord(
          id: 'entry-${sequence++}',
          collectionId: collectionId,
          targetText: targetText,
          nativeText: nativeText,
        );
  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) async {
    if (failUpdate) throw StateError('Write failed');
    if (pendingEdit != null) return pendingEdit!.future;
    return VocabularyRecord(
      id: id,
      collectionId: owner.id,
      targetText: targetText,
      nativeText: nativeText,
    );
  }

  @override
  Stream<List<VocabularyRecord>> watchByCollection(String id) =>
      Stream.value([]);
  @override
  Stream<VocabularyRecord?> watchById(String id) => Stream.value(null);
}

class NestedUserScroll extends UserScrollNotification {
  NestedUserScroll({
    required super.metrics,
    required super.context,
    required super.direction,
  });
  @override
  int get depth => 1;
}

class NestedScrollUpdate extends ScrollUpdateNotification {
  NestedScrollUpdate({
    required super.metrics,
    required super.context,
    required super.scrollDelta,
  });
  @override
  int get depth => 1;
}

Future<void> mount(
  WidgetTester tester,
  EntrySessionController session, {
  CollectionRecord collection = owner,
  InterfaceLocaleController? locale,
  bool reduced = false,
}) async {
  await tester.pumpWidget(
    PikoApp(
      localeController: locale,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: EntrySessionScreen(collection: collection, session: session),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> seed(EntrySessionController session, int count) async {
  for (var i = 0; i < count; i++) {
    session.setTargetText('Word $i');
    session.setNativeText('Wort $i');
    await session.confirmAndNext();
  }
}

Finder field(String id, String side) => find.descendant(
  of: find.byKey(ValueKey('$id-$side')),
  matching: find.byType(TextField),
);

Future<void> scrollTo(WidgetTester tester, String id) async {
  final viewport = tester.getRect(find.byKey(const ValueKey('entry-stack')));
  final card = tester.getRect(find.byKey(ValueKey('entry-card-$id')));
  await tester.dragFrom(
    Offset(viewport.left + 4, viewport.center.dy),
    Offset(0, viewport.center.dy - card.center.dy),
  );
  await tester.pumpAndSettle();
}

void clean(WidgetTester tester, EntrySessionController session) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    session.dispose();
  });
}

void main() {
  testWidgets(
    'session replacement mid-expansion resets anchors and permits fresh user navigation',
    (tester) async {
      final oldSession = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      final newSession = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      addTearDown(oldSession.dispose);
      clean(tester, newSession);
      await seed(oldSession, 3);
      await seed(newSession, 2);
      await mount(tester, oldSession);
      final id = oldSession.confirmedEntries.first.id;
      final viewport = tester.getRect(
        find.byKey(const ValueKey('entry-stack')),
      );
      final before = tester.getRect(find.byKey(ValueKey('entry-card-$id')));
      await tester.dragFrom(
        Offset(viewport.left + 4, viewport.center.dy),
        Offset(0, viewport.center.dy - before.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await mount(tester, newSession);
      expect(newSession.activeEntryId, isNull);
      await scrollTo(tester, newSession.confirmedEntries.first.id);
      expect(newSession.activeEntryId, newSession.confirmedEntries.first.id);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'old confirmation failure cannot attach to a replacement session',
    (tester) async {
      final repository = ScreenRepository()
        ..pending = Completer<VocabularyRecord>();
      final oldSession = EntrySessionController(
        collectionId: owner.id,
        repository: repository,
      );
      final newSession = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      addTearDown(oldSession.dispose);
      clean(tester, newSession);
      oldSession.setTargetText('Old');
      oldSession.setNativeText('Alt');
      await mount(tester, oldSession);
      await tester.tap(find.byTooltip('Save & Next'));
      await tester.pump();
      await mount(tester, newSession);
      repository.pending!.completeError(StateError('Old write failed'));
      await tester.pumpAndSettle();
      expect(
        find.text(const PikoCopy('en').text('entry.saveFailed')),
        findsNothing,
      );
      expect(newSession.draft.targetText, isEmpty);
      expect(newSession.confirmedEntries, isEmpty);
    },
  );

  testWidgets(
    'autosave completion during a held drag does not cancel continued scroll intent',
    (tester) async {
      final repository = ScreenRepository();
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: repository,
      );
      clean(tester, session);
      await seed(session, 5);
      await mount(tester, session);
      final id = session.confirmedEntries.last.id;
      await scrollTo(tester, id);
      await tester.tap(field(id, 'native'));
      repository.pendingEdit = Completer<VocabularyRecord>();
      await tester.enterText(field(id, 'native'), 'Changed');
      await tester.pump();
      final viewport = tester.getRect(
        find.byKey(const ValueKey('entry-stack')),
      );
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('entry-stack')),
          )
          .controller!;
      final gesture = await tester.startGesture(
        Offset(viewport.left + 4, viewport.center.dy),
      );
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 16));
      final beforeCompletion = scroll.offset;
      repository.pendingEdit!.complete(
        VocabularyRecord(
          id: id,
          collectionId: owner.id,
          targetText: session.savedEntryState(id).draft.targetText,
          nativeText: 'Changed',
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(scroll.offset, closeTo(beforeCompletion, 2));
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump(const Duration(milliseconds: 16));
      expect(scroll.offset, lessThan(beforeCompletion - 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(session.activeEntryId, isNot(id));
    },
  );
  testWidgets(
    'expansion frames retain selected identity and measured center without oscillation',
    (tester) async {
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      clean(tester, session);
      await seed(session, 4);
      await mount(tester, session);
      // An interior card can retain its measured center without requiring
      // artificial leading space before the first card.
      final id = session.confirmedEntries[2].id;
      final viewport = tester.getRect(
        find.byKey(const ValueKey('entry-stack')),
      );
      final before = tester.getRect(find.byKey(ValueKey('entry-card-$id')));
      await tester.dragFrom(
        Offset(viewport.left + 4, viewport.center.dy),
        Offset(0, viewport.center.dy - before.center.dy),
      );
      final centers = <double>[];
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(session.activeEntryId, id);
        centers.add(
          tester.getCenter(find.byKey(ValueKey('entry-card-$id'))).dy,
        );
      }
      expect(
        centers.reduce((a, b) => a > b ? a : b) -
            centers.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(2),
      );
      expect(centers.last, closeTo(viewport.center.dy, 24));
      await tester.pumpAndSettle();
      expect(session.activeEntryId, id);
    },
  );

  testWidgets(
    'only active fields enter Tab order and nested vertical scrolling cannot select cards',
    (tester) async {
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      clean(tester, session);
      await seed(session, 3);
      await mount(tester, session);
      final stack = find
          .ancestor(
            of: find.byKey(const ValueKey('entry-stack')),
            matching: find.byType(Focus),
          )
          .first;
      tester.widget<Focus>(stack).focusNode!.requestFocus();
      await tester.pump();
      var focusedFields = 0;
      for (var tab = 0; tab < 8; tab++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        for (final editor in tester.widgetList<PikoTextField>(
          find.byType(PikoTextField, skipOffstage: false),
        )) {
          if (editor.focusNode!.hasFocus) {
            focusedFields++;
            expect(
              (editor.key! as ValueKey<String>).value,
              startsWith('draft-'),
            );
          }
        }
      }
      expect(focusedFields, greaterThan(0));
      FocusManager.instance.primaryFocus?.unfocus();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('entry-stack')),
          )
          .controller!;
      scroll.jumpTo(0);
      await tester.pump();
      expect(session.activeEntryId, isNull);
      final context = tester.element(field('draft', 'target'));
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: 50,
        viewportDimension: 20,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      NestedUserScroll(
        metrics: metrics,
        context: context,
        direction: ScrollDirection.reverse,
      ).dispatch(context);
      NestedScrollUpdate(
        metrics: metrics,
        context: context,
        scrollDelta: 50,
      ).dispatch(context);
      await tester.pumpAndSettle();
      expect(session.activeEntryId, isNull);
    },
  );
  testWidgets(
    'production fields confirm and automatically edit real SQLite records',
    (tester) async {
      final db = PikoDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(db.close);
      final collection = (await tester.runAsync(
        () => SqliteCollectionsRepository(db).create(
          name: 'Real entries',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        ),
      ))!;
      final session = EntrySessionController(
        collectionId: collection.id,
        repository: SqliteVocabularyRepository(db),
      );
      clean(tester, session);
      await mount(tester, session, collection: collection);
      expect(find.byType(PikoCard), findsOneWidget);
      await tester.enterText(field('draft', 'target'), '학교');
      await tester.enterText(field('draft', 'native'), 'Schule');
      await tester.ensureVisible(find.byTooltip('Save & Next'));
      await tester.tap(find.byTooltip('Save & Next'));
      await tester.runAsync(() => db.select(db.vocabularyEntries).get());
      await tester.pumpAndSettle();
      expect(session.confirmedEntries, hasLength(1));
      final id = session.confirmedEntries.single.id;
      expect(session.activeEntryId, isNull);
      expect(session.draft.targetText, isEmpty);
      expect(find.byType(PikoCard), findsNWidgets(2));
      await scrollTo(tester, id);
      expect(session.activeEntryId, id);
      await tester.enterText(field(id, 'native'), '  Neue Schule  ');
      await tester.runAsync(session.awaitSavedEdits);
      await tester.pumpAndSettle();
      final stored = await tester.runAsync(
        () => db.select(db.vocabularyEntries).getSingle(),
      );
      expect(stored!.id, id);
      expect(stored.nativeText, 'Neue Schule');
      expect(
        tester.widget<TextField>(field(id, 'native')).controller!.text,
        '  Neue Schule  ',
      );
    },
  );

  testWidgets(
    'scroll activates without taps and preserves raw draft and controller selection',
    (tester) async {
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      clean(tester, session);
      await seed(session, 3);
      session.setTargetText('  raw draft  ');
      await mount(tester, session);
      final editor = tester
          .widget<TextField>(field('draft', 'target'))
          .controller!;
      editor.selection = const TextSelection(baseOffset: 2, extentOffset: 5);
      final firstId = session.confirmedEntries.first.id;
      await scrollTo(tester, firstId);
      expect(session.activeEntryId, firstId);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(session.draft.targetText, '  raw draft  ');
      final active = tester.widget<PikoCard>(
        find.byKey(ValueKey('entry-card-$firstId')),
      );
      expect(active.selected, isTrue);
      final selectedCenter = tester
          .getCenter(find.byKey(ValueKey('entry-card-$firstId')))
          .dy;
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byKey(ValueKey('entry-card-$firstId'))).dy,
        closeTo(selectedCenter, 1),
      );
      await scrollTo(tester, 'draft');
      expect(session.activeEntryId, isNull);
      expect(
        tester.widget<TextField>(field('draft', 'target')).controller,
        same(editor),
      );
      expect(
        editor.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.widget<TextField>(field('draft', 'target')).focusNode!.hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'stack keyboard navigation is bounded and never hijacks editing or nested scroll',
    (tester) async {
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      clean(tester, session);
      await seed(session, 2);
      await mount(tester, session);
      final stack = find
          .ancestor(
            of: find.byKey(const ValueKey('entry-stack')),
            matching: find.byType(Focus),
          )
          .first;
      tester.widget<Focus>(stack).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(session.activeEntryId, session.confirmedEntries.last.id);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      final firstId = session.confirmedEntries.first.id;
      expect(session.activeEntryId, firstId);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(session.activeEntryId, firstId);
      await tester.tap(field(firstId, 'target'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(session.activeEntryId, firstId);
      final context = tester.element(field(firstId, 'target'));
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 100,
        pixels: 50,
        viewportDimension: 20,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1,
      );
      UserScrollNotification(
        metrics: metrics,
        context: context,
        direction: ScrollDirection.reverse,
      ).dispatch(context);
      ScrollUpdateNotification(
        metrics: metrics,
        context: context,
        scrollDelta: 50,
      ).dispatch(context);
      await tester.pumpAndSettle();
      expect(session.activeEntryId, firstId);
    },
  );

  testWidgets(
    'zero-entry draft, pending confirmation and failures preserve usable editing',
    (tester) async {
      final repository = ScreenRepository();
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: repository,
      );
      clean(tester, session);
      await mount(tester, session);
      await tester.tap(find.byTooltip('Save & Next'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the target word.'), findsOneWidget);
      await tester.enterText(field('draft', 'target'), 'One');
      await tester.pumpAndSettle();
      expect(find.text('Enter the target word.'), findsNothing);
      await tester.enterText(field('draft', 'native'), 'Eins');
      repository.pending = Completer<VocabularyRecord>();
      await tester.ensureVisible(find.byTooltip('Save & Next'));
      await tester.tap(find.byTooltip('Save & Next'));
      await tester.pump();
      expect(session.isConfirming, isTrue);
      expect(
        tester.widget<TextField>(field('draft', 'target')).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<SingleChildScrollView>(
              find.byKey(const ValueKey('entry-stack')),
            )
            .physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      repository.pending!.completeError(StateError('Disk full'));
      await tester.pumpAndSettle();
      expect(session.draft.targetText, 'One');
      expect(
        find.text(const PikoCopy('en').text('entry.saveFailed')),
        findsOneWidget,
      );
      repository.pending = null;
      await tester.tap(find.byTooltip('Save & Next'));
      await tester.pumpAndSettle();
      final id = session.confirmedEntries.single.id;
      await scrollTo(tester, id);
      repository.failUpdate = true;
      await tester.enterText(field(id, 'native'), 'Failure');
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      repository.failUpdate = false;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(session.savedEntryState(id).committed.nativeText, 'Failure');
    },
  );

  testWidgets(
    'German large text, keyboard reflow, locale rebuild and reduced motion preserve state',
    (tester) async {
      tester.view.physicalSize = const Size(392, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final locale = InterfaceLocaleController(const Locale('de'));
      addTearDown(locale.dispose);
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      clean(tester, session);
      await seed(session, 1);
      await tester.pumpWidget(
        PikoApp(
          localeController: locale,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: EntrySessionScreen(collection: owner, session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(field('draft', 'target'));
      await tester.enterText(field('draft', 'target'), '  학교  ');
      final editable = tester.state<EditableTextState>(
        find.descendant(
          of: field('draft', 'target'),
          matching: find.byType(EditableText),
        ),
      );
      final controller = editable.widget.controller;
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 3,
      );
      // Rebuild the resized production viewport without simulating a user scroll.
      await tester.pumpWidget(
        PikoApp(
          localeController: locale,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: EntrySessionScreen(collection: owner, session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(session.activeEntryId, isNull);
      expect(controller.text, '  학교  ');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 3),
      );
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(find.byType(AnimatedSize), findsNothing);
      await tester.ensureVisible(find.byTooltip('Save & Next'));
      await tester.pumpAndSettle();
      final buttonBox = tester.getRect(find.byTooltip('Save & Next'));
      expect(buttonBox.bottom, lessThanOrEqualTo(700));
      expect(tester.takeException(), isNull);
    },
  );
}
