import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
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
    var mounted = false, completed = false;
    Future<void> wait(
      FutureOr<bool> Function() condition,
      String description,
    ) => review.waitUntil(tester, condition, description: description);
    Future<void> present(Finder finder, String description) =>
        wait(() => finder.evaluate().isNotEmpty, description);
    Future<void> tap(Finder finder) => review.tapVisible(tester, finder);
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
      await tester.enterText(target, '사과 fixture');
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
      await tester.enterText(target, '  ');
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
      await tester.enterText(_field('draft-target'), '친구');
      await tester.enterText(_field('draft-native'), 'Freund');
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
      await tap(addedCard);
      final savedNative = _field('${added.id}-native');
      await present(savedNative, 'saved Entry editor');
      await tester.enterText(savedNative, 'Freund fixture');
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
      await tap(_key('entry-card-draft'));
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
