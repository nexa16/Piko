import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/categories/category_assignment_picker.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';

import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

Finder _key(String id) => find.byKey(ValueKey(id));
Finder _button(String label) => find.widgetWithText(PikoButton, label);
Finder _entryField(String side) =>
    find.descendant(of: _key('draft-$side'), matching: find.byType(TextField));

/// One normal-size English acceptance pass. Only fixture.sqlite below the
/// unique round3-workflow directory is opened; installed personal data and
/// clipboard/file transports are outside this fixture's ownership.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('round3 workflow: native entry, stable selection, JSON and review', (
    tester,
  ) async {
    final config = CatalogueConfiguration();
    expect(config.locale, 'en');
    expect(config.scale, 'normal');
    expect(binding.registerTestTextInput, isFalse);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}/round3-workflow-${config.runId}',
    );
    if (await directory.exists()) {
      throw StateError('Refusing existing run directory');
    }
    await directory.create();
    final databaseFile = File('${directory.path}/fixture.sqlite');
    final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 16, 9));
    final db = review.ReviewFixtureDatabase(databaseFile, clock);
    final collections = SqliteCollectionsRepository(db);
    final vocabulary = SqliteVocabularyRepository(db);
    final categories = SqliteCategoriesRepository(db);
    final platform = CatalogueJsonPlatform();
    final captures = <Map<String, Object?>>[];
    var mounted = false, complete = false;
    String? failure;
    final retained = <String, Object?>{};
    final learningSnapshot = <LearningDirection, List<Map<String, Object?>>>{};
    Future<void> manifest() async {
      await File('${directory.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'implementationRound': 3,
          'checkpoint': 2,
          'runId': config.runId,
          'baseCommit': config.commit,
          'sourceSnapshot': const String.fromEnvironment(
            'PIKO_WORKFLOW_SOURCE',
            defaultValue: 'coordinator must pair with source manifest',
          ),
          'locale': 'en',
          'scale': 'normal',
          'palette': 'accepted Piko nine-color',
          'status': complete
              ? 'passed-captures-await-visual-review'
              : 'running-or-partial',
          'failure': ?failure,
          'database':
              'fixture.sqlite; synthetic, retained after drained close and reopen verification',
          'transports': 'CatalogueJsonPlatform; no personal clipboard/files',
          'captures': captures,
          'retained': retained,
          'limits': [
            'One EN normal-size emulator pass; no DE/large-text matrix.',
            'PNG capture uses Flutter surface; measured real IME inset/focus are recorded. Pair external adb screencap for OS keyboard pixels.',
            'No native file-picker/clipboard, process-kill or personal-database acceptance.',
          ],
        }),
        flush: true,
      );
      debugPrint(
        'PIKO_ROUND3_WORKFLOW_MANIFEST:${directory.path}/manifest.json',
      );
    }

    Future<void> wait(bool Function() ready, String description) =>
        review.waitUntil(tester, ready, description: description);
    Future<void> present(Finder finder, String description) =>
        wait(() => finder.evaluate().isNotEmpty, description);
    Future<void> tap(Finder finder) => review.tapVisible(tester, finder);
    Future<void> enter(Finder finder, String value) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await tester.enterText(finder, value);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(finder).controller!.text, value);
    }

    Future<void> capture(String id, {Finder? at, bool keyboard = false}) async {
      if (captures.any((item) => item['id'] == id)) {
        throw StateError('Duplicate capture');
      }
      if (!keyboard) await settleCatalogueCapture(tester, id, at: at);
      final screen = find.byType(Scaffold).last;
      final inset = MediaQuery.viewInsetsOf(tester.element(screen)).bottom;
      if (keyboard) {
        expect(inset, greaterThan(0), reason: 'Actual OS IME required');
      }
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
        'implementationRound': 3,
        'realKeyboardInset': inset,
        'keyboardExpected': keyboard,
        'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'physicalViewport': {
          'width': tester.view.physicalSize.width,
          'height': tester.view.physicalSize.height,
        },
        'devicePixelRatio': tester.view.devicePixelRatio,
      });
      await manifest();
      debugPrint('PIKO_ROUND3_WORKFLOW_ARTIFACT:${directory.path}/$name.png');
    }

    Future<void> revealAction(Finder finder) async {
      for (var attempt = 0; attempt < 10; attempt++) {
        final area = tester.getRect(_key('entry-stack'));
        final action = tester.getRect(finder);
        if (action.top >= area.top && action.bottom <= area.bottom) return;
        final delta = action.bottom > area.bottom
            ? area.bottom - action.bottom - 24
            : area.top - action.top + 24;
        await tester.dragFrom(
          Offset(area.left + 4, area.center.dy),
          Offset(0, delta),
        );
        await tester.pumpAndSettle();
      }
      fail('Entry action is not fully visible above actual IME');
    }

    try {
      await manifest();
      final collection = await collections.create(
        name: 'Korean Basics',
        targetLanguage: VocabularyLanguage.korean,
        nativeLanguage: VocabularyLanguage.german,
      );
      for (final pair in const [
        ('사과', 'Apfel'),
        ('물', 'Wasser'),
        ('학교', 'Schule'),
        ('친구', 'Freund'),
        ('책', 'Buch'),
      ]) {
        await vocabulary.create(
          collectionId: collection.id,
          targetText: pair.$1,
          nativeText: pair.$2,
        );
      }
      final originals = await vocabulary.watchByCollection(collection.id).first;
      final topic = await categories.createDimension(
        collectionId: collection.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final food = await categories.createValue(
        dimensionId: topic.id,
        name: 'Food',
      );
      await categories.createValue(dimensionId: topic.id, name: 'School');
      await SqliteSettingsRepository(db).write('locale', 'en');
      mounted = true;
      await tester.pumpWidget(
        PikoApp(
          home: PikoRuntime(databaseFactory: () => db, jsonPlatform: platform),
        ),
      );
      final copy = await hydratedRuntimeCopy(tester);
      await present(find.byType(CollectionsHome), 'Home');
      await tap(_key('collection-${collection.id}'));
      await present(
        _key('collection-review-targetToNative'),
        'populated Collection',
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await capture('collection-detail');

      await tap(_button(copy.text('action.new')));
      await present(find.byType(EntrySessionScreen), 'Entry');
      await enter(_entryField('target'), '강아지');
      final imeDeadline = DateTime.now().add(const Duration(seconds: 15));
      while (MediaQuery.viewInsetsOf(
                tester.element(find.byType(EntrySessionScreen)),
              ).bottom ==
              0 &&
          DateTime.now().isBefore(imeDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Allow actual Android inset animation to settle; pump alone advances
      // Flutter frames but cannot finish an OS animation's wall-clock interval.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        MediaQuery.viewInsetsOf(
          tester.element(find.byType(EntrySessionScreen)),
        ).bottom,
        greaterThan(0),
        reason: 'Native keyboard must open for real input',
      );
      final targetBounds = tester.getRect(_key('draft-target'));
      final inputViewport = tester.getRect(_key('entry-stack'));
      expect(targetBounds.top, greaterThanOrEqualTo(inputViewport.top - 1));
      expect(targetBounds.bottom, lessThanOrEqualTo(inputViewport.bottom + 1));
      await enter(_entryField('native'), 'Hund');
      final saveNext = find.byTooltip(copy.text('action.saveNext'));
      await revealAction(saveNext);
      expect(find.text(copy.text('action.saveNext')), findsOneWidget);
      final viewport = tester.getRect(_key('entry-stack'));
      expect(
        tester.getRect(saveNext).bottom,
        lessThanOrEqualTo(viewport.bottom),
      );
      debugPrint('PIKO_ROUND3_IME_READY:${config.runId}');
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump();
      await capture('entry-keyboard-save-next', keyboard: true);

      await tap(_key('category-picker-draft-${topic.id}'));
      await present(find.byType(CategoryAssignmentPicker), 'assignment popup');
      await settleCatalogueCapture(tester, 'selection-measurement');
      final row = _key('category-value-${food.id}');
      await present(row, 'category values');
      final rowBefore = tester.getRect(row),
          titleBefore = tester.getRect(find.text('Topic').last);
      expect(_button(copy.text('r2.apply')), findsNothing);
      await tap(row);
      expect(tester.getRect(row), rowBefore);
      expect(tester.getRect(find.text('Topic').last), titleBefore);
      await capture('category-selection-changed');
      await tap(_button(copy.text('r2.apply')));
      await wait(
        () => find.byType(CategoryAssignmentPicker).evaluate().isEmpty,
        'assignment applied',
      );
      final entryScreen = tester.widget<EntrySessionScreen>(
        find.byType(EntrySessionScreen),
      );
      expect(entryScreen.session.draft.assignments[topic.id], {food.id});
      await tap(saveNext);
      await wait(
        () =>
            entryScreen.session.confirmedEntries.length == 1 &&
            !entryScreen.session.isBusy,
        'Save & Next durable',
      );
      expect(entryScreen.session.draft.targetText, '');
      expect(entryScreen.session.draft.nativeText, '');
      final saved = (await vocabulary.watchByCollection(collection.id).first)
          .singleWhere((word) => word.targetText == '강아지');
      expect(saved.nativeText, 'Hund');
      expect((await categories.assignments(saved.id)).single.valueIds, {
        food.id,
      });
      learningSnapshot.addAll({
        for (final direction in LearningDirection.values)
          direction: await review.directionState(db, collection.id, direction),
      });

      // The same empty draft remains owned while the JSON page is open.
      await settleCatalogueCapture(tester, 'entry-before-json');
      await tap(_button(copy.text('json.title')));
      await present(find.byType(VocabularyJsonPage), 'Import');
      await capture('json-import', at: _key('json-import-tab'));
      final jsonPage = tester.widget<VocabularyJsonPage>(
        find.byType(VocabularyJsonPage),
      );
      await tap(_key('json-export-tab'));
      await tap(_button(copy.text('json.copy')));
      await present(find.text(copy.text('json.copied')), 'Export feedback');
      final exported = platform.exported!;
      expect((jsonDecode(exported) as Map)['collections'], isNotEmpty);
      await capture('json-export', at: find.text(copy.text('json.copied')));
      final envelope = jsonDecode(exported) as Map<String, dynamic>;
      final entries =
          ((envelope['collections'] as List).single as Map)['entries'] as List;
      final updated = entries.cast<Map>().singleWhere(
        (entry) => entry['id'] == originals.first.id,
      );
      updated['nativeText'] = 'Apfel (updated fixture)';
      platform.clipboard = const JsonEncoder.withIndent('  ').convert(envelope);
      await tap(_key('json-import-tab'));
      await tap(_button(copy.text('json.paste')));
      await tap(_button(copy.text('json.analyze')));
      await present(_button(copy.text('json.apply')), 'Import preview');
      await capture('json-preview', at: _button(copy.text('json.apply')));
      await tap(_button(copy.text('json.apply')));
      await present(
        find.text(copy.text('json.confirmTitle')),
        'replacement confirmation',
      );
      await tap(
        find.descendant(
          of: find.byType(PikoDialog),
          matching: _button(copy.text('json.apply')),
        ),
      );
      await present(
        _button(copy.text('json.returnToCollection')),
        'Import success',
      );
      await capture(
        'json-success',
        at: _button(copy.text('json.returnToCollection')),
      );
      for (final direction in LearningDirection.values) {
        expect(
          await review.directionState(db, collection.id, direction),
          learningSnapshot[direction],
        );
      }
      expect(
        (await vocabulary.watchById(originals.first.id).first)!.nativeText,
        'Apfel (updated fixture)',
      );
      expect(jsonPage.collection.id, collection.id);
      await tap(_button(copy.text('json.returnToCollection')));
      await wait(
        () =>
            find.byType(VocabularyJsonPage).evaluate().isEmpty &&
            find.byType(EntrySessionScreen).evaluate().isEmpty,
        'success returns to Collection',
      );
      expect(find.byType(CollectionDetail), findsOneWidget);
      await tap(_key('collection-review-targetToNative'));
      await present(find.byType(ReviewSessionRoute), 'normal review');
      await present(review.revealTarget, 'stored prompt');
      await tap(review.revealTarget);
      await present(_key('review-answer-text'), 'revealed translation');
      await capture('normal-review-revealed', at: _key('review-answer-text'));
      final session = tester
          .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
          .session;
      expect(session.progress.completed, 0);
      expect(session.progress.firstTryCorrect, 0);
      await tap(_key('review-exit'));
      await present(
        find.byType(CollectionDetail),
        'Collection after safe review exit',
      );
      for (final direction in LearningDirection.values) {
        expect(
          await review.directionState(db, collection.id, direction),
          learningSnapshot[direction],
        );
      }
      expect(
        (await vocabulary.watchByCollection(collection.id).first).length,
        6,
      );
      retained.addAll({
        'collectionId': collection.id,
        'savedEntryId': saved.id,
        'updatedEntryId': originals.first.id,
        'categoryValueId': food.id,
        'entryCount': 6,
      });
      expect(captures.length, 8);
      complete = true;
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
        if (complete) {
          final reopened = review.ReviewFixtureDatabase(databaseFile, clock);
          try {
            final records = await SqliteVocabularyRepository(
              reopened,
            ).watchByCollection(retained['collectionId']! as String).first;
            expect(records.length, 6);
            expect(
              records
                  .singleWhere((entry) => entry.id == retained['savedEntryId'])
                  .nativeText,
              'Hund',
            );
            expect(
              records
                  .singleWhere(
                    (entry) => entry.id == retained['updatedEntryId'],
                  )
                  .nativeText,
              'Apfel (updated fixture)',
            );
            expect(
              (await SqliteCategoriesRepository(reopened).assignments(
                retained['savedEntryId']! as String,
              )).single.valueIds,
              {retained['categoryValueId']},
            );
            for (final direction in LearningDirection.values) {
              expect(
                await review.directionState(
                  reopened,
                  retained['collectionId']! as String,
                  direction,
                ),
                learningSnapshot[direction],
              );
            }
            retained['fileReopenVerified'] = true;
            retained['directionalLearningPreservedThroughImportAndReopen'] =
                true;
          } finally {
            await reopened.close();
          }
        }
      } catch (error) {
        complete = false;
        failure = 'Drain/reopen verification: $error';
        rethrow;
      } finally {
        await manifest();
      }
    }
  });
}
