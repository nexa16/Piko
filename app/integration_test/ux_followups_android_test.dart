import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/category_tag_roles.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_full_export_service.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/statistics/statistics_widgets.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_category_tag.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_icon.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import '../test/data/statistics_test.dart' show stored;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';
import '../test/ui/selected_speed_launch_test.dart' as failure_cases;
import '../test/ui/json_transfer_test.dart' as transfer_fault_cases;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'UX followups actual Android icons, twelve tags, full viewport, selected Header, IME and native transfer',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/ux-followups-${config.runId}',
      );
      if (await directory.exists()) {
        throw StateError('Unique evidence required');
      }
      await directory.create();
      final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12));
      final db = review.ReviewFixtureDatabase(
        File('${directory.path}/fixture.sqlite'),
        clock,
      );
      final f = Fixture(database: db),
          categories = SqliteCategoriesRepository(db);
      final states = <Map<String, Object?>>[];
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
        'normalProductionDatabaseOpened': false,
        'captureMethod': 'external Android screencap; normal Flutter surface',
        'states': states,
      };
      bool passed = false;
      Finder key(String id) => find.byKey(ValueKey(id));
      late PikoCopy copy;
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
          await Scrollable.ensureVisible(
            tester.element(target.first),
            alignment: .5,
          );
          await tester.pumpAndSettle();
        }
        for (
          var i = 0;
          target.hitTestable().evaluate().isEmpty && i < 50;
          i++
        ) {
          final scroll = find.byType(Scrollable).first;
          final area = tester.getRect(scroll);
          final rect = target.evaluate().isEmpty
              ? null
              : tester.getRect(target.first);
          await tester.dragFrom(
            Offset(area.left + 40, area.center.dy),
            Offset(
              0,
              rect != null && rect.center.dy < area.center.dy ? 140 : -140,
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

      Future<void> native(String phase) async {
        await File('${directory.path}/phase.json').writeAsString(
          jsonEncode({
            'phase': phase,
            'run': config.runId,
            if (phase == 'ime-back')
              'x':
                  (tester.getCenter(key('speed-pool-size')).dx *
                          View.of(
                            tester.element(key('speed-pool-size')),
                          ).devicePixelRatio)
                      .round(),
            if (phase == 'ime-back')
              'y':
                  (tester.getCenter(key('speed-pool-size')).dy *
                          View.of(
                            tester.element(key('speed-pool-size')),
                          ).devicePixelRatio)
                      .round(),
          }),
          flush: true,
        );
        final ack = File('${directory.path}/ack-$phase');
        final end = DateTime.now().add(const Duration(seconds: 90));
        while (!await ack.exists() && DateTime.now().isBefore(end)) {
          // DocumentsUI can pause Flutter frames. Wait on wall time only.
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        expect(await ack.exists(), true, reason: 'Native phase $phase');
        await tester.pumpAndSettle();
      }

      Future<void> record(String id) async {
        final media = MediaQuery.of(tester.element(find.byType(Scaffold).last));
        final measures = <Map<String, Object?>>[];
        for (final field in find.byType(PikoFormFieldRow).evaluate()) {
          final widget = field.widget as PikoFormFieldRow;
          final outer = tester.getRect(find.byWidget(widget));
          final inner = tester.getRect(find.byWidget(widget.child));
          expect(inner.left - outer.left, closeTo(16, .1));
          measures.add({'kind': 'field', 'inset': inner.left - outer.left});
        }
        final icons = <Map<String, Object?>>[];
        for (final element in find.byType(PikoIcon).evaluate()) {
          final icon = element.widget as PikoIcon;
          final finder = find.byWidget(icon);
          final svg = find.descendant(
            of: finder,
            matching: find.byType(SvgPicture),
          );
          if (svg.evaluate().length != 1) continue;
          final rect = tester.getRect(finder);
          icons.add({
            'name': icon.name.name,
            'rect': [rect.left, rect.top, rect.width, rect.height],
            'filter': tester.widget<SvgPicture>(svg).colorFilter.toString(),
          });
        }
        states.add({
          'id': id,
          'width': media.size.width,
          'height': media.size.height,
          'scale': media.textScaler.scale(14) / 14,
          'measures': measures,
          'icons': icons,
        });
        await settleCatalogueCapture(tester, id);
        await native('capture-$id');
        await persist();
        expect(tester.takeException(), isNull, reason: id);
      }

      Future<void> top() async {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
      }

      try {
        await f.initialize();
        await f.review(at: clock.now());
        await f.review(reverse: true, at: clock.now());
        final ids = <String>[];
        for (var i = 0; i < 25; i++) {
          ids.add(
            (await f.vocabulary.create(
              collectionId: f.owner.id,
              targetText: 'Word $i',
              nativeText: 'Wort $i',
            )).id,
          );
        }
        final assignments = <String, Set<String>>{};
        for (var i = 0; i < 12; i++) {
          final group = await categories.createDimension(
            collectionId: f.owner.id,
            name: 'Group $i',
            mode: CategoryMode.multiple,
          );
          final value = await categories.createValue(
            dimensionId: group.id,
            name: 'T${i + 1}',
          );
          assignments[group.id] = {value.id};
        }
        await categories.replaceAssignments(
          entryId: f.entry.id,
          assignments: assignments,
        );
        await SqliteSettingsRepository(db).write('locale', config.locale);
        await SqliteSettingsRepository(
          db,
        ).write(PreferredDirection.settingKey, PreferredDirection.both.name);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(config.locale),
            home: PikoRuntime(databaseFactory: () => db),
          ),
        );
        copy = await hydratedRuntimeCopy(tester);
        await record('home-default-icon');
        await tap(key('collection-${f.owner.id}'));
        final detail = tester.widget<CollectionDetail>(
          find.byType(CollectionDetail),
        );
        final media = MediaQuery.of(
          tester.element(find.byType(CollectionDetail)),
        );
        if (config.scale == '200') {
          expect(media.size.width, closeTo(320, 1));
          expect(media.textScaler.scale(14), closeTo(28, 1));
        }
        final viewport = tester.getRect(find.byType(Scrollable).first);
        expect(
          viewport.height,
          greaterThan(media.size.height - media.padding.vertical - 1),
        );
        expect(key('vocabulary-selection-panel'), findsNothing);
        final card = key('vocabulary-${f.entry.id}');
        await reveal(card);
        final tags = find.descendant(
          of: card,
          matching: find.byType(PikoCategoryTag),
        );
        expect(tags, findsNWidgets(12));
        final actualRoles = tester
            .widgetList<PikoCategoryTag>(tags)
            .map((t) => t.group.tagColorRole)
            .toList();
        expect(actualRoles, categoryTagRoles);
        await record('twelve-group-tags');
        final selectCard = key('vocabulary-${ids[12]}');
        await reveal(selectCard);
        final beforeRect = tester.getRect(selectCard);
        final selection = tester
            .widget<CollectionVocabulary>(find.byType(CollectionVocabulary))
            .selection!;
        final before = await stored(db);
        await tester.longPress(selectCard);
        await tester.pumpAndSettle();
        expect(tester.getRect(selectCard).top, closeTo(beforeRect.top, .5));
        expect(
          tester.getRect(find.byType(Scrollable).first).height,
          viewport.height,
        );
        await record('selection-full-viewport');
        final endScroll = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        endScroll.jumpTo(endScroll.maxScrollExtent);
        await tester.pumpAndSettle();
        final clearance = tester.getSize(key('selection-end-clearance')).height;
        expect(clearance, greaterThan(48));
        final lastId = sortVocabulary(
          detail.queryBinding!.snapshot!.entries,
          detail.queryBinding!.scope.view.sort,
        ).last.id;
        final lastCard = key('vocabulary-$lastId');
        final lastTop = tester.getRect(lastCard).top;
        await tap(key('vocabulary-clear-selection'));
        expect(tester.getRect(lastCard).top, closeTo(lastTop, .5));
        await record('selection-cleared-end');
        expect(selection.ids, isEmpty);
        expect(key('vocabulary-selection-panel'), findsNothing);
        expect(await stored(db), before);
        // The original reviewed word has no due work in either direction, but is valid Speed practice.
        await top();
        await reveal(card);
        await tester.longPress(tags.first);
        await tester.pumpAndSettle();
        detail.queryBinding!.scope.setSearch('nothing matches');
        await tester.pumpAndSettle();
        await top();
        for (final direction in LearningDirection.values) {
          expect(
            tester
                .widget<PikoButton>(key('collection-review-${direction.name}'))
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<PikoButton>(key('collection-speed-${direction.name}'))
                .label,
            contains('1'),
          );
        }
        await record('hidden-selection-zero-longterm');
        await tap(key('collection-speed-targetToNative'));
        expect(find.byType(SpeedSetupDialog), findsOneWidget);
        await record('selected-speed-setup');
        final pool = key('speed-pool-size');
        await reveal(pool);
        await tester.tap(pool);
        await tester.enterText(pool, '1e2');
        await tester.pumpAndSettle();
        expect(
          tester.widget<PikoButton>(button('learn.startSpeed')).onPressed,
          isNull,
        );
        await native('ime-back');
        expect(tester.widget<TextField>(pool).controller!.text, '1e2');
        await record('pool-invalid');
        await native('setup-back');
        expect(find.byType(SpeedSetupDialog), findsNothing);
        expect(selection.ids, {f.entry.id});
        await tap(key('vocabulary-clear-selection'));
        detail.queryBinding!.scope.setSearch('Word 12');
        await tester.pumpAndSettle();
        await reveal(selectCard);
        await tester.longPress(selectCard);
        await tester.pumpAndSettle();
        await top();
        await tap(key('collection-review-nativeToTarget'));
        expect(find.byType(ReviewSessionRoute), findsOneWidget);
        final route = tester.widget<ReviewSessionRoute>(
          find.byType(ReviewSessionRoute),
        );
        expect(route.session.members.map((m) => m.entryId).toSet(), {ids[12]});
        await tap(key('review-reveal-target'));
        await record('selected-longterm-revealed');
        // Safe exit without an answer leaves all learning untouched.
        await native('review-back');
        expect(find.byType(CollectionDetail), findsOneWidget);
        expect(await stored(db), before);
        // Enter the real JSON route from the Collection Settings origin.
        detail.queryBinding!.scope.setSearch('');
        await tester.pumpAndSettle();
        await top();
        await tap(
          find.byTooltip(copy.text('settingsPreview.collectionSettings')),
        );
        await tap(
          find.widgetWithText(PikoFormRow, copy.text('collection.delete')),
        );
        await record('real-delete-confirmation');
        await tap(button('action.cancel'));
        await tap(
          find.widgetWithText(PikoFormRow, copy.text('json.importTab')),
        );
        final input = key('json-input');
        await reveal(input);
        await tester.enterText(input, ' {broken raw draft ');
        await tap(button('json.analyze'));
        expect(find.text(copy.text('json.invalidSyntax')), findsWidgets);
        await record('json-invalid-raw');
        await tap(button('json.file'));
        await native('file-cancel');
        expect(
          tester.widget<TextField>(input).controller!.text,
          ' {broken raw draft ',
        );
        final validWire = await SqliteVocabularyJsonService(
          db,
        ).exportCollection(f.owner.id);
        await File(
          '${directory.path}/valid-input.json',
        ).writeAsString(validWire, flush: true);
        for (final problem in [
          ('file-invalid-utf8', 'json.invalidUtf8'),
          ('file-too-large', 'json.tooLarge'),
        ]) {
          await tap(button('json.file'));
          await native(problem.$1);
          expect(find.text(copy.text(problem.$2)), findsWidgets);
          expect(
            tester.widget<TextField>(input).controller!.text,
            ' {broken raw draft ',
          );
          await record(problem.$1);
        }
        await tap(button('json.file'));
        await native('file-valid-retry');
        expect(tester.widget<TextField>(input).controller!.text, validWire);
        if (const bool.fromEnvironment('PIKO_SYNTHETIC_CLIPBOARD_AVAILABLE') &&
            !await Clipboard.hasStrings()) {
          final wire = await SqliteVocabularyJsonService(
            db,
          ).exportCollection(f.owner.id);
          await tap(button('json.exportTab'));
          await tap(button('json.copy'));
          expect((await Clipboard.getData(Clipboard.kTextPlain))?.text, wire);
          await tap(button('json.importTab'));
          await tap(button('json.paste'));
          expect(tester.widget<TextField>(input).controller!.text, wire);
          await Clipboard.setData(const ClipboardData(text: ''));
          manifest['nativeClipboard'] =
              'real UI copy/read exact bytes; no prior plain-text clip; cleared';
        } else {
          manifest['nativeClipboard'] =
              'not run: clipboard ownership/emptiness not proven; retained without reading';
        }
        await record('json-return-transport');
        final invalidRow = jsonDecode(validWire) as Map<String, dynamic>;
        ((invalidRow['collections'] as List).single['entries'] as List)
            .first['categoryAssignments'] = [
          {'dimensionId': List.filled(120, 'x').join(), 'valueIds': []},
        ];
        await reveal(input);
        await tester.enterText(input, jsonEncode(invalidRow));
        await tap(button('json.analyze'));
        await record('json-long-row-errors');
        await reveal(input);
        await tester.enterText(input, validWire);
        await tap(button('json.analyze'));
        await record('json-review');
        await tap(button('json.apply'));
        await record('json-confirmation');
        await tap(button('action.cancel'));
        expect(tester.widget<TextField>(input).controller!.text, validWire);
        await tap(button('json.apply'));
        await tap(
          find.descendant(
            of: find.byType(PikoDialog).last,
            matching: button('json.apply'),
          ),
        );
        await record('json-applied-result');
        expect(await stored(db), before);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await tap(find.byTooltip(copy.text('common.close')));
        await tap(find.byTooltip(copy.text('common.back')));
        await tap(find.byTooltip(copy.text('common.back')));
        await tap(find.byTooltip(copy.text('nav.settings')));
        await tap(
          find.widgetWithText(PikoFormRow, copy.text('fullExport.action')),
        );
        await native('full-export-cancel');
        expect(find.text(copy.text('fullExport.cancelled')), findsOneWidget);
        await File('${directory.path}/expected-full-export.json').writeAsString(
          await SqliteFullExportService(db).exportAll(),
          flush: true,
        );
        await tap(
          find.widgetWithText(PikoFormRow, copy.text('fullExport.action')),
        );
        await native('full-export-save');
        expect(find.text(copy.text('json.fileSaved')), findsOneWidget);
        await record('global-full-export-saved');
        expect(await stored(db), before);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(config.locale),
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const StatisticsReminder(),
                      PikoNavigationRow(title: 'Navigation', onTap: () {}),
                      PikoButton(
                        label: 'Primary',
                        variant: PikoButtonVariant.reviewPrimary,
                        icon: const PikoIcon(PikoIconName.plus),
                        onPressed: () {},
                      ),
                      PikoButton(
                        label: 'Danger',
                        variant: PikoButtonVariant.dangerFilled,
                        icon: const PikoIcon(PikoIconName.trash),
                        onPressed: () {},
                      ),
                      const PikoButton(
                        label: 'Disabled',
                        variant: PikoButtonVariant.reviewPrimary,
                        icon: PikoIcon(PikoIconName.plus),
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await record('warning-contextual-icon-roles');
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        manifest['passed'] = passed;
        await persist();
        debugPrint('PIKO_UX_FOLLOWUPS_EVIDENCE:${directory.path}');
      }
    },
  );
  // Production setup/controller widgets, with synthetic held/failing factories.
  // These exercise Android pending/Back/failure/retry without OS fault injection.
  failure_cases.main();
  transfer_fault_cases.main();
}
