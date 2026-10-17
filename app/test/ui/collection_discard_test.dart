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
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_icon.dart';

class ControlledRollback implements VocabularyRepository {
  ControlledRollback(this.real);
  final VocabularyRepository real;
  Completer<void>? updateGate, restoreGate;
  bool failRestore = false;
  int restores = 0;
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) =>
      real.captureOpeningSnapshot(entryId: entryId, collectionId: collectionId);
  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) async {
    restores++;
    await restoreGate?.future;
    if (failRestore) throw StateError('Rollback unavailable');
    return real.restoreOpeningSnapshot(snapshot);
  }

  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) async {
    await updateGate?.future;
    return real.update(id: id, targetText: targetText, nativeText: nativeText);
  }

  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) => real.create(
    collectionId: collectionId,
    targetText: targetText,
    nativeText: nativeText,
  );
  @override
  Stream<List<VocabularyRecord>> watchByCollection(String id) =>
      real.watchByCollection(id);
  @override
  Stream<VocabularyRecord?> watchById(String id) => real.watchById(id);
}

class Fixture {
  final db = PikoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  late final real = SqliteVocabularyRepository(db);
  late final repository = ControlledRollback(real);
  late CollectionRecord owner;
  late VocabularyRecord one, two;
  Future<void> initialize() async {
    owner = await SqliteCollectionsRepository(db).create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    one = await real.create(
      collectionId: owner.id,
      targetText: 'One',
      nativeText: 'Eins',
    );
    two = await real.create(
      collectionId: owner.id,
      targetText: 'Two',
      nativeText: 'Zwei',
    );
  }
}

Finder card(String id) => find.byKey(ValueKey('vocabulary-$id'));
Finder field(String id, [bool target = true]) => find.descendant(
  of: find.byKey(ValueKey('inline-$id-${target ? 'target' : 'native'}')),
  matching: find.byType(TextField),
);
Finder finish(String id) => find.byKey(ValueKey('inline-complete-$id'));
Finder discard(String id) => find.byKey(ValueKey('inline-discard-$id'));
Future<void> flush(WidgetTester tester, Fixture f) async {
  await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

Future<ValueNotifier<VocabularyRepository>> mount(
  WidgetTester tester,
  Fixture f, {
  String locale = 'en',
  double width = 760,
  double scale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dependency = ValueNotifier<VocabularyRepository>(f.repository);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    dependency.dispose();
    await tester.runAsync(f.db.close);
  });
  await tester.pumpWidget(
    PikoApp(
      locale: Locale(locale),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<VocabularyRepository>(
                valueListenable: dependency,
                builder: (_, repo, _) =>
                    CollectionVocabulary(collection: f.owner, repository: repo),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await flush(tester, f);
  return dependency;
}

// VOCAB-EDIT-003 r3 removed rollback from saved-card UI. Repository-level
// snapshot restoration remains covered separately for deletion/integrity uses.
void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale autosave retains one accessible collapse chevron without Finish/Discard or rollback',
      (tester) async {
        final f = Fixture();
        await tester.runAsync(f.initialize);
        await mount(
          tester,
          f,
          locale: locale,
          width: 392,
          scale: 2,
          keyboard: 300,
        );
        await tester.tap(card(f.one.id));
        await flush(tester, f);
        await tester.enterText(field(f.one.id), 'Changed');
        await flush(tester, f);
        expect(discard(f.one.id), findsNothing);
        final control = finish(f.one.id);
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        final rect = tester.getRect(control);
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(rect.bottom, lessThanOrEqualTo(700));
        final icon = find.descendant(
          of: control,
          matching: find.byType(PikoIcon),
        );
        expect(tester.widget<PikoIcon>(icon).name, PikoIconName.chevronRight);
        Focus.of(tester.element(icon)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await flush(tester, f);
        expect(field(f.one.id), findsNothing);
        expect(
          (await tester.runAsync(
            () => f.real.watchById(f.one.id).first,
          ))!.targetText,
          'Changed',
        );
        expect(f.repository.restores, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'invalid collapse retains raw selection and saved content; correction saves without rollback',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      final before = await tester.runAsync(
        () =>
            f.db.customSelect('SELECT * FROM learning_items ORDER BY id').get(),
      );
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      await tester.enterText(field(f.one.id), 'Changed');
      await flush(tester, f);
      await tester.enterText(field(f.one.id, false), '  ');
      final raw = tester.widget<TextField>(field(f.one.id, false)).controller!;
      raw.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
      await tester.tap(finish(f.one.id));
      await flush(tester, f);
      expect(field(f.one.id), findsOneWidget);
      expect(raw.text, '  ');
      expect(
        raw.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(
        (await tester.runAsync(
          () => f.real.watchById(f.one.id).first,
        ))!.targetText,
        'Changed',
      );
      expect(discard(f.one.id), findsNothing);
      expect(f.repository.restores, 0);
      await tester.enterText(field(f.one.id, false), 'Neu');
      await flush(tester, f);
      await tester.tap(finish(f.one.id));
      await flush(tester, f);
      expect(field(f.one.id), findsNothing);
      final after = await tester.runAsync(
        () =>
            f.db.customSelect('SELECT * FROM learning_items ORDER BY id').get(),
      );
      expect(after!.map((row) => row.data), before!.map((row) => row.data));
    },
  );
  testWidgets(
    'collapse drains queued autosaves and rejects competing edits until final content is saved',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      final gate = Completer<void>();
      f.repository.updateGate = gate;
      await tester.enterText(field(f.one.id), 'First');
      await tester.pump();
      await tester.enterText(field(f.one.id), 'Latest');
      await tester.pump();
      await tester.tap(finish(f.one.id));
      await tester.pump();
      expect(tester.widget<TextField>(field(f.one.id)).enabled, isFalse);
      expect(f.repository.restores, 0);
      gate.complete();
      await flush(tester, f);
      expect(field(f.one.id), findsNothing);
      expect(
        (await tester.runAsync(
          () => f.real.watchById(f.one.id).first,
        ))!.targetText,
        'Latest',
      );
    },
  );
}
