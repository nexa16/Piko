import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/collections/filter_selection_dialog.dart';
import 'package:piko/features/categories/category_management.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/piko_theme.dart';
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart'
    show CatalogueConfiguration, CatalogueJsonPlatform;
import 'support/round2_supplement_fixture.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _button(String label) => find.widgetWithText(PikoButton, label);
Finder _field(String key) =>
    find.descendant(of: _key(key), matching: find.byType(TextField));

/// Coordinator protocol: run this target separately with the same
/// PIKO_CATALOGUE_RUN/COMMIT/LOCALE/SCALE defines as the main catalogue. It owns
/// only `round2-supplement-<run>-<locale>-<scale>/fixture.sqlite`. Retrieve retained
/// PNGs/manifest after completion; never uninstall or clear personal app data.
/// This source alone is not evidence of device execution or visual acceptance.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('round 2 isolated supplemental Android key states', (
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
    final artifacts = await SupplementArtifacts.create(config);
    final file = File('${artifacts.directory.path}/fixture.sqlite');
    if (await file.exists()) {
      throw StateError('Refusing supplement DB reuse');
    }
    final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 16, 9));
    final db = review.ReviewFixtureDatabase(file, clock);
    final collections = SqliteCollectionsRepository(db);
    final vocabulary = SqliteVocabularyRepository(db);
    final learning = SqliteLearningRepository(db);
    final categories = SqliteCategoriesRepository(db);
    var mounted = false, completed = false;
    Future<void> wait(
      FutureOr<bool> Function() condition,
      String description,
    ) => review.waitUntil(tester, condition, description: description);
    Future<void> present(Finder finder, String description) =>
        wait(() => finder.evaluate().isNotEmpty, description);
    Future<Rect> revealEntryWithGesture(
      Finder finder, {
      required bool requireCenter,
    }) async {
      final viewport = _key('entry-stack');
      expect(viewport, findsOneWidget);
      var target = tester.getRect(finder);
      var area = tester.getRect(viewport);
      var visible = target.intersect(area);
      bool reachable() =>
          visible.width >= 24 &&
          visible.height >= 24 &&
          (!requireCenter || finder.hitTestable().evaluate().isNotEmpty);
      for (var attempt = 0; attempt < 3 && !reachable(); attempt++) {
        final distance = target.bottom > area.bottom
            ? area.bottom - target.bottom - 8
            : target.top < area.top
            ? area.top - target.top + 8
            : 0.0;
        if (distance.abs() < 1) break;
        final limit = area.height * .75;
        await tester.dragFrom(
          Offset(area.left + 4, area.center.dy),
          Offset(0, distance.clamp(-limit, limit).toDouble()),
        );
        await tester.pumpAndSettle();
        target = tester.getRect(finder);
        area = tester.getRect(viewport);
        visible = target.intersect(area);
      }
      expect(
        visible.width,
        greaterThanOrEqualTo(24),
        reason: 'Entry control must be horizontally reachable: '
            'target=$target visible=$visible',
      );
      expect(
        visible.height,
        greaterThanOrEqualTo(24),
        reason: 'Entry control must remain reachable above the keyboard: '
            'target=$target visible=$visible',
      );
      if (requireCenter) {
        expect(
          finder.hitTestable(),
          findsOneWidget,
          reason: 'Entry action center must receive its tap after a real drag: '
              'target=$target visible=$visible',
        );
      }
      return visible;
    }
    Future<void> tap(Finder finder) async {
      await present(finder, 'supplement action present');
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      if (finder.hitTestable().evaluate().isEmpty &&
          find
              .ancestor(of: finder, matching: _key('entry-stack'))
              .evaluate()
              .isNotEmpty) {
        await revealEntryWithGesture(finder, requireCenter: true);
      } else {
        expect(
          finder.hitTestable(),
          findsOneWidget,
          reason: 'Supplement action must receive its tap after layout settles',
        );
      }
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> activateEntry(String id) async {
      // Entry cards are scroll-driven, not tap-to-activate. Match the real
      // gesture used by entry_stack_test.dart; never call controller selection.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await wait(
        () =>
            MediaQuery.viewInsetsOf(
              tester.element(find.byType(EntrySessionScreen)),
            ).bottom ==
            0,
        'keyboard hidden before deliberate Entry stack scroll',
      );
      await tester.pumpAndSettle();
      final session = tester
          .widget<EntrySessionScreen>(find.byType(EntrySessionScreen))
          .session;
      final desired = id == 'draft' ? null : id;
      for (
        var attempt = 0;
        attempt < 8 && session.activeEntryId != desired;
        attempt++
      ) {
        final viewport = tester.getRect(_key('entry-stack'));
        final card = tester.getRect(_key('entry-card-$id'));
        final ids = [
          ...session.confirmedEntries.map((entry) => entry.id),
          'draft',
        ];
        final forward =
            ids.indexOf(id) > ids.indexOf(session.activeEntryId ?? 'draft');
        var distance = viewport.center.dy - card.center.dy;
        final position = tester
            .widget<SingleChildScrollView>(_key('entry-stack'))
            .controller!
            .position;
        if (position.maxScrollExtent - position.minScrollExtent <= .5) {
          // Fitting stacks navigate by drag direction, not a midpoint that
          // cannot be reached through scroll offset.
          distance = forward ? -80 : 80;
        }
        // A screenshot may already have programmatically centered an inactive
        // card. A real nonzero scroll is still required to activate that card.
        if (distance.abs() < 24) {
          distance = forward ? -48 : 48;
        }
        final bounded = distance.clamp(
          -viewport.height * .8,
          viewport.height * .8,
        );
        await tester.dragFrom(
          Offset(viewport.left + 4, viewport.center.dy),
          Offset(0, bounded.toDouble()),
        );
        await tester.pumpAndSettle();
      }
      expect(
        session.activeEntryId,
        desired,
        reason: 'Deliberate scrolling must activate Entry $id',
      );
      expect(tester.widget<PikoCard>(_key('entry-card-$id')).selected, isTrue);
    }

    Future<void> enter(Finder finder, String text) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      if (finder.hitTestable().evaluate().isNotEmpty) {
        await tester.tap(finder);
      } else {
        // The focused first input follows programmatic scrolls. On a narrow
        // keyboard viewport, a person instead drags the stack to reach the
        // second input. Exercise that real gesture before tapping it.
        final visible = await revealEntryWithGesture(
          finder,
          requireCenter: false,
        );
        await tester.tapAt(visible.center);
      }
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(finder).focusNode?.hasFocus,
        isTrue,
        reason: 'Supplement input must gain focus from the real tap',
      );
      await tester.enterText(finder, text);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(finder).controller!.text, text);
    }

    Future<void> capture(
      String id, {
      Finder? at,
      Map<String, Object?> metadata = const {},
    }) => artifacts.capture(binding, tester, id, at: at, metadata: metadata);
    Future<List<Object?>> learningSnapshot() => Future.wait([
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ])
        review.rows(db, table),
    ]);
    Future<CollectionRecord> create(String name) => collections.create(
      name: name,
      targetLanguage: VocabularyLanguage.korean,
      nativeLanguage: VocabularyLanguage.german,
    );
    Future<void> open(CollectionRecord collection) async {
      await tap(
        find.descendant(
          of: _key('collection-${collection.id}'),
          matching: find.text(collection.name),
        ),
      );
      await present(find.byType(CollectionDetail), 'supplement Detail route');
      await wait(
        () => tester
            .widget<CollectionDetail>(find.byType(CollectionDetail))
            .queryBinding!
            .ready,
        'supplement Detail projection ready',
      );
    }

    try {
      await SqliteSettingsRepository(db).write('locale', config.locale);
      final empty = await create('Empty fixture');
      final caughtUp = await create('Caught-up fixture');
      final practice = await create('Korean Practice');
      final futureWord = await vocabulary.create(
        collectionId: caughtUp.id,
        targetText: '내일',
        nativeText: 'Morgen',
      );
      final first = await vocabulary.create(
        collectionId: practice.id,
        targetText: '사과',
        nativeText: 'Apfel',
      );
      await vocabulary.create(
        collectionId: practice.id,
        targetText: '책',
        nativeText: 'Buch',
      );
      // Fixture-only scheduling produces truthful empty/one-direction states.
      // These writes finish before the runtime and never touch an installed DB.
      for (final item in await learning.forEntry(futureWord.id)) {
        await learning.saveCard(
          item.id,
          item.card..due = clock.now().add(const Duration(days: 7)),
        );
        await (db.update(db.learningItems)
              ..where((row) => row.id.equals(item.id)))
            .write(const LearningItemsCompanion(speedCompleted: Value(true)));
      }
      for (final word
          in await vocabulary.watchByCollection(practice.id).first) {
        for (final item in await learning.forEntry(word.id)) {
          if (item.direction == LearningDirection.nativeToTarget) {
            await learning.saveCard(
              item.id,
              item.card..due = clock.now().add(const Duration(days: 7)),
            );
            await (db.update(
              db.learningItems,
            )..where((row) => row.id.equals(item.id))).write(
              const LearningItemsCompanion(speedCompleted: Value(true)),
            );
          }
        }
      }
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
      final seededLearning = await learningSnapshot();

      await open(empty);
      expect(_key('collection-review-targetToNative'), findsNothing);
      expect(_key('collection-review-nativeToTarget'), findsNothing);
      expect(_key('collection-speed-actions'), findsNothing);
      expect(find.text(copy.text('r2.caughtUp')), findsNothing);
      await capture(
        'empty-detail',
        at: find.text(copy.text('collection.empty')),
      );
      await tap(_key('collection-menu'));
      await tap(find.text(copy.text('r2.editCategories')));
      final emptyManagement = find.descendant(
        of: find.byType(CategoryManagement),
        matching: find.text(copy.text('r2.noCategories')),
      );
      await present(emptyManagement, 'category management without definitions');
      await capture('category-management-empty', at: emptyManagement);
      expect(await categories.dimensions(empty.id), isEmpty);
      await tap(find.byTooltip(copy.text('common.close')));
      await tap(_key('collection-filters'));
      final emptyFilters = find.descendant(
        of: find.byType(FilterSelectionDialog),
        matching: find.text(copy.text('r2.noCategories')),
      );
      await present(emptyFilters, 'Filters without definitions');
      expect(_button(copy.text('r2.apply')), findsNothing);
      await capture('filters-empty', at: emptyFilters);
      await tap(find.byTooltip(copy.text('common.close')));
      expect(await categories.dimensions(empty.id), isEmpty);
      expect(await learningSnapshot(), seededLearning);
      await tap(_button(copy.text('common.back')));
      await present(find.byType(CollectionsHome), 'Home after empty Detail');
      await open(caughtUp);
      expect(_key('collection-review-targetToNative'), findsNothing);
      expect(_key('collection-review-nativeToTarget'), findsNothing);
      await present(
        find.text(copy.text('r2.caughtUp')),
        'honest caught-up encouragement',
      );
      await capture('caughtup-detail', at: find.text(copy.text('r2.caughtUp')));
      await tap(_button(copy.text('common.back')));
      await present(find.byType(CollectionsHome), 'caught-up Overview');
      final caughtUpCard = _key('collection-${caughtUp.id}');
      await wait(
        () =>
            find
                .descendant(
                  of: caughtUpCard,
                  matching: find.text(copy.text('collection.reviewLoading')),
                )
                .evaluate()
                .isEmpty &&
            find
                .descendant(
                  of: caughtUpCard,
                  matching: _key('collection-review-quick'),
                )
                .evaluate()
                .isEmpty,
        'zero Overview action hidden',
      );
      expect(
        find.descendant(
          of: caughtUpCard,
          matching: find.text(copy.text('collection.reviewLoadFailed')),
        ),
        findsNothing,
      );
      expect(find.text(copy.text('r2.caughtUp')), findsNothing);
      await capture('caughtup-home', at: caughtUpCard);

      await open(practice);
      await present(
        _key('collection-speed-targetToNative'),
        'sole forward Speed action',
      );
      expect(_key('collection-speed-nativeToTarget'), findsNothing);
      expect(_key('collection-review-nativeToTarget'), findsNothing);
      expect(_key('collection-review-targetToNative'), findsOneWidget);
      final speed = tester.getRect(_key('collection-speed-targetToNative'));
      final speedRow = tester.getRect(_key('collection-speed-actions'));
      expect(speed.left, closeTo(speedRow.left, .1));
      expect(
        speed.width * 2 + pikoDesign.dimension('spacing.2'),
        closeTo(speedRow.width, .1),
      );
      await capture(
        'one-direction-detail',
        at: _key('collection-review-targetToNative'),
        metadata: {
          'dueForward': 2,
          'dueReverse': 0,
          'speedForward': 2,
          'speedReverse': 0,
        },
      );
      expect(await learningSnapshot(), seededLearning);

      await tap(_key('vocabulary-${first.id}'));
      final target = _field('inline-${first.id}-target');
      await present(target, 'unchanged vocabulary editor');
      expect(_key('inline-discard-${first.id}'), findsNothing);
      await capture('vocabulary-unchanged', at: target);
      await enter(target, '사과 fixture');
      await wait(
        () async =>
            (await vocabulary.watchById(first.id).first)!.targetText ==
            '사과 fixture',
        'accepted reversible vocabulary autosave',
      );
      await capture(
        'vocabulary-changed',
        at: _key('inline-complete-${first.id}'),
      );
      await enter(target, '  ');
      await present(
        find.text(copy.text('entry.requiredTarget')),
        'invalid raw target retained',
      );
      expect(
        (await vocabulary.watchById(first.id).first)!.targetText,
        '사과 fixture',
      );
      await capture('vocabulary-invalid', at: target);
      await tap(_key('inline-discard-${first.id}'));
      await wait(
        () => target.evaluate().isEmpty,
        'Discard restores opening vocabulary and closes editor',
      );
      expect(
        (await vocabulary.watchById(first.id).first)!.targetText,
        first.targetText,
      );
      expect(await learningSnapshot(), seededLearning);
      await capture('vocabulary-discarded', at: _key('vocabulary-${first.id}'));

      final firstRow = _key('vocabulary-row-${first.id}');
      await tester.ensureVisible(_key('vocabulary-${first.id}'));
      await tester.drag(_key('vocabulary-${first.id}'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      final delete = find.descendant(
        of: firstRow,
        matching: _button(copy.text('vocab.delete')),
      );
      await present(delete, 'revealed explicit Collection Delete');
      await capture('collection-delete-revealed', at: firstRow);
      await tap(delete);
      final undo = _key('collection-undo-${first.id}');
      await present(undo, 'Collection Undo offer');
      expect(await vocabulary.watchById(first.id).first, isNull);
      await capture('collection-undo', at: undo);
      await tap(
        find.descendant(of: undo, matching: _button(copy.text('vocab.undo'))),
      );
      await present(_key('vocabulary-${first.id}'), 'Collection word restored');
      expect(await learningSnapshot(), seededLearning);

      await tap(_button(copy.text('action.new')));
      await present(find.byType(EntrySessionScreen), 'supplement Entry route');
      await enter(_field('draft-target'), '친구');
      await enter(_field('draft-native'), 'Freund');
      await tap(find.byTooltip(copy.text('action.saveNext')));
      final entrySession = tester
          .widget<EntrySessionScreen>(find.byType(EntrySessionScreen))
          .session;
      await wait(
        () => entrySession.confirmedEntries.length == 1 && !entrySession.isBusy,
        'Entry confirmation and fresh draft',
      );
      final added = entrySession.confirmedEntries.single;
      final addedCard = _key('entry-card-${added.id}');
      await capture('entry-saved-card', at: addedCard);
      await capture('entry-new-draft', at: _key('entry-card-draft'));
      await activateEntry(added.id);
      final savedNative = _field('${added.id}-native');
      await present(savedNative, 'saved Entry editor');
      final beforeInactiveDrafts = await learningSnapshot();
      await wait(
        () => entrySession.activeEntryId == added.id,
        'saved editor owns the stack before compact draft capture',
      );
      final compactDraft = _key('entry-card-draft');
      expect(
        find.descendant(
          of: compactDraft,
          matching: find.text(copy.text('entry.newVocabulary')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: compactDraft, matching: find.byType(TextField)),
        findsNothing,
      );
      await capture('entry-inactive-empty-draft', at: compactDraft);
      expect(entrySession.activeEntryId, added.id);
      await activateEntry('draft');
      await enter(_field('draft-target'), '부분 fixture');
      await activateEntry(added.id);
      await wait(
        () => entrySession.activeEntryId == added.id,
        'partial draft remains inactive beside the saved editor',
      );
      expect(
        find.descendant(of: compactDraft, matching: find.text('부분 fixture')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: compactDraft,
          matching: find.text(copy.text('entry.newVocabulary')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: compactDraft, matching: find.byType(TextField)),
        findsNothing,
      );
      await capture('entry-inactive-partial-draft', at: compactDraft);
      expect(entrySession.activeEntryId, added.id);
      expect(entrySession.draft.nativeText, isEmpty);
      await activateEntry('draft');
      expect(
        tester.widget<TextField>(_field('draft-target')).controller!.text,
        '부분 fixture',
      );
      await enter(_field('draft-target'), '');
      await activateEntry(added.id);
      await present(
        savedNative,
        'saved editor after temporary draft is cleared',
      );
      expect(entrySession.confirmedEntries.length, 1);
      expect(await learningSnapshot(), beforeInactiveDrafts);
      await enter(savedNative, 'Freund fixture');
      await wait(
        () async =>
            (await vocabulary.watchById(added.id).first)!.nativeText ==
            'Freund fixture',
        'saved Entry text autosave',
      );
      await capture('entry-saved-edit', at: savedNative);
      final beforeEntryDelete = await learningSnapshot();
      await tap(
        find.descendant(
          of: addedCard,
          matching: _button(copy.text('vocab.delete')),
        ),
      );
      final entryUndo = _key('undo-${added.id}');
      await present(entryUndo, 'Entry deletion Undo');
      await capture('entry-undo', at: entryUndo);
      await tap(
        find.descendant(
          of: entryUndo,
          matching: _button(copy.text('vocab.undo')),
        ),
      );
      await wait(
        () => entrySession.confirmedEntries.any((word) => word.id == added.id),
        'Entry identity restored',
      );
      expect(
        (await vocabulary.watchById(added.id).first)!.nativeText,
        'Freund fixture',
      );
      expect(await learningSnapshot(), beforeEntryDelete);
      await activateEntry('draft');
      await tap(find.byTooltip(copy.text('entry.complete')));
      await wait(
        () => find.byType(EntrySessionScreen).evaluate().isEmpty,
        'Entry completes without an extra draft word',
      );
      expect((await vocabulary.watchByCollection(practice.id).first).length, 3);

      await present(
        _key('collection-review-targetToNative'),
        'forward fixed-direction Review',
      );
      await tap(_key('collection-review-targetToNative'));
      await present(find.byType(ReviewSessionRoute), 'normal Review route');
      expect(find.byType(ReviewDirectionDialog), findsNothing);
      final session = tester
          .widget<ReviewSessionRoute>(find.byType(ReviewSessionRoute))
          .session;
      expect(session.direction, LearningDirection.targetToNative);
      await present(review.revealTarget, 'first supplement question');
      final prior = session.current!;
      await tap(review.revealTarget);
      await tap(_key('review-grade-correct'));
      await wait(
        () => !session.isSubmitting && !identical(prior, session.current),
        'one accepted regular grade',
      );
      await present(
        _key('review-correct-previous'),
        'Previous correction available',
      );
      final beforeCorrection = await learningSnapshot();
      await tap(_key('review-correct-previous'));
      await present(
        _key('review-correcting-context'),
        'previous-answer correction mode',
      );
      expect(session.isCorrecting, isTrue);
      await capture('review-correction', at: _key('review-correcting-context'));
      expect(await learningSnapshot(), beforeCorrection);
      await tap(_key('review-exit'));
      await wait(
        () => find.byType(ReviewSessionRoute).evaluate().isEmpty,
        'correction exits without regrading',
      );
      expect(await learningSnapshot(), beforeCorrection);
      // Append independent fixtures only after the original state catalogue;
      // scheduling below cannot change the earlier directional assertions.
      await tap(_button(copy.text('common.back')));
      await open(caughtUp);
      final beforeEmptyLaunch = await learningSnapshot();
      final detail = tester.widget<CollectionDetail>(
        find.byType(CollectionDetail),
      );
      final emptySession = await detail.reviewSessionFactory!(
        caughtUp.id,
        LearningDirection.targetToNative,
      );
      // Test-only navigation displays the real authoritative zero-result route.
      // Production intentionally has no zero-count launch action to tap.
      unawaited(
        Navigator.of(tester.element(find.byType(CollectionDetail))).push(
          MaterialPageRoute<void>(
            builder: (_) => ReviewSessionRoute(
              collection: caughtUp,
              session: emptySession,
              vocabularyRepository: vocabulary,
            ),
          ),
        ),
      );
      await present(_key('review-no-due'), 'authoritative no-due route');
      expect(find.text(copy.text('learn.noDueTitle')), findsOneWidget);
      expect(_key('review-prompt'), findsNothing);
      expect(_key('review-grade-correct'), findsNothing);
      await capture(
        'review-no-due',
        at: _key('review-no-due'),
        metadata: {
          'navigation':
              'test-only push after actual runtime authoritative preparation',
          'displayedZeroCountAction': false,
        },
      );
      expect(await learningSnapshot(), beforeEmptyLaunch);
      await tap(_key('review-exit'));
      await present(find.byType(CollectionDetail), 'Detail after no-due exit');
      await tap(_button(copy.text('common.back')));

      final waiting = await create('Retry waiting fixture');
      final retryWord = await vocabulary.create(
        collectionId: waiting.id,
        targetText: '다시',
        nativeText: 'Wieder',
      );
      for (final item in await learning.forEntry(retryWord.id)) {
        if (item.direction == LearningDirection.targetToNative) {
          await learning.review(
            kind: ReviewKind.regular,
            expectedPrior: item,
            rating: LearningRating.again,
            reviewedAt: clock.now(),
          );
        } else {
          await learning.saveCard(
            item.id,
            item.card..due = clock.now().add(const Duration(days: 7)),
          );
        }
      }
      await open(waiting);
      await present(
        find.text(copy.text('r2.pending')),
        'pending retry is not caught up',
      );
      expect(find.text(copy.text('r2.caughtUp')), findsNothing);
      await capture(
        'pending-retry-detail',
        at: find.text(copy.text('r2.pending')),
      );
      await tap(_button(copy.text('common.back')));

      final filtered = await create('Filtered scheduled fixture');
      final scheduled = await vocabulary.create(
        collectionId: filtered.id,
        targetText: '나중에',
        nativeText: 'Später',
      );
      await vocabulary.create(
        collectionId: filtered.id,
        targetText: '오늘',
        nativeText: 'Heute',
      );
      for (final item in await learning.forEntry(scheduled.id)) {
        await learning.saveCard(
          item.id,
          item.card..due = clock.now().add(const Duration(days: 7)),
        );
        await (db.update(db.learningItems)
              ..where((row) => row.id.equals(item.id)))
            .write(const LearningItemsCompanion(speedCompleted: Value(true)));
      }
      final scheduleDimension = await categories.createDimension(
        collectionId: filtered.id,
        name: 'Schedule',
        mode: CategoryMode.single,
      );
      final scheduledValue = await categories.createValue(
        dimensionId: scheduleDimension.id,
        name: 'Later',
      );
      await categories.replaceAssignments(
        entryId: scheduled.id,
        assignments: {
          scheduleDimension.id: {scheduledValue.id},
        },
      );
      await open(filtered);
      await tap(_key('collection-filters'));
      await tap(_key('filter-value-${scheduledValue.id}'));
      await tap(_button(copy.text('r2.apply')));
      await present(
        find.text(copy.text('collection.filteredNoReview')),
        'nonempty restricted zero is neutral',
      );
      expect(find.text(copy.text('r2.caughtUp')), findsNothing);
      await capture(
        'filtered-zero-detail',
        at: find.text(copy.text('collection.filteredNoReview')),
      );
      await tap(_button(copy.text('common.back')));

      final speedOnly = await create('Speed-only fixture');
      final speedWord = await vocabulary.create(
        collectionId: speedOnly.id,
        targetText: '새로운',
        nativeText: 'Neu',
      );
      for (final item in await learning.forEntry(speedWord.id)) {
        await learning.saveCard(
          item.id,
          item.card..due = clock.now().add(const Duration(days: 7)),
        );
      }
      await open(speedOnly);
      expect(_key('collection-review-targetToNative'), findsNothing);
      expect(_key('collection-review-nativeToTarget'), findsNothing);
      await present(
        _key('collection-speed-targetToNative'),
        'Speed-only eligibility',
      );
      expect(_key('collection-speed-nativeToTarget'), findsOneWidget);
      await capture('speed-only-detail', at: _key('collection-speed-actions'));
      await tap(_button(copy.text('common.back')));

      final emptyDimension = await categories.createDimension(
        collectionId: practice.id,
        name: 'Empty notes',
        mode: CategoryMode.multiple,
      );
      final largeDimension = await categories.createDimension(
        collectionId: practice.id,
        name: 'Large topic',
        mode: CategoryMode.single,
      );
      for (var index = 1; index <= 24; index++) {
        await categories.createValue(
          dimensionId: largeDimension.id,
          name: 'Topic ${index.toString().padLeft(2, '0')}',
        );
      }
      final beforePickers = await learningSnapshot();
      await open(practice);
      await tap(_key('vocabulary-${first.id}'));
      await tap(_key('category-picker-${first.id}-${emptyDimension.id}'));
      await present(
        find.text(copy.text('category.emptyValues')),
        'empty category picker',
      );
      await capture(
        'category-empty-picker',
        at: find.text(copy.text('category.emptyValues')),
      );
      await tap(find.byTooltip(copy.text('common.close')));
      await tap(_key('category-picker-${first.id}-${largeDimension.id}'));
      final valueSearch = _field('category-value-search');
      await present(valueSearch, 'overflow category picker search');
      await capture(
        'category-overflow-picker',
        at: valueSearch,
        metadata: {'valueCount': 24},
      );
      await enter(valueSearch, 'no-matching-fixture-value');
      await present(
        find.text(copy.text('r2.noValueMatches')),
        'category search no match',
      );
      await capture('category-no-match-picker', at: valueSearch);
      await tap(find.byTooltip(copy.text('common.close')));
      expect(await categories.assignments(first.id), isEmpty);
      await tap(_key('inline-complete-${first.id}'));
      expect(await learningSnapshot(), beforePickers);

      await tap(_button(copy.text('action.new')));
      await present(find.byType(EntrySessionScreen), 'duplicate Entry fixture');
      await enter(_field('draft-target'), first.targetText);
      await enter(_field('draft-native'), first.nativeText);
      await tap(find.byTooltip(copy.text('action.saveNext')));
      await present(
        find.text(copy.text('vocab.inlineDuplicate')),
        'specific duplicate feedback',
      );
      expect(
        tester.widget<TextField>(_field('draft-target')).controller!.text,
        first.targetText,
      );
      expect(
        tester.widget<TextField>(_field('draft-native')).controller!.text,
        first.nativeText,
      );
      expect(
        find.descendant(
          of: find.byType(EntrySessionScreen),
          matching: _button(copy.text('action.retry')),
        ),
        findsNothing,
      );
      await capture(
        'entry-duplicate',
        at: find.text(copy.text('vocab.inlineDuplicate')),
      );
      expect(await learningSnapshot(), beforePickers);
      await enter(_field('draft-target'), '');
      await enter(_field('draft-native'), '');
      await tap(find.byTooltip(copy.text('entry.complete')));
      await wait(
        () => find.byType(EntrySessionScreen).evaluate().isEmpty,
        'empty duplicate draft exits without a new vocabulary item',
      );
      await tap(_button(copy.text('common.back')));
      final savedDuplicates = await create('Saved duplicate fixture');
      await open(savedDuplicates);
      await tap(_button(copy.text('action.new')));
      await present(
        find.byType(EntrySessionScreen),
        'saved duplicate Entry route',
      );
      final duplicateSession = tester
          .widget<EntrySessionScreen>(find.byType(EntrySessionScreen))
          .session;
      await enter(_field('draft-target'), '하나');
      await enter(_field('draft-native'), 'Eins fixture');
      await tap(find.byTooltip(copy.text('action.saveNext')));
      await wait(
        () =>
            duplicateSession.confirmedEntries.length == 1 &&
            !duplicateSession.isBusy,
        'first conflict fixture confirmed',
      );
      await enter(_field('draft-target'), '둘');
      await enter(_field('draft-native'), 'Zwei fixture');
      await tap(find.byTooltip(copy.text('action.saveNext')));
      await wait(
        () =>
            duplicateSession.confirmedEntries.length == 2 &&
            !duplicateSession.isBusy,
        'second conflict fixture confirmed',
      );
      final conflict = duplicateSession.confirmedEntries.first;
      final edited = duplicateSession.confirmedEntries.last;
      final editedCard = _key('entry-card-${edited.id}');
      final duplicateLearning = await learningSnapshot();
      await activateEntry(edited.id);
      await enter(_field('${edited.id}-target'), conflict.targetText);
      await wait(
        () async =>
            (await vocabulary.watchById(edited.id).first)!.targetText ==
            conflict.targetText,
        'valid intermediate target edit drains before duplicate native text',
      );
      await enter(_field('${edited.id}-native'), conflict.nativeText);
      final savedDuplicateError = find.descendant(
        of: editedCard,
        matching: find.text(copy.text('vocab.inlineDuplicate')),
      );
      await present(
        savedDuplicateError,
        'saved-entry specific duplicate feedback',
      );
      expect(
        find.descendant(
          of: editedCard,
          matching: _button(copy.text('action.retry')),
        ),
        findsNothing,
      );
      expect(
        (await vocabulary.watchById(edited.id).first)!.nativeText,
        edited.nativeText,
      );
      await capture('entry-saved-duplicate', at: savedDuplicateError);
      await activateEntry('draft');
      await activateEntry(edited.id);
      await present(
        _field('${edited.id}-native'),
        'duplicate saved editor reopened',
      );
      await wait(
        () => !duplicateSession.savedEntryState(edited.id).isSaving,
        'unchanged duplicate revalidation settles',
      );
      expect(duplicateSession.savedEntryState(edited.id).error, isNotNull);
      expect(
        tester
            .widget<TextField>(_field('${edited.id}-native'))
            .controller!
            .text,
        conflict.nativeText,
      );
      expect(
        find.descendant(
          of: editedCard,
          matching: _button(copy.text('action.retry')),
        ),
        findsNothing,
      );
      await capture('entry-saved-duplicate-reopened', at: savedDuplicateError);
      await activateEntry(conflict.id);
      await enter(_field('${conflict.id}-native'), 'Eins geändert fixture');
      await wait(
        () async =>
            (await vocabulary.watchById(conflict.id).first)!.nativeText ==
            'Eins geändert fixture',
        'conflicting saved entry changed and drained',
      );
      await activateEntry(edited.id);
      await present(
        _field('${edited.id}-native'),
        'retained saved edit reopened after conflict removal',
      );
      await wait(
        () async =>
            (await vocabulary.watchById(edited.id).first)!.nativeText ==
                conflict.nativeText &&
            !duplicateSession.savedEntryState(edited.id).isSaving &&
            duplicateSession.savedEntryState(edited.id).error == null,
        'retained saved edit revalidates and autosaves without retyping',
      );
      expect(savedDuplicateError, findsNothing);
      await capture(
        'entry-saved-duplicate-resolved',
        at: _field('${edited.id}-native'),
      );
      expect(await learningSnapshot(), duplicateLearning);
      await activateEntry('draft');
      await tap(find.byTooltip(copy.text('entry.complete')));
      await wait(
        () => find.byType(EntrySessionScreen).evaluate().isEmpty,
        'saved duplicate fixture exits without another draft save',
      );
      expect(
        (await vocabulary.watchByCollection(savedDuplicates.id).first).length,
        2,
      );
      expect(artifacts.captures.length, supplementPlan.length);
      expect(tester.takeException(), isNull);
      completed = true;
    } catch (error) {
      artifacts.failure = error.toString();
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
        artifacts.failure = 'Supplement drain/close failed: $error';
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
