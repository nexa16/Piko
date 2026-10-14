import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsAction;
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_route.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';

const owner = CollectionRecord(
  id: 'owner',
  name: 'Words',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);

class ObservedDeletion implements VocabularyDeletionService {
  ObservedDeletion(this.real, this.session);
  final VocabularyDeletionService real;
  final EntrySessionController session;
  bool disposed = false;
  @override
  void dispose() {
    // Route must end the controller before releasing its Undo issuer.
    expect(() => session.setTargetText('late'), throwsStateError);
    disposed = true;
    real.dispose();
  }

  @override
  Future<VocabularyDeletionReceipt> delete(String id) => real.delete(id);
  @override
  Future<VocabularyRecord> restore(VocabularyDeletionReceipt receipt) =>
      real.restore(receipt);
  @override
  bool canUndo(VocabularyDeletionReceipt receipt) => real.canUndo(receipt);
  @override
  void expireUndo() => real.expireUndo();
  @override
  void forget(VocabularyDeletionReceipt receipt) => real.forget(receipt);
}

class Fixture {
  Fixture(this.db);
  final PikoDatabase db;
  late final collections = SqliteCollectionsRepository(db);
  late final vocabulary = SqliteVocabularyRepository(db);
  final sessions = <EntrySessionController>[];
  final services = <ObservedDeletion>[];
  EntrySessionResources factory(String id) {
    final real = SqliteVocabularyDeletionService(db);
    final session = EntrySessionController(
      collectionId: id,
      repository: vocabulary,
      deletionService: real,
      clock: db.clock,
    );
    sessions.add(session);
    final observed = ObservedDeletion(real, session);
    services.add(observed);
    return EntrySessionResources(session: session, deletionService: observed);
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();
  }
}

PikoDatabase database([File? file]) => PikoDatabase(
  DatabaseConnection(
    file == null ? NativeDatabase.memory() : NativeDatabase(file),
    closeStreamsSynchronously: true,
  ),
);

Finder field(bool target) => find.descendant(
  of: find.byKey(ValueKey('draft-${target ? 'target' : 'native'}')),
  matching: find.byType(TextField),
);

