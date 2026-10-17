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
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/collections/learning_help.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../test/data/regular_reviews_test.dart' show Fixture, instant;
import 'review_correction_android_test.dart' as review;
import 'support/round2_catalogue_fixture.dart';
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

Finder key(String value) => find.byKey(ValueKey(value));
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'round6 list guide and learning help preserve production data and learning',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/round6-${config.runId}');
      if (await directory.exists()) {
        throw StateError('Refusing to overwrite evidence');
      }
      await directory.create();
      final clock = review.ReviewFixtureClock(instant);
      final file = File('${directory.path}/fixture.sqlite');
      final db = review.ReviewFixtureDatabase(file, clock);
      final fixture = Fixture(database: db);
      final locale = InterfaceLocaleController();
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'fixture': 'round6-synthetic-v1',
        'captures': <Object?>[],
      };
      var passed = false;
      Future<void> present(Finder finder) => review.waitUntil(
        tester,
        () => finder.evaluate().isNotEmpty,
        description: '$finder',
      );
      Future<void> tap(Finder finder) async {
        await present(finder);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder.hitTestable().first);
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name, {Finder? at}) async {
        await settleCatalogueCapture(tester, name, at: at);
        final context = tester.element(find.byType(CollectionDetail));
        (manifest['captures'] as List).add({
          'file': '$name.png',
          'locale': locale.value.languageCode,
          'logicalSize': MediaQuery.sizeOf(context).toString(),
          'textScale': MediaQuery.textScalerOf(context).scale(14) / 14,
        });
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(await binding.takeScreenshot(name), flush: true);
      }

      Future<void> native(String phase) async {
        await File(
          '${directory.path}/phase.txt',
        ).writeAsString(phase, flush: true);
        debugPrint('PIKO_ROUND6_PHASE:$phase:${directory.path}');
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        while (!await File('${directory.path}/$phase.ack').exists()) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Native phase timed out: $phase');
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      try {
        await fixture.initialize();
        final owner = fixture.owner;
        await fixture
            .review(); // A real due-state/history baseline to preserve.
        final categories = SqliteCategoriesRepository(db);
        final topic = await categories.createDimension(
          collectionId: owner.id,
          name: 'Topic',
          mode: CategoryMode.multiple,
        );
        final food = await categories.createValue(
          dimensionId: topic.id,
          name: 'Food',
        );
        final travel = await categories.createValue(
          dimensionId: topic.id,
          name: 'Travel and other very long category names',
        );
        await categories.replaceAssignments(
          entryId: fixture.entry.id,
          assignments: {
            topic.id: {food.id, travel.id},
          },
        );
        await fixture.vocabulary.create(
          collectionId: owner.id,
          targetText: 'Deux',
          nativeText: 'Zwei',
        );
        await SqliteSettingsRepository(db).write('locale', 'en');
        final json = SqliteVocabularyJsonService(db);
        final before = await json.exportCollection(owner.id);
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
        await present(find.byType(CollectionsHome));
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await tap(key('collection-${owner.id}'));
        final bindingQuery = tester
            .widget<CollectionDetail>(find.byType(CollectionDetail))
            .queryBinding!;
        final scope = bindingQuery.scope;
        Future<void> pick(String chip, String option) async {
          await tap(key(chip));
          await tap(key(option));
          await tap(
            find.widgetWithText(
              PikoButton,
              PikoCopy(locale.value.languageCode).text('r2.apply'),
            ),
          );
        }

        await capture('01-neutral-list', at: key('collection-search'));
        await pick('collection-group', 'view.grouping-${topic.id}');
        expect(scope.expandedGroups, isEmpty);
        await capture(
          '02-collapsed-groups',
          at: key('collection-list-results'),
        );
        await tap(key('collection-group-${food.id}'));
        expect(scope.expandedGroups, {food.id});
        await tap(key('collection-toggle-groups'));
        expect(scope.expandedGroups.length, 3);
        await capture('03-expanded-groups', at: key('collection-list-results'));
        await pick(
          'collection-sort',
          'view.sort-VocabularySort.targetDescending',
        );
        await tap(key('collection-filters'));
        await tap(key('filter-value-${food.id}'));
        await tap(find.widgetWithText(PikoButton, 'Apply'));
        await tester.ensureVisible(key('collection-filters'));
        await tester.pumpAndSettle();
        final controls = [
          'collection-filters',
          'collection-group',
          'collection-sort',
        ];
        final positions = {
          for (final id in controls) id: tester.getRect(key(id)),
        };
        final start = tester.getTopLeft(key('collection-list-results'));
        await capture('04-all-active', at: key('collection-filters'));
        await tap(find.byTooltip('Clear filters'));
        expect(scope.view.grouping, topic.id);
        expect(scope.view.sort, VocabularySort.targetDescending);
        expect({
          for (final id in controls) id: tester.getRect(key(id)),
        }, positions);
        expect(tester.getTopLeft(key('collection-list-results')), start);
        await tap(find.byTooltip('Restore original order'));
        expect(scope.view.grouping, topic.id);
        await tap(key('collection-list-menu'));
        await tap(find.textContaining('Layout').last);
        await tap(key('view.mode-VocabularyViewMode.detailed'));
        await tap(find.widgetWithText(PikoButton, 'Apply'));
        await tap(key('collection-list-menu'));
        await tap(find.textContaining('Language order').last);
        await tap(key('view.languageOrder-false'));
        await tap(find.widgetWithText(PikoButton, 'Apply'));
        await capture(
          '05-detailed-reversed',
          at: key('collection-group-${food.id}'),
        );
        final preferences = scope.view;
        await tap(key('collection-learning-help'));
        expect(
          find.text(const PikoCopy('en').text('learnHelp.fsrs')),
          findsNothing,
        );
        await capture('06-learning-help');
        await tap(key('learning-help-scheduling'));
        expect(
          find.text(const PikoCopy('en').text('learnHelp.fsrs')),
          findsOneWidget,
        );
        await capture(
          '07-scheduling-help',
          at: find.text(const PikoCopy('en').text('learnHelp.expiry')),
        );
        await tap(find.byTooltip('Close learning explanation'));
        await tap(key('collection-learning-help'));
        expect(
          find.text(const PikoCopy('en').text('learnHelp.fsrs')),
          findsNothing,
        );
        await native('back');
        await present(find.byType(CollectionDetail));
        expect(find.byType(LearningHelpDialog), findsNothing);
        expect(scope.view, preferences);
        expect(await json.exportCollection(owner.id), before);
        manifest['nativeBackHelpAndExactVocabularyLearningPreservation'] = true;
        await tester.enterText(
          key('collection-search'),
          'no matching synthetic word',
        );
        await tester.pumpAndSettle();
        await capture('08-no-results', at: key('collection-list-results'));
        expect(
          tester.widget<PikoButton>(key('collection-toggle-groups')).onPressed,
          isNull,
        );
        await tap(key('collection-clear-search'));
        await tap(find.byTooltip('Remove grouping'));
        expect(scope.view.grouping, isNull);
        expect(key('collection-toggle-groups'), findsNothing);
        await native('narrow');
        locale.value = const Locale('de');
        await tester.pumpAndSettle();
        var context = tester.element(find.byType(CollectionDetail));
        expect(MediaQuery.sizeOf(context).width, closeTo(320, 1));
        expect(MediaQuery.textScalerOf(context).scale(14), closeTo(28, 1));
        await capture('09-de-320-200-list', at: key('collection-search'));
        await tap(key('collection-group'));
        await capture('10-de-320-200-picker');
        await tap(find.byTooltip(const PikoCopy('de').text('common.close')));
        await tap(key('collection-learning-help'));
        await capture('11-de-320-200-help');
        await tap(key('learning-help-scheduling'));
        await capture(
          '12-de-320-200-scheduling',
          at: find.text(const PikoCopy('de').text('learnHelp.expiry')),
        );
        await tap(find.byTooltip(const PikoCopy('de').text('learnHelp.close')));
        await native('restore');
        locale.value = const Locale('en');
        await tester.pumpAndSettle();
        expect(await json.exportCollection(owner.id), before);
        // Reopen the collection via the real route; preferences survive and help stays available.
        final saved = scope.view;
        await tap(find.byTooltip('Back'));
        await tap(key('collection-${owner.id}'));
        expect(
          tester
              .widget<CollectionDetail>(find.byType(CollectionDetail))
              .queryBinding!
              .scope
              .view,
          saved,
        );
        expect(key('collection-learning-help'), findsOneWidget);
        manifest['preferencesReopen'] = true;
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
        debugPrint('PIKO_ROUND6_EVIDENCE:${directory.path}');
      }
    },
  );
}
