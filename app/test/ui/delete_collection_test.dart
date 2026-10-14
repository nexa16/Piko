import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import '../support/collection_deletion_fixture.dart';
import '../support/entry_deletion_fixture.dart' show GatedEntryRepository;

class ControlledCollections implements CollectionsRepository {
  ControlledCollections(this.real);
  final CollectionsRepository real;
  Completer<void>? gate;
  bool fail = false;
  int deletes = 0;
  @override
  Future<void> delete(String id) async {
    deletes++;
    await gate?.future;
    if (fail) throw StateError('Deletion failed');
    await real.delete(id);
  }

  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      real.rename(id: id, name: name);
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

class ControlledVocabulary extends GatedEntryRepository {
  ControlledVocabulary(super.real);
  Completer<void>? captureGate, restoreGate;
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) async {
    await captureGate?.future;
    return super.captureOpeningSnapshot(
      entryId: entryId,
      collectionId: collectionId,
    );
  }

  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) async {
    await restoreGate?.future;
    return super.restoreOpeningSnapshot(snapshot);
  }
}

Finder button(String label) =>
    find.byWidgetPredicate((w) => w is PikoButton && w.label == label);
Finder deletion() => button('Delete collection');
Finder confirm() =>
    find.descendant(of: find.byType(PikoDialog), matching: deletion());
Finder field(String id) => find.descendant(
  of: find.byKey(ValueKey('inline-$id-target')),
  matching: find.byType(TextField),
);
Future<void> flush(WidgetTester tester, CollectionDeletionFixture f) async {
  await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  CollectionDeletionFixture f,
  ControlledCollections repository, {
  VocabularyRepository? vocabulary,
  String locale = 'en',
  double width = 760,
  double scale = 1,
  double keyboard = 0,
  ValueChanged<Future<void>>? onPending,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(f.mutations.isBusy, isFalse);
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
          child: CollectionsHome(
            repository: repository,
            vocabularyRepository: vocabulary ?? f.repository,
            vocabularyMutationsFactory: (_) => f.mutations,
            onPendingVocabularyWrites: onPending,
          ),
        ),
      ),
    ),
  );
  await flush(tester, f);
  await tester.tap(find.byKey(ValueKey('collection-${f.owner.id}')));
  await flush(tester, f);
}

