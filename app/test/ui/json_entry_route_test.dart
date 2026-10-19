import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_search_field.dart';
import 'package:piko/features/entry/entry_session_route.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_form.dart';
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
      '$language Add/Import and menu share a popup retaining raw JSON, choices and expansion across reopening',
      (tester) async {
        final db = ClosingDatabase(),
            platform = JsonTestPlatform(),
            copy = PikoCopy(language);
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
            var i = 0;
            i < 10 && find.byType(CollectionsHome).evaluate().isEmpty;
            i++
          ) {
            await flush(tester, db);
          }
          await tester.tap(find.byKey(ValueKey('collection-${collection.id}')));
          await flush(tester, db);
          final addFirst = find.byKey(const ValueKey('collection-empty-add'));
          final explanation = find.text(copy.text('collection.empty'));
          final heading = find.text(copy.text('collection.vocabulary'));
          expect(addFirst, findsOneWidget);
          expect(explanation, findsOneWidget);
          expect(find.byType(CollectionSearchField), findsNothing);
          expect(
            find.byKey(const ValueKey('collection-filters')),
            findsNothing,
          );
          expect(
            tester.getRect(explanation).top,
            greaterThanOrEqualTo(tester.getRect(heading).bottom),
          );
          expect(
            tester.getRect(addFirst).top,
            greaterThanOrEqualTo(tester.getRect(explanation).bottom),
          );
          expect(
            tester.widget<PikoButton>(addFirst).variant,
            PikoButtonVariant.primary,
          );
          final beforeLearning = await tester.runAsync(
            () async =>
                (await db.customSelect('SELECT * FROM learning_items').get())
                    .map((r) => r.data)
                    .toList(),
          );
          await tester.tap(addFirst);
          await tester.pumpAndSettle();
          expect(find.text(copy.text('entry.methodManual')), findsOneWidget);
          expect(find.text(copy.text('entry.methodJson')), findsOneWidget);
          expect(find.text(copy.text('entry.methodAi')), findsNothing);
          await tester.tap(find.byTooltip(copy.text('common.close')));
          await flush(tester, db);
          await tester.tap(addFirst);
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(
              PikoNavigationRow,
              copy.text('entry.methodManual'),
            ),
          );
          await flush(tester, db);
          expect(find.byType(EntrySessionRoute), findsOneWidget);
          await tester.binding.handlePopRoute();
          await flush(tester, db);
          expect(find.byType(EntrySessionRoute), findsNothing);
          expect(
            (await tester.runAsync(
              () => SqliteVocabularyRepository(
                db,
              ).watchByCollection(collection.id).first,
            ))!,
            isEmpty,
          );
          expect(
            await tester.runAsync(
              () async =>
                  (await db.customSelect('SELECT * FROM learning_items').get())
                      .map((r) => r.data)
                      .toList(),
            ),
            beforeLearning,
          );
          await tester.tap(addFirst);
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(
              PikoNavigationRow,
              copy.text('entry.methodJson'),
            ),
          );
          await flush(tester, db);
          expect(find.byType(VocabularyJsonPage), findsOneWidget);
          expect(find.byType(PikoDialog), findsOneWidget);
          final input = find.byKey(const ValueKey('json-input'));
          await tester.enterText(input, '  incomplete raw JSON  ');
          await pressJson(tester, 'json.expandInput', language: language);
          await pressJson(tester, 'json.analyze', language: language);
          final group = find.byKey(const ValueKey('json-group-example'));
          await tester.ensureVisible(group);
          await tester.tap(group);
          await tester.pumpAndSettle();
          expect(tester.widget<CheckboxListTile>(group).value, isFalse);
          await pressJson(tester, 'json.exportTab', language: language);
          await pressJson(tester, 'json.importTab', language: language);
          await tester.tap(find.byTooltip(copy.text('common.close')));
          await tester.pumpAndSettle();
          await flush(tester, db);
          expect(find.byType(CollectionDetail), findsOneWidget);
          expect(find.byType(VocabularyJsonPage), findsNothing);
          final menu = find.byKey(const ValueKey('collection-menu'));
          await tester.ensureVisible(menu);
          await tester.tap(menu);
          await tester.pumpAndSettle();
          final import = find.widgetWithText(
            PikoFormRow,
            copy.text('json.importTab'),
          );
          await tester.ensureVisible(import);
          await tester.tap(import);
          await flush(tester, db);
          expect(find.text(copy.text('json.collapseInput')), findsOneWidget);
          expect(
            tester.widget<TextField>(input).controller!.text,
            '  incomplete raw JSON  ',
          );
          expect(tester.widget<CheckboxListTile>(group).value, isFalse);
          platform.file = jsonEncode({
            'format': 'piko-vocabulary',
            'schemaVersion': 5,
            'collections': [
              {
                'targetLanguage': {'kind': 'catalog', 'id': 'fr'},
                'nativeLanguage': {'kind': 'catalog', 'id': 'de'},
                'entries': [
                  {'targetText': 'One', 'nativeText': 'Eins'},
                ],
              },
            ],
          });
          await pressJson(tester, 'json.file', language: language);
          await pressJson(tester, 'json.analyze', language: language);
          await flush(tester, db);
          await pressJson(tester, 'json.apply', language: language);
          await confirmJson(tester, language);
          await flush(tester, db);
          final rows = (await tester.runAsync(
            () => SqliteVocabularyRepository(
              db,
            ).watchByCollection(collection.id).first,
          ))!;
          expect(rows.single.targetText, 'One');
          expect(rows.single.addedAt, isNotNull);
          await pressJson(
            tester,
            'json.returnToCollection',
            language: language,
          );
          await flush(tester, db);
          final settingsBack = find.byTooltip(copy.text('common.back'));
          await tester.ensureVisible(settingsBack);
          await tester.pumpAndSettle();
          expect(settingsBack.hitTestable(), findsOneWidget);
          await tester.tap(settingsBack);
          await flush(tester, db);
          expect(find.byType(CollectionDetail), findsOneWidget);
          expect(
            find.byKey(const ValueKey('collection-empty-add')),
            findsNothing,
          );
          expect(find.text(copy.text('collection.empty')), findsNothing);
          expect(find.byType(CollectionSearchField), findsOneWidget);
          expect(
            find.byKey(const ValueKey('collection-filters')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => db.closed.future.timeout(const Duration(seconds: 10)),
          );
          expect(db.closed.isCompleted, isTrue);
        }
      },
    );
  }
}
