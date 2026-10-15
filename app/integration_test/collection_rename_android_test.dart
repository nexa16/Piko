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
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'inline_edit_android_test.dart' as fixture;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

/// COLL-012: actual runtime controls against an exclusively owned fixture file.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final locale in ['en', 'de']) {
    testWidgets('Android $locale rename preserves stored collection contents', (
      tester,
    ) async {
      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp('piko-rename-verification-');
      final file = File('${directory.path}/test.sqlite');
      final db = fixture.InlineFixtureDatabase(file);
      PikoDatabase? reopened;
      var mounted = false;
      try {
        final collections = SqliteCollectionsRepository(db);
        final owner = await collections.create(
          name: 'Before rename',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        await collections.create(
          name: 'Untouched collection',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        final entry = await SqliteVocabularyRepository(db).create(
          collectionId: owner.id,
          targetText: 'école',
          nativeText: 'Schule',
        );
        final learning = SqliteLearningRepository(db);
        final items = await learning.forEntry(entry.id);
        expect(items, hasLength(2));
        for (var index = 0; index < items.length; index++) {
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
        await SqliteSettingsRepository(db).write('locale', locale);
        final before = await fixture.snapshot(db);
        mounted = true;
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        final copy = await hydratedRuntimeCopy(tester);
        expect(copy.locale, locale);
        await fixture.tapVisible(
          tester,
          find.byKey(ValueKey('collection-${owner.id}')),
        );
        final edit = find.byKey(const ValueKey('collection-rename'));
        final name = find.byKey(const ValueKey('collection-name'));
        final save = find.byKey(const ValueKey('collection-name-save'));
        final cancel = find.byKey(const ValueKey('collection-name-cancel'));

        await fixture.tapVisible(tester, edit);
        await fixture.enter(tester, name, '   ');
        await fixture.tapVisible(tester, save);
        expect(find.text(copy.text('collection.requiredName')), findsOneWidget);
        expect(await fixture.snapshot(db), before);
        await fixture.enter(tester, name, 'Discarded name');
        await fixture.tapVisible(tester, cancel);
        expect(name, findsNothing);
        expect(await fixture.snapshot(db), before);

        await fixture.tapVisible(tester, edit);
        await fixture.enter(tester, name, '  Nouvelle collection  ');
        await fixture.tapVisible(tester, save);
        await fixture.waitUntil(tester, () => name.evaluate().isEmpty);
        final expected = <String, Object?>{
          ...before,
          'collections': [
            for (final row in before['collections']! as List)
              if ((row as Map)['id'] == owner.id)
                {...row, 'name': 'Nouvelle collection'}
              else
                row,
          ],
        };
        expect(find.text('Nouvelle collection'), findsOneWidget);
        // Exact all-table comparison includes both directional records, order,
        // unrelated collections, settings and allocation counters.
        expect(await fixture.snapshot(db), expected);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await db.closed.future.timeout(const Duration(seconds: 10));
        mounted = false;
        reopened = PikoDatabase(NativeDatabase(file));
        expect(await fixture.snapshot(reopened), expected);
        await reopened.close();
        reopened = null;
      } finally {
        await tester.pumpWidget(const SizedBox());
        if (mounted) {
          await db.closed.future.timeout(const Duration(seconds: 10));
        } else {
          await db.close();
        }
        await reopened?.close();
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith('piko-rename-verification-')) {
          throw StateError('Refusing cleanup outside owned rename fixture');
        }
        await directory.delete(recursive: true);
      }
    });
  }
}
