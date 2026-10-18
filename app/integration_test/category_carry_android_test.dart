import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_switch.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import '../test/ui/entry_keyboard_layout_test.dart' show scrollActionIntoView;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native carry settings, manual confirmation, failure recovery and fresh session',
    (tester) async {
      final config = CatalogueConfiguration(),
          copy = PikoCopy(CatalogueConfiguration().locale);
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/carry-${config.runId}');
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final file = File('${directory.path}/fixture.sqlite');
      final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12));
      final db = review.ReviewFixtureDatabase(file, clock);
      // The production runtime uses only this isolated fixture connection.
      final fixture = Fixture(database: db),
          categories = SqliteCategoriesRepository(db);
      var passed = false, converted = false;
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
      };
      Finder key(String value) => find.byKey(ValueKey(value));
      Finder field(String value) =>
          find.descendant(of: key(value), matching: find.byType(TextField));
      Finder button(String id) =>
          find.widgetWithText(PikoButton, copy.text(id));
      Finder body() {
        final dialog = key('selection-dialog-body');
        if (dialog.evaluate().isNotEmpty) return dialog.last;
        if (key('entry-stack').evaluate().isNotEmpty) return key('entry-stack');
        return find.byType(Scrollable).first;
      }

      Future<void> reveal(Finder target) async {
        await tester.pumpAndSettle();
        for (
          var i = 0;
          target.hitTestable().evaluate().isEmpty && i < 45;
          i++
        ) {
          final area = tester.getRect(body()), rect = tester.getRect(target);
          await tester.dragFrom(
            Offset(area.left + 4, area.center.dy),
            Offset(0, rect.center.dy > area.center.dy ? -160 : 160),
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

      Future<void> text(Finder target, String value) async {
        await reveal(target);
        await tester.enterText(target, value);
        await tester.pumpAndSettle();
      }

      Future<void> done() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await review.waitUntil(
          tester,
          () => tester.view.viewInsets.bottom == 0,
          description: 'native keyboard hidden',
        );
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

      try {
        await fixture.initialize();
        await fixture.review();
        await fixture.review(reverse: true);
        final groups = <CategoryDimensionRecord>[],
            values = <List<CategoryValueRecord>>[];
        for (var i = 0; i < 3; i++) {
          final g = await categories.createDimension(
            collectionId: fixture.owner.id,
            name: ['Topic', 'Context', 'Level'][i],
            mode: i == 1 ? CategoryMode.multiple : CategoryMode.single,
          );
          groups.add(g);
          values.add([
            for (var j = 0; j < (i == 1 ? 2 : 1); j++)
              await categories.createValue(
                dimensionId: g.id,
                name:
                    ['Travel', 'Daily', 'Basic'][i] + (j == 1 ? ' extra' : ''),
              ),
          ]);
        }
        await SqliteSettingsRepository(db).write('locale', config.locale);
        final protected = {
          for (final t in [
            'learning_items',
            'regular_reviews',
            'retry_obligations',
            'scope_answer_ordinals',
            'statistics_activity',
            'speed_completion_receipts',
          ])
            t: await review.rows(db, t),
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
        await tap(key('collection-${fixture.owner.id}'));
        await tap(key('collection-menu'));
        await tap(key('collection-menu-categories'));
        final firstToggle = key('category-carry-over-${groups[0].id}');
        await tap(key('category-dimension-${groups[0].id}'));
        expect(tester.widget<PikoSwitch>(firstToggle).value, isFalse);
        await tap(firstToggle);
        expect(
          (await categories.dimensionById(groups[0].id))!.carryOver,
          isFalse,
        );
        await tap(find.byTooltip(copy.text('common.close')));
        await tap(key('collection-menu'));
        await tap(key('collection-menu-categories'));
        for (var i = 0; i < 2; i++) {
          await tap(key('category-dimension-${groups[i].id}'));
          final toggle = key('category-carry-over-${groups[i].id}');
          expect(tester.widget<PikoSwitch>(toggle).value, isFalse);
          await tap(toggle);
          if (i == 0) {
            await db.customStatement(
              "CREATE TRIGGER fail_pref BEFORE INSERT ON category_group_preferences BEGIN SELECT RAISE(ABORT,'synthetic failure'); END",
            );
            await tap(button('category.saveDimension'));
            expect(
              find.text(copy.text('category.dimensionSaveFailed')),
              findsOneWidget,
            );
            expect(tester.widget<PikoSwitch>(toggle).value, isTrue);
            expect(
              (await categories.dimensionById(groups[i].id))!.carryOver,
              isFalse,
            );
            await db.customStatement('DROP TRIGGER fail_pref');
          }
          await tap(button('category.saveDimension'));
          await review.waitUntil(
            tester,
            () async =>
                (await categories.dimensionById(groups[i].id))!.carryOver,
          );
          if (i == 0) {
            await reveal(toggle);
            await capture('carry-settings');
          }
          await tap(key('category-dimension-${groups[i].id}'));
        }
        await tap(find.byTooltip(copy.text('common.close')));
        await tap(find.byTooltip(copy.text('action.addEntry')));
        await review.waitUntil(
          tester,
          () => find.byType(EntrySessionScreen).evaluate().isNotEmpty,
        );
        final screen = tester.widget<EntrySessionScreen>(
              find.byType(EntrySessionScreen),
            ),
            session = screen.session;
        final media = MediaQuery.of(
          tester.element(find.byType(EntrySessionScreen)),
        );
        manifest['width'] = media.size.width;
        manifest['textScale'] = media.textScaler.scale(14) / 14;
        if (config.scale == '200') {
          expect(media.size.width, closeTo(320, 1));
          expect(media.textScaler.scale(14), closeTo(28, 1));
        }
        expect(session.draft.assignments, isEmpty);
        await text(field('draft-target'), ' raw A ');
        await text(field('draft-native'), ' native A ');
        expect(integration.registerTestTextInput, isFalse);
        await review.waitUntil(
          tester,
          () => tester.view.viewInsets.bottom > 0,
          description: 'real IME shown',
        );
        final nativeController = tester
            .widget<TextField>(field('draft-native'))
            .controller!;
        nativeController.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 5,
        );
        final disclosure = key('categories-toggle-draft');
        await scrollActionIntoView(tester, disclosure);
        final top = tester.getTopLeft(disclosure).dy;
        await tester.tap(disclosure);
        final deltas = <double>[];
        for (var frame = 0; frame < 24; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final delta = tester.getTopLeft(disclosure).dy - top;
          deltas.add(delta);
          expect(delta.abs(), lessThanOrEqualTo(.5));
        }
        expect(nativeController.text, ' native A ');
        expect(
          nativeController.selection,
          const TextSelection(baseOffset: 2, extentOffset: 5),
        );
        expect(
          tester.widget<TextField>(field('draft-native')).focusNode!.hasFocus,
          isTrue,
        );
        manifest['categoryDisclosureFrameDeltas'] = deltas;
        await done();
        for (var i = 0; i < 3; i++) {
          await tap(key('category-picker-draft-${groups[i].id}'));
          for (final value in values[i]) {
            await tap(key('category-value-${value.id}'));
          }
          await tap(button('r2.apply'));
        }
        await tap(button('action.saveNext'));
        await review.waitUntil(
          tester,
          () => session.confirmedEntries.length == 1,
        );
        final carried = {
          groups[0].id: {values[0][0].id},
          groups[1].id: values[1].map((v) => v.id).toSet(),
        };
        expect(session.draft.assignments, carried);
        expect(session.hasDraftCategoryEdits, isFalse);
        // Confirmed values are visible in the collapsed disclosure of the fresh card.
        await reveal(key('categories-toggle-draft'));
        await capture('carry-next-draft');
        await text(field('draft-target'), ' raw B ');
        await text(field('draft-native'), ' native B ');
        await done();
        final picker = key('category-picker-draft-${groups[0].id}');
        if (picker.evaluate().isEmpty) {
          await tap(key('categories-toggle-draft'));
        }
        for (var i = 0; i < 2; i++) {
          await tap(key('category-picker-draft-${groups[i].id}'));
          await tap(key('category-value-${values[i][0].id}'));
          await tap(button('r2.apply'));
        }
        final edited = {
              groups[1].id: {values[1][1].id},
            },
            rawDraft = session.draft;
        expect(rawDraft.assignments, edited);
        await db.customStatement(
          "CREATE TRIGGER fail_word BEFORE INSERT ON vocabulary_entries BEGIN SELECT RAISE(ABORT,'synthetic failure'); END",
        );
        await tap(button('action.saveNext'));
        expect(session.confirmedEntries.length, 1);
        expect(session.draft, same(rawDraft));
        expect(session.draft.targetText, ' raw B ');
        expect(session.draft.nativeText, ' native B ');
        await db.customStatement('DROP TRIGGER fail_word');
        await tap(button('action.retry'));
        await review.waitUntil(
          tester,
          () => session.confirmedEntries.length == 2,
        );
        expect(session.draft.assignments, edited);
        final confirmedIds = session.confirmedEntries.map((e) => e.id).toSet();
        await tap(button('entry.complete'));
        await review.waitUntil(
          tester,
          () => find.byType(EntrySessionScreen).evaluate().isEmpty,
        );
        await tap(find.byTooltip(copy.text('action.addEntry')));
        await review.waitUntil(
          tester,
          () => find.byType(EntrySessionScreen).evaluate().isNotEmpty,
        );
        expect(
          tester
              .widget<EntrySessionScreen>(find.byType(EntrySessionScreen))
              .session
              .draft
              .assignments,
          isEmpty,
        );
        await tap(button('entry.complete'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.closed.future;
        final reopened = PikoDatabase(NativeDatabase(file), clock: clock);
        try {
          for (final entry in protected.entries) {
            var actual = await review.rows(reopened, entry.key);
            if (entry.key == 'learning_items') {
              actual = actual
                  .where((r) => !confirmedIds.contains(r['entry_id']))
                  .toList();
            }
            expect(actual, entry.value, reason: entry.key);
          }
          expect((await review.rows(reopened, 'vocabulary_entries')).length, 4);
          expect(
            (await SqliteCategoriesRepository(
              reopened,
            ).dimensions(fixture.owner.id)).map((g) => g.carryOver),
            [true, true, false],
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
        debugPrint('PIKO_CARRY_EVIDENCE:${directory.path}');
      }
    },
  );
}
