import 'dart:async';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_card.dart';
import '../support/vocabulary_opening_snapshot.dart';

const owner = CollectionRecord(
  id: 'owner',
  name: 'Words',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);
const one = VocabularyRecord(
  id: 'one',
  collectionId: 'owner',
  targetText: 'Café',
  nativeText: 'Kaffee',
);
const two = VocabularyRecord(
  id: 'two',
  collectionId: 'owner',
  targetText: 'École',
  nativeText: 'Schule',
);

class LiveVocabulary implements VocabularyRepository {
  Completer<void>? captureGate;
  bool failCapture = false;
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) async {
    await captureGate?.future;
    if (failCapture) throw StateError('Capture failed');
    return TestOpeningSnapshot(
      records.singleWhere(
        (row) => row.id == entryId && row.collectionId == collectionId,
      ),
    );
  }

  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) => update(
    id: snapshot.entry.id,
    targetText: snapshot.entry.targetText,
    nativeText: snapshot.entry.nativeText,
  );
  List<VocabularyRecord> records = [one, two];
  final streams = <StreamController<List<VocabularyRecord>>>[];
  final writes =
      <
        ({
          String id,
          String target,
          String native,
          Completer<VocabularyRecord> result,
        })
      >[];
  bool delay = false, fail = false;
  int watchCalls = 0;
  @override
  Stream<List<VocabularyRecord>> watchByCollection(String id) {
    watchCalls++;
    late StreamController<List<VocabularyRecord>> stream;
    stream = StreamController(onListen: () => stream.add(List.of(records)));
    streams.add(stream);
    return stream.stream;
  }

  void emit() {
    for (final stream in streams) {
      if (stream.hasListener && !stream.isClosed) stream.add(List.of(records));
    }
  }

  void error() => streams.last.addError(StateError('read failed'));
  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) async {
    if (delay) {
      final result = Completer<VocabularyRecord>();
      writes.add((
        id: id,
        target: targetText,
        native: nativeText,
        result: result,
      ));
      return result.future;
    }
    if (fail) throw StateError('write failed');
    final record = VocabularyRecord(
      id: id,
      collectionId: owner.id,
      targetText: targetText,
      nativeText: nativeText,
    );
    records = [for (final row in records) row.id == id ? record : row];
    emit();
    return record;
  }

  void complete() {
    final write = writes.firstWhere((w) => !w.result.isCompleted);
    write.result.complete(
      VocabularyRecord(
        id: write.id,
        collectionId: owner.id,
        targetText: write.target,
        nativeText: write.native,
      ),
    );
  }

  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) => throw UnimplementedError();
  @override
  Stream<VocabularyRecord?> watchById(String id) =>
      Stream.value(records.where((r) => r.id == id).firstOrNull);
  Future<void> close() async {
    for (final stream in streams) {
      await stream.close();
    }
  }
}

class LiveCollections implements CollectionsRepository {
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      throw UnimplementedError();
  final streams = <StreamController<CollectionRecord?>>[];
  CollectionRecord current = owner;
  @override
  Stream<CollectionRecord?> watchById(String id) {
    late StreamController<CollectionRecord?> stream;
    stream = StreamController(onListen: () => stream.add(current));
    streams.add(stream);
    return stream.stream;
  }

  @override
  Stream<List<CollectionRecord>> watchAll() => Stream.value([current]);
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => throw UnimplementedError();
  Future<void> close() async {
    for (final stream in streams) {
      await stream.close();
    }
  }
}

