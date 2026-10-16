import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:piko/ui/components/piko_dialog.dart';

import '../test/data/regular_reviews_test.dart' show Fixture, instant;
import '../test/data/speed_eligibility_test.dart' show completeSnapshot;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

Finder _key(String id) => find.byKey(ValueKey(id));
Finder _button(String label) => find.widgetWithText(PikoButton, label);
Finder _entryField(String side) =>
    find.descendant(of: _key('draft-$side'), matching: find.byType(TextField));

/// One EN normal-size CP4 pass. Only a newly owned synthetic file is opened;
/// fixture JSON transport never reads personal files or the actual clipboard.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('round3 optional content: editor, JSONv2, review and Speed', (
    tester,
  ) async {
    final config = CatalogueConfiguration();
    expect(config.locale, 'en');
    expect(config.scale, 'normal');
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}/round3-content-${config.runId}',
    );
    if (await directory.exists()) {
      throw StateError('Refusing to overwrite an existing content fixture');
    }
    await directory.create();
    final file = File('${directory.path}/fixture.sqlite');
    final clock = review.ReviewFixtureClock(instant);
    final db = review.ReviewFixtureDatabase(file, clock);
    final fixture = Fixture(database: db);
    final platform = CatalogueJsonPlatform();
    final captures = <Map<String, Object?>>[];
    final retained = <String, Object?>{};
    Map<String, Object?>? baseline;
    var mounted = false, passed = false;
    String? failure;
    String? savedId;
    const expectedContent = VocabularyContent(
      exampleTargetText: 'Un café, merci.',
      exampleNativeText: 'Einen Kaffee, bitte.',
      hintText: 'Imported hot drink',
      hintVisibility: HintVisibility.hidden,
    );

    Future<void> manifest() async {
      await File('${directory.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'implementationRound': 3,
          'checkpoint': 4,
          'runId': config.runId,
          'baseCommit': config.commit,
          'sourceSnapshot': const String.fromEnvironment(
            'PIKO_WORKFLOW_SOURCE',
          ),
          'locale': 'en',
          'scale': 'normal',
          'palette': 'accepted Piko nine-color',
          'status': passed
              ? 'passed-captures-await-visual-review'
              : 'running-or-partial',
          'failure': ?failure,
          'fixture':
              'new isolated schema-current database; two unrelated '
              'sentinel Collections with real directional learning; one UI-created content word',
          'database': 'fixture.sqlite; retained after drained close and reopen',
          'transports': 'CatalogueJsonPlatform; synthetic JSON only',
          'captures': captures,
          'retained': retained,
          'limits': [
            'One EN normal-size emulator pass, seven keyboard-hidden captures.',
            'Native file picker/clipboard, process kill, large text and DE are not tested.',
            'Review/Speed exit without grading; persistence of existing learning is asserted exactly.',
          ],
        }),
        flush: true,
      );
      debugPrint(
        'PIKO_ROUND3_CONTENT_MANIFEST:${directory.path}/manifest.json',
      );
    }

    Future<void> present(Finder finder, String description) => review.waitUntil(
      tester,
      () => finder.evaluate().isNotEmpty,
      description: description,
    );
    Future<void> tap(Finder finder) => review.tapVisible(tester, finder);
    Future<void> enter(Finder finder, String text) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await tester.enterText(finder, text);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(finder).controller!.text, text);
    }

    Future<void> capture(String id, Finder at) async {
      await settleCatalogueCapture(tester, id, at: at);
      expect(tester.takeException(), isNull, reason: id);
      final name = '${config.runId}-$id-en-normal';
      final bytes = await binding.takeScreenshot(name);
      expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes, flush: true);
      captures.add({
        'id': id,
        'file': '$name.png',
        'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'physicalViewport': {
          'width': tester.view.physicalSize.width,
          'height': tester.view.physicalSize.height,
        },
        'devicePixelRatio': tester.view.devicePixelRatio,
      });
      await manifest();
      debugPrint('PIKO_ROUND3_CONTENT_ARTIFACT:${directory.path}/$name.png');
    }

    Future<void> preserved(PikoDatabase database) async {
      final after = await completeSnapshot(database);
      for (final table in baseline!.entries) {
        if (table.key == 'vocabulary_entries') {
          final expected = [
            for (final row
                in (table.value! as List).cast<Map<String, Object?>>())
              {
                ...row,
                if (row['id'] == savedId) 'hint_text': expectedContent.hintText,
              },
          ];
          expect(
            after[table.key],
            expected,
            reason: 'Only imported Hint may change',
          );
        } else {
          expect(after[table.key], table.value, reason: table.key);
        }
      }
      final records = SqliteVocabularyRepository(database);
      expect(
        (await records.watchById(savedId!).first)!.content,
        expectedContent,
      );
      expect(
        (await records.watchById(fixture.entry.id).first)!.content,
        const VocabularyContent(),
        reason: 'Changing the new-entry default never rewrites existing words',
      );
      expect(
        (await records.watchById(fixture.other.id).first)!.content,
        const VocabularyContent(),
      );
      expect(
        await SqliteSettingsRepository(
          database,
        ).read(HintVisibility.settingKey),
        HintVisibility.hidden.name,
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    }

    try {
      await manifest();
      await fixture.initialize();
      await fixture.review(rating: LearningRating.good);
      await fixture.review(
        word: fixture.other,
        reverse: true,
        rating: LearningRating.again,
      );
      final collection = await fixture.collections.create(
        name: 'Café examples',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final settings = SqliteSettingsRepository(db);
      await settings.write('locale', 'en');
      await settings.write(
        PreferredDirection.settingKey,
        PreferredDirection.targetToNative.name,
      );
      await settings.write(
        HintVisibility.settingKey,
        HintVisibility.always.name,
      );
      mounted = true;
      await tester.pumpWidget(
        PikoApp(
          home: PikoRuntime(databaseFactory: () => db, jsonPlatform: platform),
        ),
      );
      final copy = await hydratedRuntimeCopy(tester);
      await present(find.byType(CollectionsHome), 'Home');
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await capture(
        'home-synthetic-collections',
        _key('home-collections-heading'),
      );
      await tap(_key('collection-${collection.id}'));
      await present(find.byType(CollectionDetail), 'empty content Collection');
      await tap(_button(copy.text('collection.addFirstWord')));
      await present(find.byType(EntrySessionScreen), 'content Entry');
      final entry = tester.widget<EntrySessionScreen>(
        find.byType(EntrySessionScreen),
      );
      await review.waitUntil(
        tester,
        () => entry.session.contentReady,
        description: 'default hydration',
      );
      expect(entry.session.draft.content.hintVisibility, HintVisibility.always);
      await enter(_entryField('target'), ' Café ');
      await enter(_entryField('native'), ' Kaffee ');
      await enter(_key('content-example-target'), ' Un café, merci. ');
      await enter(_key('content-example-native'), ' Einen Kaffee, bitte. ');
      await enter(_key('content-hint'), ' A hot drink ');
      await tap(_key('content-hint-visibility-hidden'));
      await tap(
        find.widgetWithText(PikoCheckbox, copy.text('vocab.makeHintDefault')),
      );
      expect(entry.session.draft.makeHintVisibilityDefault, isTrue);
      expect(entry.session.draft.content.hintText, ' A hot drink ');
      await capture('optional-content-editor', _key('content-hint'));
      await tap(_button(copy.text('action.saveNext')));
      await review.waitUntil(
        tester,
        () =>
            entry.session.confirmedEntries.length == 1 && !entry.session.isBusy,
        description: 'content save and next draft',
      );
      final saved = entry.session.confirmedEntries.single;
      savedId = saved.id;
      expect(saved.targetText, 'Café');
      expect(
        saved.content.exampleTargetText,
        expectedContent.exampleTargetText,
      );
      expect(
        saved.content.exampleNativeText,
        expectedContent.exampleNativeText,
      );
      expect(saved.content.hintText, 'A hot drink');
      expect(saved.content.hintVisibility, HintVisibility.hidden);
      expect(
        entry.session.draft.content,
        const VocabularyContent(hintVisibility: HintVisibility.hidden),
      );
      expect(entry.session.draft.makeHintVisibilityDefault, isFalse);
      expect(
        (await fixture.vocabulary.watchById(fixture.entry.id).first)!
            .content
            .hintVisibility,
        HintVisibility.always,
      );
      baseline = await completeSnapshot(db);

      // Export/import through the real page, but exclusively fixture-owned transport.
      await tap(_button(copy.text('json.title')));
      await present(find.byType(VocabularyJsonPage), 'JSON page');
      await tap(_key('json-export-tab'));
      await tap(_button(copy.text('json.copy')));
      await present(find.text(copy.text('json.copied')), 'JSONv2 export');
      final envelope = jsonDecode(platform.exported!) as Map<String, dynamic>;
      expect(envelope['schemaVersion'], 2);
      final exportedEntries =
          ((envelope['collections'] as List).single as Map)['entries'] as List;
      final exported = exportedEntries.cast<Map>().single;
      expect(exported['id'], savedId);
      expect(exported['example'], {
        'targetText': 'Un café, merci.',
        'nativeText': 'Einen Kaffee, bitte.',
      });
      expect(exported['hint'], {'text': 'A hot drink', 'visibility': 'hidden'});
      (exported['hint'] as Map)['text'] = expectedContent.hintText;
      platform.clipboard = const JsonEncoder.withIndent('  ').convert(envelope);
      await tap(_key('json-import-tab'));
      await tap(_button(copy.text('json.paste')));
      await tap(_button(copy.text('json.analyze')));
      await present(
        _button(copy.text('json.apply')),
        'optional-content import preview',
      );
      await capture('json-content-preview', _button(copy.text('json.apply')));
      await tap(_button(copy.text('json.apply')));
      await present(
        find.byType(PikoDialog),
        'confirmed optional-content replacement',
      );
      await tap(
        find.descendant(
          of: find.byType(PikoDialog),
          matching: _button(copy.text('json.apply')),
        ),
      );
      await present(
        _button(copy.text('json.returnToCollection')),
        'JSONv2 content import success',
      );
      await preserved(db);
      await tap(_button(copy.text('json.returnToCollection')));
      await present(find.byType(CollectionDetail), 'Collection after import');
      expect(find.byType(EntrySessionScreen), findsNothing);
      await capture('content-collection-detail', _key('vocabulary-$savedId'));

      await tap(_key('collection-review-targetToNative'));
      await present(find.byType(ReviewSessionRoute), 'normal content review');
      await present(_key('learning-prompt-example'), 'stored prompt example');
      final normal = tester
          .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
          .session;
      expect(find.text('Un café, merci.'), findsOneWidget);
      expect(find.text('Einen Kaffee, bitte.'), findsNothing);
      expect(find.text(expectedContent.hintText!), findsNothing);
      await capture('normal-hidden-hint', _key('learning-reveal-hint'));
      await tap(_key('learning-reveal-hint'));
      expect(find.text(expectedContent.hintText!), findsOneWidget);
      expect(_key('review-answer-text'), findsNothing);
      expect(normal.progress.completed, 0);
      await tap(review.revealTarget);
      await present(_key('review-answer-text'), 'normal answer');
      expect(find.text('Un café, merci.'), findsOneWidget);
      expect(find.text('Einen Kaffee, bitte.'), findsOneWidget);
      expect(find.text(expectedContent.hintText!), findsOneWidget);
      expect(normal.progress.completed, 0);
      await capture('normal-content-answer', _key('learning-answer-example'));
      await tap(_key('review-exit'));
      await present(
        find.byType(CollectionDetail),
        'Collection after ungraded normal exit',
      );
      await preserved(db);

      await tap(_key('collection-speed-targetToNative'));
      await present(find.byType(SpeedSetupDialog), 'Speed setup');
      await tap(_button(copy.text('learn.startSpeed')));
      await present(find.byType(SpeedSessionRoute), 'Speed content question');
      await present(_key('learning-reveal-hint'), 'fresh hidden Hint in Speed');
      final speed = tester
          .widget<SpeedSessionRoute>(find.byType(SpeedSessionRoute))
          .session;
      final turn = speed.current;
      expect(turn!.entryId, savedId);
      expect(find.text('Un café, merci.'), findsOneWidget);
      expect(find.text('Einen Kaffee, bitte.'), findsNothing);
      expect(find.text(expectedContent.hintText!), findsNothing);
      await tap(_key('learning-reveal-hint'));
      expect(speed.current, same(turn));
      expect(speed.revealed, isFalse);
      expect(_key('review-answer-text'), findsNothing);
      expect(find.text(expectedContent.hintText!), findsOneWidget);
      await tap(_key('review-prompt'));
      await present(_key('review-answer-text'), 'Speed content answer');
      expect(speed.revealed, isTrue);
      expect(speed.state!.completedEntryIds, isEmpty);
      expect(find.text('Un café, merci.'), findsOneWidget);
      expect(find.text('Einen Kaffee, bitte.'), findsOneWidget);
      expect(find.text(expectedContent.hintText!), findsOneWidget);
      await capture('speed-content-answer', _key('learning-answer-example'));
      await tap(_key('speed-exit'));
      await present(
        find.byType(CollectionDetail),
        'Collection after ungraded Speed exit',
      );
      await tap(_button(copy.text('action.new')));
      await present(find.byType(EntrySessionScreen), 'fresh entry session');
      final fresh = tester.widget<EntrySessionScreen>(
        find.byType(EntrySessionScreen),
      );
      await review.waitUntil(
        tester,
        () => fresh.session.contentReady,
        description: 'new session stored default',
      );
      expect(
        fresh.session.draft.content,
        const VocabularyContent(hintVisibility: HintVisibility.hidden),
      );
      expect(fresh.session.draft.makeHintVisibilityDefault, isFalse);
      expect(fresh.session.draft.targetText, isEmpty);
      await tap(_button(copy.text('entry.complete')));
      await present(
        find.byType(CollectionDetail),
        'Finish empty fresh session',
      );
      await preserved(db);
      retained.addAll({
        'collectionId': collection.id,
        'entryId': savedId,
        'jsonSchemaVersion': 2,
        'newDraftInheritedHidden': true,
        'existingWordsRetainedAlways': true,
        'learningTablesPreservedExactly': true,
      });
      expect(captures.length, 7);
      passed = true;
    } catch (error) {
      failure = error.toString();
      rethrow;
    } finally {
      try {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (mounted) {
          await db.closed.future.timeout(const Duration(seconds: 15));
        } else {
          await db.close();
        }
        if (passed) {
          final reopened = review.ReviewFixtureDatabase(file, clock);
          try {
            await preserved(reopened);
            retained['fileReopenVerified'] = true;
          } finally {
            await reopened.close();
          }
        }
      } catch (error) {
        passed = false;
        failure = 'Drain/reopen: $error';
        rethrow;
      } finally {
        await manifest();
      }
    }
  });
}
