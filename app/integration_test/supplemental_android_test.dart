import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/language_picker.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_form.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import '../test/data/statistics_test.dart' show stored;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'language identity, meaning preservation and current native JSON round-trip',
    (tester) async {
      final config = CatalogueConfiguration(),
          copy = PikoCopy(CatalogueConfiguration().locale);
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/supplemental-${config.runId}',
      );
      if (await directory.exists()) {
        throw StateError('Unique evidence directory required');
      }
      await directory.create();
      final db = review.ReviewFixtureDatabase(
        File('${directory.path}/fixture.sqlite'),
        review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12)),
      );
      final fixture = Fixture(database: db);
      final states = <Map<String, Object?>>[];
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
        'states': states,
      };
      bool passed = false, converted = false;
      Future<void> persist() => File(
        '${directory.path}/manifest.json',
      ).writeAsString(jsonEncode(manifest), flush: true);
      Finder key(String id) => find.byKey(ValueKey(id));
      Finder button(String id) =>
          find.widgetWithText(PikoButton, copy.text(id));
      Future<void> reveal(Finder target) async {
        await tester.pumpAndSettle();
        await tester.ensureVisible(target.last);
        await tester.pumpAndSettle();
        expect(target.last.hitTestable(), findsOneWidget);
      }

      Future<void> tap(Finder target) async {
        await reveal(target);
        await tester.tap(target.last);
        await tester.pumpAndSettle();
      }

      Future<void> close() async =>
          tap(find.byTooltip(copy.text('common.close')).last);
      Future<void> record(String id) async {
        await tester.pumpAndSettle();
        final media = MediaQuery.of(tester.element(find.byType(Scaffold).last));
        final rows = <Map<String, Object?>>[];
        for (final row in tester.widgetList<PikoFormRow>(
          find.byType(PikoFormRow),
        )) {
          final owner = find.byWidget(row), bounds = tester.getRect(owner);
          final title = find
              .descendant(of: owner, matching: find.text(row.title))
              .first;
          final inset = tester.getRect(title).left - bounds.left;
          expect(inset, closeTo(16, .5));
          expect(bounds.height, greaterThanOrEqualTo(48));
          rows.add({'inset': inset, 'height': bounds.height});
        }
        states.add({
          'id': id,
          'width': media.size.width,
          'scale': media.textScaler.scale(14) / 14,
          'rows': rows,
        });
        await settleCatalogueCapture(tester, id);
        if (!converted) {
          await integration.convertFlutterSurfaceToImage();
          await tester.pump();
          converted = true;
        }
        await File(
          '${directory.path}/$id.png',
        ).writeAsBytes(await integration.takeScreenshot(id));
        await persist();
        expect(tester.takeException(), isNull, reason: id);
      }

      Future<void> native(String phase) async {
        await File('${directory.path}/phase.json').writeAsString(
          jsonEncode({'phase': phase, 'run': config.runId}),
          flush: true,
        );
        final ack = File('${directory.path}/ack-$phase');
        final end = DateTime.now().add(const Duration(seconds: 90));
        while (!await ack.exists() && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          await ack.exists(),
          isTrue,
          reason: 'Native ACK $phase required',
        );
      }

      try {
        await fixture.initialize();
        await fixture.review(rating: LearningRating.again);
        await fixture.review(reverse: true, rating: LearningRating.good);
        await SqliteSettingsRepository(db).write('locale', config.locale);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(config.locale),
            home: PikoRuntime(databaseFactory: () => db),
          ),
        );
        await hydratedRuntimeCopy(tester);
        await tester.pumpAndSettle();
        await tap(button('action.new'));
        final name = tester
            .widget<TextField>(find.byType(TextField))
            .controller!;
        await tester.enterText(find.byType(TextField), '  Parent raw draft  ');
        name.selection = const TextSelection(baseOffset: 2, extentOffset: 8);
        final draft = name.value;
        await tap(key('collection.targetLanguage'));
        expect(find.byType(LanguagePickerDialog), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'Mandarin');
        await tester.pumpAndSettle();
        await record('language-search');
        await native('picker-back');
        await tester.pumpAndSettle();
        expect(find.byType(LanguagePickerDialog), findsNothing);
        expect(name.value, draft);
        await tap(key('collection.targetLanguage'));
        await tester.enterText(find.byType(TextField).last, 'Mandarin');
        await tester.pumpAndSettle();
        await tap(key('language-zh-Hans'));
        expect(name.value, draft);
        await tap(key('collection.nativeLanguage'));
        await tap(
          find.widgetWithText(PikoNavigationRow, copy.text('language.custom')),
        );
        final custom = find.byType(TextField).last;
        await tester.enterText(custom, '?! ');
        await tap(button('language.customSave'));
        expect(find.text(copy.text('language.customRequired')), findsOneWidget);
        await tester.enterText(custom, '  Unser Dialekt!  ');
        await tester.tap(custom);
        await tester.pump(const Duration(seconds: 1));
        await native('ime-back');
        await tester.pumpAndSettle();
        expect(find.byType(LanguagePickerDialog), findsOneWidget);
        await tap(button('language.customSave'));
        expect(name.value, draft);
        await record('collection-language-fields');
        await tap(button('action.create'));
        await review.waitUntil(
          tester,
          () => find.byType(PikoDialog).evaluate().isEmpty,
        );
        final created = (await fixture.collections.watchAll().first).last;
        expect(created.targetLanguage.code, 'zh-Hans');
        expect(created.nativeLanguage.customName, '  Unser Dialekt!  ');
        await tap(key('collection-${created.id}'));
        expect(find.byType(CollectionDetail), findsOneWidget);
        await record('custom-collection');
        await tap(find.byTooltip(copy.text('common.back')));
        await tap(key('collection-${fixture.owner.id}'));
        Future<void> meaning(String hint) =>
            fixture.vocabulary.createWithContent(
              collectionId: fixture.owner.id,
              targetText: 'run',
              nativeText: 'laufen',
              assignments: {},
              content: VocabularyContent(hintText: hint),
            );
        await meaning('machine');
        await meaning('movement');
        final before = await stored(db),
            service = SqliteVocabularyJsonService(db);
        final file = File('${directory.path}/collection.json');
        await file.writeAsString(
          await service.exportCollection(fixture.owner.id),
        );
        final preview = await service.analyzeImport(
          collectionId: fixture.owner.id,
          json: await file.readAsString(),
        );
        expect(preview.canApply, isTrue);
        await service.applyImport(preview);
        expect(await stored(db), before);
        await tap(key('collection-menu'));
        await tap(
          find.widgetWithText(PikoFormRow, copy.text('json.importTab')),
        );
        expect(find.byType(VocabularyJsonPage), findsOneWidget);
        await record('json-input');
        await tester.enterText(key('json-input'), '{broken');
        await tap(button('json.analyze'));
        expect(find.text(copy.text('json.invalidSyntax')), findsWidgets);
        await record('json-invalid');
        final payload =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        ((payload['collections'] as List).single['entries'] as List).add({
          'targetText': 'new file word',
          'nativeText': 'neues Dateiwort',
          'hint': {'text': 'fresh'},
        });
        await tester.enterText(key('json-input'), jsonEncode(payload));
        await tap(button('json.analyze'));
        await record('json-review');
        await tap(button('json.apply'));
        await record('json-confirmation');
        await tap(button('action.cancel'));
        expect(await stored(db), before);
        await tap(button('json.apply'));
        await tap(
          find.descendant(
            of: find.byType(PikoDialog).last,
            matching: button('json.apply'),
          ),
        );
        final after = await stored(db);
        for (final table in [
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
          'statistics_activity',
        ]) {
          expect(after[table], before[table], reason: table);
        }
        expect(
          (after['learning_items'] as List)
              .take((before['learning_items'] as List).length)
              .toList(),
          before['learning_items'],
        );
        await record('json-applied');
        await tap(button('json.exportTab'));
        await reveal(button('json.download'));
        await tester.tap(button('json.download'));
        await tester.pump(const Duration(milliseconds: 300));
        await native('file-save');
        await tester.pumpAndSettle();
        expect(find.text(copy.text('json.fileSaved')), findsOneWidget);
        await tap(button('json.importTab'));
        await reveal(button('json.file'));
        await tester.tap(button('json.file'));
        await tester.pump(const Duration(milliseconds: 300));
        await native('file-open');
        await tester.pumpAndSettle();
        final imported = tester
            .widget<TextField>(key('json-input'))
            .controller!
            .text;
        expect((jsonDecode(imported) as Map)['schemaVersion'], 5);
        await tap(button('json.analyze'));
        await record('native-file-roundtrip');
        await close();
        await tap(find.byTooltip(copy.text('action.addEntry')));
        await tap(
          find.widgetWithText(PikoNavigationRow, copy.text('json.importTab')),
        );
        expect(find.byType(VocabularyJsonPage), findsOneWidget);
        await close();
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        manifest['passed'] = passed;
        await persist();
        debugPrint('PIKO_SUPPLEMENTAL_EVIDENCE:${directory.path}');
      }
    },
  );
}
