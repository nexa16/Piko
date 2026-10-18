import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../test/data/regular_reviews_test.dart' show Fixture, instant;
import 'review_correction_android_test.dart' as review;
import 'support/round2_catalogue_fixture.dart';
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Collection originating filter stays in place through learning reflow',
    (tester) async {
      const requireAnchor = bool.fromEnvironment(
        'REQUIRE_ANCHOR',
        defaultValue: true,
      );
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/anchor-${config.runId}');
      if (await directory.exists()) {
        throw StateError('Refusing to overwrite evidence');
      }
      await directory.create();
      final clock = review.ReviewFixtureClock(instant);
      final db = review.ReviewFixtureDatabase(
        File('${directory.path}/fixture.sqlite'),
        clock,
      );
      final fixture = Fixture(database: db);
      final locale = InterfaceLocaleController(Locale(config.locale));
      final copy = PikoCopy(config.locale);
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'fixture': 'anchor-synthetic-v1',
        'requireAnchor': requireAnchor,
        'locale': config.locale,
        'classification': 'instrumented-android-app-surface',
        'measurements': <Object?>[],
      };
      var passed = false;
      Finder key(String text) => find.byKey(ValueKey(text));
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder.hitTestable().first);
        await tester.pumpAndSettle();
      }

      try {
        await fixture.initialize();
        await SqliteSettingsRepository(db).write('locale', config.locale);
        await fixture.review();
        final categories = SqliteCategoriesRepository(db);
        final topic = await categories.createDimension(
          collectionId: fixture.owner.id,
          name: 'Topic',
          mode: CategoryMode.single,
        );
        final food = await categories.createValue(
          dimensionId: topic.id,
          name: 'Food',
        );
        await categories.replaceAssignments(
          entryId: fixture.entry.id,
          assignments: {
            topic.id: {food.id},
          },
        );
        for (var i = 0; i < 35; i++) {
          await fixture.vocabulary.create(
            collectionId: fixture.owner.id,
            targetText: 'Word $i',
            nativeText: 'Translation $i',
          );
        }
        final json = SqliteVocabularyJsonService(db);
        final before = await json.exportCollection(fixture.owner.id);
        await tester.pumpWidget(
          PikoApp(
            localeController: locale,
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
          description: 'synthetic Collection',
        );
        await tap(key('collection-${fixture.owner.id}'));
        await tester.scrollUntilVisible(
          key('collection-filters'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tap(key('collection-filters'));
        await tap(key('filter-value-${food.id}'));
        await tap(find.widgetWithText(PikoButton, copy.text('r2.apply')));
        final chip = key('collection-filters');
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await File(
          '${directory.path}/before.png',
        ).writeAsBytes(await binding.takeScreenshot('before'));
        final top = tester.getTopLeft(chip).dy;
        final clear = find.byTooltip(copy.text('r2.clearFilters'));
        // No ensureVisible after sampling: measure the actual originating control.
        await tester.tap(clear.hitTestable().first);
        var maximumDelta = 0.0;
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          final delta = tester.getTopLeft(chip).dy - top;
          if (delta.abs() > maximumDelta.abs()) maximumDelta = delta;
          (manifest['measurements'] as List).add(delta);
          if (requireAnchor) expect(delta, closeTo(0, .5));
        }
        manifest['maximumDelta'] = maximumDelta;
        final context = tester.element(find.byType(CollectionDetail));
        manifest['logicalSize'] = MediaQuery.sizeOf(context).toString();
        manifest['textScale'] = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (config.scale == '200') {
          expect(MediaQuery.sizeOf(context).width, closeTo(320, 1));
          expect(MediaQuery.textScalerOf(context).scale(14), closeTo(28, 1));
        }
        final query = tester
            .widget<CollectionDetail>(find.byType(CollectionDetail))
            .queryBinding!;
        expect(query.scope.filters, isEmpty);
        expect(query.snapshot!.entries.length, 36);
        expect(await json.exportCollection(fixture.owner.id), before);
        await File(
          '${directory.path}/after.png',
        ).writeAsBytes(await binding.takeScreenshot('after'));
        final transitions = <Object?>[];
        for (final (control, option) in [
          ('collection-group', 'view.grouping-${topic.id}'),
          ('collection-sort', 'view.sort-VocabularySort.targetDescending'),
        ]) {
          final origin = key(control);
          await tester.ensureVisible(origin);
          await tester.pumpAndSettle();
          final top = tester.getTopLeft(origin).dy;
          await tap(origin);
          await tap(key(option));
          await tester.tap(
            find.widgetWithText(PikoButton, copy.text('r2.apply')),
          );
          var clampedFrames = 0;
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 20));
            final delta = tester.getTopLeft(origin).dy - top;
            if (delta.abs() > .5) {
              final position = tester
                  .state<ScrollableState>(find.byType(Scrollable).first)
                  .position;
              final desired = position.pixels + delta;
              expect(
                desired < position.minScrollExtent ||
                    desired > position.maxScrollExtent,
                isTrue,
              );
              expect(
                position.pixels,
                delta > 0 ? position.maxScrollExtent : position.minScrollExtent,
              );
              clampedFrames++;
            }
          }
          transitions.add({'control': control, 'clampedFrames': clampedFrames});
        }
        await tap(key('collection-group-unassigned'));
        final header = key('collection-group-${food.id}');
        await tester.ensureVisible(header);
        await tester.pumpAndSettle();
        final headerTop = tester.getTopLeft(header).dy;
        for (var repeat = 0; repeat < 4; repeat++) {
          await tester.tap(header);
          for (var frame = 0; frame < 20; frame++) {
            await tester.pump(const Duration(milliseconds: 20));
            expect(tester.getTopLeft(header).dy, closeTo(headerTop, .5));
          }
        }
        manifest['groupSortTransitions'] = transitions;
        manifest['groupDisclosureChecks'] = 4;
        expect(await json.exportCollection(fixture.owner.id), before);
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        locale.dispose();
        manifest['passed'] = passed;
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(manifest),
          flush: true,
        );
        debugPrint('PIKO_ANCHOR_EVIDENCE:${directory.path}');
      }
    },
  );
}
