import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/ai/ai_content.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import '../test/features/entry_ai_test.dart' show HeldAiGateway;
import '../test/ui/entry_keyboard_layout_test.dart' show scrollActionIntoView;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native manual AI review remains local, guarded and independently saveable',
    (tester) async {
      final config = CatalogueConfiguration(),
          copy = PikoCopy(CatalogueConfiguration().locale);
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/ai-${config.runId}');
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final file = File('${directory.path}/fixture.sqlite');
      final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12));
      final db = review.ReviewFixtureDatabase(file, clock),
          gateway = HeldAiGateway();
      final access = AiAccess(gateway), fixture = Fixture(database: db);
      var passed = false, converted = false;
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
        'normalProductionDatabaseOpened': false,
        'transport':
            'deterministic injected gateway; live backend/provider NOT verified',
      };
      Finder key(String name) => find.byKey(ValueKey(name));
      Finder field(String name) =>
          find.descendant(of: key(name), matching: find.byType(TextField));
      Finder button(String name) =>
          find.widgetWithText(PikoButton, copy.text(name));
      Future<void> reveal(Finder target) async {
        await tester.pumpAndSettle();
        for (
          var i = 0;
          target.hitTestable().evaluate().isEmpty && i < 45;
          i++
        ) {
          final body = key('entry-stack').evaluate().isNotEmpty
              ? key('entry-stack')
              : find.byType(Scrollable).first;
          final area = tester.getRect(body);
          final rect = target.evaluate().isEmpty
              ? null
              : tester.getRect(target);
          await tester.dragFrom(
            Offset(area.left + 4, area.center.dy),
            Offset(
              0,
              rect == null || rect.center.dy > area.center.dy ? -160 : 160,
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(target.hitTestable(), findsWidgets);
      }

      Future<void> tap(Finder target) async {
        await reveal(target);
        await tester.tap(target.hitTestable().first);
        await tester.pumpAndSettle();
      }

      Future<void> text(Finder target, String value) async {
        await reveal(target);
        await tester.enterText(target, value);
        await tester.pumpAndSettle();
      }

      Future<Map<String, Object?>> stored(PikoDatabase source) async => {
        for (final table in source.allTables)
          table.actualTableName: await review.rows(
            source,
            table.actualTableName,
          ),
      };
      try {
        await fixture.initialize();
        await fixture.review();
        await fixture.review(reverse: true);
        await SqliteSettingsRepository(db).write('locale', config.locale);
        final baseline = await stored(db);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(config.locale),
            home: PikoRuntime(databaseFactory: () => db, aiAccess: access),
          ),
        );
        await hydratedRuntimeCopy(tester);
        await review.waitUntil(
          tester,
          () => key('collection-${fixture.owner.id}').evaluate().isNotEmpty,
        );
        expect(gateway.connections, 0);
        expect(gateway.calls, isEmpty);
        await tap(key('collection-${fixture.owner.id}'));
        await tap(find.byTooltip(copy.text('action.addEntry')));
        await tap(button('entry.manualMethod'));
        await review.waitUntil(
          tester,
          () => find.byType(EntrySessionScreen).evaluate().isNotEmpty,
        );
        final screen = tester.widget<EntrySessionScreen>(
              find.byType(EntrySessionScreen),
            ),
            session = screen.session;
        final media = MediaQuery.of(
          tester.element(find.byType(EntrySessionScreen)),
        );
        manifest['width'] = media.size.width;
        manifest['textScale'] = media.textScaler.scale(14) / 14;
        if (config.scale == '200') {
          expect(media.size.width, closeTo(320, 1));
          expect(media.textScaler.scale(14), closeTo(28, 1));
        }
        await text(field('draft-target'), 'chat');
        await text(field('draft-native'), 'Katze');
        expect(integration.registerTestTextInput, isFalse);
        await review.waitUntil(
          tester,
          () => tester.view.viewInsets.bottom > 0,
          description: 'real IME shown',
        );
        final native = tester
            .widget<TextField>(field('draft-native'))
            .controller!;
        native.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
        await scrollActionIntoView(tester, key('content-examples-toggle'));
        await tap(key('content-examples-toggle'));
        await tap(key('ai-suggest-example'));
        expect(find.text(copy.text('ai.processing')), findsOneWidget);
        expect(gateway.connections, 0);
        await tap(button('ai.enable'));
        expect(gateway.connections, 1);
        expect(gateway.calls, hasLength(1));
        expect(
          native.selection,
          const TextSelection(baseOffset: 1, extentOffset: 4),
        );
        expect(session.draft.nativeText, 'Katze');
        session.setTargetText('chien');
        session.setTargetText('chat');
        gateway.example();
        await tester.pumpAndSettle();
        expect(key('ai-use-example'), findsNothing);
        await tap(key('ai-suggest-example'));
        final top = tester.getTopLeft(key('ai-suggest-example')).dy;
        gateway.example();
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(key('ai-suggest-example')).dy,
          closeTo(top, .5),
        );
        expect(await stored(db), baseline);
        if (config.locale == 'en') {
          await settleCatalogueCapture(tester, 'ai-example-preview');
          await integration.convertFlutterSurfaceToImage();
          await tester.pump();
          converted = true;
          await File('${directory.path}/example-preview.png').writeAsBytes(
            await integration.takeScreenshot('ai-example-preview'),
          );
        }
        await tap(key('ai-use-example'));
        expect(session.draft.content.examples, hasLength(1));
        await tap(key('content-hint-toggle'));
        await text(key('content-hint'), 'manual clue');
        await tap(key('ai-suggest-hint'));
        gateway.response!.completeError(AiFailure.limit);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('ai.limit')), findsOneWidget);
        expect(session.draft.content.hintText, 'manual clue');
        await tap(key('ai-suggest-hint'));
        gateway.hint();
        await tester.pumpAndSettle();
        expect(find.text(copy.text('ai.replaceHint')), findsOneWidget);
        await tap(key('ai-use-hint'));
        expect(session.draft.content.hintText, 'Ein Haustier, das miaut.');
        expect(await stored(db), baseline);
        await tap(key('ai-suggest-hint'));
        await tap(button('action.saveNext'));
        await review.waitUntil(
          tester,
          () => session.confirmedEntries.length == 1,
        );
        final saved = session.confirmedEntries.single;
        gateway.hint();
        await tester.pumpAndSettle();
        expect(session.draft.targetText, isEmpty);
        expect(session.draft.content.hintText, isNull);
        expect(saved.targetText, 'chat');
        expect(saved.nativeText, 'Katze');
        expect(saved.content.examples.single.targetText, 'Le chat dort.');
        expect(saved.content.hintText, 'Ein Haustier, das miaut.');
        for (final table in [
          'regular_reviews',
          'statistics_activity',
          'speed_completion_receipts',
          'retry_obligations',
        ]) {
          expect(await review.rows(db, table), baseline[table]);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        final reopened = PikoDatabase(NativeDatabase(file));
        try {
          final record = await SqliteVocabularyRepository(
            reopened,
          ).watchById(saved.id).first;
          expect(record!.content.hintText, saved.content.hintText);
          expect(record.content.examples, saved.content.examples);
          expect(
            await reopened.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await reopened.close();
        }
        manifest['assertions'] = [
          'no identity on launch',
          'voluntary explanation',
          'real IME/cursor retained',
          'changed-back pair invalidates response',
          'preview/use does not save',
          'limit preserves input',
          'explicit hint replacement',
          'local save while pending',
          'late response cannot enter next draft',
          'ordinary content reopen; statistics/reviews/retries unchanged',
        ];
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        access.dispose();
        if (!db.closed.isCompleted) await db.close();
        manifest['passed'] = passed;
        manifest['captured'] = converted;
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(manifest),
          flush: true,
        );
        debugPrint('PIKO_AI_EVIDENCE:${directory.path}');
      }
    },
  );
}