class LiveCollections implements CollectionsRepository {
  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      throw UnimplementedError();
  final detail = StreamController<CollectionRecord?>.broadcast();
  @override
  Stream<CollectionRecord?> watchById(String id) => detail.stream;
  @override
  Stream<List<CollectionRecord>> watchAll() => Stream.value([owner]);
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets(
    'create, open, plus, confirm, complete and file reopen use actual owner and fresh session',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('piko-route-');
      final file = File('${dir.path}/fixture.sqlite');
      final f = Fixture(database(file));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(f.db.close);
        dir.deleteSync(recursive: true);
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionsHome(
            repository: f.collections,
            entrySessionFactory: f.factory,
          ),
        ),
      );
      await f.flush(tester);
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Owned words');
      await tester.tap(find.byType(DropdownButton<VocabularyLanguage>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('French').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create collection'));
      await tester.tap(find.text('Create collection'));
      await f.flush(tester);
      final records = await tester.runAsync(
        () => f.collections.watchAll().first,
      );
      final record = records!.single;
      await tester.tap(find.byKey(ValueKey('collection-${record.id}')));
      await f.flush(tester);
      final add = find.byTooltip('Add Entry');
      // A queued second activation of the same action cannot push another route.
      final activate = tester
          .widget<PikoIconButton>(
            find.ancestor(of: add, matching: find.byType(PikoIconButton)),
          )
          .onPressed!;
      await tester.tap(add);
      activate();
      await tester.pumpAndSettle();
      expect(f.sessions, hasLength(1));
      final screen = tester.widget<EntrySessionScreen>(
        find.byType(EntrySessionScreen),
      );
      expect(screen.collection.id, record.id);
      expect(screen.collection.targetLanguage, VocabularyLanguage.french);
      expect(screen.collection.nativeLanguage, VocabularyLanguage.german);
      await tester.enterText(field(true), ' pomme ');
      await tester.enterText(field(false), ' Apfel ');
      await tester.tap(find.byTooltip('Save & Next'));
      await f.flush(tester);
      expect(f.sessions.single.draft.targetText, isEmpty);
      expect(f.sessions.single.confirmedEntries, hasLength(1));
      await tester.enterText(field(true), 'poire');
      await tester.enterText(field(false), 'Birne');
      await tester.tap(find.byTooltip('Save last entry & end session'));
      await f.flush(tester);
      expect(find.byType(EntrySessionScreen), findsNothing);
      expect(f.services.single.disposed, isTrue);
      final saved = await tester.runAsync(
        () => f.vocabulary.watchByCollection(record.id).first,
      );
      expect(saved!.map((e) => e.targetText), ['pomme', 'poire']);
      expect(saved.every((e) => e.collectionId == record.id), isTrue);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(f.sessions, hasLength(2));
      expect(f.sessions.last.draft.targetText, isEmpty);
      expect(f.sessions.last.confirmedEntries, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(f.services.last.disposed, isTrue);
      // Back and route disposal did not close the caller's database.
      expect(
        await tester.runAsync(() => f.db.select(f.db.vocabularyEntries).get()),
        hasLength(2),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(f.db.close);
      final reopened = database(file);
      try {
        final retained = await tester.runAsync(
          () => SqliteVocabularyRepository(
            reopened,
          ).watchByCollection(record.id).first,
        );
        expect(retained!.map((e) => e.id), saved.map((e) => e.id));
        expect(retained.map((e) => e.nativeText), ['Apfel', 'Birne']);
      } finally {
        await tester.runAsync(reopened.close);
      }
    },
  );

  testWidgets(
    'loading, error with stale data and missing collection never offer Add Entry',
    (tester) async {
      final repo = LiveCollections();
      final f = Fixture(database());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await repo.detail.close();
        await tester.runAsync(f.db.close);
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: repo,
            collectionId: owner.id,
            entrySessionFactory: f.factory,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Entry'), findsNothing);
      repo.detail.add(owner);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Entry'), findsOneWidget);
      repo.detail.addError(StateError('read failed'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Entry'), findsNothing);
      repo.detail.add(null);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add Entry'), findsNothing);
      expect(f.sessions, isEmpty);
    },
  );

  testWidgets(
    'German normal-flow plus is 44px, semantic and keyboard accessible at 392px 200%',
    (tester) async {
      tester.view.physicalSize = const Size(392, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = LiveCollections();
      final f = Fixture(database());
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await repo.detail.close();
        await tester.runAsync(f.db.close);
      });
      await tester.pumpWidget(
        PikoApp(
          locale: const Locale('de'),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: CollectionDetail(
                repository: repo,
                collectionId: owner.id,
                entrySessionFactory: f.factory,
              ),
            ),
          ),
        ),
      );
      repo.detail.add(owner);
      await tester.pumpAndSettle();
      final add = find.byTooltip('Eintrag hinzufügen');
      final button = find.descendant(
        of: add,
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(button), const Size(44, 44));
      expect(find.text('Vokabeln'), findsOneWidget);
      final heading = tester.widget<Text>(find.text('Vokabeln'));
      expect(heading.style!.fontSize, 17);
      expect(heading.style!.fontWeight, FontWeight.w700);
      expect(
        tester.getRect(add).center.dy,
        closeTo(tester.getRect(find.text('Vokabeln')).center.dy, 1),
      );
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Eintrag hinzufügen'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Eintrag hinzufügen'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
      final focus = Focus.of(
        tester.element(
          find.descendant(of: button, matching: find.byType(Row)).first,
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(f.sessions, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'locale rebuild retains one route resource and raw draft until route removal',
    (tester) async {
      final f = Fixture(database());
      final locale = InterfaceLocaleController(const Locale('en'));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        locale.dispose();
        await tester.runAsync(f.db.close);
      });
      await tester.pumpWidget(
        PikoApp(
          localeController: locale,
          home: EntrySessionRoute(collection: owner, factory: f.factory),
        ),
      );
      f.sessions.single.setTargetText('  é  ');
      await tester.pumpAndSettle();
      locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(f.sessions, hasLength(1));
      expect(f.sessions.single.draft.targetText, '  é  ');
      expect(f.services.single.disposed, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(f.services.single.disposed, isTrue);
    },
  );
}
