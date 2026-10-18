import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/create_collection.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/settings/settings_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/components/piko_preference_picker.dart';
import 'package:piko/ui/components/piko_switch.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

/// An audit records guideline findings; it does not silently repair the product.
void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'inventory real Android surfaces and explicit preference boundaries',
    (tester) async {
      final config = CatalogueConfiguration(),
          copy = PikoCopy(CatalogueConfiguration().locale);
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/ux-audit-${config.runId}');
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final db = review.ReviewFixtureDatabase(
        File('${directory.path}/fixture.sqlite'),
        review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12)),
      );
      final fixture = Fixture(database: db),
          categories = SqliteCategoriesRepository(db);
      final surfaces = <Map<String, Object?>>[];
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
        'surfaces': surfaces,
      };
      var passed = false, converted = false;
      final semantics = tester.ensureSemantics();
      Finder key(String value) => find.byKey(ValueKey(value));
      Finder button(String id) =>
          find.widgetWithText(PikoButton, copy.text(id));
      Future<void> persist() =>
          File('${directory.path}/manifest.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(manifest),
            flush: true,
          );
      Future<void> reveal(Finder target) async {
        await tester.pumpAndSettle();
        if (target.evaluate().isNotEmpty) {
          await tester.ensureVisible(target.first);
          await tester.pumpAndSettle();
        }
        for (
          var attempt = 0;
          target.hitTestable().evaluate().isEmpty && attempt < 45;
          attempt++
        ) {
          final dialog = key('selection-dialog-body');
          final area = tester.getRect(
            dialog.evaluate().isNotEmpty
                ? dialog.last
                : find.byType(Scrollable).first,
          );
          final rect = target.evaluate().isEmpty
              ? null
              : tester.getRect(target.first);
          await tester.dragFrom(
            Offset(area.left + 4, area.center.dy),
            Offset(
              0,
              rect == null || rect.center.dy > area.center.dy ? -140 : 140,
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(target.hitTestable(), findsWidgets);
      }

      Future<void> tap(Finder target) async {
        await reveal(target);
        await tester.tap(target.hitTestable().first);
        await tester.pumpAndSettle();
      }

      Future<void> back() async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      Finder nav(String id) =>
          find.widgetWithText(PikoNavigationRow, copy.text(id));
      Finder action(String id) =>
          find.widgetWithText(PikoFormRow, copy.text(id));
      Future<void> pageBack() => tap(find.byTooltip(copy.text('common.back')));
      Future<void> close() => tap(find.byTooltip(copy.text('common.close')));
      Future<void> record(String id, {bool capture = false}) async {
        await tester.pumpAndSettle();
        final targets = await androidTapTargetGuideline.evaluate(tester);
        final labels = await labeledTapTargetGuideline.evaluate(tester);
        final rows = <Map<String, Object?>>[];
        for (final row in tester.widgetList<PikoFormRow>(
          find.byType(PikoFormRow),
        )) {
          final owner = find.byWidget(row);
          final bounds = tester.getRect(owner);
          final title = find
              .descendant(of: owner, matching: find.text(row.title))
              .first;
          final content = tester.getRect(title);
          final inset = content.left - bounds.left;
          expect(
            inset,
            closeTo(16, .5),
            reason: '$id / ${row.title}: shared row inset',
          );
          expect(bounds.height, greaterThanOrEqualTo(48));
          final icons = find.descendant(
            of: owner,
            matching: find.byType(PikoIcon),
          );
          double? trailingInset, centerDelta;
          if (icons.evaluate().isNotEmpty) {
            final glyph = tester.getRect(icons.last);
            trailingInset = bounds.right - glyph.right;
            centerDelta = glyph.center.dy - bounds.center.dy;
            expect(
              trailingInset,
              closeTo(16, .5),
              reason: '$id / ${row.title}: trailing inset',
            );
            expect(
              centerDelta,
              closeTo(0, .5),
              reason: '$id / ${row.title}: centered trailing icon',
            );
          }
          rows.add({
            'title': row.title,
            'inset': inset,
            'height': bounds.height,
            'trailingInset': trailingInset,
            'iconCenterDelta': centerDelta,
          });
        }
        surfaces.add({
          'id': id,
          'androidTargets': targets.passed,
          'targetFindings': targets.reason,
          'labels': labels.passed,
          'labelFindings': labels.reason,
          'formRowMeasurements': rows,
          'visibleText': [
            for (final text in tester.widgetList<Text>(find.byType(Text)))
              if (text.data != null) text.data,
          ],
        });
        if (capture && config.locale == 'en') {
          await settleCatalogueCapture(tester, id);
          if (!converted) {
            await integration.convertFlutterSurfaceToImage();
            await tester.pump();
            converted = true;
          }
          await File(
            '${directory.path}/$id.png',
          ).writeAsBytes(await integration.takeScreenshot(id));
        }
        await persist();
        expect(tester.takeException(), isNull, reason: id);
      }

      Future<void> menu() async {
        final expanded = key('collection-menu');
        if (expanded.evaluate().isNotEmpty) {
          await tester.ensureVisible(expanded);
          await tester.pumpAndSettle();
        }
        final compact = key('collection-compact-menu');
        await tap(
          compact.hitTestable().evaluate().isNotEmpty ? compact : expanded,
        );
      }

      Future<void> launch(String mode) async {
        final expanded = key('collection-$mode-targetToNative');
        if (expanded.evaluate().isNotEmpty) {
          await tester.ensureVisible(expanded);
          await tester.pumpAndSettle();
        }
        await tap(
          expanded.hitTestable().evaluate().isNotEmpty
              ? expanded
              : key('collection-$mode-compact'),
        );
        final direction = key('learning-direction-targetToNative');
        if (direction.evaluate().isNotEmpty) await tap(direction);
      }

      try {
        await fixture.initialize();
        final topic = await categories.createDimension(
          collectionId: fixture.owner.id,
          name: 'Topic',
          mode: CategoryMode.single,
        );
        final travel = await categories.createValue(
          dimensionId: topic.id,
          name: 'Travel',
        );
        final work = await categories.createValue(
          dimensionId: topic.id,
          name: 'Work',
        );
        await categories.setValueSelected(
          entryId: fixture.entry.id,
          valueId: travel.id,
          selected: true,
        );
        final settings = SqliteSettingsRepository(db);
        await settings.write('locale', config.locale);
        await settings.write(
          PreferredDirection.settingKey,
          PreferredDirection.both.name,
        );
        final protected = {
          for (final table in [
            'vocabulary_entries',
            'learning_items',
            'regular_reviews',
            'retry_obligations',
            'scope_answer_ordinals',
            'statistics_activity',
            'speed_completion_receipts',
            'vocabulary_category_assignments',
          ])
            table: await review.rows(db, table),
        };
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
        await record('home');
        await tap(find.byTooltip(copy.text('nav.settings')));
        expect(find.byType(SettingsRoute), findsOneWidget);
        final media = MediaQuery.of(tester.element(find.byType(SettingsRoute)));
        manifest['width'] = media.size.width;
        manifest['textScale'] = media.textScaler.scale(14) / 14;
        if (config.scale == '200') {
          expect(media.size.width, closeTo(320, 1));
          expect(media.textScaler.scale(14), closeTo(28, 1));
        }
        await record('global-settings', capture: true);
        await tap(find.byType(PikoPreferencePicker<Locale>));
        await record('global-language-choices');
        await back();
        await tap(key('settings-preferred-direction'));
        await record('global-direction-choices');
        await back();
        await tap(nav('settingsPreview.collections'));
        await record('settings-collections', capture: true);
        await tap(key('collection-settings-${fixture.owner.id}'));
        await record('collection-settings-from-global', capture: true);
        await pageBack();
        await pageBack();
        await pageBack();
        if (config.locale == 'en') {
          await tap(button('action.new'));
          expect(find.byType(CreateCollectionDialog), findsOneWidget);
          await record('create-collection');
          await close();
          await tap(key('statistics-open'));
          await record('statistics', capture: true);
          await tap(key('statistics-calendar-toggle'));
          await tap(key('statistics-month-jump'));
          await record('statistics-month-picker');
          await close();
          await tap(key('statistics-help'));
          await record('statistics-help');
          await tap(button('home.collections'));
        }
        await tap(key('collection-${fixture.owner.id}'));
        expect(find.byType(CollectionDetail), findsOneWidget);
        await record('collection-detail');
        await menu();
        await record('collection-settings', capture: true);
        final hint = key('collection-hint-default');
        final openingHint = tester.widget<PikoSwitch>(hint).value;
        await tap(hint);
        expect(tester.widget<PikoSwitch>(hint).value, !openingHint);
        await pageBack();
        await menu();
        expect(tester.widget<PikoSwitch>(hint).value, !openingHint);
        await tap(hint);
        await tap(nav('catPreview.categories'));
        await record('category-overview', capture: true);
        await tap(find.text('Topic').last);
        final carry = key('category-carry-over-${topic.id}');
        await record('category-definition-form', capture: true);
        await tap(carry);
        expect((await categories.dimensionById(topic.id))!.carryOver, isFalse);
        await pageBack();
        await record('category-unsaved-confirmation');
        await tap(button('form.discard'));
        await tap(find.text('Topic').last);
        expect(tester.widget<PikoSwitch>(carry).value, isFalse);
        await record('category-reopened-unsaved-discarded');
        await tap(carry);
        await tap(button('category.saveDimension'));
        expect((await categories.dimensionById(topic.id))!.carryOver, isTrue);
        await pageBack();
        await tap(find.text('Topic').last);
        expect(tester.widget<PikoSwitch>(carry).value, isTrue);
        await record('category-properties-saved-and-reopened');
        await tap(carry);
        await tap(button('category.saveDimension'));
        expect((await categories.dimensionById(topic.id))!.carryOver, isFalse);
        await tap(nav('r2.addValue'));
        await record('category-value-create', capture: true);
        await tap(button('r2.save'));
        await record('category-value-validation');
        final valueField = find.descendant(
          of: key('category-value-name'),
          matching: find.byType(TextField),
        );
        await tester.enterText(valueField, 'Audit value');
        await tester.pumpAndSettle();
        await tap(button('r2.save'));
        final created = (await categories.values(
          topic.id,
        )).singleWhere((v) => v.name == 'Audit value');
        Finder valueRow(String name) => find
            .ancestor(
              of: find.text(name),
              matching: find.byType(PikoFormFieldRow),
            )
            .first;
        await tap(
          find.descendant(
            of: valueRow('Audit value'),
            matching: find.byTooltip(copy.text('r2.editValue')),
          ),
        );
        await record('category-value-rename');
        await tester.enterText(valueField, 'Renamed audit value');
        await tester.pumpAndSettle();
        await tap(button('r2.save'));
        expect(
          (await categories.values(
            topic.id,
          )).singleWhere((v) => v.id == created.id).name,
          'Renamed audit value',
        );
        await tap(
          find.descendant(
            of: valueRow('Renamed audit value'),
            matching: find.byTooltip(copy.text('category.deleteValue')),
          ),
        );
        await record('category-value-delete-confirmation');
        await tap(button('catPreview.delete'));
        expect(
          (await categories.values(topic.id)).where((v) => v.id == created.id),
          isEmpty,
        );
        await pageBack();
        await pageBack();
        await pageBack();
        if (config.locale == 'en') {
          await tap(key('collection-filters'));
          await record('filters', capture: true);
          await tap(key('filter-value-${work.id}'));
          await record('filters-staged');
          await close();
          expect(
            tester
                .widget<CollectionDetail>(find.byType(CollectionDetail))
                .queryBinding!
                .scope
                .filters,
            isEmpty,
          );
          for (final id in ['collection-group', 'collection-sort']) {
            await tap(key(id));
            await record(id);
            await close();
          }
          await tap(key('collection-list-menu'));
          await record('list-options');
          await tap(find.textContaining(copy.text('view.mode')).last);
          await record('layout-picker');
          await pageBack();
          await record('layout-returned-overview');
          await close();
          await tap(key('collection-list-menu'));
          await tap(find.textContaining(copy.text('view.languageOrder')).last);
          await record('language-order-picker');
          await close();
          await tap(key('collection-learning-help'));
          await record('learning-help');
          await tap(find.byTooltip(copy.text('learnHelp.close')));
          await tap(key('vocabulary-${fixture.entry.id}'));
          await record('saved-vocabulary-editor', capture: true);
          await tap(key('category-picker-${fixture.entry.id}-${topic.id}'));
          await record('category-assignment', capture: true);
          await tap(key('category-value-${work.id}'));
          await close();
          expect(
            (await categories.assignments(fixture.entry.id)).single.valueIds,
            {travel.id},
          );
          await tap(nav('category.addDimension'));
          await record('create-category-group');
          await close();
          await tap(key('inline-delete-${fixture.entry.id}'));
          // Explicit vocabulary deletion uses its bounded Undo contract;
          // Collection/category definitions separately require confirmation.
          await tap(button('vocab.undo'));
          await record('vocabulary-restored-after-undo');
          await tap(find.byTooltip(copy.text('action.addEntry')));
          await record('entry-method');
          await tap(nav('entry.manualMethod'));
          expect(find.byType(EntrySessionScreen), findsOneWidget);
          await record('new-vocabulary-editor', capture: true);
          final target = find.descendant(
            of: key('draft-target'),
            matching: find.byType(TextField),
          );
          await reveal(target);
          await tester.enterText(target, 'audit word');
          final native = find.descendant(
            of: key('draft-native'),
            matching: find.byType(TextField),
          );
          await tester.enterText(native, 'Auditwort');
          await tester.pumpAndSettle();
          await tap(find.byTooltip(copy.text('action.saveNext')));
          final entryScreen = tester.widget<EntrySessionScreen>(
            find.byType(EntrySessionScreen),
          );
          final saved = entryScreen.session.confirmedEntries.single;
          expect(key('entry-card-${saved.id}'), findsOneWidget);
          await record('entry-session-retains-history', capture: true);
          final stackRect = tester.getRect(key('entry-stack'));
          await tester.dragFrom(
            Offset(stackRect.left + 4, stackRect.center.dy),
            const Offset(0, 2000),
          );
          await tester.pumpAndSettle();
          expect(entryScreen.session.activeEntryId, saved.id);
          await record('entry-session-revisit', capture: true);
          await pageBack();
          await tap(find.byTooltip(copy.text('action.addEntry')));
          await tap(nav('entry.manualMethod'));
          await tester.enterText(
            find.descendant(
              of: key('draft-target'),
              matching: find.byType(TextField),
            ),
            'unfinished audit',
          );
          await pageBack();
          await record('entry-discard-confirmation');
          await tap(button('entry.discard'));
          await menu();
          await tap(action('json.importTab'));
          await record('json-import');
          final input = key('json-input');
          await reveal(input);
          await tester.enterText(input, '{ invalid audit JSON');
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tap(button('json.analyze'));
          expect(find.text(copy.text('json.invalidSyntax')), findsOneWidget);
          await record('json-error', capture: true);
          final expandInput = button('json.expandInput');
          await reveal(expandInput);
          // The PikoButton widget can resolve to a merged dialog ancestor.
          // Measure the specifically labeled button node, not that ancestor.
          final nodes = <SemanticsNode>[];
          void collect(SemanticsNode node) {
            if (node.label == copy.text('json.expandInput')) nodes.add(node);
            node.visitChildren((child) {
              collect(child);
              return true;
            });
          }

          for (final view in tester.binding.renderViews) {
            collect(view.owner!.semanticsOwner!.rootSemanticsNode!);
          }
          expect(nodes, hasLength(1));
          final semanticRect = nodes.single.rect;
          manifest['jsonExpandTargetAfterReveal'] = {
            'width': semanticRect.width,
            'height': semanticRect.height,
          };
          expect(semanticRect.width, greaterThanOrEqualTo(48));
          expect(semanticRect.height, greaterThanOrEqualTo(48));
          await record('json-error-expand-revealed');
          await tap(key('json-export-tab'));
          await record('json-export');
          await close();
          await pageBack();
          await launch('speed');
          await record('speed-setup', capture: true);
          await close();
          await launch('review');
          await record('review-question');
          await tap(key('review-reveal-target'));
          await record('review-answer');
          await tap(key('learning-edit-answer'));
          await record('review-answer-editor');
          await tap(key('inline-complete-${fixture.entry.id}'));
          await tap(key('review-exit'));
          await menu();
          await tap(key('collection-menu-delete'));
          await record('delete-collection-confirmation');
          await tap(button('action.cancel'));
        }
        for (final table in protected.keys) {
          final after = await review.rows(db, table);
          expect(
            after,
            containsAll(protected[table]!),
            reason:
                'Audit preserved original fixture $table; new session records are explicit',
          );
        }
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        semantics.dispose();
        manifest['passed'] = passed;
        await persist();
        debugPrint('PIKO_UX_AUDIT_EVIDENCE:${directory.path}');
      }
    },
  );
}
