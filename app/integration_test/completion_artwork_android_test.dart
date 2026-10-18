import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native completion art follows committed results and one Collection slot',
    (tester) async {
      final config = CatalogueConfiguration(),
          copy = PikoCopy(CatalogueConfiguration().locale);
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/celebration-${config.runId}',
      );
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final file = File('${directory.path}/fixture.sqlite');
      final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12));
      final db = review.ReviewFixtureDatabase(file, clock);
      // The runtime and fixture must share the isolated file, never production.
      final fixture = Fixture(database: db);
      var passed = false, converted = false;
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
      };
      Finder key(String value) => find.byKey(ValueKey(value));
      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            140,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder.hitTestable().first);
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        if (config.locale != 'en') return;
        await settleCatalogueCapture(tester, name);
        if (!converted) {
          await integration.convertFlutterSurfaceToImage();
          await tester.pump();
          converted = true;
        }
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(await integration.takeScreenshot(name));
      }

      Future<Map<String, Object?>> learning(PikoDatabase store) async => {
        for (final table in [
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
        ])
          table: [
            for (final row in await review.rows(store, table))
              {...row}..remove('speed_completed'),
          ],
      };
      try {
        await fixture.initialize();
        final settings = SqliteSettingsRepository(db);
        await settings.write('locale', config.locale);
        await settings.write(
          PreferredDirection.settingKey,
          PreferredDirection.both.name,
        );
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(config.locale),
            home: PikoRuntime(
              databaseFactory: () => db,
              jsonPlatform: CatalogueJsonPlatform(),
            ),
          ),
        );
        await hydratedRuntimeCopy(tester);
        await review.waitUntil(
          tester,
          () => key('collection-${fixture.owner.id}').evaluate().isNotEmpty,
        );
        await tap(key('collection-${fixture.owner.id}'));
        final media = MediaQuery.of(
          tester.element(find.byType(CollectionDetail)),
        );
        manifest['width'] = media.size.width;
        manifest['textScale'] = media.textScaler.scale(14) / 14;
        if (config.scale == '200') {
          expect(media.size.width, closeTo(320, 1));
          expect(media.textScaler.scale(14), closeTo(28, 1));
        }
        expect(key('piko-reading'), findsOneWidget);
        expect(key('piko-celebration'), findsNothing);
        await tap(key('collection-review-nativeToTarget'));
        await tap(key('review-reveal-target'));
        await db.customStatement(
          "CREATE TRIGGER fail_regular BEFORE INSERT ON regular_reviews BEGIN SELECT RAISE(ABORT, 'Synthetic failure'); END",
        );
        await tap(key('review-grade-correct'));
        expect(find.byType(ReviewSummaryDialog), findsNothing);
        expect(key('piko-celebration'), findsNothing);
        expect(await review.rows(db, 'regular_reviews'), isEmpty);
        await db.customStatement('DROP TRIGGER fail_regular');
        await tap(key('review-grade-correct'));
        await review.waitUntil(
          tester,
          () => find.byType(ReviewSummaryDialog).evaluate().isNotEmpty,
        );
        expect(key('piko-celebration'), findsOneWidget);
        expect(key('piko-reading'), findsNothing);
        expect(
          tester.widget<Image>(key('piko-celebration')).excludeFromSemantics,
          isTrue,
        );
        await capture('review-complete');
        await tap(find.byTooltip(copy.text('common.close')));
        expect(find.byType(CollectionDetail), findsOneWidget);
        expect(key('piko-celebration'), findsNothing);
        expect(key('piko-reading'), findsOneWidget);
        final before = await learning(db);
        Future<void> startSpeed() async {
          await tap(key('collection-speed-targetToNative'));
          await tap(find.text(copy.text('learn.startSpeed')));
        }

        await startSpeed();
        await tap(key('speed-exit'));
        expect(key('speed-completion-notice'), findsNothing);
        expect(key('piko-celebration'), findsNothing);
        await startSpeed();
        await tap(key('review-reveal-target'));
        await db.customStatement(
          "CREATE TRIGGER fail_speed BEFORE UPDATE OF speed_completed ON learning_items BEGIN SELECT RAISE(ABORT, 'Synthetic failure'); END",
        );
        await tap(key('speed-grade-correct'));
        expect(find.byType(SpeedSessionRoute), findsOneWidget);
        expect(key('piko-celebration'), findsNothing);
        expect(
          (await review.rows(
            db,
            'statistics_activity',
          )).where((r) => r['mode'] == 'speed'),
          isEmpty,
        );
        await db.customStatement('DROP TRIGGER fail_speed');
        await tap(key('speed-grade-correct'));
        await review.waitUntil(
          tester,
          () => key('speed-completion-notice').evaluate().isNotEmpty,
        );
        expect(key('piko-celebration'), findsOneWidget);
        expect(key('piko-reading'), findsNothing);
        expect(find.byType(ReviewSummaryDialog), findsNothing);
        expect(await learning(db), before);
        await capture('speed-complete');
        await tap(
          find.byWidgetPredicate(
            (w) =>
                w is PikoIconButton &&
                w.semanticLabel == copy.text('speed.dismissCompletion'),
          ),
        );
        expect(key('piko-celebration'), findsNothing);
        expect(key('piko-reading'), findsOneWidget);
        expect(await learning(db), before);
        final credits = await review.rows(db, 'statistics_activity');
        expect(credits.where((r) => r['mode'] == 'regular').length, 1);
        expect(credits.where((r) => r['mode'] == 'speed').length, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.closed.future;
        final reopened = PikoDatabase(NativeDatabase(file), clock: clock);
        try {
          expect(await learning(reopened), before);
          expect(await review.rows(reopened, 'statistics_activity'), credits);
        } finally {
          await reopened.close();
        }
        manifest['assertions'] = [
          'no celebration for failed regular/Speed writes',
          'existing regular summary has exactly one original pose',
          'Speed exit does not celebrate',
          'committed Speed notice suppresses reading',
          'X restores current reading',
          'art does not change counters or Long-term state',
          'reopened data exact',
        ];
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        manifest['passed'] = passed;
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(manifest),
          flush: true,
        );
        debugPrint('PIKO_CELEBRATION_EVIDENCE:${directory.path}');
      }
    },
  );
}