Future<void> openConfirmation(WidgetTester tester) async {
  await tester.tap(deletion());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('accepted Discard drains before confirmed Collection cascade', (
    tester,
  ) async {
    final f = CollectionDeletionFixture();
    await tester.runAsync(f.initialize);
    final vocabulary = ControlledVocabulary(f.real),
        repository = ControlledCollections(f.collections);
    await mount(tester, f, repository, vocabulary: vocabulary);
    final id = f.entries[0].id;
    await tester.tap(find.byKey(ValueKey('vocabulary-$id')));
    await flush(tester, f);
    await tester.enterText(field(id), 'Changed');
    await flush(tester, f);
    final gate = Completer<void>();
    vocabulary.restoreGate = gate;
    await tester.tap(find.byKey(ValueKey('inline-discard-$id')));
    await tester.pump();
    await openConfirmation(tester);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(repository.deletes, 0);
    gate.complete();
    await flush(tester, f);
    expect(repository.deletes, 1);
    expect(find.byType(CollectionDetail), findsNothing);
  });
  testWidgets(
    'in-flight opening capture drains but cannot expose a new editor during destructive freeze',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final vocabulary = ControlledVocabulary(f.real),
          repository = ControlledCollections(f.collections);
      await mount(tester, f, repository, vocabulary: vocabulary);
      final gate = Completer<void>();
      vocabulary.captureGate = gate;
      await tester.tap(find.byKey(ValueKey('vocabulary-${f.entries[0].id}')));
      await tester.pump();
      await openConfirmation(tester);
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
      expect(find.byType(TextField), findsNothing);
      gate.complete();
      await flush(tester, f);
      expect(repository.deletes, 1);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets(
    'target replacement closes only owned dialog, including replacement before first dialog build',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final repository = ControlledCollections(f.collections);
      final other = (await tester.runAsync(
        () => f.collections.create(
          name: 'Other',
          targetLanguage: f.owner.targetLanguage,
          nativeLanguage: f.owner.nativeLanguage,
        ),
      ))!;
      final identity = ValueNotifier(f.owner.id);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        identity.dispose();
        await tester.runAsync(f.dispose);
      });
      await tester.pumpWidget(
        PikoApp(
          home: ValueListenableBuilder<String>(
            valueListenable: identity,
            builder: (_, id, _) => CollectionDetail(
              repository: repository,
              collectionId: id,
              vocabularyRepository: f.repository,
            ),
          ),
        ),
      );
      await flush(tester, f);
      await openConfirmation(tester);
      final stale = tester.widget<PikoButton>(confirm()).onPressed!;
      final staleClose = tester
          .widget<PikoIconButton>(
            find.byWidgetPredicate(
              (w) => w is PikoIconButton && w.semanticLabel == 'Close',
            ),
          )
          .onPressed!;
      identity.value = other.id;
      await flush(tester, f);
      expect(find.byType(PikoDialog), findsNothing);
      stale();
      staleClose();
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsOneWidget);
      expect(repository.deletes, 0);
      tester.widget<PikoButton>(deletion()).onPressed!();
      identity.value = f.owner.id;
      await flush(tester, f);
      expect(find.byType(PikoDialog), findsNothing);
      expect(repository.deletes, 0);
    },
  );
  testWidgets(
    'disposing owner under a covered confirmation removes its dialog but never the covering route',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final repository = ControlledCollections(f.collections);
      await mount(tester, f, repository);
      await openConfirmation(tester);
      final ownerRoute = ModalRoute.of(
        tester.element(find.byType(CollectionDetail)),
      )!;
      final navigator = ownerRoute.navigator!;
      final stale = tester.widget<PikoButton>(confirm()).onPressed!;
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Other route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.removeRoute(ownerRoute);
      await tester.pumpAndSettle();
      expect(find.text('Other route'), findsOneWidget);
      expect(find.byType(PikoDialog, skipOffstage: false), findsNothing);
      stale();
      await tester.pumpAndSettle();
      expect(find.text('Other route'), findsOneWidget);
      expect(repository.deletes, 0);
    },
  );
  testWidgets(
    'accepted database delete survives owner disposal and its runtime callback drains without late pop or error',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final repository = ControlledCollections(f.collections)
        ..gate = Completer<void>();
      var accepted = 0, completed = 0;
      await mount(
        tester,
        f,
        repository,
        onPending: (work) {
          accepted++;
          unawaited(
            work.then<void>(
              (_) => completed++,
              onError: (Object _, StackTrace _) => completed++,
            ),
          );
        },
      );
      await openConfirmation(tester);
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(repository.deletes, 1);
      expect(accepted, greaterThan(0));
      final ownerRoute = ModalRoute.of(
            tester.element(find.byType(CollectionDetail)),
          )!,
          navigator = Navigator.of(
            tester.element(find.byType(CollectionDetail)),
          );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Other route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.removeRoute(ownerRoute);
      await tester.pumpAndSettle();
      repository.gate!.complete();
      await flush(tester, f);
      expect(find.text('Other route'), findsOneWidget);
      expect(completed, accepted);
      expect(
        (await tester.runAsync(
          () => f.collections.watchById(f.owner.id).first,
        )),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'every safe dismissal and repeated opener preserve Collection vocabulary/progress without deleting',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final repository = ControlledCollections(f.collections);
      await mount(tester, f, repository);
      for (final mode in ['x', 'escape', 'backdrop', 'system']) {
        final open = tester.widget<PikoButton>(deletion()).onPressed!;
        open();
        open();
        await tester.pumpAndSettle();
        expect(find.byType(PikoDialog), findsOneWidget);
        expect(
          find.text(
            'Delete Words? Its vocabulary and learning progress will also be deleted. This cannot be undone.',
          ),
          findsOneWidget,
        );
        if (mode == 'x') {
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is PikoIconButton && w.semanticLabel == 'Close',
            ),
          );
        } else if (mode == 'escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else if (mode == 'backdrop') {
          await tester.tapAt(const Offset(1, 1));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(repository.deletes, 0);
        expect(find.byType(CollectionDetail), findsOneWidget);
      }
      expect(
        (await tester.runAsync(
          () => f.real.watchByCollection(f.owner.id).first,
        ))!.length,
        3,
      );
      expect(
        (await tester.runAsync(
          () => f.db.select(f.db.learningItems).get(),
        ))!.length,
        6,
      );
    },
  );
  testWidgets(
    'duplicate names delete only captured UUID; stale confirm and X cannot pop Detail while storage is pending',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final other = (await tester.runAsync(
        () => f.collections.create(
          name: f.owner.name,
          targetLanguage: f.owner.targetLanguage,
          nativeLanguage: f.owner.nativeLanguage,
        ),
      ))!;
      final repository = ControlledCollections(f.collections)
        ..gate = Completer<void>();
      await mount(tester, f, repository);
      await openConfirmation(tester);
      final action = tester.widget<PikoButton>(confirm()).onPressed!;
      final close = tester
          .widget<PikoIconButton>(
            find.byWidgetPredicate(
              (w) => w is PikoIconButton && w.semanticLabel == 'Close',
            ),
          )
          .onPressed!;
      action();
      action();
      close();
      await tester.pumpAndSettle();
      expect(repository.deletes, 1);
      expect(find.byType(CollectionDetail), findsOneWidget);
      repository.gate!.complete();
      await flush(tester, f);
      expect(find.byType(CollectionDetail), findsNothing);
      expect(find.byKey(ValueKey('collection-${f.owner.id}')), findsNothing);
      expect(find.byKey(ValueKey('collection-${other.id}')), findsOneWidget);
    },
  );
  testWidgets(
    'confirmation freezes invalid/raw fields and drains accepted A/B saves before cascade',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final repository = ControlledCollections(f.collections);
      await mount(tester, f, repository);
      final id = f.entries[0].id;
      await tester.tap(find.byKey(ValueKey('vocabulary-$id')));
      await flush(tester, f);
      final gate = Completer<void>();
      f.repository.updateGates[id] = gate;
      await tester.enterText(field(id), 'A');
      await tester.enterText(field(id), 'B');
      await tester.enterText(field(id), ' ');
      await openConfirmation(tester);
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
      expect(tester.widget<TextField>(field(id)).enabled, isFalse);
      expect(tester.widget<TextField>(field(id)).controller!.text, ' ');
      gate.complete();
      await flush(tester, f);
      expect(repository.deletes, 1);
      expect(find.byType(CollectionDetail), findsNothing);
      expect(
        (await tester.runAsync(() => f.db.select(f.db.learningItems).get()))!,
        isEmpty,
      );
    },
  );
  testWidgets(
    'pending vocabulary Undo drains without early Collection deletion',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final vocabulary = ControlledVocabulary(f.real);
      final repository = ControlledCollections(f.collections);
      await mount(tester, f, repository, vocabulary: vocabulary);
      final id = f.entries[0].id;
      await tester.tap(find.byKey(ValueKey('vocabulary-$id')));
      await flush(tester, f);
      await tester.enterText(field(id), 'Changed');
      await flush(tester, f);
      await tester.runAsync(() => f.mutations.delete(f.entries[2]));
      await tester.pumpAndSettle();
      final undoGate = Completer<void>();
      f.deletion.restoreGate = undoGate;
      await tester.tap(button('Undo'));
      await tester.pump();
      await openConfirmation(tester);
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
      undoGate.complete();
      await flush(tester, f);
      expect(repository.deletes, 1);
      expect(find.byType(CollectionDetail), findsNothing);
    },
  );
  testWidgets(
    'failed delete unlocks same invalid raw selection/focus and retains Undo deadline for retry',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await tester.runAsync(() => f.mutations.delete(f.entries[2]));
      final offer = f.mutations.latest!, deadline = offer.receipt.expiresAt;
      final repository = ControlledCollections(f.collections)..fail = true;
      await mount(tester, f, repository);
      final id = f.entries[0].id;
      await tester.tap(find.byKey(ValueKey('vocabulary-$id')));
      await flush(tester, f);
      await tester.enterText(field(id), '  ');
      final text = tester.widget<TextField>(field(id));
      text.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 1,
      );
      await openConfirmation(tester);
      await tester.tap(confirm());
      await flush(tester, f);
      expect(
        find.text("Couldn't delete this collection. Please try again."),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field(id)).controller,
        same(text.controller),
      );
      expect(text.controller!.text, '  ');
      expect(
        text.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(text.focusNode!.hasFocus, isTrue);
      expect(f.mutations.latest, same(offer));
      expect(offer.receipt.expiresAt, deadline);
      repository.fail = false;
      await openConfirmation(tester);
      await tester.tap(confirm());
      await flush(tester, f);
      expect(find.byType(CollectionDetail), findsNothing);
    },
  );
  testWidgets(
    'accepted delete covered by another route never pops or focuses that route after commit',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final repository = ControlledCollections(f.collections)
        ..gate = Completer<void>();
      await mount(tester, f, repository);
      await openConfirmation(tester);
      await tester.tap(confirm());
      await tester.pumpAndSettle();
      final navigator = Navigator.of(
        tester.element(find.byType(CollectionDetail)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Other route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repository.gate!.complete();
      await flush(tester, f);
      expect(find.text('Other route'), findsOneWidget);
      expect(navigator.canPop(), isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(
        find.text('This collection is no longer available.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'German 392px 200 percent confirmation explicitly names vocabulary/progress with reachable safe actions',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final repository = ControlledCollections(f.collections);
      await mount(
        tester,
        f,
        repository,
        locale: 'de',
        width: 392,
        scale: 2,
        keyboard: 300,
      );
      await tester.ensureVisible(button('Sammlung löschen'));
      await tester.tap(button('Sammlung löschen'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Words löschen? Die Vokabeln und der Lernfortschritt werden ebenfalls gelöscht. Dies kann nicht rückgängig gemacht werden.',
        ),
        findsOneWidget,
      );
      final positive = find.descendant(
        of: find.byType(PikoDialog),
        matching: button('Sammlung löschen'),
      );
      await tester.ensureVisible(positive);
      await tester.pumpAndSettle();
      expect(tester.getRect(positive).bottom, lessThanOrEqualTo(700));
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
    },
  );
}
