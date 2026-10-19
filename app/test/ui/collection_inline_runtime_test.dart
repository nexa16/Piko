import 'dart:async';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_route.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/vocabulary/inline_vocabulary_edit_controller.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';

class ObservedDatabase extends PikoDatabase {
  ObservedDatabase()
    : super(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
  int closeCalls = 0;
  final closed = Completer<void>();
  List<VocabularyEntry> finalRows = [];
  @override
  Future<void> close() async {
    closeCalls++;
    finalRows = await select(vocabularyEntries).get();
    await super.close();
    closed.complete();
  }
}

class GatedRepository implements VocabularyRepository {
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) =>
      real.captureOpeningSnapshot(entryId: entryId, collectionId: collectionId);
  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) => real.restoreOpeningSnapshot(snapshot);
  GatedRepository(this.real);
  final VocabularyRepository real;
  final gates = <Completer<void>>[];
  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) async {
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
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
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) =>
      real.watchByCollection(collectionId);
  @override
  Stream<VocabularyRecord?> watchById(String id) => real.watchById(id);
}

void main() {
  testWidgets(
    'F22 Hint and Example typing keep focus through the real runtime autosave',
    (tester) async {
      final db = ObservedDatabase();
      final collections = SqliteCollectionsRepository(db);
      final vocabulary = SqliteVocabularyRepository(db);
      final owner = (await tester.runAsync(
        () => collections.create(
          name: 'F22 synthetic',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        ),
      ))!;
      final entry = (await tester.runAsync(
        () => vocabulary.createWithContent(
          collectionId: owner.id,
          targetText: 'pomme',
          nativeText: 'Apfel',
          assignments: const {},
          content: const VocabularyContent(
            hintText: 'A fruit',
            examples: [
              ExamplePair(targetText: 'Une pomme.', nativeText: 'Ein Apfel.'),
            ],
          ),
        ),
      ))!;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
      await tester.pumpWidget(
        PikoApp(home: PikoRuntime(databaseFactory: () => db)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byKey(ValueKey('collection-${owner.id}')),
              matching: find.text(owner.name),
            )
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('vocabulary-${entry.id}')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(ValueKey('vocabulary-${entry.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('vocabulary-${entry.id}')));
      await tester.pumpAndSettle();
      final hint = find.byKey(const ValueKey('content-hint'));
      await tester.ensureVisible(hint);
      await tester.tap(hint);
      await tester.enterText(hint, 'B');
      await tester.pumpAndSettle();
      final edit = find.descendant(
        of: hint,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(edit).focusNode.hasFocus, isTrue);
      expect(tester.widget<EditableText>(edit).controller.text, 'B');
      await tester.enterText(hint, 'BC');
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(edit).focusNode.hasFocus, isTrue);
      expect(tester.widget<EditableText>(edit).controller.text, 'BC');
      final example = find.byKey(const ValueKey('content-example-native'));
      await tester.ensureVisible(example);
      await tester.tap(example);
      await tester.enterText(example, 'E');
      await tester.pumpAndSettle();
      final exampleEdit = find.descendant(
        of: example,
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(exampleEdit).focusNode.hasFocus,
        isTrue,
      );
      await tester.enterText(example, 'Ein Beispiel.');
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(exampleEdit).focusNode.hasFocus,
        isTrue,
      );
      expect(
        tester.widget<EditableText>(exampleEdit).controller.text,
        'Ein Beispiel.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual Collection row expands without allocating add-entry session; Plus alone opens real route',
    (tester) async {
      final db = ObservedDatabase();
      final collections = SqliteCollectionsRepository(db);
      final vocabulary = SqliteVocabularyRepository(db);
      final owner = (await tester.runAsync(
        () => collections.create(
          name: 'Words',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        ),
      ))!;
      final entry = (await tester.runAsync(
        () => vocabulary.create(
          collectionId: owner.id,
          targetText: 'Café',
          nativeText: 'Kaffee',
        ),
      ))!;
      var calls = 0;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(db.close);
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: collections,
            collectionId: owner.id,
            vocabularyRepository: vocabulary,
            entrySessionFactory: (id) {
              calls++;
              final deletion = SqliteVocabularyDeletionService(db);
              return EntrySessionResources(
                session: EntrySessionController(
                  collectionId: id,
                  repository: vocabulary,
                  deletionService: deletion,
                  clock: db.clock,
                ),
                deletionService: deletion,
              );
            },
          ),
        ),
      );
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('vocabulary-${entry.id}')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      for (final side in ['target', 'native']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('inline-${entry.id}-$side')),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
      }
      expect(find.byType(EntrySessionScreen), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      final addEntry = find.byWidgetPredicate(
        (w) => w is PikoButton && w.label == 'New',
      );
      await tester.ensureVisible(addEntry);
      await tester.tap(addEntry);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(EntrySessionScreen), findsOneWidget);
    },
  );

  testWidgets(
    'runtime shutdown drains accepted queued editor writes before one DB close and absorbs registry failures',
    (tester) async {
      final db = ObservedDatabase();
      final real = SqliteVocabularyRepository(db);
      final owner = (await tester.runAsync(
        () => SqliteCollectionsRepository(db).create(
          name: 'Words',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        ),
      ))!;
      final entry = (await tester.runAsync(
        () => real.create(
          collectionId: owner.id,
          targetText: 'One',
          nativeText: 'Eins',
        ),
      ))!;
      await tester.pumpWidget(
        PikoApp(home: PikoRuntime(databaseFactory: () => db)),
      );
      await tester.pumpAndSettle();
      final register = tester
          .widget<CollectionsHome>(find.byType(CollectionsHome))
          .onPendingVocabularyWrites!;
      final repository = GatedRepository(real);
      final edits = await InlineVocabularyEditController.open(
        entryId: entry.id,
        collectionId: entry.collectionId,
        repository: repository,
      );
      edits.setTargetText('Accepted A');
      edits.setTargetText('Accepted B');
      register(edits.awaitSavedEdits());
      register(Future<void>.error(StateError('observed failure')));
      edits.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(db.closeCalls, 0);
      repository.gates.first.complete();
      await tester.runAsync(() async {
        while (repository.gates.length < 2) {
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(db.closeCalls, 0);
      repository.gates.last.complete();
      await tester.runAsync(() => db.closed.future);
      await tester.pump();
      expect(db.closeCalls, 1);
      expect(db.finalRows.single.targetText, 'Accepted B');
      expect(db.finalRows.single.id, entry.id);
      expect(tester.takeException(), isNull);
    },
  );
}
