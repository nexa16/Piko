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
import 'package:piko/ui/components/piko_button.dart';
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

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale has one unchanged collapse X, then distinct labelled 44px Finish and Discard with keyboard activation',
      (tester) async {
        final f = Fixture();
        await tester.runAsync(f.initialize);
        await mount(tester, f, locale: locale);
        final semantics = tester.ensureSemantics();
        try {
          await tester.tap(card(f.one.id));
          await flush(tester, f);
          expect(discard(f.one.id), findsNothing);
          expect(
            tester.widget<PikoIconButton>(finish(f.one.id)).semanticLabel,
            locale == 'en'
                ? 'Collapse vocabulary editor'
                : 'Vokabeleditor einklappen',
          );
          await tester.enterText(field(f.one.id), 'Changed');
          await flush(tester, f);
          final labels = locale == 'en'
              ? ['Finish editing', 'Discard changes']
              : ['Bearbeiten abschließen', 'Änderungen verwerfen'];
          for (final (finder, label) in [
            (finish(f.one.id), labels[0]),
            (discard(f.one.id), labels[1]),
          ]) {
            final rect = tester.getRect(finder);
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(find.bySemanticsLabel(label), findsOneWidget);
            expect(
              find.descendant(
                of: finder,
                matching: find.byWidgetPredicate(
                  (w) => w is Tooltip && w.message == label,
                ),
              ),
              findsOneWidget,
            );
          }
          final completeIcon = find.descendant(
            of: finish(f.one.id),
            matching: find.byType(PikoIcon),
          );
          final discardIcon = find.descendant(
            of: discard(f.one.id),
            matching: find.byType(PikoIcon),
          );
          Focus.of(tester.element(completeIcon)).requestFocus();
          await tester.pump();
          expect(Focus.of(tester.element(completeIcon)).hasPrimaryFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(Focus.of(tester.element(discardIcon)).hasPrimaryFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await flush(tester, f);
          expect(field(f.one.id), findsNothing);
          expect(
            (await tester.runAsync(
              () => f.real.watchById(f.one.id).first,
            ))!.targetText,
            'One',
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets(
    'invalid raw input cannot Finish but Discard restores both opening fields and leaves learning state unchanged',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      final progress = await tester.runAsync(
        () async =>
            (await f.db
                    .customSelect('SELECT * FROM learning_items ORDER BY id')
                    .get())
                .map((r) => r.data)
                .toList(),
      );
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      await tester.enterText(field(f.one.id), 'Changed');
      await flush(tester, f);
      await tester.enterText(field(f.one.id, false), ' ');
      await tester.pumpAndSettle();
      await tester.tap(finish(f.one.id));
      await tester.pumpAndSettle();
      expect(field(f.one.id), findsOneWidget);
      await tester.tap(discard(f.one.id));
      await flush(tester, f);
      expect(field(f.one.id), findsNothing);
      final saved = (await tester.runAsync(
        () => f.real.watchById(f.one.id).first,
      ))!;
      expect(saved.targetText, 'One');
      expect(saved.nativeText, 'Eins');
      expect(
        await tester.runAsync(
          () async =>
              (await f.db
                      .customSelect('SELECT * FROM learning_items ORDER BY id')
                      .get())
                  .map((r) => r.data)
                  .toList(),
        ),
        progress,
      );
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      expect(discard(f.one.id), findsNothing);
    },
  );
  testWidgets(
    'queued autosaves drain then one rollback; pending controls and fields cannot compete',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      final updates = Completer<void>();
      f.repository.updateGate = updates;
      await tester.enterText(field(f.one.id), 'A');
      await tester.enterText(field(f.one.id), 'B');
      await tester.tap(discard(f.one.id));
      await tester.pump();
      await tester.tap(discard(f.one.id));
      await tester.pump();
      expect(f.repository.restores, 0);
      expect(tester.widget<TextField>(field(f.one.id)).enabled, isFalse);
      expect(tester.widget<PikoIconButton>(finish(f.one.id)).onPressed, isNull);
      await tester.tap(card(f.two.id));
      await tester.pump();
      expect(field(f.two.id), findsNothing);
      updates.complete();
      await flush(tester, f);
      expect(f.repository.restores, 1);
      expect(field(f.one.id), findsNothing);
      expect(
        (await tester.runAsync(
          () => f.real.watchById(f.one.id).first,
        ))!.targetText,
        'One',
      );
    },
  );
  testWidgets(
    'rollback storage failure retains raw selection and focus, and retry restores the original capture',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      await tester.enterText(field(f.one.id), 'Changed');
      await flush(tester, f);
      final text = tester.widget<TextField>(field(f.one.id));
      text.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 2,
      );
      f.repository.failRestore = true;
      await tester.tap(discard(f.one.id));
      await flush(tester, f);
      expect(
        find.text("Couldn't discard changes. Please try again."),
        findsOneWidget,
      );
      expect(text.controller!.text, 'Changed');
      expect(
        text.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      expect(text.focusNode!.hasFocus, isTrue);
      f.repository.failRestore = false;
      await tester.tap(find.text('Try again'));
      await flush(tester, f);
      expect(field(f.one.id), findsNothing);
      expect(f.repository.restores, 2);
    },
  );
  testWidgets(
    'opening-pair collision keeps Discard error and raw editor until retry becomes safe',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      await tester.enterText(field(f.one.id), 'Changed');
      await flush(tester, f);
      final other = (await tester.runAsync(
        () => f.real.create(
          collectionId: f.owner.id,
          targetText: 'One',
          nativeText: 'Eins',
        ),
      ))!;
      await tester.tap(discard(f.one.id));
      await flush(tester, f);
      expect(field(f.one.id), findsOneWidget);
      expect(
        tester.widget<TextField>(field(f.one.id)).controller!.text,
        'Changed',
      );
      expect(
        (await tester.runAsync(
          () => f.real.watchById(other.id).first,
        ))!.targetText,
        'One',
      );
      await tester.runAsync(
        () => (f.db.delete(
          f.db.vocabularyEntries,
        )..where((row) => row.id.equals(other.id))).go(),
      );
      await tester.tap(find.text('Try again'));
      await flush(tester, f);
      expect(field(f.one.id), findsNothing);
      expect(
        (await tester.runAsync(
          () => f.real.watchById(f.one.id).first,
        ))!.targetText,
        'One',
      );
    },
  );
  testWidgets(
    'late rollback cannot collapse or focus a replacement row or navigate a covered route',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      final dependency = await mount(tester, f);
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      await tester.enterText(field(f.one.id), 'Changed');
      await flush(tester, f);
      final gate = Completer<void>();
      f.repository.restoreGate = gate;
      await tester.tap(discard(f.one.id));
      await tester.pump();
      dependency.value = ControlledRollback(f.real);
      await flush(tester, f);
      await tester.tap(card(f.two.id));
      await flush(tester, f);
      await tester.enterText(field(f.two.id), ' ');
      final text = tester.widget<TextField>(field(f.two.id));
      final navigator = Navigator.of(tester.element(field(f.two.id)));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Other route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      gate.complete();
      await flush(tester, f);
      expect(find.text('Other route'), findsOneWidget);
      expect(navigator.canPop(), isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field(f.two.id)).controller,
        same(text.controller),
      );
      expect(text.controller!.text, ' ');
    },
  );
  testWidgets(
    'German 392px 200 percent reaches both independent controls above simulated keyboard',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f, locale: 'de', width: 392, scale: 2, keyboard: 300);
      await tester.tap(card(f.one.id));
      await flush(tester, f);
      await tester.enterText(field(f.one.id), ' ');
      await tester.pumpAndSettle();
      for (final action in [finish(f.one.id), discard(f.one.id)]) {
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final rect = tester.getRect(action);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(700));
        expect(rect.right, lessThanOrEqualTo(392));
      }
      await tester.tap(discard(f.one.id));
      await flush(tester, f);
      expect(field(f.one.id), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
