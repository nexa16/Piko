import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/collections/create_collection.dart';
import 'package:piko/features/categories/category_management.dart';
import 'package:piko/features/categories/category_assignment_picker.dart';
import 'package:piko/features/categories/category_dimension_form.dart';
import 'package:piko/features/collections/filter_selection_dialog.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/features/settings/settings_route.dart';
import 'package:piko/features/speed/speed_numbers_break.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:piko/ui/components/piko_field.dart';

import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

const _words = <(String, String)>[
  ('사과', 'Apfel'),
  ('물', 'Wasser'),
  ('학교', 'Schule'),
  ('친구', 'Freund'),
  ('책', 'Buch'),
];

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _button(String label) => find.widgetWithText(PikoButton, label);
Finder _icon(String label) => find.byWidgetPredicate(
  (widget) => widget is PikoIconButton && widget.semanticLabel == label,
);
Finder _field(String key) =>
    find.descendant(of: _key(key), matching: find.byType(TextField));
Finder _entryField(String value) =>
    find.descendant(of: _key('draft-$value'), matching: find.byType(TextField));

/// Real-runtime visual catalogue, one explicit locale/text-scale invocation.
/// The only database opened is a newly owned fixture.sqlite in the run folder.
/// PNGs, the manifest and synthetic DB intentionally remain for host retrieval.
/// No screenshots are evidence until this integration test runs on a device.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('round 2 isolated Android route and state catalogue', (
    tester,
  ) async {
    final config = CatalogueConfiguration();
    expect(binding.registerTestTextInput, isFalse);
    tester.platformDispatcher.textScaleFactorTestValue = config.scale == '200'
        ? 2
        : 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final artifacts = await CatalogueArtifacts.create(config);
    final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 16, 9));
    final databaseFile = File('${artifacts.directory.path}/fixture.sqlite');
    if (await databaseFile.exists()) {
      throw StateError('Refusing to reuse a catalogue database');
    }
    final db = review.ReviewFixtureDatabase(databaseFile, clock);
    final collections = SqliteCollectionsRepository(db);
    final vocabulary = SqliteVocabularyRepository(db);
    final categories = SqliteCategoriesRepository(db);
    final platform = CatalogueJsonPlatform();
    var mounted = false;
    var completed = false;

    Future<void> capture(
      String id, {
      Finder? at,
      Map<String, Object?> metadata = const {},
    }) => artifacts.capture(binding, tester, id, at: at, metadata: metadata);
    Future<void> tap(Finder finder) => review.tapVisible(tester, finder);
    void pause() {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    }

    void resume() {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    Future<void> enter(Finder finder, String text) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await tester.enterText(finder, text);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(finder).controller!.text, text);
    }

    Future<void> wait(bool Function() condition, String description) =>
        review.waitUntil(tester, condition, description: description);
    Future<void> present(Finder finder, String description) =>
        wait(() => finder.evaluate().isNotEmpty, description);

    try {
      await SqliteSettingsRepository(db).write('locale', config.locale);
      mounted = true;
      await tester.pumpWidget(
        PikoApp(
          home: PikoRuntime(databaseFactory: () => db, jsonPlatform: platform),
        ),
      );
      final copy = await hydratedRuntimeCopy(tester);
      expect(copy.locale, config.locale);
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(CollectionsHome)),
        ).scale(10),
        closeTo(config.scale == '200' ? 20 : 10, .01),
      );
      await present(
        find.text(copy.text('home.emptyDescription')),
        'hydrated empty Home',
      );
      expect(await collections.watchAll().first, isEmpty);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await capture('home-empty');

      await tap(_button(copy.text('action.new')));
      await present(find.byType(CreateCollectionDialog), 'Collection creation');
      await capture('collection-create');
      await enter(
        find.descendant(
          of: find.byType(CreateCollectionDialog),
          matching: find.byType(TextField),
        ),
        'Korean Basics',
      );
      await tap(_button(copy.text('action.create')));
      await wait(
        () => find.byType(CreateCollectionDialog).evaluate().isEmpty,
        'saved Collection',
      );
      final collection = (await collections.watchAll().first).single;
      expect(collection.targetLanguage, VocabularyLanguage.korean);
      expect(collection.nativeLanguage, VocabularyLanguage.german);
      // The catalogue shows settled pages; the creation toast is covered by
      // creation behavior tests and must not obscure unrelated later screens.
      ScaffoldMessenger.of(
        tester.element(find.byType(CollectionsHome)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      // Only fixture setup bypasses UI entry; all subsequent routes are real.
      for (final (target, native) in _words) {
        await vocabulary.create(
          collectionId: collection.id,
          targetText: target,
          nativeText: native,
        );
      }
      final fixtureWords = await vocabulary
          .watchByCollection(collection.id)
          .first;
      final firstWord = fixtureWords.first;
      final topic = await categories.createDimension(
        collectionId: collection.id,
        name: 'Topic',
        mode: CategoryMode.multiple,
      );
      final food = await categories.createValue(
        dimensionId: topic.id,
        name: 'Food',
      );
      final school = await categories.createValue(
        dimensionId: topic.id,
        name: 'School',
      );
      await categories.replaceAssignments(
        entryId: firstWord.id,
        assignments: {
          topic.id: {food.id},
        },
      );
      await categories.replaceAssignments(
        entryId: fixtureWords[2].id,
        assignments: {
          topic.id: {school.id},
        },
      );
      // Fixture writes bypass Entry's normal route-return invalidation. Exercise
      // the real resume refresh before expecting Home's passive count to change.
      pause();
      await tester.pump();
      resume();
      await present(
        _key('collection-review-quick'),
        'populated Home due count',
      );
      await capture('home-populated', at: _key('collection-review-quick'));
      await tap(_key('collection-review-quick'));
      await present(
        find.byType(ReviewDirectionDialog),
        'Home direction choice',
      );
      expect(find.byType(PikoDropdown<LearningDirection>), findsNothing);
      await capture('review-choice');
      await tap(find.byTooltip(copy.text('common.close')));

      final owner = _key('collection-${collection.id}');
      await tap(
        find.descendant(of: owner, matching: find.text(collection.name)),
      );
      await present(
        _key('collection-speed-targetToNative'),
        'ready Collection detail',
      );
      expect(find.byType(CollectionDetail), findsOneWidget);
      await capture('detail');
      await tap(_key('collection-menu'));
      await present(_key('collection-menu-delete'), 'Collection overflow');
      await capture('collection-overflow');
      await tap(_key('collection-menu-delete'));
      await present(_button(copy.text('action.cancel')), 'delete confirmation');
      await capture('collection-delete-confirmation');
      await tap(_button(copy.text('action.cancel')));
      expect((await collections.watchAll().first).single.id, collection.id);
      await tap(_key('collection-rename'));
      await present(_key('collection-name'), 'inline name editor');
      await capture('collection-rename');
      await tap(_key('collection-name-cancel'));
      final learningBeforeCategories = {
        for (final direction in LearningDirection.values)
          direction: await review.directionState(db, collection.id, direction),
      };

      // Category edits affect definitions/assignments only. All five original
      // directional learning items remain eligible for the later learning flow.
      await tap(_key('collection-menu'));
      await tap(find.text(copy.text('r2.editCategories')));
      await present(
        find.byType(CategoryManagement),
        'inline category management',
      );
      await capture(
        'category-management',
        at: _key('collection-menu-categories'),
      );
      final topicBranch = _key('category-dimension-${topic.id}');
      await tap(find.descendant(of: topicBranch, matching: find.text('Topic')));
      final topicName = _field('category-management-name-${topic.id}');
      await present(topicName, 'unchanged dimension form');
      expect(_button(copy.text('category.saveDimension')), findsNothing);
      await capture('category-dimension-unchanged', at: topicName);
      final single = find.descendant(
        of: topicBranch,
        matching: find.widgetWithText(
          RadioListTile<CategoryMode>,
          copy.text('r2.single'),
        ),
      );
      await capture('category-dimension-mode', at: single);
      await enter(topicName, 'Topics');
      await tap(single);
      final saveDimension = _button(copy.text('category.saveDimension'));
      await present(saveDimension, 'changed dimension confirmation');
      await capture('category-dimension-changed', at: saveDimension);
      await tap(saveDimension);
      await wait(
        () => saveDimension.evaluate().isEmpty,
        'dimension name and mode stored',
      );
      final savedTopic = (await categories.dimensionById(topic.id))!;
      expect(savedTopic.name, 'Topics');
      expect(savedTopic.mode, CategoryMode.single);
      await capture('category-dimension-saved', at: topicName);

      await tap(
        find.descendant(
          of: topicBranch,
          matching: _button(copy.text('r2.addValue')),
        ),
      );
      final newManagedValue = _field(
        'category-management-value-new-${topic.id}',
      );
      await present(newManagedValue, 'inline new managed value');
      expect(
        find.descendant(
          of: topicBranch,
          matching: _icon(copy.text('r2.saveValue')),
        ),
        findsNothing,
      );
      await capture('category-value-create-empty', at: newManagedValue);
      await enter(newManagedValue, 'Leisure');
      final saveManagedValue = find.descendant(
        of: topicBranch,
        matching: _icon(copy.text('r2.saveValue')),
      );
      await capture('category-value-create-changed', at: saveManagedValue);
      await tap(saveManagedValue);
      await present(
        find.descendant(of: topicBranch, matching: find.text('Leisure')),
        'created managed value',
      );
      final leisure = (await categories.values(
        topic.id,
      )).singleWhere((value) => value.name == 'Leisure');
      final leisureRow = _key(leisure.id);
      await tap(
        find.descendant(
          of: leisureRow,
          matching: _icon(copy.text('r2.editValue')),
        ),
      );
      final renameValue = _field('category-management-value-${leisure.id}');
      await capture('category-value-rename-unchanged', at: renameValue);
      expect(
        find.descendant(
          of: leisureRow,
          matching: _icon(copy.text('r2.saveValue')),
        ),
        findsNothing,
      );
      await enter(renameValue, 'Travel');
      await capture('category-value-rename-changed', at: renameValue);
      await tap(
        find.descendant(
          of: leisureRow,
          matching: _icon(copy.text('r2.saveValue')),
        ),
      );
      await present(
        find.descendant(of: leisureRow, matching: find.text('Travel')),
        'renamed managed value',
      );
      await tap(
        find.descendant(
          of: leisureRow,
          matching: _icon(copy.text('category.deleteValue')),
        ),
      );
      await present(
        _button(copy.text('action.cancel')),
        'category value deletion confirmation',
      );
      await capture('category-delete-value-confirmation');
      await tap(_button(copy.text('action.cancel')));
      expect((await categories.valueById(leisure.id))!.name, 'Travel');
      await tap(
        find.descendant(
          of: topicBranch,
          matching: _button(copy.text('category.deleteDimension')),
        ),
      );
      await present(
        _button(copy.text('action.cancel')),
        'category dimension deletion confirmation',
      );
      await capture('category-delete-dimension-confirmation');
      await tap(_button(copy.text('action.cancel')));
      expect(await categories.dimensionById(topic.id), isNotNull);

      await tap(
        find.descendant(
          of: find.byType(CategoryManagement),
          matching: _button(copy.text('category.addDimension')),
        ),
      );
      final newDimensionName = _field('category-management-name-new');
      await capture('category-dimension-create-empty', at: newDimensionName);
      expect(saveDimension, findsNothing);
      await enter(newDimensionName, 'Topics');
      await tap(saveDimension);
      await present(
        find.text(copy.text('r2.categoryInvalid')),
        'duplicate category dimension validation',
      );
      await capture(
        'category-dimension-create-invalid',
        at: find.text(copy.text('r2.categoryInvalid')),
      );
      await enter(newDimensionName, 'Unit');
      await capture('category-dimension-create-changed', at: saveDimension);
      await tap(saveDimension);
      await wait(
        () => newDimensionName.evaluate().isEmpty,
        'new Unit dimension stored',
      );
      final unit = (await categories.dimensions(
        collection.id,
      )).singleWhere((dimension) => dimension.name == 'Unit');
      await capture(
        'category-dimension-created',
        at: _field('category-management-name-${unit.id}'),
      );
      await tap(find.byTooltip(copy.text('common.close')));

      final firstRow = _key('vocabulary-row-${firstWord.id}');
      await present(
        _key('category-label-${firstWord.id}-${food.id}'),
        'assigned category second row',
      );
      await capture(
        'vocabulary-assigned-chip',
        at: _key('category-label-${firstWord.id}-${food.id}'),
      );
      await tap(_key('vocabulary-${firstWord.id}'));
      final topicPicker = _key('category-picker-${firstWord.id}-${topic.id}');
      await present(topicPicker, 'vocabulary category picker action');
      await tap(topicPicker);
      await present(
        _key('category-value-${food.id}'),
        'assignment opening values',
      );
      expect(_button(copy.text('r2.apply')), findsNothing);
      await capture(
        'category-assignment-unchanged',
        at: _key('category-value-${food.id}'),
      );
      await tap(_key('category-value-${school.id}'));
      await present(_button(copy.text('r2.apply')), 'pending assignment Apply');
      await capture(
        'category-assignment-changed',
        at: _button(copy.text('r2.apply')),
      );
      await tap(_button(copy.text('r2.addValue')));
      final newPickerValue = _field('category-new-value-name');
      await capture('category-assignment-create-empty', at: newPickerValue);
      expect(_icon(copy.text('r2.saveValue')), findsNothing);
      await enter(newPickerValue, 'Practice');
      await capture(
        'category-assignment-create-changed',
        at: _icon(copy.text('r2.saveValue')),
      );
      await tap(_icon(copy.text('r2.saveValue')));
      await wait(
        () => newPickerValue.evaluate().isEmpty,
        'inline picker value stored without closing',
      );
      final practice = (await categories.values(
        topic.id,
      )).singleWhere((value) => value.name == 'Practice');
      await present(
        _key('category-value-${practice.id}'),
        'new independent unassigned value',
      );
      expect(
        tester
            .widget<PikoCheckbox>(_key('category-value-${practice.id}'))
            .value,
        isFalse,
      );
      expect(
        tester.widget<PikoCheckbox>(_key('category-value-${school.id}')).value,
        isTrue,
      );
      await capture(
        'category-assignment-value-created',
        at: _key('category-value-${practice.id}'),
      );
      await tap(find.byTooltip(copy.text('common.close')));
      await wait(
        () => find.byType(CategoryAssignmentPicker).evaluate().isEmpty,
        'safe assignment cancellation',
      );
      expect(
        (await categories.assignments(firstWord.id))
            .singleWhere((assignment) => assignment.dimensionId == topic.id)
            .valueIds,
        {food.id},
      );
      await capture(
        'category-assignment-cancelled',
        at: _key('category-label-${firstWord.id}-${food.id}'),
      );
      await tap(topicPicker);
      await present(_key('category-value-${school.id}'), 'reopened assignment');
      expect(_button(copy.text('r2.apply')), findsNothing);
      await tap(_key('category-value-${school.id}'));
      await tap(_button(copy.text('r2.apply')));
      await wait(
        () => find.byType(CategoryAssignmentPicker).evaluate().isEmpty,
        'confirmed assignment handed to autosave',
      );
      await present(
        _key('category-label-${firstWord.id}-${school.id}'),
        'confirmed assignment chip',
      );
      expect(
        (await categories.assignments(firstWord.id))
            .singleWhere((assignment) => assignment.dimensionId == topic.id)
            .valueIds,
        {school.id},
      );
      await capture(
        'category-assignment-applied',
        at: _key('category-label-${firstWord.id}-${school.id}'),
      );

      await tap(
        find.descendant(
          of: firstRow,
          matching: _button(copy.text('category.addDimension')),
        ),
      );
      await present(
        find.byType(CategoryDimensionForm),
        'vocabulary new-dimension popup',
      );
      final popupDimensionName = _field('category-dimension-name');
      expect(saveDimension, findsNothing);
      await capture('category-dimension-popup-empty', at: popupDimensionName);
      await enter(popupDimensionName, 'Source');
      await tap(_key('category-dimension-mode-multiple'));
      await capture('category-dimension-popup-changed', at: saveDimension);
      await tap(saveDimension);
      await wait(
        () => find.byType(CategoryDimensionForm).evaluate().isEmpty,
        'new dimension popup accepted',
      );
      expect(
        (await categories.dimensions(
          collection.id,
        )).singleWhere((dimension) => dimension.name == 'Source').mode,
        CategoryMode.multiple,
      );
      await wait(
        () =>
            tester
                .widget<PikoIconButton>(_key('inline-complete-${firstWord.id}'))
                .onPressed !=
            null,
        'category metadata refresh settles before finishing editor',
      );
      await tap(_key('inline-complete-${firstWord.id}'));
      await capture(
        'vocabulary-category-second-row',
        at: _key('category-label-${firstWord.id}-${school.id}'),
      );

      final liveDetail = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      await tap(_key('collection-filters'));
      await present(
        find.byType(FilterSelectionDialog),
        'unchanged Filters popup',
      );
      expect(_button(copy.text('r2.apply')), findsNothing);
      await capture('filters-unchanged', at: _key('filter-value-${school.id}'));
      await tap(_key('filter-value-${school.id}'));
      await capture('filters-changed', at: _button(copy.text('r2.apply')));
      await tap(_button(copy.text('r2.apply')));
      await wait(
        () =>
            liveDetail.queryBinding!.ready &&
            liveDetail.queryBinding!.snapshot!.entries.length == 2,
        'filtered Collection with two School words',
      );
      expect(liveDetail.queryBinding!.scope.filters, {
        topic.id: {school.id},
      });
      await capture(
        'detail-filtered-actions',
        at: _key('collection-review-targetToNative'),
        metadata: {'visibleWords': 2, 'dueDirectionalItems': 4},
      );
      await capture(
        'detail-filtered-vocabulary',
        at: _key('vocabulary-${firstWord.id}'),
      );
      await tap(_key('collection-filters'));
      await present(_key('filters-clear-pending'), 'active Filters reopening');
      expect(_button(copy.text('r2.apply')), findsNothing);
      await capture('filters-active', at: _key('filters-clear-pending'));
      await tap(_key('filters-clear-pending'));
      await capture('filters-clear-staged', at: _button(copy.text('r2.apply')));
      await tap(find.byTooltip(copy.text('common.close')));
      expect(liveDetail.queryBinding!.scope.filters, {
        topic.id: {school.id},
      });

      await enter(_key('collection-search'), 'no-such-fixture-word');
      await present(
        _key('collection-no-matches-clear-filters'),
        'search and category no matches',
      );
      expect(liveDetail.queryBinding!.scope.search, 'no-such-fixture-word');
      await capture(
        'search-no-matches',
        at: _key('collection-no-matches-clear-filters'),
      );
      await tap(_key('collection-no-matches-clear-filters'));
      await wait(
        () =>
            liveDetail.queryBinding!.ready &&
            liveDetail.queryBinding!.scope.filters.isEmpty,
        'direct category clear retains search',
      );
      expect(liveDetail.queryBinding!.scope.search, 'no-such-fixture-word');
      await capture('search-only-no-matches', at: _key('collection-search'));
      await tap(_key('collection-clear-search'));
      await wait(
        () =>
            liveDetail.queryBinding!.ready &&
            liveDetail.queryBinding!.snapshot!.entries.length == _words.length,
        'independent search clear restores all fixture words',
      );
      expect(liveDetail.queryBinding!.scope.filters, isEmpty);
      expect(liveDetail.queryBinding!.scope.search, '');

      // Exercise Apply for staged Clear as well as the safe-cancel path above.
      await tap(_key('collection-filters'));
      await present(
        _key('filter-value-${school.id}'),
        'Filters for clear confirmation',
      );
      await tap(_key('filter-value-${school.id}'));
      await tap(_button(copy.text('r2.apply')));
      await wait(
        () =>
            liveDetail.queryBinding!.ready &&
            liveDetail.queryBinding!.snapshot!.entries.length == 2,
        'School filter restored',
      );
      await tap(_key('collection-filters'));
      await present(_key('filters-clear-pending'), 'staged clear confirmation');
      await tap(_key('filters-clear-pending'));
      await tap(_button(copy.text('r2.apply')));
      await wait(
        () =>
            liveDetail.queryBinding!.ready &&
            liveDetail.queryBinding!.snapshot!.entries.length == _words.length,
        'confirmed filter clear restores full learning membership',
      );
      expect(liveDetail.queryBinding!.scope.filters, isEmpty);
      await capture('detail-filters-cleared', at: _key('collection-search'));
      expect(
        (await vocabulary.watchByCollection(collection.id).first).length,
        _words.length,
      );
      expect(
        liveDetail.queryBinding!.snapshot!.entries.map(
          (entry) => (entry.id, entry.targetText, entry.nativeText),
        ),
        fixtureWords.map(
          (entry) => (entry.id, entry.targetText, entry.nativeText),
        ),
      );
      for (final direction in LearningDirection.values) {
        expect(
          liveDetail.queryBinding!.snapshot!.directions[direction]!.dueCount,
          _words.length,
        );
        expect(
          liveDetail
              .queryBinding!
              .snapshot!
              .directions[direction]!
              .newSpeedItems
              .length,
          _words.length,
        );
        expect(
          await review.directionState(db, collection.id, direction),
          learningBeforeCategories[direction],
        );
      }

      await tap(_button(copy.text('action.new')));
      await present(find.byType(EntrySessionScreen), 'Entry session');
      await present(_entryField('target'), 'blank draft');
      await capture('entry-empty');
      await enter(_entryField('target'), '미완성');
      await tap(find.byTooltip(copy.text('action.saveNext')));
      await present(
        find.text(copy.text('entry.requiredNative')),
        'required native validation',
      );
      await capture('entry-required', at: _entryField('native'));
      await tap(find.byTooltip(copy.text('common.back')));
      await present(
        _button(copy.text('entry.continue')),
        'draft discard confirmation',
      );
      await capture('entry-discard');
      await tap(_button(copy.text('entry.continue')));
      await enter(_entryField('target'), '');

      await tap(_button(copy.text('json.title')));
      await present(find.byType(VocabularyJsonPage), 'Collection JSON page');
      await capture('json-input', at: _key('json-input'));
      await enter(_key('json-input'), '{ invalid fixture JSON');
      await tap(_button(copy.text('json.analyze')));
      await present(
        find.text(copy.text('json.invalidSyntax')),
        'invalid JSON issue',
      );
      await capture(
        'json-error',
        at: find.text(copy.text('json.invalidSyntax')),
      );

      final jsonPage = tester.widget<VocabularyJsonPage>(
        find.byType(VocabularyJsonPage),
      );
      final exported = await jsonPage.service.exportCollection(collection.id);
      final envelope = jsonDecode(exported) as Map<String, dynamic>;
      final importedCollections = envelope['collections'] as List;
      final entries = (importedCollections.single as Map)['entries'] as List;
      (entries.first as Map)['nativeText'] = 'Apfel (fixture preview only)';
      platform.clipboard = const JsonEncoder.withIndent('  ').convert(envelope);
      await tap(_button(copy.text('json.paste')));
      await tap(_button(copy.text('json.analyze')));
      await present(
        _button(copy.text('json.apply')),
        'valid changed-entry preview',
      );
      await capture('json-preview', at: _button(copy.text('json.apply')));
      await tap(_button(copy.text('json.apply')));
      await present(
        find.text(copy.text('json.confirmTitle')),
        'JSON replacement confirmation',
      );
      await capture('json-confirmation');
      await tap(_button(copy.text('action.cancel')));
      await tap(_button(copy.text('json.copy')));
      await present(
        find.text(copy.text('json.copied')),
        'export copied to fixture transport',
      );
      expect(platform.exported, exported);
      await capture('json-export', at: find.text(copy.text('json.copied')));
      platform.failCopy = true;
      await tap(_button(copy.text('json.copy')));
      await present(_key('json-fallback'), 'selectable export fallback');
      expect(
        tester.widget<TextField>(_key('json-fallback')).controller!.text,
        exported,
      );
      await capture(
        'json-export-fallback',
        at: _key('json-fallback'),
        metadata: {
          'injectedFailure': 'clipboard transport only; real export service',
        },
      );
      await tap(_button(copy.text('common.back')));
      await present(find.byType(EntrySessionScreen), 'Entry after JSON');
      await tap(find.byTooltip(copy.text('entry.complete')));
      await wait(
        () => find.byType(EntrySessionScreen).evaluate().isEmpty,
        'Entry completion',
      );

      // Reverse normal review leaves forward Speed eligibility untouched.
      await present(
        _key('collection-review-nativeToTarget'),
        'reverse review launch',
      );
      await tap(_key('collection-review-nativeToTarget'));
      await present(find.byType(ReviewSessionRoute), 'normal review route');
      final session = tester
          .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
          .session;
      await present(review.revealTarget, 'first hidden review card');
      await capture('review-hidden', at: review.revealTarget);
      for (var index = 0; index < _words.length; index++) {
        final prior = session.current!;
        await tap(review.revealTarget);
        if (index == 0) {
          await capture('review-revealed', at: _key('review-answer-text'));
          final hard = find.descendant(
            of: _key('review-hard'),
            matching: find.byType(PikoCheckbox),
          );
          await tap(hard);
          expect(session.hard, isTrue);
          await capture('review-hard', at: _key('review-hard'));
          await tap(
            hard,
          ); // Catalogue-only toggle must not alter the fixture grade.
        }
        await tap(_key('review-grade-${index == 0 ? 'incorrect' : 'correct'}'));
        await wait(
          () => !session.isSubmitting && !identical(prior, session.current),
          'accepted regular grade ${index + 1}',
        );
        if (index < _words.length - 1) {
          await present(review.revealTarget, 'next captured regular card');
          if (index == 0) {
            await capture(
              'review-previous-available',
              at: _key('review-correct-previous'),
            );
          }
        }
      }
      await present(_key('review-retry-wait'), 'persisted retry countdown');
      expect(session.retryWaitSeconds, 10);
      expect(_button(copy.text('action.retry')), findsNothing);
      await capture('review-countdown', at: _key('review-retry-wait'));
      final deadline = session.retryWaitDeadline!;
      pause();
      await tester.pump();
      clock.set(deadline);
      resume();
      await present(review.revealTarget, 'automatic eligible retry on resume');
      await capture(
        'review-retry',
        at: review.revealTarget,
        metadata: {'fixtureClockAdvancedTo': deadline.toIso8601String()},
      );
      await tap(review.revealTarget);
      await tap(_key('review-grade-correct'));
      await present(find.byType(ReviewSummaryDialog), 'normal review summary');
      expect(session.progress.completed, 5);
      expect(session.progress.firstTryCorrect, 4);
      await capture('review-summary');
      await tap(find.byTooltip(copy.text('common.close')));
      await wait(
        () => find.byType(ReviewSessionRoute).evaluate().isEmpty,
        'summary return to Collection',
      );

      await present(
        _key('collection-speed-targetToNative'),
        'forward Speed still new',
      );
      await tap(_key('collection-speed-targetToNative'));
      await present(find.byType(SpeedSetupDialog), 'Speed setup');
      expect(
        tester.widget<TextField>(_key('speed-pool-size')).controller!.text,
        '5',
      );
      await capture('speed-setup');
      await enter(_key('speed-pool-size'), '0');
      await present(
        find.text(copy.text('r2.poolInvalid')),
        'invalid pool validation',
      );
      expect(
        tester
            .widget<PikoButton>(_button(copy.text('learn.startSpeed')))
            .onPressed,
        isNull,
      );
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      await capture('speed-setup-invalid');
      await enter(_key('speed-pool-size'), '5');
      await tap(_button(copy.text('learn.startSpeed')));
      await present(find.byType(SpeedSessionRoute), 'Speed session route');
      final speed = tester
          .widget<SpeedSessionRoute>(find.byType(SpeedSessionRoute))
          .session;
      await present(_key('review-prompt'), 'first Speed card');
      await capture('speed-hidden', at: _key('review-prompt'));
      for (var index = 0; index < _words.length; index++) {
        final prior = speed.current!;
        await tap(_key('review-prompt'));
        if (index == 0) {
          await capture('speed-revealed', at: _key('review-answer-text'));
        }
        await tap(_key('speed-grade-${index == 0 ? 'incorrect' : 'correct'}'));
        await wait(
          () => !speed.isSubmitting && !identical(prior, speed.current),
          'accepted Speed answer ${index + 1}',
        );
        if (index < _words.length - 1) {
          await present(_key('review-prompt'), 'next Speed pass turn');
        }
      }
      await present(
        find.byType(SpeedNumbersBreak),
        'short-pool game after whole pass',
      );
      await capture(
        'speed-game',
        metadata: {'positions': speed.state!.numberGame!.positions},
      );
      // A wrong tap must leave both sequence and vocabulary progress unchanged.
      final beforeGame = speed.state!;
      await tap(_key('speed-number-10'));
      expect(identical(speed.state, beforeGame), isTrue);
      for (var number = 1; number <= 3; number++) {
        await tap(_key('speed-number-$number'));
      }
      await capture(
        'speed-game-progress',
        metadata: {
          'positions': speed.state!.numberGame!.positions,
          'nextNumber': 4,
          'completedVocabulary': speed.state!.completedEntryIds.length,
        },
      );
      for (var number = 4; number <= 10; number++) {
        await tap(_key('speed-number-$number'));
      }
      await present(
        _key('review-prompt'),
        'complete remaining pass after game',
      );
      final prior = speed.current!;
      await tap(_key('review-prompt'));
      await tap(_key('speed-grade-correct'));
      await wait(
        () => !speed.isSubmitting && !identical(prior, speed.current),
        'first consecutive correct after error',
      );
      await present(find.byType(SpeedNumbersBreak), 'one more whole-pass game');
      for (var number = 1; number <= 10; number++) {
        await tap(_key('speed-number-$number'));
      }
      await present(_key('review-prompt'), 'final remaining pass');
      await tap(_key('review-prompt'));
      await tap(_key('speed-grade-correct'));
      await wait(
        () => find.byType(SpeedSessionRoute).evaluate().isEmpty,
        'durable Speed completion auto-return',
      );
      final detail = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      await wait(
        () =>
            detail.queryBinding!.ready &&
            detail
                .queryBinding!
                .snapshot!
                .directions[LearningDirection.targetToNative]!
                .newSpeedItems
                .isEmpty,
        'final eligibility projection after Speed',
      );
      expect(find.byType(ReviewSummaryDialog), findsNothing);
      expect(_key('collection-speed-targetToNative'), findsNothing);
      await capture('speed-completed-detail');

      await tap(_button(copy.text('common.back')));
      await present(
        find.byType(CollectionsHome),
        'Home after completed sessions',
      );
      await tap(_button(copy.text('nav.settings')));
      await present(find.byType(SettingsRoute), 'Settings route');
      await present(
        find.byType(PikoDropdown<Locale>),
        'hydrated locale preference',
      );
      await capture('settings');
      await tap(
        find.descendant(
          of: find.byType(PikoDropdown<Locale>),
          matching: find.byType(DropdownButton<Locale>),
        ),
      );
      await capture('settings-language-choice');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(artifacts.captures.length, cataloguePlan.length);
      completed = true;
    } catch (error) {
      artifacts.failure = error.toString();
      rethrow;
    } finally {
      try {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (mounted) {
          // PikoRuntime drains every registered accepted operation before close.
          await db.closed.future.timeout(const Duration(seconds: 15));
        } else {
          await db.close();
        }
      } catch (error) {
        completed = false;
        artifacts.failure = 'Drain/close failed: $error';
        rethrow;
      } finally {
        artifacts.status = completed
            ? 'captured-not-yet-visually-reviewed'
            : 'failed-partial';
        await artifacts.writeManifest();
      }
    }
  });
}
