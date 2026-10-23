import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/features/vocabulary/compact_vocabulary_pair.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import '../test/data/regular_reviews_test.dart' show Fixture, instant;
import 'review_correction_android_test.dart' as native;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

/// Native, isolated fixture: never opens ordinary piko.sqlite or calls AI.
/// Required defines use the existing catalogue source/run provenance contract.
void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Round11 native cards, selection, IME, Undo and language preservation',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/round11-feedback-${config.runId}',
      );
      if (await directory.exists()) {
        throw StateError('Unique feedback run ID required');
      }
      await directory.create();
      final db = native.ReviewFixtureDatabase(
        File('${directory.path}/fixture.sqlite'),
        native.ReviewFixtureClock(instant),
      );
      final fixture = Fixture(database: db);
      final stages = <Map<String, Object?>>[];
      final report = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'normalProductionDatabaseOpened': false,
        'providerCalled': false,
        'evidenceDirectory': directory.path,
        'states': stages,
        'passed': false,
      };
      Future<void> persist() =>
          File('${directory.path}/manifest.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(report),
            flush: true,
          );
      Future<void> wait(bool Function() condition, String description) async {
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          await tester.pump(const Duration(milliseconds: 40));
          if (condition()) return;
        }
        throw StateError('Feedback condition not reached: $description');
      }

      Finder keyed(String key) => find.byKey(ValueKey(key));
      Future<void> reveal(Finder target) async {
        for (var i = 0; i < 45; i++) {
          if (target.hitTestable().evaluate().isNotEmpty) return;
          if (target.evaluate().isNotEmpty) {
            await Scrollable.ensureVisible(
              tester.element(target.first),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            if (target.hitTestable().evaluate().isNotEmpty) return;
          }
          final viewport = tester.getRect(find.byType(Scrollable).first);
          await tester.dragFrom(
            Offset(viewport.left + 28, viewport.bottom - 40),
            const Offset(0, -150),
          );
          await tester.pumpAndSettle();
        }
        throw StateError('Feedback control not reachable');
      }

      Future<void> tap(Finder target) async {
        await reveal(target);
        await tester.tap(target.hitTestable().first);
        await tester.pumpAndSettle();
      }

      Offset visibleRowPoint(Finder target) {
        var area = tester.getRect(find.byType(Scrollable).first);
        final compact = keyed('collection-compact-header');
        if (compact.evaluate().isNotEmpty) {
          final bottom = tester.getRect(compact).bottom;
          if (bottom > area.top) {
            area = Rect.fromLTRB(area.left, bottom, area.right, area.bottom);
          }
        }
        final visible = tester.getRect(target).intersect(area);
        expect(
          visible.height,
          greaterThan(0),
          reason: 'A visible row target is required',
        );
        return Offset(visible.left + 12, visible.center.dy);
      }

      Future<Map<String, Object?>> contentSnapshot() async => {
        for (final table in [
          'vocabulary_entries',
          'vocabulary_examples',
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'vocabulary_category_assignments',
          'scope_answer_ordinals',
        ])
          table:
              (await db.customSelect('SELECT * FROM $table').get())
                  .map((r) => r.data)
                  .toList()
                ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b))),
      };
      bool mountedRuntime = false;
      try {
        await fixture.initialize();
        await fixture.review();
        await fixture.review(reverse: true);
        final categories = SqliteCategoriesRepository(db);
        final group = await categories.createDimension(
          collectionId: fixture.owner.id,
          name: 'Feedback topic',
          mode: CategoryMode.multiple,
        );
        final value = await categories.createValue(
          dimensionId: group.id,
          name: 'Travel',
        );
        final entry = await fixture.vocabulary.updateWithContent(
          id: fixture.entry.id,
          targetText: 'A complete vocabulary phrase with several words',
          nativeText: 'Eine vollständige Übersetzung mit mehreren Wörtern',
          assignments: {
            group.id: {value.id},
          },
          content: const VocabularyContent(
            examples: [
              ExamplePair(
                targetText: 'First example.',
                nativeText: 'Erstes Beispiel.',
              ),
              ExamplePair(
                targetText: 'Second example.',
                nativeText: 'Zweites Beispiel.',
              ),
              ExamplePair(
                targetText: 'Third example.',
                nativeText: 'Drittes Beispiel.',
              ),
            ],
            hintText: 'Synthetic feedback content',
          ),
        );
        for (var i = 0; i < 40; i++) {
          await fixture.vocabulary.create(
            collectionId: fixture.owner.id,
            targetText: 'Word $i',
            nativeText: 'Übersetzung $i',
          );
        }
        await SqliteSettingsRepository(db).write('locale', config.locale);
        mountedRuntime = true;
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        final copy = await hydratedRuntimeCopy(tester);
        await tap(
          find.descendant(
            of: keyed('collection-${fixture.owner.id}'),
            matching: find.text(fixture.owner.name),
          ),
        );
        await wait(
          () => find.byType(CollectionDetail).evaluate().isNotEmpty,
          'Collection route',
        );
        final detail = tester.widget<CollectionDetail>(
          find.byType(CollectionDetail),
        );
        final query = detail.queryBinding!;
        await wait(() => query.ready, 'Ready projection');
        // At enlarged text the vocabulary sliver is below the initial cache;
        // scroll to the actual row before reading its lazily built consumer.
        await reveal(keyed('vocabulary-${entry.id}'));
        final list = tester.widget<CollectionVocabulary>(
          find.byType(CollectionVocabulary),
        );
        final selection = list.selection!;
        final card = keyed('vocabulary-${entry.id}');
        await reveal(card);
        expect(
          find.descendant(
            of: card,
            matching: find.byType(CompactVocabularyPair),
          ),
          findsOneWidget,
        );
        final pair = find.descendant(
          of: card,
          matching: find.text(entry.nativeText),
        );
        expect(tester.widget<Text>(pair).maxLines, isNull);
        expect(keyed('vocabulary-edit-${entry.id}'), findsOneWidget);
        stages.add({
          'state': 'compact',
          'fullTextWrap': true,
          'editVisible': true,
        });

        await query.scope.saveView(
          const CollectionViewPreferences(mode: VocabularyViewMode.detailed),
        );
        await tester.pumpAndSettle();
        await reveal(card);
        expect(find.text('First example.'), findsOneWidget);
        expect(find.text('Second example.'), findsNothing);
        await tap(keyed('vocabulary-examples-${entry.id}'));
        expect(find.text('Second example.'), findsOneWidget);
        expect(find.byType(PikoDialog), findsNothing);
        await tap(keyed('vocabulary-examples-${entry.id}'));
        expect(find.text('Second example.'), findsNothing);
        await tester.longPressAt(visibleRowPoint(card));
        await tester.pumpAndSettle();
        final indicator = keyed('vocabulary-selection-indicator-${entry.id}');
        expect(
          tester.getCenter(indicator).dy,
          lessThan(tester.getRect(card).center.dy),
        );
        expect(selection.ids, {entry.id});
        selection.clear();
        await tester.pumpAndSettle();
        stages.add({
          'state': 'detailed',
          'firstExampleDisclosure': true,
          'selectionTopRight': true,
        });

        // Native IME: no substituted viewInsets/test text-input registration.
        expect(integration.registerTestTextInput, isFalse);
        await tap(keyed('vocabulary-edit-${entry.id}'));
        final field = find.descendant(
          of: keyed('inline-${entry.id}-target'),
          matching: find.byType(TextField),
        );
        await tap(field);
        await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        double imeInset() => MediaQuery.viewInsetsOf(
          tester.element(find.byType(PikoDialog).last),
        ).bottom;
        await wait(() => imeInset() > 0, 'Actual IME visible');
        final nativeInset = imeInset();
        await tester.tap(
          find
              .descendant(
                of: find.byType(PikoDialog).last,
                matching: find.text(copy.text('vocab.inlineEdit')),
              )
              .first,
        );
        await wait(() => imeInset() == 0, 'Outside title tap hides actual IME');
        expect(
          tester.widget<TextField>(field).controller!.text,
          entry.targetText,
        );
        await tap(field);
        await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        await wait(() => imeInset() > 0, 'Actual IME reopened');
        await tester.enterText(field, '  ');
        await tester.pumpAndSettle();
        final controller = tester.widget<TextField>(field).controller!;
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 1,
        );
        final close = find.byWidgetPredicate(
          (w) =>
              w is PikoIconButton &&
              w.semanticLabel == copy.text('common.close'),
        );
        await tap(close);
        expect(field, findsOneWidget);
        expect(controller.text, '  ');
        expect(
          controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 1),
        );
        expect(tester.takeException(), isNull);
        await tap(field);
        await wait(() => imeInset() > 0, 'IME focused for correction');
        await tester.enterText(field, entry.targetText);
        await tester.pumpAndSettle();
        await wait(
          () =>
              tester.widget<TextField>(field).controller!.text ==
              entry.targetText,
          'Corrected draft (${tester.widget<TextField>(field).controller!.text})',
        );
        await tap(close);
        await wait(
          () => find.byType(PikoDialog).evaluate().isEmpty,
          'One-tap valid Close',
        );
        await wait(
          () =>
              MediaQuery.viewInsetsOf(
                tester.element(find.byType(CollectionDetail)),
              ).bottom ==
              0,
          'IME hidden after first action tap',
        );
        expect(tester.takeException(), isNull);
        stages.add({
          'state': 'native-ime',
          'actualInset': nativeInset,
          'outsideTapDefocused': true,
          'invalidDraftPreserved': true,
          'firstActionTapClosed': true,
          'layoutException': false,
        });

        await query.scope.saveView(
          CollectionViewPreferences(
            grouping: group.id,
            sort: VocabularySort.targetDescending,
          ),
        );
        query.scope.setFilters({
          group.id: {value.id},
        });
        await wait(
          () => query.ready && query.snapshot!.entries.length == 1,
          'Filtered group',
        );
        await tester.pumpAndSettle();
        final heading = keyed('collection-group-${value.id}');
        await reveal(heading);
        expect(keyed('collection-group-selection-${value.id}'), findsNothing);
        await tester.longPressAt(visibleRowPoint(heading));
        await tester.pumpAndSettle();
        expect(selection.ids, {entry.id});
        expect(query.scope.expandedGroups, isEmpty);
        expect(
          tester
              .widget<Checkbox>(keyed('collection-group-selection-${value.id}'))
              .value,
          isTrue,
        );
        selection.clear();
        query.scope.expandGroups([value.id], true);
        await tester.pumpAndSettle();
        final groupedCard = keyed('vocabulary-${value.id}/${entry.id}');
        await reveal(groupedCard);
        final beforeUndo = await contentSnapshot();
        final beforeCount = query.snapshot!.allEntries.length;
        final viewport = tester.getRect(find.byType(Scrollable).first);
        await tester.dragFrom(
          visibleRowPoint(groupedCard),
          const Offset(-170, 0),
        );
        await tester.pumpAndSettle();
        final delete = find.descendant(
          of: keyed('vocabulary-row-${value.id}/${entry.id}'),
          matching: find.widgetWithText(PikoButton, copy.text('vocab.delete')),
        );
        await tester.tapAt(tester.getRect(delete).intersect(viewport).center);
        await wait(
          () =>
              query.ready &&
              query.snapshot!.allEntries.length == beforeCount - 1,
          'Deleted projection',
        );
        final undo = find.widgetWithText(PikoButton, copy.text('vocab.undo'));
        await wait(
          () =>
              undo.evaluate().isNotEmpty &&
              tester.widget<PikoButton>(undo).onPressed != null,
          'Undo re-enabled after query',
        );
        await tester.tap(undo);
        await wait(
          () => query.ready && query.snapshot!.allEntries.length == beforeCount,
          'Restored projection',
        );
        expect(await contentSnapshot(), beforeUndo);
        expect(query.snapshot!.entries.map((e) => e.id), [entry.id]);
        expect(query.scope.filters, {
          group.id: {value.id},
        });
        expect(query.scope.expandedGroups, {value.id});
        stages.add({
          'state': 'undo',
          'actualFeedbackTap': true,
          'filteredGroupedSorted': true,
          'completeContentLearningPreserved': true,
        });

        final beforeLanguages = await contentSnapshot();
        await (fixture.collections as CollectionLanguageRepository)
            .setLanguages(
              id: fixture.owner.id,
              targetLanguage: VocabularyLanguage.korean,
              nativeLanguage: VocabularyLanguage.english,
            );
        await wait(
          () =>
              query.ready &&
              query.snapshot!.collection.targetLanguage ==
                  VocabularyLanguage.korean,
          'Updated language metadata',
        );
        expect(await contentSnapshot(), beforeLanguages);
        stages.add({
          'state': 'language-change',
          'sourceFieldNotSwapped': true,
          'contentLearningPreserved': true,
          'verification':
              'actual Android SQLite operation; settings entrance covered separately',
        });

        query.scope.setFilters(const {});
        await query.scope.saveView(const CollectionViewPreferences());
        await wait(
          () => query.ready && query.snapshot!.entries.length == beforeCount,
          'Full list again',
        );
        await tester.pumpAndSettle();
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(position.viewportDimension * 1.2);
        await tester.pumpAndSettle();
        await tap(keyed('collection-scroll-to-top'));
        await wait(() => position.pixels.abs() < 1, 'Scroll to top');
        expect(keyed('collection-scroll-to-top'), findsNothing);
        expect(tester.takeException(), isNull);
        stages.add({
          'state': 'scroll',
          'viewportThresholdFab': true,
          'returnedToBeginning': true,
          'nativeViewport': MediaQuery.sizeOf(
            tester.element(find.byType(CollectionDetail)),
          ).toString(),
        });

        // Two normal app-surface captures after real keyboard interaction ends.
        await reveal(keyed('vocabulary-${entry.id}'));
        await settleCatalogueCapture(tester, 'round11-compact');
        await integration.convertFlutterSurfaceToImage();
        await tester.pump();
        await File(
          '${directory.path}/compact.png',
        ).writeAsBytes(await integration.takeScreenshot('round11-compact'));
        await query.scope.saveView(
          const CollectionViewPreferences(mode: VocabularyViewMode.detailed),
        );
        await tester.pumpAndSettle();
        await reveal(keyed('vocabulary-${entry.id}'));
        await File(
          '${directory.path}/detailed.png',
        ).writeAsBytes(await integration.takeScreenshot('round11-detailed'));
        report['passed'] = true;
        integration.reportData ??= <String, dynamic>{};
        integration.reportData!['round11Feedback'] = report;
      } finally {
        await persist();
        if (mountedRuntime) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await db.closed.future;
        } else {
          await db.close();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
