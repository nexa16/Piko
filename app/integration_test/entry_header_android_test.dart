import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android production route distinguishes Back, next-card save and final completion',
    (tester) async {
      expect(binding.registerTestTextInput, isFalse);
      final support = await getApplicationSupportDirectory();
      for (final name in [
        'piko-entry-header-normal.png',
        'piko-entry-header-ime.png',
      ]) {
        if (await File('${support.path}/$name').exists()) {
          throw StateError(
            'Refusing to overwrite an existing verification screenshot: $name',
          );
        }
      }
      final directory = await support.createTemp(
        'piko-entry-header-verification-',
      );
      final db = PikoDatabase(
        NativeDatabase(File('${directory.path}/test.sqlite')),
      );
      final locale = InterfaceLocaleController(const Locale('de'));
      final sessions = <EntrySessionController>[];
      try {
        final collection = await SqliteCollectionsRepository(db).create(
          name: 'Header verification',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        final repository = SqliteVocabularyRepository(db);
        EntrySessionController newSession() {
          final value = EntrySessionController(
            collectionId: collection.id,
            repository: repository,
          );
          sessions.add(value);
          return value;
        }

        var session = newSession()
          ..setTargetText('학교')
          ..setNativeText('Schule');
        await tester.pumpWidget(
          PikoApp(
            localeController: locale,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: const TextScaler.linear(2)),
                          child: EntrySessionScreen(
                            collection: collection,
                            session: session,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open verification session'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open verification session'));
        await tester.pumpAndSettle();
        var copy = const PikoCopy('de');
        expect(
          tester.getSize(find.byTooltip(copy.text('entry.complete'))),
          Size.square(pikoDesign.dimension('controls.largeHeight')),
        );
        await tester.tap(find.byTooltip(copy.text('common.back')));
        await tester.pumpAndSettle();
        expect(find.text(copy.text('entry.exitTitle')), findsOneWidget);
        await tester.tap(find.text(copy.text('entry.continue')));
        await tester.pumpAndSettle();
        expect(session.draft.targetText, '학교');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(copy.text('entry.exitTitle')), findsOneWidget);
        await tester.tap(find.byTooltip(copy.text('common.close')));
        await tester.pumpAndSettle();
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await File(
          '${support.path}/piko-entry-header-normal.png',
        ).writeAsBytes(await binding.takeScreenshot('entry-header-normal'));
        final field = find.descendant(
          of: find.byKey(const ValueKey('draft-target')),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        var inset = 0.0;
        for (var attempt = 0; attempt < 100 && inset <= 0; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          inset = MediaQuery.viewInsetsOf(
            tester.element(find.byType(EntrySessionScreen)),
          ).bottom;
        }
        expect(inset, greaterThan(0));
        await tester.pumpAndSettle();
        await File(
          '${support.path}/piko-entry-header-ime.png',
        ).writeAsBytes(await binding.takeScreenshot('entry-header-ime'));
        debugPrint(
          'Header Android actual IME inset=$inset; screenshot captures Flutter activity with keyboard-resized content.',
        );
        await tester.ensureVisible(
          find.byTooltip(copy.text('action.saveNext')),
        );
        await tester.tap(find.byTooltip(copy.text('action.saveNext')));
        await db.customSelect('SELECT 1').get();
        await tester.pumpAndSettle();
        expect(session.confirmedEntries, hasLength(1));
        expect(session.isCompleted, isFalse);
        session.setTargetText('물');
        session.setNativeText('Wasser');
        locale.value = const Locale('en');
        await tester.pumpAndSettle();
        copy = const PikoCopy('en');
        await tester.tap(find.byTooltip(copy.text('entry.complete')));
        await db.customSelect('SELECT 1').get();
        await tester.pumpAndSettle();
        expect(find.byType(EntrySessionScreen), findsNothing);
        expect(session.isCompleted, isTrue);
        expect(await db.select(db.vocabularyEntries).get(), hasLength(2));
        session = newSession()..setTargetText('discard only');
        await tester.tap(find.text('Open verification session'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(copy.text('common.back')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(copy.text('entry.discard')));
        await tester.pumpAndSettle();
        expect(find.byType(EntrySessionScreen), findsNothing);
        expect(await db.select(db.vocabularyEntries).get(), hasLength(2));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        for (final session in sessions) {
          session.dispose();
        }
        locale.dispose();
        await db.close();
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last
                .startsWith('piko-entry-header-verification-')) {
          throw StateError('Refusing cleanup outside owned header fixture');
        }
        await directory.delete(recursive: true);
        // Two synthetic screenshots are retrieved and removed by the host check.
      }
    },
  );
}
