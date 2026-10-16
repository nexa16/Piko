import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'json_import_test.dart' show confirmJson;
import 'json_transfer_test.dart' show JsonTestPlatform, pressJson;
import 'review_launch_test.dart' show ClosingDatabase;

Future<void> flush(WidgetTester tester, ClosingDatabase db) async {
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language runtime entry JSON route preserves incomplete draft and refreshes saved cards without replacing invalid raw edits',
      (tester) async {
        final db = ClosingDatabase();
        final platform = JsonTestPlatform();
        try {
          final collection = (await tester.runAsync(() async {
            await SqliteSettingsRepository(db).write('locale', language);
            return SqliteCollectionsRepository(db).create(
              name: 'Portable words',
              targetLanguage: VocabularyLanguage.french,
              nativeLanguage: VocabularyLanguage.german,
            );
          }))!;
          await tester.pumpWidget(
            PikoApp(
              home: PikoRuntime(
                databaseFactory: () => db,
                jsonPlatform: platform,
              ),
            ),
          );
          for (
            var frame = 0;
            frame < 10 && find.byType(CollectionsHome).evaluate().isEmpty;
            frame++
          ) {
            await flush(tester, db);
          }
          expect(find.byType(CollectionsHome), findsOneWidget);
          await tester.tap(find.byKey(ValueKey('collection-${collection.id}')));
          await flush(tester, db);
          await tester.tap(
            find.byTooltip(PikoCopy(language).text('action.addEntry')),
          );
          await tester.pumpAndSettle();
          final session = tester
              .widget<EntrySessionScreen>(find.byType(EntrySessionScreen))
              .session;
          session.setTargetText('One');
          session.setNativeText('Eins');
          final first = session.confirmAndNext();
          await flush(tester, db);
          expect(session.isConfirming, isFalse);
          session.setTargetText('Two');
          session.setNativeText('Zwei');
          final second = session.confirmAndNext();
          await flush(tester, db);
          expect(session.isConfirming, isFalse);
          final entries = [await first, await second];
          await flush(tester, db);
          session.selectSavedEntry(entries.last.id);
          session.editSavedEntry(entries.last.id, targetText: ' ');
          session.setTargetText(' Incomplete raw draft ');
          final rawDraft = session.draft;
          final invalidBuffer = session.savedEntryState(entries.last.id).draft;
          final learning = (await tester.runAsync(
            () => db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get(),
          ))!.map((row) => row.data).toList();
          expect(learning, hasLength(4));
          platform.file = jsonEncode({
            'format': 'piko-vocabulary',
            'schemaVersion': 1,
            'collections': [
              {
                'targetLanguage': 'fr',
                'nativeLanguage': 'de',
                'entries': [
                  {
                    'id': entries.first.id,
                    'targetText': 'Imported one',
                    'nativeText': 'Importiert eins',
                  },
                  {
                    'id': entries.last.id,
                    'targetText': 'Imported two',
                    'nativeText': 'Importiert zwei',
                  },
                  {
                    'targetText': 'Imported new',
                    'nativeText': 'Importiert neu',
                  },
                ],
              },
            ],
          });
          await tester.pumpAndSettle();
          final open = find.text(PikoCopy(language).text('json.title'));
          await tester.ensureVisible(open);
          await tester.tap(open);
          await flush(tester, db);
          expect(find.byType(VocabularyJsonPage), findsOneWidget);
          await pressJson(tester, 'json.file', language: language);
          await pressJson(tester, 'json.analyze', language: language);
          await flush(tester, db);
          await pressJson(tester, 'json.apply', language: language);
          await confirmJson(tester, language);
          await flush(tester, db);
          await pressJson(tester, 'common.back', language: language);
          await flush(tester, db);
          expect(find.text(PikoCopy(language).text('entry.exitTitle')), findsOneWidget);
          await pressJson(tester, 'entry.continue', language: language);
          await flush(tester, db);
          final returned = tester
              .widget<EntrySessionScreen>(find.byType(EntrySessionScreen))
              .session;
          expect(returned, same(session));
          expect(session.draft, same(rawDraft));
          expect(session.draft.nativeText, isEmpty);
          expect(session.confirmedEntries, hasLength(2));
          expect(
            session.savedEntryState(entries.first.id).draft.targetText,
            'Imported one',
          );
          final invalid = session.savedEntryState(entries.last.id);
          expect(invalid.draft, same(invalidBuffer));
          expect(invalid.draft.targetText, ' ');
          expect(invalid.draft.nativeText, 'Zwei');
          expect(invalid.error, VocabularyValidation.requiredTarget);
          expect(invalid.committed.targetText, 'Imported two');
          final target = find.descendant(
            of: find.byKey(ValueKey('${entries.last.id}-target')),
            matching: find.byType(TextField),
          );
          expect(tester.widget<TextField>(target).controller!.text, ' ');
          final rows = (await tester.runAsync(
            () => SqliteVocabularyRepository(
              db,
            ).watchByCollection(collection.id).first,
          ))!;
          expect(rows, hasLength(3));
          expect(rows.last.targetText, 'Imported new');
          final after = (await tester.runAsync(
            () => db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get(),
          ))!.map((row) => row.data).toList();
          expect(after.take(4).toList(), learning);
          expect(after, hasLength(6));
          // Returning to Collection is explicit and still protects the raw draft.
          await tester.ensureVisible(open);
          await tester.tap(open);
          await flush(tester, db);
          await pressJson(tester, 'common.back', language: language);
          await flush(tester, db);
          await pressJson(tester, 'entry.discard', language: language);
          await flush(tester, db);
          expect(find.byType(VocabularyJsonPage), findsNothing);
          expect(find.byType(EntrySessionScreen), findsNothing);
          expect(find.byType(CollectionDetail), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          for (var frame = 0; frame < 20 && !db.closed.isCompleted; frame++) {
            await tester.pump();
            await tester.runAsync(() async {
              await Future<void>.delayed(Duration.zero);
            });
          }
          expect(db.closed.isCompleted, isTrue);
        }
      },
    );
  }
}
