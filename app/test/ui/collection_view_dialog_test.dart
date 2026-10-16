import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/collections/collection_view_preferences.dart';
import 'package:piko/features/collections/collection_view_controls.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_inline_edit_test.dart' show owner;
import 'collection_query_detail_test.dart' show ProjectionService;
import 'collection_filters_test.dart' show definitions;

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language View popup at 320px/200% keeps Apply visible through changes and reversion',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final scope = CollectionViewScope(), copy = PikoCopy(language);
        final binding = CollectionQueryBinding(
          collectionId: owner.id,
          service: ProjectionService(definitions()),
          scope: scope,
          invalidations: const Stream<void>.empty(),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          binding.dispose();
          scope.dispose();
        });
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(language),
            home: Scaffold(
              body: CollectionViewControls(binding: binding, enabled: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('collection-view')));
        await tester.pumpAndSettle();
        final apply = find.widgetWithText(PikoButton, copy.text('r2.apply'));
        final before = tester.getRect(apply);
        expect(before.bottom, lessThan(900));
        expect(before.width, greaterThanOrEqualTo(48));
        expect(tester.widget<PikoButton>(apply).onPressed, isNull);
        final mode = find.byType(DropdownButtonFormField<VocabularyViewMode>);
        tester
            .widget<DropdownButtonFormField<VocabularyViewMode>>(mode)
            .onChanged!(VocabularyViewMode.detailed);
        await tester.pumpAndSettle();
        expect(tester.getRect(apply), before);
        expect(tester.widget<PikoButton>(apply).onPressed, isNotNull);
        tester
            .widget<DropdownButtonFormField<VocabularyViewMode>>(mode)
            .onChanged!(VocabularyViewMode.compact);
        await tester.pumpAndSettle();
        expect(tester.getRect(apply), before);
        expect(tester.widget<PikoButton>(apply).onPressed, isNull);
        final order = find.byKey(const ValueKey('view.languageOrder'));
        await tester.ensureVisible(order);
        await tester.tap(order);
        await tester.pumpAndSettle();
        await tester.tap(find.text(copy.text('view.nativeFirst')).last);
        await tester.pumpAndSettle();
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(scope.view.targetFirst, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
