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

Future<double> waitForRealKeyboard(
  WidgetTester tester, {
  required bool visible,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final inset = MediaQuery.viewInsetsOf(
      tester.element(find.byType(EntrySessionScreen)),
    ).bottom;
    if ((inset > 0) == visible) return inset;
  }
  throw StateError('Platform keyboard did not reach the requested state');
}

Finder input(String id, String side) => find.descendant(
  of: find.byKey(ValueKey('$id-$side')),
  matching: find.byType(TextField),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android production stack scrolls and retains editing through a real keyboard',
    (tester) async {
      // No mocked text-input registration: tapping must open the platform IME.
      expect(binding.registerTestTextInput, isFalse);
      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp(
        'piko-entry-stack-verification-',
      );
      final db = PikoDatabase(
        NativeDatabase(File('${directory.path}/test.sqlite')),
      );
      final locale = InterfaceLocaleController(const Locale('de'));
      EntrySessionController? session;
      try {
        final collection = await SqliteCollectionsRepository(db).create(
          name: 'Android stack verification',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        session = EntrySessionController(
          collectionId: collection.id,
          repository: SqliteVocabularyRepository(db),
        );
        for (final pair in [
          ['학교', 'Schule'],
          ['물', 'Wasser'],
        ]) {
          session.setTargetText(pair[0]);
          session.setNativeText(pair[1]);
          await session.confirmAndNext();
        }
        session.setTargetText('  초안  ');
        session.setNativeText('  Entwurf  ');
        await tester.pumpWidget(
          PikoApp(
            localeController: locale,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: EntrySessionScreen(
                  collection: collection,
                  session: session!,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          MediaQuery.viewInsetsOf(
            tester.element(find.byType(EntrySessionScreen)),
          ).bottom,
          0,
        );
        final draftController = tester
            .widget<TextField>(input('draft', 'target'))
            .controller!;
        draftController.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 3,
        );
        final originalSelection = draftController.selection;
        final firstId = session.confirmedEntries.first.id;
        final viewport = tester.getRect(
          find.byKey(const ValueKey('entry-stack')),
        );
        final first = tester.getRect(
          find.byKey(ValueKey('entry-card-$firstId')),
        );
        await tester.dragFrom(
          Offset(viewport.left + 4, viewport.center.dy),
          Offset(0, viewport.center.dy - first.center.dy),
        );
        await tester.pumpAndSettle();
        expect(session.activeEntryId, firstId);
        expect(session.draft.targetText, '  초안  ');
        expect(draftController.selection, originalSelection);
        expect(
          MediaQuery.viewInsetsOf(
            tester.element(find.byType(EntrySessionScreen)),
          ).bottom,
          0,
        );
        final currentViewport = tester.getRect(
          find.byKey(const ValueKey('entry-stack')),
        );
        final draftCard = tester.getRect(
          find.byKey(const ValueKey('entry-card-draft')),
        );
        await tester.dragFrom(
          Offset(currentViewport.left + 4, currentViewport.center.dy),
          Offset(0, currentViewport.center.dy - draftCard.center.dy),
        );
        await tester.pumpAndSettle();
        expect(session.activeEntryId, isNull);
        await tester.ensureVisible(input('draft', 'target'));
        await tester.tap(input('draft', 'target'));
        final inset = await waitForRealKeyboard(tester, visible: true);
        final editable = tester.state<EditableTextState>(
          find.descendant(
            of: input('draft', 'target'),
            matching: find.byType(EditableText),
          ),
        );
        draftController.selection = originalSelection;
        locale.value = const Locale('en');
        await tester.pumpAndSettle();
        expect(session.activeEntryId, isNull);
        expect(draftController.text, '  초안  ');
        expect(draftController.selection, originalSelection);
        expect(editable.widget.focusNode.hasFocus, isTrue);
        expect(
          MediaQuery.viewInsetsOf(
            tester.element(find.byType(EntrySessionScreen)),
          ).bottom,
          greaterThan(0),
        );
        final media = MediaQuery.of(
          tester.element(find.byType(EntrySessionScreen)),
        );
        final usableBottom = media.size.height - media.viewInsets.bottom;
        final targetBox = tester.getRect(input('draft', 'target'));
        expect(targetBox.bottom, lessThanOrEqualTo(usableBottom));
        await tester.ensureVisible(
          find.byTooltip(const PikoCopy('en').text('action.saveNext')),
        );
        await tester.pumpAndSettle();
        final confirmBox = tester.getRect(
          find.byTooltip(const PikoCopy('en').text('action.saveNext')),
        );
        expect(confirmBox.bottom, lessThanOrEqualTo(usableBottom));
        debugPrint(
          'Android actual IME: inset=$inset; viewport=${media.size}; confirmation bottom=${confirmBox.bottom}; no keyboard from scroll.',
        );
        await tester.tap(
          find.byTooltip(const PikoCopy('en').text('action.saveNext')),
        );
        await db.customSelect('SELECT 1').get();
        await tester.pumpAndSettle();
        expect(session.confirmedEntries, hasLength(3));
        expect(session.draft.targetText, isEmpty);
        expect((await db.select(db.vocabularyEntries).get()), hasLength(3));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        session?.dispose();
        locale.dispose();
        await db.close();
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last
                .startsWith('piko-entry-stack-verification-')) {
          throw StateError('Refusing cleanup outside owned stack fixture');
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