Finder card(String id) => find.byKey(ValueKey('vocabulary-$id'));
Finder field(String id, [bool target = true]) => find.descendant(
  of: find.byKey(ValueKey('inline-$id-${target ? 'target' : 'native'}')),
  matching: find.byType(TextField),
);
Finder collapse() => find.byWidgetPredicate(
  (w) =>
      (w is PikoButton &&
          (w.label == 'Finish editing' ||
              w.label == 'Bearbeiten abschließen')) ||
      w is PikoIconButton &&
          (w.semanticLabel == 'Close' ||
              w.semanticLabel == 'Schließen' ||
              w.semanticLabel == 'Collapse vocabulary editor' ||
              w.semanticLabel == 'Vokabeleditor einklappen' ||
              w.semanticLabel == 'Finish editing' ||
              w.semanticLabel == 'Bearbeiten abschließen'),
);
Future<void> mount(
  WidgetTester tester,
  VocabularyRepository repository, {
  CollectionRecord collection = owner,
  InterfaceLocaleController? locale,
  double width = 760,
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    PikoApp(
      localeController: locale,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: CollectionVocabulary(
                collection: collection,
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void cleanup(WidgetTester tester, LiveVocabulary repository) =>
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await repository.close();
    });

void main() {
  testWidgets(
    'capture completes before editable buffers exist; captured values then retain raw selection',
    (tester) async {
      final repository = LiveVocabulary()..captureGate = Completer<void>();
      addTearDown(repository.close);
      await mount(tester, repository);
      await tester.tap(card('one'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      repository.records[0] = const VocabularyRecord(
        id: 'one',
        collectionId: 'owner',
        targetText: 'Fresh stored',
        nativeText: 'Frisch',
      );
      repository.captureGate!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('one')).controller!.text,
        'Fresh stored',
      );
      await tester.enterText(field('one'), ' raw ');
      final controller = tester.widget<TextField>(field('one')).controller!;
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 3,
      );
      repository.emit();
      await tester.pumpAndSettle();
      expect(controller.text, ' raw ');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
    },
  );

  testWidgets(
    'failed capture retries and late capture cannot revive removed row or disposed view',
    (tester) async {
      final repository = LiveVocabulary()..failCapture = true;
      addTearDown(repository.close);
      await mount(tester, repository);
      await tester.tap(card('one'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      repository.failCapture = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(field('one'), findsOneWidget);
      await tester.tap(collapse());
      await tester.pumpAndSettle();
      repository.captureGate = Completer<void>();
      await tester.tap(card('one'));
      await tester.pump();
      repository.records.removeAt(0);
      repository.emit();
      await tester.pump();
      repository.captureGate!.complete();
      await tester.pumpAndSettle();
      expect(field('one'), findsNothing);
      repository.captureGate = Completer<void>();
      await tester.tap(card('two'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      repository.captureGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'real SQLite same card expands, autosaves, guards invalid and duplicate input, and reopens committed values',
    (tester) async {
      final db = PikoDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.close();
      });
      final collection = (await tester.runAsync(
        () => SqliteCollectionsRepository(db).create(
          name: 'Words',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        ),
      ))!;
      final repo = SqliteVocabularyRepository(db);
      final first = (await tester.runAsync(
        () => repo.create(
          collectionId: collection.id,
          targetText: 'Café',
          nativeText: 'Kaffee',
        ),
      ))!;
      final second = (await tester.runAsync(
        () => repo.create(
          collectionId: collection.id,
          targetText: 'École',
          nativeText: 'Schule',
        ),
      ))!;
      final before = (await tester.runAsync(
        () => db.customSelect('SELECT * FROM learning_items ORDER BY id').get(),
      ))!.map((r) => r.data).toList();
      await mount(tester, repo, collection: collection);
      final element = tester.element(card(first.id));
      await tester.tap(card(first.id));
      await tester.pumpAndSettle();
      expect(tester.element(card(first.id)), same(element));
      expect(find.text('French'), findsOneWidget);
      expect(find.text('German'), findsOneWidget);
      await tester.enterText(field(first.id), ' Bonjour ');
      await tester.pumpAndSettle();
      await tester.enterText(field(first.id, false), ' Guten Tag ');
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          () => repo.watchById(first.id).first,
        ))!.targetText,
        'Bonjour',
      );
      await tester.enterText(field(first.id), ' ');
      await tester.pumpAndSettle();
      await tester.tap(collapse());
      await tester.pumpAndSettle();
      expect(field(first.id), findsOneWidget);
      expect(field(second.id), findsNothing);
      await tester.enterText(field(first.id), 'École');
      await tester.pumpAndSettle();
      await tester.enterText(field(first.id, false), 'Schule');
      await tester.pumpAndSettle();
      await tester.tap(collapse());
      await tester.pumpAndSettle();
      expect(field(first.id), findsOneWidget);
      expect(
        (await tester.runAsync(
          () => repo.watchById(first.id).first,
        ))!.nativeText,
        'Guten Tag',
      );
      await tester.enterText(field(first.id, false), 'Andere');
      await tester.pumpAndSettle();
      await tester.tap(collapse());
      await tester.pumpAndSettle();
      expect(field(first.id), findsNothing);
      await tester.tap(card(first.id));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field(first.id, false)).controller!.text,
        'Andere',
      );
      expect(
        (await tester.runAsync(
          () =>
              db.customSelect('SELECT * FROM learning_items ORDER BY id').get(),
        ))!.map((r) => r.data).toList(),
        before,
      );
    },
  );

  testWidgets(
    'stream and locale rebuilds retain raw text, selection and focused field; retry resubscribes without retiring editor',
    (tester) async {
      final repo = LiveVocabulary();
      cleanup(tester, repo);
      final locale = InterfaceLocaleController();
      addTearDown(locale.dispose);
      await mount(tester, repo, locale: locale);
      await tester.tap(card(one.id));
      await tester.pumpAndSettle();
      await tester.enterText(field(one.id), '  ');
      final text = tester.widget<TextField>(field(one.id));
      text.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 1,
      );
      repo.emit();
      locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field(one.id)).controller,
        same(text.controller),
      );
      expect(text.controller!.text, '  ');
      expect(
        text.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(text.focusNode!.hasFocus, isTrue);
      repo.error();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor-source-retry')));
      await tester.pumpAndSettle();
      expect(repo.watchCalls, 2);
      expect(
        tester.widget<TextField>(field(one.id)).controller,
        same(text.controller),
      );
      expect(text.focusNode!.hasFocus, isTrue);
    },
  );

  testWidgets(
    'metadata error and real retry preserve the same keyed invalid editor, selection and focus',
    (tester) async {
      final repo = LiveVocabulary();
      final collections = LiveCollections();
      cleanup(tester, repo);
      addTearDown(collections.close);
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: collections,
            collectionId: owner.id,
            vocabularyRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(card(one.id));
      await tester.pumpAndSettle();
      await tester.enterText(field(one.id), ' ');
      final text = tester.widget<TextField>(field(one.id));
      text.controller!.selection = const TextSelection.collapsed(offset: 0);
      // Detail has independent subscriptions for the saved-entry subtitle and
      // the editable list. Retrying failed metadata recreates only the former.
      expect(repo.watchCalls, 2);
      collections.streams.last.addError(StateError('metadata failed'));
      await tester.pumpAndSettle();
      expect(field(one.id), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('editor-source-retry')));
      await tester.pumpAndSettle();
      expect(collections.streams.length, 2);
      expect(repo.watchCalls, 3);
      expect(
        tester.widget<TextField>(field(one.id)).controller,
        same(text.controller),
      );
      expect(text.controller!.text, ' ');
      expect(text.controller!.selection.baseOffset, 0);
      expect(text.focusNode!.hasFocus, isTrue);
      collections.current = const CollectionRecord(
        id: 'owner',
        name: 'Renamed',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      collections.streams.last.add(collections.current);
      await tester.pumpAndSettle();
      expect(find.text('Renamed'), findsOneWidget);
      expect(
        tester.widget<TextField>(field(one.id)).controller,
        same(text.controller),
      );
    },
  );

  testWidgets(
    'removal during accepted-save drain invalidates transition and remaining rows stay usable',
    (tester) async {
      final repo = LiveVocabulary()..delay = true;
      cleanup(tester, repo);
      await mount(tester, repo);
      await tester.tap(card(one.id));
      await tester.pumpAndSettle();
      await tester.enterText(field(one.id), 'Changed');
      await tester.pump();
      await tester.tap(collapse());
      await tester.pump();
      expect(tester.widget<TextField>(field(one.id)).enabled, isFalse);
      repo.records = [two];
      repo.emit();
      await tester.pumpAndSettle();
      await tester.tap(card(two.id));
      await tester.pumpAndSettle();
      expect(field(two.id), findsOneWidget);
      repo.complete();
      await tester.pumpAndSettle();
      expect(field(two.id), findsOneWidget);
      expect(tester.widget<TextField>(field(two.id)).enabled, isTrue);
    },
  );

  testWidgets(
    'vocabulary retry during drain releases transition without closing the retained raw editor',
    (tester) async {
      final repo = LiveVocabulary()..delay = true;
      cleanup(tester, repo);
      await mount(tester, repo);
      await tester.tap(card(one.id));
      await tester.pumpAndSettle();
      await tester.enterText(field(one.id), 'Changed');
      await tester.pump();
      repo.error();
      await tester.pumpAndSettle();
      await tester.tap(collapse());
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('editor-source-retry')));
      await tester.pumpAndSettle();
      expect(repo.watchCalls, 2);
      expect(tester.widget<TextField>(field(one.id)).enabled, isTrue);
      repo.complete();
      await tester.pumpAndSettle();
      expect(field(one.id), findsOneWidget);
      expect(
        tester.widget<TextField>(field(one.id)).controller!.text,
        'Changed',
      );
    },
  );

  testWidgets(
    'storage failure keeps input and editor open until explicit retry succeeds',
    (tester) async {
      final repo = LiveVocabulary()..fail = true;
      cleanup(tester, repo);
      await mount(tester, repo);
      await tester.tap(card(one.id));
      await tester.pumpAndSettle();
      await tester.enterText(field(one.id), 'Changed');
      await tester.pumpAndSettle();
      await tester.tap(collapse());
      await tester.pumpAndSettle();
      expect(field(one.id), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repo.records.first.targetText, 'Changed');
      await tester.tap(collapse());
      await tester.pumpAndSettle();
      expect(field(one.id), findsNothing);
    },
  );

  testWidgets(
    'edit action is labelled and keyboard activated; modal fields remain stacked across widths',
    (tester) async {
      final repo = LiveVocabulary();
      cleanup(tester, repo);
      final semantics = tester.ensureSemantics();
      await mount(tester, repo, width: 421);
      expect(find.bySemanticsLabel('Edit Café · Kaffee'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<PikoCard>(card(one.id)).focused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(field(one.id), findsOneWidget);
      expect(
        tester.getTopLeft(field(one.id, false)).dy,
        greaterThan(tester.getBottomLeft(field(one.id)).dy),
      );
      expect(
        tester.widget<TextField>(field(one.id)).style!.fontWeight,
        FontWeight.w400,
      );
      tester.view.physicalSize = const Size(420, 1000);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(field(one.id, false)).dy,
        greaterThan(tester.getBottomLeft(field(one.id)).dy),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'German 392px at 200 percent keeps both fields and collapse reachable above keyboard',
    (tester) async {
      final repo = LiveVocabulary();
      cleanup(tester, repo);
      final locale = InterfaceLocaleController(const Locale('de'));
      addTearDown(locale.dispose);
      await mount(
        tester,
        repo,
        locale: locale,
        width: 392,
        scale: 2,
        keyboard: 300,
      );
      await tester.tap(card(one.id));
      await tester.pumpAndSettle();
      await tester.ensureVisible(field(one.id, false));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(field(one.id, false)).bottom,
        lessThanOrEqualTo(700),
      );
      await tester.enterText(field(one.id, false), ' ');
      await tester.pumpAndSettle();
      await tester.ensureVisible(collapse());
      await tester.pumpAndSettle();
      expect(tester.getRect(collapse()).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(collapse()).bottom, lessThanOrEqualTo(700));
      await tester.tap(collapse());
      await tester.pumpAndSettle();
      expect(field(one.id, false), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
