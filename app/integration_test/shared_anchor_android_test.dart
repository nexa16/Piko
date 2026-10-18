import 'dart:convert';
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
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_page.dart';
import '../test/ui/entry_keyboard_layout_test.dart' show scrollActionIntoView;
import 'collection_anchor_android_test.dart' as collection;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  collection.main();
  testWidgets(
    'shared surfaces and manual optional content retain their Android anchors',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/shared-anchor-${config.runId}',
      );
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final db = PikoDatabase(
        NativeDatabase(File('${directory.path}/fixture.sqlite')),
      );
      final measurements = <Object?>[];
      EntrySessionController? session;
      var passed = false;
      try {
        for (final dialog in [false, true]) {
          for (final scale in [1.0, 2.0]) {
            final height = ValueNotifier(700.0);
            final body = ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (context, value, _) => Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: value,
                  ),
                  PikoButton(
                    key: const ValueKey('android-anchor-action'),
                    label: 'Change / Ändern',
                    onPressed: () => height.value += 180,
                  ),
                  const SizedBox(height: 1800),
                ],
              ),
            );
            await tester.pumpWidget(
              PikoApp(
                key: UniqueKey(),
                locale: Locale(scale == 1 ? 'en' : 'de'),
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: dialog
                              ? PikoDialog(
                                  title: 'Options',
                                  body: body,
                                  actions: [
                                    PikoDialogAction(
                                      label: 'Apply',
                                      onPressed: () {},
                                    ),
                                  ],
                                )
                              : PikoPage(child: body),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            position.jumpTo(500);
            await tester.pumpAndSettle();
            final action = find.byKey(const ValueKey('android-anchor-action'));
            final top = tester.getTopLeft(action).dy;
            await tester.tap(action);
            final deltas = <double>[];
            for (var frame = 0; frame < 20; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              final delta = tester.getTopLeft(action).dy - top;
              deltas.add(delta);
              expect(delta.abs(), lessThanOrEqualTo(.5));
            }
            height.value += 120;
            await tester.pumpAndSettle();
            expect(tester.getTopLeft(action).dy, closeTo(top, .5));
            measurements.add({
              'surface': dialog ? 'dialog' : 'page',
              'scale': scale,
              'width': 320,
              'frameDeltas': deltas,
              'settledDelta': tester.getTopLeft(action).dy - top,
            });
            await tester.pumpWidget(const SizedBox());
            height.dispose();
          }
        }

        final owner = await SqliteCollectionsRepository(db).create(
          name: 'Anchor verification',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        session =
            EntrySessionController(
                collectionId: owner.id,
                repository: SqliteVocabularyRepository(db),
              )
              ..setTargetText(' raw manual word ')
              ..setNativeText(' manueller Entwurf ');
        await tester.pumpWidget(
          PikoApp(
            key: UniqueKey(),
            home: EntrySessionScreen(collection: owner, session: session),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byKey(const ValueKey('draft-target')),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 50));
          if (MediaQuery.viewInsetsOf(
                tester.element(find.byType(EntrySessionScreen)),
              ).bottom >
              0) {
            break;
          }
        }
        expect(binding.registerTestTextInput, isFalse);
        final inset = MediaQuery.viewInsetsOf(
          tester.element(find.byType(EntrySessionScreen)),
        ).bottom;
        expect(inset, greaterThan(0), reason: 'Real Android IME must open');
        await tester.pumpAndSettle();
        final controller = tester.widget<TextField>(field).controller!;
        controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 5,
        );
        final disclosure = find.byKey(
          const ValueKey('content-examples-toggle'),
        );
        await scrollActionIntoView(tester, disclosure);
        final top = tester.getTopLeft(disclosure).dy;
        await tester.tap(disclosure);
        final deltas = <double>[];
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final delta = tester.getTopLeft(disclosure).dy - top;
          deltas.add(delta);
          expect(delta.abs(), lessThanOrEqualTo(.5));
        }
        expect(controller.text, ' raw manual word ');
        expect(
          controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 5),
        );
        expect(session.activeEntryId, isNull);
        expect(session.confirmedEntries, isEmpty);
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        measurements.add({
          'surface': 'manual-entry-examples',
          'realKeyboardInset': inset,
          'frameDeltas': deltas,
          'rawTextSelectionFocusRetained': true,
        });
        await binding.convertFlutterSurfaceToImage();
        // Android image conversion requires a rendered frame before capture.
        await tester.pump();
        final png = await binding
            .takeScreenshot('entry-examples-anchor')
            .timeout(const Duration(seconds: 20));
        await File(
          '${directory.path}/entry-examples-anchor.png',
        ).writeAsBytes(png, flush: true);
        expect(tester.takeException(), isNull);
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        session?.dispose();
        await db.close();
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'sourceCommit': config.commit,
            'fixture': 'shared-anchor-v1',
            'classification': 'instrumented-android',
            'passed': passed,
            'measurements': measurements,
          }),
          flush: true,
        );
        debugPrint('PIKO_SHARED_ANCHOR_EVIDENCE:${directory.path}');
      }
    },
  );
}
