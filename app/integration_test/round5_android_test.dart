import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../test/data/regular_reviews_test.dart' show Fixture, instant;
import '../test/data/speed_eligibility_test.dart' show completeSnapshot;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/frozen_v15_schema.dart';
import 'support/round2_catalogue_fixture.dart';

Finder key(String value) => find.byKey(ValueKey(value));
Finder button(String label) => find.widgetWithText(PikoButton, label);

Future<void> verifyUpgrade(Directory directory) async {
  final clock = review.ReviewFixtureClock(instant);
  final seed = review.ReviewFixtureDatabase(
    File('${directory.path}/seed.sqlite'),
    clock,
  );
  final fixture = Fixture(database: seed);
  await fixture.initialize();
  await fixture.review(rating: LearningRating.again);
  await fixture.review(reverse: true, rating: LearningRating.good);
  await seed.customStatement(
    "UPDATE vocabulary_entries SET hint_visibility='always'",
  );
  final before = await completeSnapshot(seed);
  await seed.close();
  final file = File('${directory.path}/upgraded.sqlite');
  final legacy = sqlite.sqlite3.open(file.path);
  try {
    for (final sql in frozenV15Sql) {
      legacy.execute(sql);
    }
    for (final table in before.entries) {
      for (final stored in table.value as List) {
        final row = Map<String, Object?>.from(stored as Map);
        if (table.key == 'collections') {
          row.remove('automatic_hint_default');
          row.remove('hint_default_offer_handled');
        }
        if (table.key == 'vocabulary_entries') row.remove('active');
        final columns = row.keys
            .map((name) => name == 'stored_rowid' ? 'rowid' : name)
            .join(',');
        legacy.execute(
          'INSERT INTO ${table.key} ($columns) VALUES (${List.filled(row.length, '?').join(',')})',
          row.values.toList(),
        );
      }
    }
    legacy.execute('PRAGMA user_version=15');
  } finally {
    legacy.close();
  }
  for (var reopen = 0; reopen < 2; reopen++) {
    final db = review.ReviewFixtureDatabase(file, clock);
    try {
      expect(await completeSnapshot(db), before);
      final vocabulary = SqliteVocabularyRepository(db);
      expect(
        (await vocabulary.watchById(fixture.entry.id).first)!.active,
        isTrue,
      );
      expect(
        (await vocabulary.watchById(fixture.entry.id).first)!
            .content
            .hintVisibility,
        HintVisibility.always,
      );
      expect(
        await vocabulary.readHintVisibilityDefault(
          collectionId: fixture.owner.id,
        ),
        HintVisibility.hidden,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
    } finally {
      await db.close();
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'round5 compact editors, Hint defaults, activity, learning Back and durable upgrade',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/round5-${config.runId}');
      if (await directory.exists())
        throw StateError('Refusing to overwrite fixture');
      await directory.create();
      final clock = review.ReviewFixtureClock(instant);
      final file = File('${directory.path}/fixture.sqlite');
      final db = review.ReviewFixtureDatabase(file, clock);
      final f = Fixture(database: db);
      final evidence = <String, Object?>{
        'sourceCommit': config.commit,
        'runId': config.runId,
        'locale': 'en',
        'scale': 'normal',
      };
      var passed = false;
      Future<void> present(Finder at) => review.waitUntil(
        tester,
        () => at.evaluate().isNotEmpty,
        description: '$at',
      );
      Future<void> tap(Finder at) async {
        await present(at);
        for (var attempt = 0; attempt < 5; attempt++) {
          await tester.ensureVisible(at);
          await tester.pumpAndSettle();
          if (at.hitTestable().evaluate().isNotEmpty) {
            await tester.tap(at.hitTestable());
            await tester.pumpAndSettle();
            return;
          }
        }
        fail('Target is not hittable: $at');
      }

      Future<void> capture(String name, {Finder? at}) async {
        await settleCatalogueCapture(tester, name, at: at);
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(await binding.takeScreenshot(name), flush: true);
      }

      Future<void> hiddenKeyboard() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await settleCatalogueCapture(tester, 'keyboard-hidden');
      }

      try {
        await verifyUpgrade(directory);
        evidence['schema15UpgradeAndReopen'] = true;
        await f.initialize();
        final owner = await f.collections.create(
          name: 'Round 5 · French',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final categories = SqliteCategoriesRepository(db),
            settings = SqliteSettingsRepository(db);
        await settings.write('locale', 'en');
        await settings.write(
          PreferredDirection.settingKey,
          PreferredDirection.both.name,
        );
        final topic = await categories.createDimension(
          collectionId: owner.id,
          name: 'Topic',
          mode: CategoryMode.multiple,
        );
        final food = await categories.createValue(
          dimensionId: topic.id,
          name: 'Food',
        );
        final apple = await f.vocabulary.createWithContent(
          collectionId: owner.id,
          targetText: 'pomme',
          nativeText: 'Apfel',
          assignments: {
            topic.id: {food.id},
          },
          content: const VocabularyContent(
            examples: [
              ExamplePair(targetText: 'Une pomme.', nativeText: 'Ein Apfel.'),
            ],
            hintText: 'A fruit',
            hintVisibility: HintVisibility.hidden,
          ),
        );
        final bread = await f.vocabulary.create(
          collectionId: owner.id,
          targetText: 'pain',
          nativeText: 'Brot',
        );
        final before = await completeSnapshot(db);
        await tester.pumpWidget(
          PikoApp(
            home: PikoRuntime(
              databaseFactory: () => db,
              jsonPlatform: CatalogueJsonPlatform(),
            ),
          ),
        );
        final copy = await hydratedRuntimeCopy(tester);
        await present(find.byType(CollectionsHome));
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await tap(key('collection-${owner.id}'));
        await tap(key('vocabulary-${apple.id}'));
        await present(key('inline-${apple.id}-target'));
        expect(key('content-example-target'), findsNothing);
        expect(key('content-hint'), findsNothing);
        await capture(
          '01-compact-editor',
          at: key('inline-${apple.id}-target'),
        );
        await tap(key('content-examples-toggle'));
        await tester.enterText(key('content-example-native'), '');
        await tester.pumpAndSettle();
        await tap(key('inline-complete-${apple.id}'));
        expect(key('inline-${apple.id}-target'), findsOneWidget);
        await tester.enterText(key('content-example-native'), 'Ein Apfel.');
        await tester.pumpAndSettle();
        await tap(key('content-hint-toggle'));
        await tap(key('content-hint-automatic'));
        await present(find.text(copy.text('vocab.hintDefaultOfferTitle')));
        await capture('02-hint-offer');
        await tap(find.text(copy.text('vocab.hintDefaultAccept')));
        await review.waitUntil(
          tester,
          () => find
              .text(copy.text('vocab.hintDefaultOfferTitle'))
              .evaluate()
              .isEmpty,
          description: 'saved offer',
        );
        expect(await f.vocabulary.hintDefaultOfferHandled(owner.id), isTrue);
        expect(
          await f.vocabulary.readHintVisibilityDefault(collectionId: owner.id),
          HintVisibility.always,
        );
        expect(
          (await f.vocabulary.watchById(bread.id).first)!
              .content
              .hintVisibility,
          HintVisibility.hidden,
        );
        await tap(key('categories-toggle-${apple.id}'));
        await present(key('category-picker-${apple.id}-${topic.id}'));
        await capture(
          '03-expanded-sections',
          at: key('inline-active-${apple.id}'),
        );
        await tap(key('inline-active-${apple.id}'));
        await tap(key('inline-complete-${apple.id}'));
        await present(find.text(copy.text('vocab.inactive')));
        await capture('04-inactive-list', at: key('vocabulary-${apple.id}'));
        await tap(key('vocabulary-${apple.id}'));
        await tap(key('inline-active-${apple.id}'));
        await tap(key('inline-complete-${apple.id}'));
        await tap(key('collection-menu'));
        await tap(key('collection-menu-settings'));
        await present(key('collection-hint-default'));
        await capture('05-collection-hint-setting');
        await tap(find.byTooltip(copy.text('common.close')));
        // New-entry confirmation keeps the Collection default and creates Active.
        await tap(button(copy.text('action.new')));
        await present(find.byType(EntrySessionScreen));
        await tester.enterText(key('draft-target'), 'eau');
        await tester.enterText(key('draft-native'), 'Wasser');
        await tap(find.byTooltip(copy.text('action.saveNext')));
        await present(key('draft-target'));
        final water = (await f.vocabulary.watchByCollection(owner.id).first)
            .singleWhere((entry) => entry.targetText == 'eau');
        expect(water.active, isTrue);
        expect(water.content.hintVisibility, HintVisibility.always);
        await tap(find.byTooltip(copy.text('entry.complete')));
        await present(find.byType(CollectionDetail));
        final afterContent = await completeSnapshot(db);
        for (final table in [
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
        ]) {
          expect(afterContent[table], before[table]);
        }
        // Normal and retry use the same current answer editor; no delete action.
        await tap(key('collection-review-targetToNative'));
        await present(find.byType(ReviewSessionRoute));
        var normal = tester
            .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
            .session;
        await present(key('review-prompt-text'));
        final handle = normal.current!;
        normal.setHard(handle, true);
        await tap(key('review-reveal-target'));
        await tap(key('learning-edit-answer'));
        await present(key('learning-answer-editor'));
        expect(key('inline-menu-${handle.item.entryId}'), findsNothing);
        await tester.enterText(
          key('inline-${handle.item.entryId}-target'),
          'pomme fraîche',
        );
        await tester.pumpAndSettle();
        await capture(
          '06-learning-answer-editor',
          at: key('inline-${handle.item.entryId}-target'),
        );
        // Restore a live Android surface and exercise actual docked IME + Back.
        const channel = MethodChannel('plugins.flutter.io/integration_test');
        await channel.invokeMethod<void>('revertFlutterImage');
        await hiddenKeyboard();
        await tap(key('inline-${handle.item.entryId}-native'));
        final keyboardDeadline = DateTime.now().add(
          const Duration(seconds: 15),
        );
        var inset = 0.0;
        while (DateTime.now().isBefore(keyboardDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          inset = MediaQuery.viewInsetsOf(
            tester.element(find.byType(ReviewSessionRoute)),
          ).bottom;
          if (inset > 0) break;
        }
        expect(inset, greaterThan(0));
        evidence['nativeKeyboardInset'] = inset;
        debugPrint('PIKO_ROUND5_BACK1:${config.runId}');
        await review.waitUntil(
          tester,
          () =>
              MediaQuery.viewInsetsOf(
                tester.element(find.byType(ReviewSessionRoute)),
              ).bottom ==
              0,
          description: 'native first Back hides IME',
        );
        expect(key('learning-answer-editor'), findsOneWidget);
        debugPrint('PIKO_ROUND5_BACK2:${config.runId}');
        await review.waitUntil(
          tester,
          () => key('learning-answer-editor').evaluate().isEmpty,
          description: 'native second Back collapses editor',
        );
        await present(key('review-answer-text'));
        expect(normal.current, same(handle));
        expect(normal.hard, isTrue);
        expect(normal.acceptedReviews, isEmpty);
        evidence['nativeBackKeyboardThenEditor'] = true;
        await channel.invokeMethod<void>('convertFlutterSurfaceToImage');
        await tester.pump();
        await capture('07-same-revealed-answer', at: key('review-exit'));
        await tap(key('review-grade-incorrect'));
        // Deactivate remaining normal words without grading, leaving the captured retry.
        while (normal.current != null && !normal.currentIsRetry) {
          final id = normal.current!.item.entryId;
          await present(key('review-prompt-text'));
          await tap(key('review-reveal-target'));
          await tap(key('learning-edit-answer'));
          await tap(key('inline-active-$id'));
          await review.waitUntil(
            tester,
            () => normal.current?.item.entryId != id,
            description: 'inactive current skips',
          );
        }
        await present(key('review-retry-wait'));
        clock.set(instant.add(const Duration(seconds: 11)));
        await normal.refreshRetries();
        await tester.pumpAndSettle();
        expect(normal.currentIsRetry, isTrue);
        await tap(key('review-reveal-target'));
        await tap(key('learning-edit-answer'));
        final retryId = normal.current!.item.entryId;
        final retainedRetry = await db.select(db.retryObligations).get();
        final ordinals = await db.select(db.scopeAnswerOrdinals).get();
        await tester.enterText(key('inline-$retryId-native'), 'Frischer Apfel');
        await tester.pumpAndSettle();
        await tap(key('inline-complete-$retryId'));
        expect(normal.currentIsRetry, isTrue);
        await tap(key('learning-edit-answer'));
        await tap(key('inline-active-$retryId'));
        await review.waitUntil(
          tester,
          () => normal.current == null,
          description: 'inactive retry skipped',
        );
        expect(await db.select(db.retryObligations).get(), retainedRetry);
        expect(await db.select(db.scopeAnswerOrdinals).get(), ordinals);
        expect(find.byType(ReviewSummaryDialog), findsNothing);
        await tap(key('review-exit'));
        await present(find.byType(CollectionDetail));
        // Reactivate through the ordinary editor; reverse Speed retains its eligibility.
        await tap(key('vocabulary-${apple.id}'));
        await tap(key('inline-active-${apple.id}'));
        await tap(key('inline-complete-${apple.id}'));
        await tap(key('collection-speed-nativeToTarget'));
        await present(find.byType(SpeedSetupDialog));
        await tap(find.text(copy.text('learn.startSpeed')));
        await present(find.byType(SpeedSessionRoute));
        await present(key('review-prompt-text'));
        final speed = tester
            .widget<SpeedSessionRoute>(find.byType(SpeedSessionRoute))
            .session;
        final speedHandle = speed.current!;
        await tap(key('review-reveal-target'));
        await tap(key('learning-edit-answer'));
        await tester.enterText(
          key('inline-${speedHandle.entryId}-target'),
          'pomme',
        );
        await tester.pumpAndSettle();
        await tap(key('inline-complete-${speedHandle.entryId}'));
        expect(speed.current, same(speedHandle));
        expect(speed.revealed, isTrue);
        await capture('08-speed-edited-answer', at: key('speed-exit'));
        await tap(key('learning-edit-answer'));
        await tap(key('inline-active-${speedHandle.entryId}'));
        await review.waitUntil(
          tester,
          () => find.byType(SpeedSessionRoute).evaluate().isEmpty,
          description: 'inactive-only Speed exits without success',
        );
        expect(await db.select(db.scopeAnswerOrdinals).get(), ordinals);
        evidence['normalRetrySpeedActivity'] = true;
        var exported = await SqliteVocabularyJsonService(
          db,
        ).exportCollection(owner.id);
        final document = jsonDecode(exported) as Map;
        expect(document['schemaVersion'], 4);
        expect(
          ((document['collections'] as List).single['entries'] as List).every(
            (entry) => entry['active'] == false,
          ),
          isTrue,
        );
        final beforeImport = await completeSnapshot(db);
        final importedEntries =
            (document['collections'] as List).single['entries'] as List;
        importedEntries.first['active'] = true;
        final jsonService = SqliteVocabularyJsonService(db);
        final preview = await jsonService.analyzeImport(
          collectionId: owner.id,
          json: jsonEncode(document),
          groups: {VocabularyJsonGroup.activity},
        );
        expect(preview.canApply, isTrue);
        expect(preview.updatedCount, 1);
        expect(await completeSnapshot(db), beforeImport);
        await jsonService.applyImport(preview);
        final afterImport = await completeSnapshot(db);
        for (final table in [
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
          'collections',
        ]) {
          expect(afterImport[table], beforeImport[table]);
        }
        exported = await jsonService.exportCollection(owner.id);
        evidence['activityOnlyJsonPreservesLearning'] = true;
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.closed.future;
        final reopened = review.ReviewFixtureDatabase(file, clock);
        try {
          expect(
            await SqliteVocabularyJsonService(
              reopened,
            ).exportCollection(owner.id),
            exported,
          );
          expect(
            await SqliteVocabularyRepository(
              reopened,
            ).hintDefaultOfferHandled(owner.id),
            isTrue,
          );
        } finally {
          await reopened.close();
        }
        evidence['contentAndDefaultsReopen'] = true;
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        evidence['passed'] = passed;
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(evidence),
          flush: true,
        );
        debugPrint('PIKO_ROUND5_EVIDENCE:${directory.path}');
      }
    },
  );
}
