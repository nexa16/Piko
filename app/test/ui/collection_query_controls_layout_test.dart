import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/features/collections/filter_selection_dialog.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner;
import 'collection_query_detail_test.dart' show ProjectionService, projection;
import 'collection_review_entry_points_test.dart' show Collections;

void main() {
  for (final language in ['en', 'de']) {
    testWidgets('$language 320dp 200% search clear and Filters remain usable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scope = CollectionViewScope()
        ..setSearch('Long retained search Straße École');
      final binding = CollectionQueryBinding(
        collectionId: owner.id,
        service: ProjectionService(projection()),
        scope: scope,
        invalidations: const Stream<void>.empty(),
      );
      final vocabulary = LiveVocabulary();
      final scale = ValueNotifier(2.0);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        binding.dispose();
        scope.dispose();
        scale.dispose();
        await vocabulary.close();
      });
      await tester.pumpWidget(
        PikoApp(
          locale: Locale(language),
          home: ValueListenableBuilder<double>(
            valueListenable: scale,
            builder: (context, textScale, _) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: CollectionDetail(
                repository: const Collections([owner]),
                collectionId: owner.id,
                vocabularyRepository: vocabulary,
                queryBinding: binding,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('collection-search'));
      final filters = find.byKey(const ValueKey('collection-filters'));
      final clear = find.byKey(const ValueKey('collection-clear-search'));
      await tester.scrollUntilVisible(
        search,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(search).width,
        closeTo(320 - 2 * pikoDesign.dimension('layout.mobilePadding'), 0.1),
      );
      expect(
        tester.getRect(filters).top,
        greaterThanOrEqualTo(tester.getRect(search).bottom),
      );
      for (final control in [search, filters, clear]) {
        final bounds = tester.getRect(control);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
        expect(bounds.height, greaterThanOrEqualTo(48));
      }
      final label = find.descendant(
        of: filters,
        matching: find.text(PikoCopy(language).text('action.filters')),
      );
      final labelRect = tester.getRect(label);
      final buttonRect = tester.getRect(filters);
      expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
      expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
      expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
      final editable = find.descendant(
        of: search,
        matching: find.byType(EditableText),
      );
      expect(
        tester.state<EditableTextState>(editable).renderEditable.size.width,
        greaterThan(0),
      );
      expect(
        tester.widget<PikoIconButton>(clear).semanticLabel,
        PikoCopy(language).text('r2.clearSearch'),
      );
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(scope.search, '');
      await tester.enterText(search, 'New query');
      await tester.pumpAndSettle();
      expect(scope.search, 'New query');
      final controller = tester.widget<TextField>(search).controller;
      final selection = controller!.selection;
      await tester.tap(filters);
      await tester.pumpAndSettle();
      expect(find.byType(FilterSelectionDialog), findsOneWidget);
      await tester.tap(find.byTooltip(PikoCopy(language).text('common.close')));
      await tester.pumpAndSettle();
      expect(find.byType(FilterSelectionDialog), findsNothing);
      tester.view.physicalSize = const Size(1000, 1000);
      scale.value = 1;
      await tester.pumpAndSettle();
      expect(
        tester.getRect(filters).top,
        greaterThanOrEqualTo(tester.getRect(search).bottom),
      );
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(controller.text, 'New query');
      expect(controller.selection, selection);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      final lines = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: PikoCopy(language).text('action.filters').length,
        ),
      );
      expect(
        lines.map((box) => box.top).toSet(),
        hasLength(1),
        reason: 'Normal-size Filters label must stay on one line',
      );
      tester.view.physicalSize = const Size(320, 1000);
      scale.value = 2;
      await tester.pumpAndSettle();
      final retainedSearch = find.byKey(
        const ValueKey('collection-search'),
        skipOffstage: false,
      );
      expect(
        tester.widget<TextField>(retainedSearch).controller,
        same(controller),
      );
      await tester.ensureVisible(retainedSearch);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller, same(controller));
      expect(
        tester.getRect(filters).top,
        greaterThanOrEqualTo(tester.getRect(search).bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
