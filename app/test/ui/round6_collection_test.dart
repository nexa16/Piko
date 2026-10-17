import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/collections/learning_help.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_filters_test.dart' show FilterHarness;
import 'collection_views_test.dart' show grouped;

Finder key(String value) => find.byKey(ValueKey(value));
void main() {
  for (final language in ['en', 'de']) {
    for (final layout in [(390.0, 1.0), (320.0, 2.0)]) {
      testWidgets(
        '$language $layout chips reserve footprint and reset independently',
        (tester) async {
          tester.view.physicalSize = Size(layout.$1, 1100);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final h = FilterHarness(), copy = PikoCopy(language);
          h.service.value = grouped();
          await h.mount(tester);
          final detail = tester.widget<CollectionDetail>(
            find.byType(CollectionDetail),
          );
          await tester.pumpWidget(
            PikoApp(locale: Locale(language), home: detail),
          );
          await tester.pumpAndSettle();
          final controls = [
            'collection-filters',
            'collection-group',
            'collection-sort',
          ];
          Future<Map<String, Rect>> positions() async {
            await tester.ensureVisible(key('collection-filters'));
            await tester.pumpAndSettle();
            return {
              for (final id in controls)
                id: tester
                    .getRect(key(id))
                    .shift(-tester.getTopLeft(key('collection-filters'))),
            };
          }

          final neutral = await positions();
          h.scope.setFilters({
            'topic': {'food'},
          });
          await h.scope.saveView(
            const CollectionViewPreferences(
              grouping: 'topic',
              sort: VocabularySort.newest,
            ),
          );
          await tester.pumpAndSettle();
          expect(await positions(), neutral);
          final resultY = tester.getTopLeft(key('collection-list-results')).dy;
          await tester.tap(find.byTooltip(copy.text('r2.clearFilters')));
          await tester.pumpAndSettle();
          expect(h.scope.filters, isEmpty);
          expect(h.scope.view.grouping, 'topic');
          expect(h.scope.view.sort, VocabularySort.newest);
          expect(await positions(), neutral);
          expect(tester.getTopLeft(key('collection-list-results')).dy, resultY);
          await tester.ensureVisible(
            find.byTooltip(copy.text('list.resetSort')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(copy.text('list.resetSort')));
          await tester.pumpAndSettle();
          expect(h.scope.view.sort, VocabularySort.original);
          expect(h.scope.view.grouping, 'topic');
          h.scope.setSearch('retained');
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byTooltip(copy.text('list.clearGrouping')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(copy.text('list.clearGrouping')));
          await tester.pumpAndSettle();
          expect(h.scope.view.grouping, isNull);
          expect(h.scope.search, 'retained');
          expect(key('collection-toggle-groups'), findsNothing);
          expect(key('collection-view'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '$language help metadata, disclosure, close/back and reopening preserve state at 320/200%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = FilterHarness(), copy = PikoCopy(language);
        h.scope.setSearch('retained');
        h.scope.setFilters({
          'topic': {'food'},
        });
        await h.mount(tester);
        final detail = tester.widget<CollectionDetail>(
          find.byType(CollectionDetail),
        );
        await tester.pumpWidget(
          PikoApp(locale: Locale(language), home: detail),
        );
        await tester.pumpAndSettle();
        final view = h.scope.view, rows = h.binding.snapshot!.allEntries;
        final info = key('collection-learning-help');
        expect(tester.getSize(info), const Size(48, 48));
        await tester.tap(info);
        await tester.pumpAndSettle();
        expect(find.byType(LearningHelpDialog), findsOneWidget);
        expect(find.text(copy.text('learnHelp.fsrs')), findsNothing);
        await tester.ensureVisible(key('learning-help-scheduling'));
        await tester.tap(key('learning-help-scheduling'));
        await tester.pumpAndSettle();
        expect(find.text(copy.text('learnHelp.fsrs')), findsOneWidget);
        Focus.of(
          tester.element(find.text(copy.text('learnHelp.scheduling'))),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('learnHelp.fsrs')), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('learnHelp.fsrs')), findsOneWidget);
        final close = find.byTooltip(copy.text('learnHelp.close'));
        expect(tester.getRect(close).top, greaterThanOrEqualTo(0));
        expect(tester.getRect(close).bottom, lessThan(1100));
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(tester.widget<PikoIconButton>(info).focusNode!.hasFocus, isTrue);
        await tester.ensureVisible(info);
        await tester.tap(info);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('learnHelp.fsrs')), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(LearningHelpDialog), findsNothing);
        expect(h.scope.search, 'retained');
        expect(h.scope.filters, {
          'topic': {'food'},
        });
        expect(h.scope.view, view);
        expect(h.binding.snapshot!.allEntries, rows);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'mixed grouped state expands remaining groups then collapses all; headers share title edge',
    (tester) async {
      final h = FilterHarness();
      h.service.value = grouped();
      await h.scope.saveView(
        const CollectionViewPreferences(grouping: 'topic'),
      );
      await h.mount(tester);
      expect(h.scope.expandedGroups, isEmpty);
      final food = key('collection-group-food'),
          travel = key('collection-group-travel');
      await tester.scrollUntilVisible(
        food,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(food).left, tester.getRect(travel).left);
      await tester.tap(food);
      await tester.pumpAndSettle();
      expect(h.scope.expandedGroups, {'food'});
      final bulk = key('collection-toggle-groups');
      await tester.ensureVisible(bulk);
      await tester.tap(bulk);
      await tester.pumpAndSettle();
      expect(h.scope.expandedGroups, {'food', 'travel', 'unassigned'});
      expect(tester.widget<PikoButton>(bulk).label, 'Collapse all');
      await tester.tap(bulk);
      await tester.pumpAndSettle();
      expect(h.scope.expandedGroups, isEmpty);
    },
  );
}
