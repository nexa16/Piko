import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_search_field.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner;
import 'collection_query_detail_test.dart' show projection;
import 'collection_review_entry_points_test.dart' show Collections;

class SearchQueryService implements CollectionQueryService {
  String search = '';
  Map<String, Set<String>> filters = const {};
  @override
  Future<CollectionQuerySnapshot> query({
    required String collectionId,
    required DateTime at,
    Map<String, Set<String>> filters = const {},
    String search = '',
  }) async {
    this.search = search;
    this.filters = filters;
    return search.isEmpty ? projection() : projection(visible: []);
  }
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language search preserves raw Unicode text and clears only search',
      (tester) async {
        final scope = CollectionViewScope()
          ..setSearch('  Straße ÉCOLE  ')
          ..setFilters({
            'topic': {'food'},
          });
        addTearDown(scope.dispose);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(language),
            home: Scaffold(body: CollectionSearchField(scope: scope)),
          ),
        );
        final field = find.byKey(const ValueKey('collection-search'));
        expect(
          tester.widget<TextField>(field).controller!.text,
          '  Straße ÉCOLE  ',
        );
        final clear = find.byKey(const ValueKey('collection-clear-search'));
        expect(
          tester.widget<PikoIconButton>(clear).semanticLabel,
          language == 'en' ? 'Clear search' : 'Suche löschen',
        );
        expect(tester.getSize(clear).shortestSide, greaterThanOrEqualTo(48));
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(scope.search, '');
        expect(scope.filters, {
          'topic': {'food'},
        });
        expect(clear, findsNothing);
        await tester.enterText(field, 'ß ss É e\u0301');
        expect(scope.search, 'ß ss É e\u0301');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'disabled search rejects captured typing and clear callbacks while preserving its draft',
    (tester) async {
      final scope = CollectionViewScope()..setSearch('Café');
      addTearDown(scope.dispose);
      Future<void> mount(bool enabled) => tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: CollectionSearchField(scope: scope, enabled: enabled),
          ),
        ),
      );
      await mount(true);
      final changed = tester
          .widget<TextField>(find.byKey(const ValueKey('collection-search')))
          .onChanged!;
      final clear = tester
          .widget<PikoIconButton>(
            find.byKey(const ValueKey('collection-clear-search')),
          )
          .onPressed!;
      await mount(false);
      changed('stale');
      clear();
      expect(scope.search, 'Café');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('collection-search')))
            .enabled,
        isFalse,
      );
      scope.setSearch('outside');
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('collection-search')))
            .controller!
            .text,
        'outside',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Detail search combines with filters and retains its query in a no-match state',
    (tester) async {
      final service = SearchQueryService();
      final scope = CollectionViewScope()
        ..setFilters({
          'topic': {'food'},
        });
      final binding = CollectionQueryBinding(
        collectionId: owner.id,
        service: service,
        scope: scope,
        invalidations: const Stream<void>.empty(),
      );
      final vocabulary = LiveVocabulary();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        binding.dispose();
        scope.dispose();
        await vocabulary.close();
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: const Collections([owner]),
            collectionId: owner.id,
            vocabularyRepository: vocabulary,
            queryBinding: binding,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('collection-search'));
      await tester.enterText(field, '  Straße  ');
      await tester.pumpAndSettle();
      expect(service.search, '  Straße  ');
      expect(service.filters, {
        'topic': {'food'},
      });
      expect(find.text('No vocabulary matches these filters.'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, '  Straße  ');
      await tester.tap(find.byKey(const ValueKey('collection-clear-search')));
      await tester.pumpAndSettle();
      expect(service.search, '');
      expect(service.filters, {
        'topic': {'food'},
      });
    },
  );
}
