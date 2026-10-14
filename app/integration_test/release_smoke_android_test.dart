import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';

import 'inline_edit_android_test.dart' as fixture;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

const _fixturePrefix = 'piko-release-smoke-';

Finder _button(String label) => find.widgetWithText(PikoButton, label);

Finder _draftField(String side) => find.descendant(
  of: find.byKey(ValueKey('draft-$side')),
  matching: find.byType(TextField),
);

Future<void> _waitForKeyboard(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (MediaQuery.viewInsetsOf(
          tester.element(find.byType(EntrySessionScreen)),
        ).bottom >
        0) {
      return;
    }
  }
  throw StateError('The Android keyboard did not open for the release smoke.');
}

Future<CollectionRecord> _createCollection(
  WidgetTester tester,
  PikoDatabase db,
  PikoCopy copy,
  String name,
) async {
  final before = (await db.select(db.collections).get())
      .map((row) => row.id)
      .toSet();
  await fixture.tapVisible(tester, _button(copy.text('action.new')));
  await fixture.enter(tester, find.byType(TextField), name);
  await fixture.tapVisible(tester, _button(copy.text('action.create')));
  await fixture.waitUntil(
    tester,
    () async =>
        (await db.select(db.collections).get()).length == before.length + 1,
  );
  final records = await SqliteCollectionsRepository(db).watchAll().first;
  return records.singleWhere((record) => !before.contains(record.id));
}

Future<void> _openCollection(
  WidgetTester tester,
  CollectionRecord collection,
) async {
  await fixture.tapVisible(
    tester,
    find.byKey(ValueKey('collection-${collection.id}')),
  );
  await fixture.waitUntil(
    tester,
    () => find.byType(CollectionDetail).evaluate().isNotEmpty,
  );
}

