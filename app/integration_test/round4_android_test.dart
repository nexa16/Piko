import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_page.dart';
import '../test/data/regular_reviews_test.dart' show Fixture, instant;
import '../test/data/speed_eligibility_test.dart' show completeSnapshot;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

Finder key(String value) => find.byKey(ValueKey(value));
Finder button(String label) => find.widgetWithText(PikoButton, label);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'round4 integrated views, examples, popup and learning header transitions',
    (tester) async {
      final config = CatalogueConfiguration(),
          support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/round4-${config.runId}');
      if (await directory.exists()) {
        throw StateError('Refusing to overwrite fixture');
      }
      await directory.create();
      final clock = review.ReviewFixtureClock(instant),
          file = File('${directory.path}/fixture.sqlite');
      final db = review.ReviewFixtureDatabase(file, clock),
          platform = CatalogueJsonPlatform();
      final fixture = Fixture(database: db);
      final evidence = <String, Object?>{
        'sourceCommit': config.commit,
        'runId': config.runId,
        'locale': 'en',
        'scale': 'normal',
        'headerSourceChangedBeforeInvestigation': false,
      };
      final frames = <Map<String, Object?>>[];
      var passed = false;
      Future<void> present(Finder at) => review.waitUntil(
        tester,
        () => at.evaluate().isNotEmpty,
        description: '$at',
      );
      Future<void> tap(Finder at) async {
        await present(at);
        // Lazy list extents can change while an expanded editor is scrolled.
        // Let layout settle, then verify the actual target before tapping it.
        for (var attempt = 0; attempt < 4; attempt++) {
          await tester.ensureVisible(at);
          await tester.pumpAndSettle();
          if (at.hitTestable().evaluate().isNotEmpty) {
            await tester.tap(at.hitTestable());
            await tester.pumpAndSettle();
            return;
          }
        }
        fail('Target did not become hittable: $at');
      }

      Future<void> capture(String name, {Finder? at}) async {
        await settleCatalogueCapture(tester, name, at: at);
        final bytes = await binding.takeScreenshot(name);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes, flush: true);
      }

      Future<void> transition(String name, Finder action) async {
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final heading = find.byType(PikoHeading),
            original = tester.element(heading);
        await tester.tap(action);
        for (final ms in [0, 16, 32, 64, 128, 256]) {
          await tester.pump(Duration(milliseconds: ms));
          expect(heading, findsOneWidget, reason: '$name at $ms');
          expect(
            tester.element(heading),
            same(original),
            reason: 'Session header must stay mounted',
          );
          final rect = tester.getRect(heading);
          frames.add({
            'transition': name,
            'stepMs': ms,
            'top': rect.top,
            'bottom': rect.bottom,
            'headerPresent': true,
          });
          if (ms == 16 || ms == 128) {
            final bytes = await binding.takeScreenshot('$name-$ms');
            await File(
              '${directory.path}/$name-$ms.png',
            ).writeAsBytes(bytes, flush: true);
          }
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      try {
        await fixture.initialize();
        final collection = await fixture.collections.create(
          name: 'Round 4 · French',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final settings = SqliteSettingsRepository(db),
            categories = SqliteCategoriesRepository(db);
        await settings.write('locale', 'en');
        await settings.write(
          PreferredDirection.settingKey,
          PreferredDirection.targetToNative.name,
        );
        final topic = await categories.createDimension(
          collectionId: collection.id,
          name: 'Topic',
          mode: CategoryMode.multiple,
        );
        final travel = await categories.createValue(
          dimensionId: topic.id,
          name: 'Travel',
        );
        final food = await categories.createValue(
          dimensionId: topic.id,
          name: 'Food',
        );
        final apple = await fixture.vocabulary.createWithContent(
          collectionId: collection.id,
          targetText: 'pomme',
          nativeText: 'Apfel',
          assignments: {
            topic.id: {food.id, travel.id},
          },
          content: const VocabularyContent(
            examples: [
              ExamplePair(targetText: 'Une pomme.', nativeText: 'Ein Apfel.'),
              ExamplePair(
                targetText: 'La pomme est rouge.',
                nativeText: 'Der Apfel ist rot.',
              ),
            ],
            hintText: 'A fruit',
          ),
        );
        await fixture.vocabulary.create(
          collectionId: collection.id,
          targetText: 'pain',
          nativeText: 'Brot',
        );
        final baseline = await completeSnapshot(db);
        await tester.pumpWidget(
          PikoApp(
            home: PikoRuntime(
              databaseFactory: () => db,
              jsonPlatform: platform,
            ),
          ),
        );
        final copy = await hydratedRuntimeCopy(tester);
        await present(find.byType(CollectionsHome));
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await tap(key('collection-${collection.id}'));
        await present(key('collection-view'));
        await capture('01-compact', at: key('collection-view'));
        await tap(key('collection-filters'));
        final apply = button(copy.text('r2.apply'));
        final clear = key('filters-clear-pending');
        final geometry = [tester.getRect(apply), tester.getRect(clear)];
        await capture('01a-filters-unchanged');
        await tap(key('filter-value-${food.id}'));
        expect([tester.getRect(apply), tester.getRect(clear)], geometry);
        await capture('01b-filters-changed');
        await tap(clear);
        expect([tester.getRect(apply), tester.getRect(clear)], geometry);
        await capture('01c-filters-cleared');
        await tap(key('filter-value-${food.id}'));
        await tap(key('filter-value-${food.id}'));
        expect([tester.getRect(apply), tester.getRect(clear)], geometry);
        await capture('01d-filters-reverted');
        await tap(find.byTooltip(copy.text('common.close')));
        await tap(key('collection-view'));
        await capture('02-view-dialog');
        await tap(key('view.mode'));
        await tap(find.text(copy.text('view.detailed')).last);
        await tap(key('view.grouping'));
        await tap(find.text('Topic').last);
        await tap(button(copy.text('r2.apply')));
        await present(key('collection-expand-all'));
        expect(key('vocabulary-${food.id}/${apple.id}'), findsNothing);
        await tap(key('collection-expand-all'));
        await present(key('vocabulary-${food.id}/${apple.id}'));
        await capture('03-grouped-detailed', at: key('collection-expand-all'));
        await tap(key('vocabulary-${food.id}/${apple.id}'));
        await present(key('content-example-target-1'));
        await tester.ensureVisible(key('content-example-target-1'));
        await tester.enterText(
          key('content-example-target-1'),
          'Raw second example',
        );
        await tester.enterText(key('content-example-native-1'), '');
        await tester.pumpAndSettle();
        expect(
          (await fixture.vocabulary.watchById(apple.id).first)!
              .content
              .examples
              .last
              .nativeText,
          'Der Apfel ist rot.',
        );
        await tester.enterText(
          key('content-example-native-1'),
          'Zweites Beispiel.',
        );
        await tester.pumpAndSettle();
        await review.waitUntil(
          tester,
          () async =>
              (await fixture.vocabulary.watchById(apple.id).first)!
                  .content
                  .examples
                  .last
                  .nativeText ==
              'Zweites Beispiel.',
        );
        await tester.showKeyboard(key('content-example-native-1'));
        await review.waitUntil(
          tester,
          () =>
              MediaQuery.viewInsetsOf(
                tester.element(find.byType(Scaffold).last),
              ).bottom >
              0,
        );
        final keyboardBytes = await binding.takeScreenshot(
          '04a-editor-keyboard',
        );
        await File(
          '${directory.path}/04a-editor-keyboard.png',
        ).writeAsBytes(keyboardBytes, flush: true);
        await capture(
          '04-multiple-example-editor',
          at: key('content-example-target-1'),
        );
        await tap(button(copy.text('vocab.inlineDiscard')));
        await review.waitUntil(
          tester,
          () => key('content-example-target-1').evaluate().isEmpty,
        );
        expect(
          (await fixture.vocabulary.watchById(apple.id).first)!
              .content
              .examples
              .last
              .nativeText,
          'Der Apfel ist rot.',
        );
        await tester.scrollUntilVisible(
          key('collection-menu'),
          -500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tap(key('collection-menu'));
        await tap(button(copy.text('json.title')));
        await present(key('json-input'));
        await capture('05-import-popup');
        await tap(button(copy.text('json.example')));
        final template = jsonDecode(platform.exported!) as Map;
        expect(template['schemaVersion'], 3);
        await tester.enterText(key('json-input'), jsonEncode(template));
        await tap(button(copy.text('json.analyze')));
        await present(button(copy.text('json.apply')));
        await capture('05a-json-preview', at: button(copy.text('json.apply')));
        await tap(key('json-export-tab'));
        await tap(button(copy.text('json.copy')));
        final document = jsonDecode(platform.exported!) as Map;
        final exported =
            (document['collections'] as List).single['entries'] as List;
        expect((exported.first['examples'] as List).length, 2);
        expect(exported.first['addedAt'], isNotNull);
        await tap(find.byTooltip(copy.text('common.close')));
        await present(find.byType(CollectionDetail));
        final afterContent = await completeSnapshot(db);
        for (final table in [
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
        ]) {
          expect(afterContent[table], baseline[table]);
        }
        // New presentations capture the setting, normal and Speed answers still show every pair.
        await settings.write('questionExamples', 'false');
        await tap(key('collection-review-targetToNative'));
        await present(find.byType(ReviewSessionRoute));
        await present(key('review-prompt-text'));
        expect(find.text('Une pomme.'), findsNothing);
        await tap(review.revealTarget);
        await present(key('learning-answer-example-1'));
        await capture('06-normal-answer', at: key('review-exit'));
        await transition('normal-grade', key('review-grade-incorrect'));
        await present(key('review-correct-previous'));
        await transition('normal-correction', key('review-correct-previous'));
        await transition(
          'normal-correction-submit',
          key('review-grade-incorrect'),
        );
        await present(key('review-prompt-text'));
        await tap(review.revealTarget);
        await transition('normal-retry-wait', key('review-grade-incorrect'));
        await present(key('review-retry-wait'));
        final normal = tester
            .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
            .session;
        clock.set(instant.add(const Duration(seconds: 11)));
        await normal.refreshRetries();
        await tester.pumpAndSettle();
        await present(key('review-prompt-text'));
        await capture('07-retry-resumed', at: key('review-exit'));
        await tap(key('review-exit'));
        await present(find.byType(CollectionDetail));
        await tap(key('collection-speed-targetToNative'));
        await present(find.byType(SpeedSetupDialog));
        await capture('07a-speed-setup');
        await tap(button(copy.text('learn.startSpeed')));
        await present(find.byType(SpeedSessionRoute));
        await present(key('review-prompt-text'));
        expect(find.text('Une pomme.'), findsNothing);
        await tap(key('review-prompt'));
        await capture('08-speed-answer', at: key('speed-exit'));
        await transition('speed-grade', key('speed-grade-incorrect'));
        await present(key('review-prompt'));
        await tap(key('review-prompt'));
        await transition('speed-game-start', key('speed-grade-incorrect'));
        await present(key('speed-numbers-break'));
        final speed = tester
            .widget<SpeedSessionRoute>(find.byType(SpeedSessionRoute))
            .session;
        while (speed.state!.numberGame!.nextNumber! < 10) {
          await tap(key('speed-number-${speed.state!.numberGame!.nextNumber}'));
        }
        await transition('speed-game-end', key('speed-number-10'));
        await present(key('review-prompt'));
        await tap(key('speed-exit'));
        await present(find.byType(CollectionDetail));
        evidence['learningTransitions'] = frames;
        evidence['headerResult'] =
            'Header remained mounted in sampled frames; owner recording cases remain unidentified.';
        evidence['viewPreferences'] = jsonDecode(
          (await settings.read('collectionView:${collection.id}'))!,
        );
        expect(
          CollectionViewPreferences.fromJson(
            evidence['viewPreferences']! as Map<String, dynamic>,
          ).grouping,
          topic.id,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        // Verify durable reopen, including examples and Collection preferences.
        final exportedBefore = await SqliteVocabularyJsonService(
          db,
        ).exportCollection(collection.id);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.closed.future;
        final reopened = review.ReviewFixtureDatabase(file, clock);
        try {
          expect(
            await SqliteVocabularyJsonService(
              reopened,
            ).exportCollection(collection.id),
            exportedBefore,
          );
        } finally {
          await reopened.close();
        }
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        evidence['passed'] = passed;
        evidence['frames'] = frames;
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(evidence),
          flush: true,
        );
        debugPrint('PIKO_ROUND4_EVIDENCE:${directory.path}');
      }
    },
  );
}
