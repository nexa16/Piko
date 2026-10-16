import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_field.dart';
import '../test/data/regular_reviews_test.dart' show Fixture, instant;
import '../test/data/speed_eligibility_test.dart' show completeSnapshot;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/frozen_v12_schema.dart';
import 'support/round2_catalogue_fixture.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _button(String label) => find.widgetWithText(PikoButton, label);

/// Retains a newly owned synthetic schema-12 database and its upgraded file.
/// No production database, device preferences, clipboard or external file is read.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('round3 preferences/status upgrade isolated v12 learning sentinels', (
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
      '${support.path}/round3-preferences-${config.runId}',
    );
    if (await directory.exists()) {
      throw StateError('Refusing existing fixture run');
    }
    await directory.create();
    final clock = review.ReviewFixtureClock(instant);
    final seedFile = File('${directory.path}/seed.sqlite');
    final file = File('${directory.path}/fixture.sqlite');
    final seed = review.ReviewFixtureDatabase(seedFile, clock);
    final fixture = Fixture(database: seed);
    review.ReviewFixtureDatabase? migrated;
    var seedClosed = false, mounted = false, passed = false;
    String? failure;
    final captures = <Map<String, Object?>>[];
    Map<String, Object?>? baseline;

    Future<void> manifest() async {
      await File('${directory.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'implementationRound': 3,
          'checkpoint': 3,
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
              'frozen schema12; missing direction preference; forward retry and reverse scheduled review; unrelated Collection and learning sentinel; one extra new word',
          'clock': instant.toIso8601String(),
          'captures': captures,
          'files': ['seed.sqlite', 'fixture.sqlite'],
          'preservation': passed
              ? 'All synthetic tables/rowids exact through migration, preference selection, Overview launch/safe exit and file reopen; only preferredDirection was added then changed.'
              : 'Not established',
          'limits': [
            'EN normal-size emulator only; no native IME/file/clipboard or personal-data test.',
          ],
        }),
        flush: true,
      );
      debugPrint(
        'PIKO_ROUND3_PREFERENCES_MANIFEST:${directory.path}/manifest.json',
      );
    }

    Future<void> present(Finder finder, String description) => review.waitUntil(
      tester,
      () => finder.evaluate().isNotEmpty,
      description: description,
    );
    Future<void> tap(Finder finder) => review.tapVisible(tester, finder);
    Future<void> capture(String id, Finder at) async {
      await settleCatalogueCapture(tester, id, at: at);
      expect(tester.takeException(), isNull);
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
      debugPrint(
        'PIKO_ROUND3_PREFERENCES_ARTIFACT:${directory.path}/$name.png',
      );
    }

    Future<void> preserved(
      PikoDatabase database,
      PreferredDirection choice,
    ) async {
      final after = await completeSnapshot(database);
      for (final entry in baseline!.entries) {
        if (entry.key != 'app_settings') {
          expect(after[entry.key], entry.value, reason: entry.key);
        }
      }
      final settings = (after['app_settings']! as List)
          .cast<Map<String, Object?>>();
      expect(
        settings
            .where((row) => row['key'] != PreferredDirection.settingKey)
            .toList(),
        baseline['app_settings'],
      );
      expect(
        settings.singleWhere(
          (row) => row['key'] == PreferredDirection.settingKey,
        )['value'],
        choice.name,
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    }

    try {
      await manifest();
      await fixture.initialize();
      await fixture.review(rating: LearningRating.again);
      await fixture.review(reverse: true, rating: LearningRating.good);
      final newWord = await fixture.vocabulary.create(
        collectionId: fixture.owner.id,
        targetText: 'Three',
        nativeText: 'Drei',
      );
      final settings = SqliteSettingsRepository(seed);
      await settings.write('locale', 'en');
      await settings.write('unrelated', 'preserve exactly');
      await settings.remove(PreferredDirection.settingKey);
      final before = await completeSnapshot(seed);
      baseline = before;
      final legacy = sqlite.sqlite3.open(file.path);
      try {
        for (final sql in frozenV12Sql) {
          legacy.execute(sql);
        }
        for (final table in before.entries) {
          for (final stored in table.value! as List) {
            final row = stored as Map<String, Object?>;
            final columns = row.keys
                .map((key) => key == 'stored_rowid' ? 'rowid' : key)
                .join(',');
            legacy.execute(
              'INSERT INTO ${table.key} ($columns) VALUES (${List.filled(row.length, '?').join(',')})',
              row.values.toList(),
            );
          }
        }
        legacy.execute('PRAGMA user_version = 12');
        expect(legacy.select('PRAGMA user_version').single['user_version'], 12);
        expect(
          legacy.select('SELECT * FROM app_settings WHERE key = ?', [
            PreferredDirection.settingKey,
          ]),
          isEmpty,
        );
      } finally {
        legacy.close();
      }
      await seed.close();
      seedClosed = true;
      migrated = review.ReviewFixtureDatabase(file, clock);
      final db = migrated;
      await preserved(db, PreferredDirection.nativeToTarget);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        13,
      );
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
      await present(find.byType(CollectionsHome), 'migrated Home');
      await tap(_button(copy.text('nav.settings')));
      await present(
        _key('settings-preferred-direction'),
        'hydrated direction setting',
      );
      expect(
        tester
            .widget<PikoDropdown<PreferredDirection>>(
              _key('settings-preferred-direction'),
            )
            .value,
        PreferredDirection.nativeToTarget,
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await capture(
        'settings-existing-default',
        _key('settings-preferred-direction'),
      );
      await tap(_button(copy.text('common.back')));
      await tap(_key('collection-${fixture.owner.id}'));
      await present(
        _key('vocabulary-status-${fixture.entry.id}-nativeToTarget'),
        'single reverse status',
      );
      expect(_key('collection-review-targetToNative'), findsNothing);
      expect(_key('collection-review-nativeToTarget'), findsOneWidget);
      expect(_key('collection-speed-targetToNative'), findsNothing);
      final single = tester
          .widget<Text>(
            _key('vocabulary-status-${fixture.entry.id}-nativeToTarget'),
          )
          .data!;
      expect(single.contains('→'), isFalse);
      expect(single, contains('Next review:'));
      expect(
        _key('vocabulary-status-${fixture.entry.id}-targetToNative'),
        findsNothing,
      );
      await capture(
        'detail-single-status',
        _key('vocabulary-status-${fixture.entry.id}-nativeToTarget'),
      );
      await tap(find.byTooltip(copy.text('common.back')));

      // Overview must still offer both directions while Detail prefers reverse.
      final quick = find.descendant(
        of: _key('collection-${fixture.owner.id}'),
        matching: _key('collection-review-quick'),
      );
      await tap(quick);
      await present(
        find.byType(ReviewDirectionDialog),
        'Overview direction picker',
      );
      for (final direction in LearningDirection.values) {
        expect(
          _button(
            copy.text('r2.due', {
              'direction': reviewDirectionLabel(fixture.owner, direction),
              'count': 1,
            }),
          ),
          findsOneWidget,
        );
      }
      await tap(
        _button(
          copy.text('r2.due', {
            'direction': reviewDirectionLabel(
              fixture.owner,
              LearningDirection.targetToNative,
            ),
            'count': 1,
          }),
        ),
      );
      await present(
        find.byType(ReviewSessionRoute),
        'forward Overview session',
      );
      expect(
        tester
            .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
            .session
            .direction,
        LearningDirection.targetToNative,
      );
      await tap(_key('review-exit'));
      await present(
        find.byType(CollectionsHome),
        'Home after safe Overview exit',
      );
      expect(
        await SqliteSettingsRepository(db).read(PreferredDirection.settingKey),
        PreferredDirection.nativeToTarget.name,
      );
      await preserved(db, PreferredDirection.nativeToTarget);

      await tap(_button(copy.text('nav.settings')));
      await present(
        _key('settings-preferred-direction'),
        'preference dropdown',
      );
      await tap(
        find.descendant(
          of: _key('settings-preferred-direction'),
          matching: find.byType(DropdownButton<PreferredDirection>),
        ),
      );
      await tap(find.text(copy.text('settings.directionBoth')).last);
      await review.waitUntil(
        tester,
        () async =>
            await SqliteSettingsRepository(
              db,
            ).read(PreferredDirection.settingKey) ==
            PreferredDirection.both.name,
        description: 'stored Both preference',
      );
      await tap(_button(copy.text('common.back')));
      await tap(_key('collection-${fixture.owner.id}'));
      await present(
        _key('vocabulary-status-${fixture.entry.id}-targetToNative'),
        'both directional statuses',
      );
      final forward = tester
          .widget<Text>(
            _key('vocabulary-status-${fixture.entry.id}-targetToNative'),
          )
          .data!;
      final reverse = tester
          .widget<Text>(
            _key('vocabulary-status-${fixture.entry.id}-nativeToTarget'),
          )
          .data!;
      expect(
        forward,
        '${reviewDirectionLabel(fixture.owner, LearningDirection.targetToNative)} · ${copy.text('vocab.statusRetryPending')}',
      );
      expect(
        reverse,
        startsWith(
          '${reviewDirectionLabel(fixture.owner, LearningDirection.nativeToTarget)} · ',
        ),
      );
      for (final direction in LearningDirection.values) {
        expect(_key('collection-review-${direction.name}'), findsOneWidget);
        expect(_key('collection-speed-${direction.name}'), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                _key('vocabulary-status-${newWord.id}-${direction.name}'),
              )
              .data,
          '${reviewDirectionLabel(fixture.owner, direction)} · ${copy.text('vocab.statusNew')}',
        );
      }
      await capture(
        'detail-both-statuses',
        _key('vocabulary-status-${fixture.entry.id}-targetToNative'),
      );
      await preserved(db, PreferredDirection.both);
      expect(captures.length, 3);
      passed = true;
    } catch (error) {
      failure = error.toString();
      rethrow;
    } finally {
      try {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!seedClosed) {
          await seed.close();
        }
        final db = migrated;
        if (db != null) {
          if (mounted) {
            await db.closed.future.timeout(const Duration(seconds: 15));
          } else {
            await db.close();
          }
        }
        if (passed) {
          final reopened = review.ReviewFixtureDatabase(file, clock);
          try {
            await preserved(reopened, PreferredDirection.both);
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