/// Joined Android release smoke against one exclusively owned SQLite file.
///
/// HTTP construction is blocked to prove the UI/storage journey has no network
/// dependency. This test unmounts and reopens the same file; it deliberately
/// does not claim an external process restart or device-offline acceptance.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android joined collection and entry journey survives isolated file reopen',
    (tester) async {
      expect(binding.registerTestTextInput, isFalse);
      var networkAttempts = 0;
      await HttpOverrides.runZoned<Future<void>>(
        () async {
          // Exercise the guard once, then require the product journey to make
          // no HTTP client attempt.
          expect(() => HttpClient(), throwsA(isA<StateError>()));
          expect(networkAttempts, 1);
          networkAttempts = 0;

          final support = await getApplicationSupportDirectory();
          final directory = await support.createTemp(_fixturePrefix);
          final file = File('${directory.path}/test.sqlite');
          final databases = <fixture.InlineFixtureDatabase>[];
          final semantics = tester.ensureSemantics();
          try {
            final db = fixture.InlineFixtureDatabase(file);
            databases.add(db);
            await tester.pumpWidget(
              PikoApp(home: PikoRuntime(databaseFactory: () => db)),
            );
            final copy = await hydratedRuntimeCopy(tester);
            expect(find.byType(CollectionsHome), findsOneWidget);
            await fixture.waitUntil(
              tester,
              () => find
                  .text(copy.text('home.emptyDescription'))
                  .evaluate()
                  .isNotEmpty,
            );
            expect(
              find.text(copy.text('home.emptyDescription')),
              findsOneWidget,
            );
            expect(await db.select(db.collections).get(), isEmpty);

            final survivor = await _createCollection(
              tester,
              db,
              copy,
              'Release survivor',
            );
            final removed = await _createCollection(
              tester,
              db,
              copy,
              'Release removal',
            );
            expect(await db.select(db.collections).get(), hasLength(2));

            // A cancelled rename is inert; the following trimmed rename is
            // the committed survivor name.
            await _openCollection(tester, survivor);
            await fixture.tapVisible(
              tester,
              find.byKey(const ValueKey('collection-rename')),
            );
            await fixture.enter(
              tester,
              find.byKey(const ValueKey('collection-name')),
              'Cancelled rename',
            );
            await fixture.tapVisible(
              tester,
              find.byKey(const ValueKey('collection-name-cancel')),
            );
            expect(find.text('Release survivor'), findsOneWidget);
            await fixture.tapVisible(
              tester,
              find.byKey(const ValueKey('collection-rename')),
            );
            await fixture.enter(
              tester,
              find.byKey(const ValueKey('collection-name')),
              '  Retained words  ',
            );
            await fixture.tapVisible(
              tester,
              find.byKey(const ValueKey('collection-name-save')),
            );
            await fixture.waitUntil(
              tester,
              () => find.text('Retained words').evaluate().isNotEmpty,
            );
            await fixture.tapVisible(tester, _button(copy.text('common.back')));

            // Deletion remains explicit: closing the first confirmation does
            // nothing, while the second confirmation removes only its owner.
            await _openCollection(tester, removed);
            final delete = find.byWidgetPredicate(
              (widget) =>
                  widget is PikoButton &&
                  widget.label == copy.text('collection.delete'),
            );
            await fixture.tapVisible(tester, delete);
            final close = find.descendant(
              of: find.byType(PikoDialog),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is PikoIconButton &&
                    widget.semanticLabel == copy.text('common.close'),
              ),
            );
            await fixture.tapVisible(tester, close);
            expect(await db.select(db.collections).get(), hasLength(2));
            await fixture.tapVisible(tester, delete);
            await fixture.tapVisible(
              tester,
              find.descendant(of: find.byType(PikoDialog), matching: delete),
            );
            await fixture.waitUntil(
              tester,
              () async => (await db.select(db.collections).get()).length == 1,
            );
            await fixture.waitUntil(
              tester,
              () => find
                  .byKey(ValueKey('collection-${survivor.id}'))
                  .evaluate()
                  .isNotEmpty,
            );
            expect(
              find.byKey(ValueKey('collection-${removed.id}')),
              findsNothing,
            );

            final renamed = (await SqliteCollectionsRepository(
              db,
            ).watchById(survivor.id).first)!;
            expect(renamed.name, 'Retained words');
            await _openCollection(tester, renamed);
            await fixture.tapVisible(
              tester,
              find.byTooltip(copy.text('action.addEntry')),
            );
            expect(find.byType(EntrySessionScreen), findsOneWidget);

            final target = _draftField('target');
            final native = _draftField('native');
            await fixture.tapVisible(tester, target);
            await _waitForKeyboard(tester);

            // Incomplete input is rejected without a write.
            await fixture.enter(tester, target, '학교');
            await fixture.enter(tester, native, '');
            await fixture.tapVisible(
              tester,
              find.byTooltip(copy.text('action.saveNext')),
            );
            expect(
              find.text(copy.text('entry.requiredNative')),
              findsOneWidget,
            );
            expect(await db.select(db.vocabularyEntries).get(), isEmpty);

            // The valid pair is saved, then the same pair is rejected as a
            // duplicate while its raw draft remains available to discard.
            await fixture.enter(tester, native, 'Schule');
            await fixture.tapVisible(
              tester,
              find.byTooltip(copy.text('action.saveNext')),
            );
            await fixture.waitUntil(
              tester,
              () async =>
                  (await db.select(db.vocabularyEntries).get()).length == 1,
            );
            final saved = await SqliteVocabularyRepository(
              db,
            ).watchByCollection(survivor.id).first;
            expect(saved, hasLength(1));
            expect(saved.single.targetText, '학교');
            expect(saved.single.nativeText, 'Schule');

            await fixture.enter(tester, target, '학교');
            await fixture.enter(tester, native, 'Schule');
            await fixture.tapVisible(
              tester,
              find.byTooltip(copy.text('action.saveNext')),
            );
            expect(
              find.text(copy.text('vocab.inlineDuplicate')),
              findsOneWidget,
            );
            expect(await db.select(db.vocabularyEntries).get(), hasLength(1));

            await fixture.enter(tester, target, '  unfinished raw draft  ');
            await fixture.enter(tester, native, '');
            await fixture.tapVisible(
              tester,
              find.byTooltip(copy.text('common.back')),
            );
            expect(find.text(copy.text('entry.exitTitle')), findsOneWidget);
            await fixture.tapVisible(
              tester,
              _button(copy.text('entry.discard')),
            );
            await fixture.waitUntil(
              tester,
              () => find.byType(EntrySessionScreen).evaluate().isEmpty,
            );
            expect(await db.select(db.vocabularyEntries).get(), hasLength(1));

            // Unmount the production runtime, wait for its owned database to
            // close, then reopen the same isolated file with a fresh runtime.
            await tester.pumpWidget(const SizedBox());
            await db.closed.future.timeout(const Duration(seconds: 10));
            final reopened = fixture.InlineFixtureDatabase(file);
            databases.add(reopened);
            await tester.pumpWidget(
              PikoApp(home: PikoRuntime(databaseFactory: () => reopened)),
            );
            final reopenedCopy = await hydratedRuntimeCopy(tester);
            expect(reopenedCopy.locale, copy.locale);
            await fixture.waitUntil(
              tester,
              () => find
                  .byKey(ValueKey('collection-${survivor.id}'))
                  .evaluate()
                  .isNotEmpty,
            );
            expect(
              find.byKey(ValueKey('collection-${survivor.id}')),
              findsOneWidget,
            );
            expect(
              find.byKey(ValueKey('collection-${removed.id}')),
              findsNothing,
            );
            final retained = await SqliteVocabularyRepository(
              reopened,
            ).watchByCollection(survivor.id).first;
            expect(retained, hasLength(1));
            expect(retained.single.id, saved.single.id);
            expect(retained.single.targetText, '학교');
            expect(retained.single.nativeText, 'Schule');

            await _openCollection(tester, renamed);
            await fixture.waitUntil(
              tester,
              () =>
                  find.text('학교').evaluate().isNotEmpty &&
                  find.text('Schule').evaluate().isNotEmpty,
            );
            expect(find.text('학교'), findsOneWidget);
            expect(find.text('Schule'), findsOneWidget);
            await fixture.tapVisible(
              tester,
              find.byTooltip(reopenedCopy.text('action.addEntry')),
            );
            expect(find.byType(EntrySessionScreen), findsOneWidget);
            expect(
              tester.widget<TextField>(_draftField('target')).controller!.text,
              isEmpty,
            );
            expect(
              tester.widget<TextField>(_draftField('native')).controller!.text,
              isEmpty,
            );
            expect(
              find.byKey(const ValueKey('entry-card-draft')),
              findsOneWidget,
            );
            expect(
              find.text(reopenedCopy.text('entry.prototype')),
              findsNothing,
            );
            expect(networkAttempts, 0);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
            await tester.pumpWidget(const SizedBox());
            for (final db in databases) {
              await db.close();
            }
            if (directory.parent.absolute.path != support.absolute.path ||
                !directory.uri.pathSegments
                    .where((part) => part.isNotEmpty)
                    .last
                    .startsWith(_fixturePrefix)) {
              throw StateError(
                'Refusing cleanup outside the owned release-smoke fixture.',
              );
            }
            await directory.delete(recursive: true);
          }
        },
        createHttpClient: (_) {
          networkAttempts++;
          throw StateError('HTTP is disabled in the Android release smoke.');
        },
      );
    },
  );
}
