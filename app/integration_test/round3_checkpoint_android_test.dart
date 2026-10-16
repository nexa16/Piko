import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/speed/speed_numbers_break.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_reading.dart';

import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart'
    show CatalogueConfiguration, CatalogueJsonPlatform, settleCatalogueCapture;

// Coordinator protocol is the existing catalogue build-only APK, direct adb
// install -r -t, manual launch, attach-only drive, and host retrieval. Supply
// fresh PIKO_CATALOGUE_RUN/COMMIT/LOCALE/SCALE for each invocation. This test
// opens only a newly owned synthetic fixture.sqlite and retains its evidence.
const _plan = <String, String>{
  'home-populated': 'Populated Home and compact heading',
  'detail-both-normal-speed': 'First normal card with reading Piko and Speed',
  'detail-reverse-only': 'Reverse-only normal review owns the reading pose',
  'detail-zero': 'No normal or Speed action and no mascot',
  'speed-hidden': 'Speed hidden prompt and initial progress',
  'speed-revealed': 'Speed revealed answer and initial progress',
  'speed-partial-hidden': 'Speed next hidden prompt with 1 / 2 completed',
  'speed-game': 'Speed number break with 1 / 2 completed',
};

Map<String, int> _specRevisions(String id) => switch (id) {
  'home-populated' => {'UX-HOME-001': 1, 'UX-HEADER-002': 1},
  'detail-both-normal-speed' || 'detail-reverse-only' => {
    'MASCOT-001': 1,
    'UX-MASCOT-001': 2,
    'UX-COLL-008': 3,
    'UX-HEADER-002': 1,
  },
  'detail-zero' => {'MASCOT-001': 1, 'UX-MASCOT-001': 2, 'UX-COLL-008': 3},
  'speed-game' => {'UX-REVIEW-001': 4, 'SPEED-007': 3, 'SPEED-012': 2},
  _ => {'UX-REVIEW-001': 4},
};

