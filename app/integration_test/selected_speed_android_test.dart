import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/features/vocabulary/vocabulary_selection.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'selected Speed on native Collection preserves cancellation, ordering and reopened learning',
    (tester) async {
      final config = CatalogueConfiguration(),
          copy = PikoCopy(CatalogueConfiguration().locale);
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/selected-speed-${config.runId}',
      );
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final file = File('${directory.path}/fixture.sqlite');
      final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12));
      final db = review.ReviewFixtureDatabase(file, clock);
      final f = Fixture(database: db);
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
        'fixture': 'selected-speed-synthetic-v1',
        'normalProductionDatabaseOpened': false,
      };
      var passed = false;
      Finder key(String value) => find.byKey(ValueKey(value));
      Future<void> reveal(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            finder,
            140,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder finder) async {
        await reveal(finder);
        await tester.tap(finder.hitTestable().first);
        await tester.pumpAndSettle();
      }

      VocabularySelection selection() => tester
          .widget<CollectionVocabulary>(
            find.byType(CollectionVocabulary, skipOffstage: false),
          )
          .selection!;
      CollectionDetail detail() =>
          tester.widget<CollectionDetail>(find.byType(CollectionDetail));
      Future<void> openSelected() async {
        final directions = detail().directionBinding!.value!.value.directions;
        final chosen = directions.length == 1
            ? directions.single
            : LearningDirection.targetToNative;
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        await tap(key('collection-speed-${chosen.name}'));
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
        await f.initialize();
        await f.review(rating: LearningRating.again, at: clock.now());
        await f.review(
          reverse: true,
          rating: LearningRating.again,
          at: clock.now(),
        );
        final b = await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Zebra',
          nativeText: 'Zebra',
        );
        final c = await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Inactive',
          nativeText: 'Inaktiv',
        );
        await db.customStatement(
          'UPDATE vocabulary_entries SET active=0 WHERE id=?',
          [c.id],
        );
        await db.customStatement(
          'UPDATE learning_items SET speed_completed=1 WHERE entry_id=?',
          [f.entry.id],
        );
        final settings = SqliteSettingsRepository(db);
        await settings.write('locale', config.locale);
        await settings.write(
          PreferredDirection.settingKey,
          PreferredDirection.both.name,
        );
        final before = await learning(db);
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
          () => key('collection-${f.owner.id}').evaluate().isNotEmpty,
        );
        await tap(key('collection-${f.owner.id}'));
        final media = MediaQuery.of(
          tester.element(find.byType(CollectionDetail)),
        );
        manifest['width'] = media.size.width;
        manifest['textScale'] = media.textScaler.scale(14) / 14;
        if (config.scale == '200') {
          expect(media.size.width, closeTo(320, 1));
          expect(media.textScaler.scale(14), closeTo(28, 1));
        }
        final aCard = key('vocabulary-${f.entry.id}');
        await reveal(aCard);
        final rect = tester.getRect(aCard);
        await tester.longPress(aCard);
        await tester.pumpAndSettle();
        expect(tester.getRect(aCard), rect);
        await tap(key('vocabulary-${b.id}'));
        await tap(key('vocabulary-${c.id}'));
        final selected = selection();
        expect(selected.ids, {f.entry.id, b.id, c.id});
        final query = detail().queryBinding!,
            scope = detail().queryBinding!.scope;
        await scope.saveView(
          const CollectionViewPreferences(
            sort: VocabularySort.targetDescending,
          ),
        );
        scope.setSearch('Zebra');
        await tester.pumpAndSettle();
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        final offset = scroll.pixels;
        await openSelected();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(selected.ids.length, 3);
        expect(scroll.pixels, closeTo(offset, .1));
        await openSelected();
        expect(
          find.text(copy.text('selectedSpeed.included', {'count': 2})),
          findsOneWidget,
        );
        expect(
          find.text(copy.text('selectedSpeed.hidden', {'count': 1})),
          findsOneWidget,
        );
        expect(
          find.text(copy.text('selectedSpeed.inactive', {'count': 1})),
          findsOneWidget,
        );
        expect(key('speed-new-count'), findsNothing);
        final pool = key('speed-pool-size');
        await reveal(pool);
        await tester.enterText(pool, '1');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        // Done is an explicit Start, with the same single-flight admission guard.
        final route = tester.widget<SpeedSessionRoute>(
          find.byType(SpeedSessionRoute),
        );
        expect(route.session.state!.entryIds, [b.id, f.entry.id]);
        expect(
          route.session.state!.direction,
          LearningDirection.targetToNative,
        );
        expect(selected.ids, isEmpty);
        for (final answer in [
          'correct',
          'incorrect',
          'incorrect',
          'correct',
          'correct',
          'correct',
        ]) {
          await tap(key('review-reveal-target'));
          await tap(key('speed-grade-$answer'));
        }
        await review.waitUntil(
          tester,
          () => key('speed-completion-notice').evaluate().isNotEmpty,
        );
        expect(await learning(db), before);
        expect(
          (await review.rows(
            db,
            'statistics_activity',
          )).where((r) => r['mode'] == 'speed').length,
          2,
        );
        // Repractice hidden, already completed/reviewed A, direct one-direction setup.
        for (final direction in [
          PreferredDirection.targetToNative,
          PreferredDirection.nativeToTarget,
        ]) {
          await detail().directionBinding!.value!.select(direction);
          scope.setSearch('');
          await tester.pumpAndSettle();
          await reveal(aCard);
          await tester.longPress(aCard);
          await tester.pumpAndSettle();
          scope.setSearch('Zebra');
          await tester.pumpAndSettle();
          await openSelected();
          expect(find.byType(SpeedSetupDialog), findsOneWidget);
          if (direction == PreferredDirection.targetToNative) {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(selected.ids, {f.entry.id});
            await openSelected();
            if (config.locale == 'en') {
              await integration.convertFlutterSurfaceToImage();
              await tester.pump();
              await File('${directory.path}/selected-setup.png').writeAsBytes(
                await integration.takeScreenshot('selected-setup'),
              );
            }
          }
          await tap(find.text(copy.text('learn.startSpeed')));
          await tap(key('review-reveal-target'));
          await tap(key('speed-grade-correct'));
          await review.waitUntil(
            tester,
            () => key('speed-completion-notice').evaluate().isNotEmpty,
          );
          expect(await learning(db), before);
        }
        expect(
          (await review.rows(
            db,
            'statistics_activity',
          )).where((r) => r['mode'] == 'speed').length,
          3,
        );
        expect(query.scope.search, 'Zebra');
        manifest['assertions'] = [
          'cancel picker/setup preserves selection/scroll',
          'full sorted hidden selection, inactive excluded',
          'keyboard Done explicit start',
          'successful departure clears selection',
          'two errors preserve both Long-term directions/retries',
          'repeat same direction/day no extra credit',
          'opposite direction credits once',
          'one-direction direct setup',
        ];
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.closed.future;
        final reopened = PikoDatabase(NativeDatabase(file), clock: clock);
        try {
          expect(await learning(reopened), before);
          expect(
            (await review.rows(
              reopened,
              'statistics_activity',
            )).where((r) => r['mode'] == 'speed').length,
            3,
          );
          expect(
            await reopened.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await reopened.close();
        }
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
        debugPrint('PIKO_SELECTED_SPEED_EVIDENCE:${directory.path}');
      }
    },
  );
}
