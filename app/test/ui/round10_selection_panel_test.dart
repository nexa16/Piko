import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/vocabulary/vocabulary_selection.dart';
import 'package:piko/features/vocabulary/vocabulary_selection_panel.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';

void main() {
  for (final locale in ['en', 'de']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$locale selection has deliberate count row at 320/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final selection = VocabularySelection()..selectAll(['one', 'two']);
        addTearDown(selection.dispose);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: VocabularySelectionPanel(
                  selection: selection,
                  matchingIds: const ['one', 'two', 'three'],
                  enabled: true,
                  onDelete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final copy = PikoCopy(locale);
        final count = find.text(copy.text('selection.count', {'count': 2}));
        final all = find.byKey(const ValueKey('vocabulary-select-all'));
        final clear = find.byKey(const ValueKey('vocabulary-clear-selection'));
        final panel = find.byKey(const ValueKey('vocabulary-selection-panel'));
        expect(tester.getRect(count).bottom, lessThan(tester.getRect(all).top));
        expect(tester.getRect(all).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(clear).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(panel).bottom, lessThanOrEqualTo(900));
        expect(tester.getRect(all).overlaps(tester.getRect(clear)), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