Finder _key(String name) => find.byKey(ValueKey(name));
Finder _button(String label) => find.widgetWithText(PikoButton, label);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('round 3 checkpoint one Android smoke', (tester) async {
    final config = CatalogueConfiguration();
    expect(binding.registerTestTextInput, isFalse);
    tester.platformDispatcher.textScaleFactorTestValue = config.scale == '200'
        ? 2
        : 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}/round3-checkpoint1-${config.runId}-${config.locale}-${config.scale}',
    );
    if (await directory.exists()) {
      throw StateError('Refusing to overwrite visual delta: ${directory.path}');
    }
    await directory.create();
    final captures = <Map<String, Object?>>[];
    final manifest = File('${directory.path}/manifest.json');
    var status = 'running';
    String? failure;
    Future<void> writeManifest() async {
      await manifest.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'kind': 'round3-checkpoint1',
          'runId': config.runId,
          'commit': config.commit,
          'locale': config.locale,
          'scale': config.scale,
          'fixture': 'synthetic-three-collection-mascot-speed-v1',
          'palette': 'accepted Piko',
          'status': status,
          'failure': ?failure,
          'database': 'fixture.sqlite (synthetic; retained after drain/close)',
          'fixtureClock': '2026-10-16T09:00:00Z; unchanged during capture',
          'nativeIo': 'fixture transport, no personal clipboard/files',
          'numberShuffle':
              'production shuffle; positions recorded in capture metadata',
          'plan': _plan,
          'captures': captures,
          'notCaptured': _plan.keys
              .where((id) => !captures.any((entry) => entry['id'] == id))
              .toList(),
          'coverageGaps': {
            'scope':
                'Only latest Home, mascot and Speed progress deltas are captured; the full round-2 catalogue remains separate.',
            'review': 'Captured screenshots still require owner visual review.',
          },
        }),
        flush: true,
      );
    }

    await writeManifest();
    Future<void> capture(
      String id, {
      Finder? at,
      Map<String, Object?> metadata = const {},
    }) async {
      if (!_plan.containsKey(id) ||
          captures.any((entry) => entry['id'] == id)) {
        throw StateError('Unknown or duplicate visual delta state: $id');
      }
      await settleCatalogueCapture(tester, id, at: at);
      expect(tester.takeException(), isNull, reason: 'Before capture $id');
      final name = '${config.runId}-$id-${config.locale}-${config.scale}';
      final file = File('${directory.path}/$name.png');
      if (await file.exists()) throw StateError('Screenshot exists: $name');
      final bytes = await binding.takeScreenshot(name);
      expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      await file.writeAsBytes(bytes, flush: true);
      final scrollPositions = <Map<String, Object?>>[];
      final scrollables = find.byType(Scrollable);
      for (var index = 0; index < scrollables.evaluate().length; index++) {
        final state = tester.state<ScrollableState>(scrollables.at(index));
        final position = state.position;
        if (!position.hasContentDimensions ||
            position.maxScrollExtent <= position.minScrollExtent) {
          continue;
        }
        scrollPositions.add({
          'index': index,
          'axis': position.axis.name,
          'pixels': position.pixels,
          'minScrollExtent': position.minScrollExtent,
          'maxScrollExtent': position.maxScrollExtent,
          'viewportDimension': position.viewportDimension,
        });
      }
      captures.add({
        'id': id,
        'file': '$name.png',
        'locale': config.locale,
        'scale': config.scale,
        'fixture': 'synthetic-three-collection-mascot-speed-v1',
        'commit': config.commit,
        'description': _plan[id],
        'specRevisions': _specRevisions(id),
        'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'physicalViewport': {
          'width': tester.view.physicalSize.width,
          'height': tester.view.physicalSize.height,
        },
        'devicePixelRatio': tester.view.devicePixelRatio,
        'logicalViewport': {
          'width':
              tester.view.physicalSize.width / tester.view.devicePixelRatio,
          'height':
              tester.view.physicalSize.height / tester.view.devicePixelRatio,
        },
        if (at != null) 'anchor': at.toString(),
        'scrollPositions': scrollPositions,
        ...metadata,
      });
      await writeManifest();
      debugPrint('PIKO_VISUAL_DELTA_ARTIFACT:${file.path}');
    }

    final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 16, 9));
    final databaseFile = File('${directory.path}/fixture.sqlite');
    if (await databaseFile.exists()) {
      throw StateError('Refusing to reuse visual delta database');
    }
    final db = review.ReviewFixtureDatabase(databaseFile, clock);
    final collections = SqliteCollectionsRepository(db);
    final vocabulary = SqliteVocabularyRepository(db);
    final learning = SqliteLearningRepository(db);
    var mounted = false;
    var completed = false;

    Future<void> present(Finder finder, String description) => review.waitUntil(
      tester,
      () => finder.evaluate().isNotEmpty,
      description: description,
    );
    Future<void> tap(Finder finder) => review.tapVisible(tester, finder);
    Future<CollectionRecord> create(String name) => collections.create(
      name: name,
      targetLanguage: VocabularyLanguage.korean,
      nativeLanguage: VocabularyLanguage.german,
    );
    Future<void> scheduleAway(
      String entryId, {
      required bool forward,
      required bool reverse,
    }) async {
      for (final item in await learning.forEntry(entryId)) {
        final selected = item.direction == LearningDirection.targetToNative
            ? forward
            : reverse;
        if (!selected) continue;
        await learning.saveCard(
          item.id,
          item.card..due = clock.now().add(const Duration(days: 7)),
        );
        await (db.update(db.learningItems)
              ..where((row) => row.id.equals(item.id)))
            .write(const LearningItemsCompanion(speedCompleted: Value(true)));
      }
    }

    Future<void> open(CollectionRecord collection) async {
      await tap(
        find.descendant(
          of: _key('collection-${collection.id}'),
          matching: find.text(collection.name),
        ),
      );
      await present(find.byType(CollectionDetail), 'Collection Detail');
      await review.waitUntil(
        tester,
        () => tester
            .widget<CollectionDetail>(find.byType(CollectionDetail))
            .queryBinding!
            .ready,
        description: 'ready Detail projection',
      );
    }

    try {
      await SqliteSettingsRepository(db).write('locale', config.locale);
      final both = await create('Korean Both');
      final reverse = await create('Korean Reverse');
      final zero = await create('Korean Zero');
      await vocabulary.create(
        collectionId: both.id,
        targetText: '사과',
        nativeText: 'Apfel',
      );
      await vocabulary.create(
        collectionId: both.id,
        targetText: '책',
        nativeText: 'Buch',
      );
      final reverseWord = await vocabulary.create(
        collectionId: reverse.id,
        targetText: '물',
        nativeText: 'Wasser',
      );
      await scheduleAway(reverseWord.id, forward: true, reverse: false);
      for (final item in await learning.forEntry(reverseWord.id)) {
        if (item.direction == LearningDirection.nativeToTarget) {
          await (db.update(db.learningItems)
                ..where((row) => row.id.equals(item.id)))
              .write(const LearningItemsCompanion(speedCompleted: Value(true)));
        }
      }
      final zeroWord = await vocabulary.create(
        collectionId: zero.id,
        targetText: '학교',
        nativeText: 'Schule',
      );
      await scheduleAway(zeroWord.id, forward: true, reverse: true);

      mounted = true;
      await tester.pumpWidget(
        PikoApp(
          home: PikoRuntime(
            databaseFactory: () => db,
            jsonPlatform: CatalogueJsonPlatform(),
          ),
        ),
      );
      final copy = await hydratedRuntimeCopy(tester);
      expect(copy.locale, config.locale);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await present(_key('collection-${both.id}'), 'populated Home');
      await capture('home-populated');

      await open(both);
      await present(_key('collection-review-targetToNative'), 'both review');
      await present(_key('collection-speed-targetToNative'), 'both Speed');
      expect(find.byType(PikoReading), findsOneWidget);
      await capture('detail-both-normal-speed', at: find.byType(PikoReading));
      await tap(_button(copy.text('common.back')));

      await open(reverse);
      expect(_key('collection-review-targetToNative'), findsNothing);
      await present(_key('collection-review-nativeToTarget'), 'reverse review');
      expect(find.byType(PikoReading), findsOneWidget);
      expect(_key('collection-speed-actions'), findsNothing);
      await capture('detail-reverse-only', at: find.byType(PikoReading));
      await tap(_button(copy.text('common.back')));

      await open(zero);
      expect(_key('collection-review-targetToNative'), findsNothing);
      expect(_key('collection-review-nativeToTarget'), findsNothing);
      expect(_key('collection-speed-actions'), findsNothing);
      expect(find.byType(PikoReading), findsNothing);
      await capture('detail-zero', at: find.text(copy.text('r2.caughtUp')));
      await tap(_button(copy.text('common.back')));

      await open(both);
      await tap(_key('collection-speed-targetToNative'));
      await present(find.byType(SpeedSetupDialog), 'Speed setup');
      await tap(_button(copy.text('learn.startSpeed')));
      await present(find.byType(SpeedSessionRoute), 'Speed route');
      await present(_key('review-prompt'), 'Speed hidden prompt');
      await capture('speed-hidden', at: _key('review-prompt'));
      await tap(_key('review-prompt'));
      await present(_key('review-answer-text'), 'Speed revealed answer');
      await capture('speed-revealed', at: _key('review-answer-text'));
      await tap(_key('speed-grade-correct'));
      await present(_key('review-prompt'), 'second Speed hidden prompt');
      await review.waitUntil(
        tester,
        () => find
            .text(
              copy.text('learn.speedProgress', {'completed': 1, 'total': 2}),
            )
            .evaluate()
            .isNotEmpty,
        description: 'one of two Speed words completed',
      );
      await capture('speed-partial-hidden', at: _key('speed-progress-count'));
      await tap(_key('review-prompt'));
      await tap(_key('speed-grade-incorrect'));
      await present(find.byType(SpeedNumbersBreak), 'Speed number break');
      final speed = tester
          .widget<SpeedSessionRoute>(find.byType(SpeedSessionRoute))
          .session;
      await review.waitUntil(
        tester,
        () => speed.state?.numberGame != null,
        description: 'started Speed number break',
      );
      expect(speed.state!.completedEntryIds.length, 1);
      await capture(
        'speed-game',
        at: find.byType(SpeedNumbersBreak),
        metadata: {
          'completedVocabulary': speed.state!.completedEntryIds.length,
          'totalVocabulary': speed.state!.entryIds.length,
          'numberPositions': speed.state!.numberGame!.positions,
        },
      );
      expect(tester.takeException(), isNull);
      expect(captures.length, _plan.length);
      completed = true;
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
      } catch (error) {
        completed = false;
        failure = 'Drain/close failed: $error';
        rethrow;
      } finally {
        status = completed
            ? 'captured-not-yet-visually-reviewed'
            : 'failed-partial';
        await writeManifest();
        debugPrint('PIKO_VISUAL_DELTA_MANIFEST:${manifest.path}');
      }
    }
  });
}
