import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/learning_help.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/features/vocabulary/vocabulary_selection.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/interface_locale.dart';
import '../test/data/regular_reviews_test.dart' show Fixture, instant;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'selection-only Collection states retain geometry, data and learning scope',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/selection-${config.runId}');
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
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'fixture': 'selection-synthetic-v1',
        'locale': config.locale,
        'classification': 'instrumented-profile-app-surface',
        'captures': <Object?>[],
      };
      var passed = false;
      Finder key(String value) => find.byKey(ValueKey(value));
      VocabularySelection selection() => tester
          .widget<CollectionVocabulary>(
            find.byType(CollectionVocabulary, skipOffstage: false),
          )
          .selection!;
      Future<void> reveal(Finder finder) async {
        if (finder.evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            finder,
            160,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 200,
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

      Future<void> native(String phase) async {
        debugPrint('PIKO_SELECTION_PHASE:$phase:${directory.path}');
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        while (!await File('${directory.path}/$phase.ack').exists()) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Native phase timeout: $phase');
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(CollectionDetail));
        (manifest['captures'] as List).add({
          'file': '$name.png',
          'logicalWidth': MediaQuery.sizeOf(context).width,
          'logicalHeight': MediaQuery.sizeOf(context).height,
          'textScale': MediaQuery.textScalerOf(context).scale(14) / 14,
        });
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(await binding.takeScreenshot(name));
      }

      try {
        await fixture.initialize();
        await fixture.review();
        await SqliteSettingsRepository(db).write('locale', config.locale);
        for (var i = 0; i < 19; i++) {
          await fixture.vocabulary.create(
            collectionId: fixture.owner.id,
            targetText: 'Word $i',
            nativeText: 'Translation $i',
          );
        }
        final categories = SqliteCategoriesRepository(db);
        final topic = await categories.createDimension(
          collectionId: fixture.owner.id,
          name: 'Topic',
          mode: CategoryMode.multiple,
        );
        final food = await categories.createValue(
          dimensionId: topic.id,
          name: 'Food',
        );
        final travel = await categories.createValue(
          dimensionId: topic.id,
          name: 'Travel',
        );
        await categories.replaceAssignments(
          entryId: fixture.entry.id,
          assignments: {
            topic.id: {food.id, travel.id},
          },
        );
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
        final context = tester.element(find.byType(CollectionDetail));
        if (config.scale == '200') {
          expect(MediaQuery.sizeOf(context).width, closeTo(320, 1));
          expect(MediaQuery.textScalerOf(context).scale(14), closeTo(28, 1));
        }
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        final card = key('vocabulary-${fixture.entry.id}');
        await reveal(card);
        final cardRect = tester.getRect(card);
        final text = find.descendant(of: card, matching: find.text('One'));
        final textOrigin = tester.getTopLeft(text);
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        final pixels = scroll.pixels;
        await capture('00-ordinary');
        await tester.longPress(card);
        await tester.pumpAndSettle();
        expect(selection().ids, {fixture.entry.id});
        expect(tester.getRect(card), cardRect);
        expect(tester.getTopLeft(text), textOrigin);
        expect(scroll.pixels, pixels);
        await capture('01-selected');
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(selection().active, isTrue);
        expect(selection().ids, isEmpty);
        expect(tester.getRect(card), cardRect);
        expect(scroll.pixels, pixels);
        await capture('02-selectable-zero');
        await tap(key('vocabulary-clear-selection'));
        expect(tester.getRect(card), cardRect);
        expect(tester.getTopLeft(text), textOrigin);
        expect(scroll.pixels, pixels);
        await tester.longPress(card);
        await tester.pumpAndSettle();
        final query = tester
            .widget<CollectionDetail>(find.byType(CollectionDetail))
            .queryBinding!;
        final scope = query.scope;
        scope.setSearch('Word 9');
        await tester.pumpAndSettle();
        expect(selection().hidden(query.snapshot!.entries.map((e) => e.id)), 1);
        await capture('03-hidden-selection');
        await tap(key('vocabulary-select-all'));
        expect(selection().ids.length, 2);
        scope.setSearch('');
        await tester.pumpAndSettle();
        await scope.saveView(CollectionViewPreferences(grouping: topic.id));
        await tester.pumpAndSettle();
        expect(scope.expandedGroups, isEmpty);
        await tap(key('vocabulary-select-all'));
        expect(selection().ids.length, 20);
        scope.expandGroups([food.id, travel.id, 'unassigned'], true);
        await tester.pumpAndSettle();
        await tap(key('vocabulary-${food.id}/${fixture.entry.id}'));
        expect(selection().ids.length, 19);
        await tap(key('vocabulary-${travel.id}/${fixture.entry.id}'));
        expect(selection().ids.length, 20);
        await scope.saveView(
          const CollectionViewPreferences(
            mode: VocabularyViewMode.detailed,
            targetFirst: false,
          ),
        );
        await tester.pumpAndSettle();
        expect(selection().ids.length, 20);
        final last = key('vocabulary-${query.snapshot!.entries.last.id}');
        await reveal(last);
        final viewport = tester.getRect(find.byType(Scrollable).first);
        final panel = tester.getRect(key('vocabulary-selection-panel'));
        expect(viewport.bottom, lessThan(panel.top));
        expect(
          tester.getRect(last).bottom,
          lessThanOrEqualTo(viewport.bottom + .5),
        );
        await capture('04-last-card-clearance');
        expect(await json.exportCollection(fixture.owner.id), before);
        final retainedSelection = selection();
        await tap(key('collection-learning-help'));
        expect(find.byType(LearningHelpDialog), findsOneWidget);
        await native('back-help');
        await review.waitUntil(
          tester,
          () => find.byType(LearningHelpDialog).evaluate().isEmpty,
          description: 'native Back closes learning help',
        );
        expect(find.byType(CollectionDetail), findsOneWidget);
        expect(
          ModalRoute.of(
            tester.element(find.byType(CollectionDetail)),
          )!.isCurrent,
          isTrue,
        );
        expect(retainedSelection.ids.length, 20);
        await scope.saveView(const CollectionViewPreferences());
        await tester.pumpAndSettle();
        await tap(key('vocabulary-clear-selection'));
        await reveal(card);
        await tester.longPress(card);
        await tester.pumpAndSettle();
        final ownerSelection = selection();
        final due = query
            .snapshot!
            .directions[LearningDirection.targetToNative]!
            .dueCount;
        expect(due, greaterThan(1));
        await tap(key('collection-review-targetToNative'));
        await review.waitUntil(
          tester,
          () => find.byType(ReviewSessionRoute).evaluate().isNotEmpty,
          description: 'normal learning route',
        );
        final session = tester
            .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
            .session;
        expect(session.unreviewedMembers.length, due);
        expect(ownerSelection.active, isFalse);
        expect(ownerSelection.ids, isEmpty);
        await native('back-learning');
        await review.waitUntil(
          tester,
          () =>
              find.byType(ReviewSessionRoute).evaluate().isEmpty &&
              find.byType(CollectionDetail).evaluate().isNotEmpty,
          description: 'native Back returns to Collection',
        );
        expect(
          ModalRoute.of(
            tester.element(find.byType(CollectionDetail)),
          )!.isCurrent,
          isTrue,
        );
        await reveal(card);
        expect(selection().active, isFalse);
        expect(await json.exportCollection(fixture.owner.id), before);
        manifest['learningScopeCount'] = due;
        manifest['dataPreserved'] = true;
        manifest['navigationReset'] = true;
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
        debugPrint('PIKO_SELECTION_EVIDENCE:${directory.path}');
      }
    },
  );
}
