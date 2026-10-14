import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_normalization.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

/// VOCAB-EDIT-002 acceptance. Every database connection is explicitly injected
/// from this newly created fixture file; the production piko database is unused.
class InlineFixtureDatabase extends PikoDatabase {
  InlineFixtureDatabase(File file) : super(NativeDatabase(file));
  final closed = Completer<void>();
  bool _closing = false;

  @override
  Future<void> close() async {
    if (_closing) return closed.future;
    _closing = true;
    try {
      await super.close();
      closed.complete();
    } catch (error, stack) {
      closed.completeError(error, stack);
      rethrow;
    }
  }
}

Finder field(String id, String side) => find.descendant(
  of: find.byKey(ValueKey('inline-$id-$side')),
  matching: find.byType(TextField),
);
Finder finish(String id) => find.byKey(ValueKey('inline-complete-$id'));
Finder discard(String id) => find.byKey(ValueKey('inline-discard-$id'));

Future<void> waitUntil(
  WidgetTester tester,
  FutureOr<bool> Function() ready,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (await ready()) return;
  }
  throw StateError('Isolated inline-edit fixture did not become ready');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await waitUntil(tester, () => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Future<Map<String, Object?>> snapshot(PikoDatabase db) => db.transaction(
  () async {
    final result = <String, Object?>{};
    for (final table in db.allTables) {
      final name = table.actualTableName;
      result[name] =
          (await db
                  .customSelect(
                    'SELECT rowid AS stored_rowid, * FROM $name ORDER BY rowid',
                  )
                  .get())
              .map((row) => row.data)
              .toList();
    }
    result['schema'] =
        (await db.customSelect('PRAGMA user_version').getSingle()).data;
    return result;
  },
);

Map<String, Object?> changedPair(
  Map<String, Object?> original,
  String id,
  String target,
  String native,
) => {
  ...original,
  'vocabulary_entries': [
    for (final row in (original['vocabulary_entries'] as List).cast<Map>())
      if (row['id'] == id)
        {
          ...row,
          'target_text': target,
          'native_text': native,
          'target_key': vocabularyComparisonKey(target),
          'native_key': vocabularyComparisonKey(native),
        }
      else
        row,
  ],
};

Future<void> waitForStoredPair(
  WidgetTester tester,
  PikoDatabase db,
  String id,
  String target,
  String native,
) => waitUntil(tester, () async {
  final row = await (db.select(
    db.vocabularyEntries,
  )..where((row) => row.id.equals(id))).getSingle();
  return row.targetText == target && row.nativeText == native;
});

Future<void> expectControl(
  WidgetTester tester,
  Finder finder,
  String label,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final control = tester.widget<PikoIconButton>(finder);
  expect(control.semanticLabel, label);
  expect(control.onPressed, isNotNull);
  expect(tester.getSemantics(finder).label, label);
  final rect = tester.getRect(finder);
  final media = MediaQuery.of(tester.element(find.byType(CollectionDetail)));
  expect(rect.width, greaterThanOrEqualTo(44));
  expect(rect.height, greaterThanOrEqualTo(44));
  expect(rect.left, greaterThanOrEqualTo(media.padding.left));
  expect(rect.right, lessThanOrEqualTo(media.size.width - media.padding.right));
  expect(rect.top, greaterThanOrEqualTo(media.padding.top));
  expect(
    rect.bottom,
    lessThanOrEqualTo(media.size.height - media.viewInsets.bottom),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'de']) {
    testWidgets(
      'Android $language runtime inline autosave, invalid Finish and exact opening Discard preserve identity/order/full directional state',
      (tester) async {
        expect(binding.registerTestTextInput, isFalse);
        final support = await getApplicationSupportDirectory();
        final directory = await support.createTemp(
          'piko-inline-edit-verification-',
        );
        final file = File('${directory.path}/test.sqlite');
        final db = InlineFixtureDatabase(file);
        PikoDatabase? reopened;
        var runtimeMounted = false;
        final semantics = tester.ensureSemantics();
        try {
          final owner = await SqliteCollectionsRepository(db).create(
            name: 'Inline Android $language',
            targetLanguage: VocabularyLanguage.french,
            nativeLanguage: VocabularyLanguage.german,
          );
          final vocabulary = SqliteVocabularyRepository(db);
          await vocabulary.create(
            collectionId: owner.id,
            targetText: 'Avant',
            nativeText: 'Vorher',
          );
          final entry = await vocabulary.create(
            collectionId: owner.id,
            targetText: 'Café',
            nativeText: 'Kaffee',
          );
          await vocabulary.create(
            collectionId: owner.id,
            targetText: 'École',
            nativeText: 'Schule',
          );
          // Explicit legacy-format fixture: Discard must restore actual stored
          // opening bytes, including whitespace and decomposed text.
          const originalTarget = '  Cafe\u0301  ',
              originalNative = '  Kaffee  ';
          await db.customStatement(
            'UPDATE vocabulary_entries SET target_text = ?, native_text = ? WHERE id = ?',
            [originalTarget, originalNative, entry.id],
          );
          final learning = SqliteLearningRepository(db);
          final items = await learning.forEntry(entry.id);
          expect(items, hasLength(2));
          for (var index = 0; index < items.length; index++) {
            // Divergent stored memory is fixture preparation, not a review claim.
            final instant = DateTime.utc(2026, 10, 14, 9);
            await learning.saveCard(
              items[index].id,
              fsrs.Card(
                cardId: items[index].id,
                state: fsrs.State.review,
                stability: 3.125 + index,
                difficulty: 5.625 - index,
                due: instant.add(Duration(days: 4 + index)),
                lastReview: instant.subtract(Duration(days: index)),
              ),
            );
          }
          await SqliteSettingsRepository(db).write('locale', language);
          final original = await snapshot(db);
          runtimeMounted = true;
          await tester.pumpWidget(
            PikoApp(home: PikoRuntime(databaseFactory: () => db)),
          );
          final copy = await hydratedRuntimeCopy(tester);
          expect(copy.locale, language);
          await tapVisible(
            tester,
            find.byKey(ValueKey('collection-${owner.id}')),
          );
          await waitUntil(
            tester,
            () => find
                .byKey(ValueKey('vocabulary-${entry.id}'))
                .evaluate()
                .isNotEmpty,
          );
          expect(find.byType(CollectionDetail), findsOneWidget);

          // Open through the stored Collection row, then edit both real fields.
          await tapVisible(
            tester,
            find.byKey(ValueKey('vocabulary-${entry.id}')),
          );
          await waitUntil(
            tester,
            () => field(entry.id, 'target').evaluate().isNotEmpty,
          );
          expect(
            tester
                .widget<TextField>(field(entry.id, 'target'))
                .controller!
                .text,
            originalTarget,
          );
          expect(
            tester
                .widget<TextField>(field(entry.id, 'native'))
                .controller!
                .text,
            originalNative,
          );
          expect(discard(entry.id), findsNothing);
          await expectControl(
            tester,
            finish(entry.id),
            copy.text('vocab.inlineCollapse'),
          );
          await tester.ensureVisible(field(entry.id, 'target'));
          await tester.tap(field(entry.id, 'target'));
          await waitUntil(
            tester,
            () =>
                MediaQuery.viewInsetsOf(
                  tester.element(find.byType(CollectionDetail)),
                ).bottom >
                0,
          );
          await enter(
            tester,
            field(entry.id, 'target'),
            '  Nouvelle e\u0301cole  ',
          );
          await enter(
            tester,
            field(entry.id, 'native'),
            '  Geänderte Schule  ',
          );
          await waitForStoredPair(
            tester,
            db,
            entry.id,
            'Nouvelle école',
            'Geänderte Schule',
          );
          final edited = changedPair(
            original,
            entry.id,
            'Nouvelle école',
            'Geänderte Schule',
          );
          expect(await snapshot(db), edited);
          await expectControl(
            tester,
            finish(entry.id),
            copy.text('vocab.inlineFinish'),
          );
          await expectControl(
            tester,
            discard(entry.id),
            copy.text('vocab.inlineDiscard'),
          );

          // Incomplete raw input remains visible and cannot replace valid storage
          // or finish; explicit Discard still restores the exact opening pair.
          await enter(tester, field(entry.id, 'target'), '   ');
          expect(find.text(copy.text('entry.requiredTarget')), findsOneWidget);
          expect(await snapshot(db), edited);
          await tapVisible(tester, finish(entry.id));
          expect(field(entry.id, 'target'), findsOneWidget);
          expect(
            tester
                .widget<TextField>(field(entry.id, 'target'))
                .controller!
                .text,
            '   ',
          );
          expect(await snapshot(db), edited);
          await tapVisible(tester, discard(entry.id));
          await waitUntil(
            tester,
            () => field(entry.id, 'target').evaluate().isEmpty,
          );
          expect(await snapshot(db), original);

          // A separate opening commits both auto-saved edits through Finish.
          await tapVisible(
            tester,
            find.byKey(ValueKey('vocabulary-${entry.id}')),
          );
          await waitUntil(
            tester,
            () => field(entry.id, 'target').evaluate().isNotEmpty,
          );
          await enter(tester, field(entry.id, 'target'), '  Café fini  ');
          await enter(tester, field(entry.id, 'native'), '  Fertiger Kaffee  ');
          await waitForStoredPair(
            tester,
            db,
            entry.id,
            'Café fini',
            'Fertiger Kaffee',
          );
          final finished = changedPair(
            original,
            entry.id,
            'Café fini',
            'Fertiger Kaffee',
          );
          expect(await snapshot(db), finished);
          await expectControl(
            tester,
            finish(entry.id),
            copy.text('vocab.inlineFinish'),
          );
          await tapVisible(tester, finish(entry.id));
          await waitUntil(
            tester,
            () => field(entry.id, 'target').evaluate().isEmpty,
          );
          expect(await snapshot(db), finished);

          // Duplicate pair is a distinct invalid case. Its last valid intermediate
          // autosave is retained, and Discard restores this opening's final pair.
          await tapVisible(
            tester,
            find.byKey(ValueKey('vocabulary-${entry.id}')),
          );
          await waitUntil(
            tester,
            () => field(entry.id, 'target').evaluate().isNotEmpty,
          );
          await enter(tester, field(entry.id, 'target'), 'École');
          await waitForStoredPair(
            tester,
            db,
            entry.id,
            'École',
            'Fertiger Kaffee',
          );
          final beforeDuplicate = changedPair(
            original,
            entry.id,
            'École',
            'Fertiger Kaffee',
          );
          await enter(tester, field(entry.id, 'native'), 'Schule');
          await waitUntil(
            tester,
            () => find
                .text(copy.text('vocab.inlineDuplicate'))
                .evaluate()
                .isNotEmpty,
          );
          expect(await snapshot(db), beforeDuplicate);
          await tapVisible(tester, finish(entry.id));
          expect(
            tester
                .widget<TextField>(field(entry.id, 'native'))
                .controller!
                .text,
            'Schule',
          );
          expect(await snapshot(db), beforeDuplicate);
          await tapVisible(tester, discard(entry.id));
          await waitUntil(
            tester,
            () => field(entry.id, 'target').evaluate().isEmpty,
          );
          expect(await snapshot(db), finished);
          expect(tester.takeException(), isNull);

          // Production runtime owns/drains/closes its injected file exactly once.
          await tester.pumpWidget(const SizedBox());
          await db.closed.future.timeout(const Duration(seconds: 10));
          runtimeMounted = false;
          reopened = PikoDatabase(NativeDatabase(file));
          expect(await snapshot(reopened), finished);
          await reopened.close();
          reopened = null;
        } finally {
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
          if (runtimeMounted) {
            await db.closed.future.timeout(const Duration(seconds: 10));
          } else {
            await db.close();
          }
          await reopened?.close();
          // Never delete support/root or any pre-existing path; only this exact
          // newly created fixture subdirectory, after every connection closes.
          if (directory.parent.absolute.path != support.absolute.path ||
              !directory.uri.pathSegments
                  .where((part) => part.isNotEmpty)
                  .last
                  .startsWith('piko-inline-edit-verification-')) {
            throw StateError('Refusing cleanup outside owned inline fixture');
          }
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
