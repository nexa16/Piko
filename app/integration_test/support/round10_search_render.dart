import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/main.dart';
import '../../test/data/regular_reviews_test.dart' show Fixture;

/// Complements collection_search_scale_test's query-only measurement with real
/// Collection rendering, using the same synthetic 600/5,000-word fixture recipe.
/// Input is supplied by the Flutter test channel; this is not human typing speed.
void registerRound10SearchRenderTests({
  required void Function(Map<String, Object>) onMeasurement,
}) {
  for (final size in [600, 5000]) {
    testWidgets(
      'Round10 actual viewport Collection input to matching render $size words',
      (tester) async {
        final fixture = Fixture();
        final scope = CollectionViewScope();
        CollectionQueryBinding? binding;
        Future<void> waitFor(bool Function() complete, String state) async {
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          while (!complete() && DateTime.now().isBefore(deadline)) {
            await tester.runAsync(
              () => fixture.db.customSelect('SELECT 1').get(),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(complete(), isTrue, reason: state);
          await tester.pump();
        }

        Future<void> reveal(Finder finder) async {
          await tester.scrollUntilVisible(
            finder,
            160,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 12,
          );
          await tester.pumpAndSettle();
          expect(finder.hitTestable(), findsOneWidget);
        }

        try {
          await tester.runAsync(() async {
            await fixture.initialize();
            await fixture.db.transaction(() async {
              for (var index = 1; index < size; index++) {
                await fixture.vocabulary.create(
                  collectionId: fixture.owner.id,
                  targetText: 'Scale word $index',
                  nativeText: 'Skalierung $index',
                );
              }
            });
          });
          binding = CollectionQueryBinding(
            collectionId: fixture.owner.id,
            service: SqliteCollectionQueryService(fixture.db),
            scope: scope,
            clock: fixture.db.clock,
            invalidations: const Stream<void>.empty(),
          );
          await tester.pumpWidget(
            PikoApp(
              home: CollectionDetail(
                repository: fixture.collections,
                collectionId: fixture.owner.id,
                vocabularyRepository: fixture.vocabulary,
                queryBinding: binding,
              ),
            ),
          );
          await waitFor(
            () => binding!.ready,
            'initial $size-word Collection loaded',
          );
          expect(binding.snapshot!.allEntries, hasLength(size));
          final search = find.byKey(const ValueKey('collection-search'));
          for (final query in [
            'Scale',
            'Scale word 4999',
            'no such vocabulary',
          ]) {
            await reveal(search);
            await tester.tap(search);
            final stopwatch = Stopwatch()..start();
            await tester.enterText(search, query);
            await tester.testTextInput.receiveAction(TextInputAction.search);
            await waitFor(
              () => binding!.ready && scope.search == query,
              'latest query committed for $size words: $query',
            );
            final expected = query == 'Scale'
                ? size - 1
                : query == 'Scale word 4999' && size == 5000
                ? 1
                : 0;
            final result = binding.snapshot!;
            expect(result.allEntries, hasLength(size));
            expect(result.entries, hasLength(expected));
            for (final direction in result.directions.values) {
              expect(direction.dueCount, expected);
              expect(direction.newSpeedItems, hasLength(expected));
            }
            final rendered = expected == 0
                ? find.text('No matching vocabulary.')
                : find.byWidgetPredicate(
                    (widget) =>
                        widget is Text &&
                        widget.data ==
                            (query == 'Scale'
                                ? 'Scale word 1'
                                : 'Scale word 4999'),
                  );
            await reveal(rendered);
            stopwatch.stop();
            final measurement = <String, Object>{
              'words': size,
              'query': query,
              'matching': expected,
              'inputToMatchingRenderMs': stopwatch.elapsedMilliseconds,
              'viewportWidth':
                  tester.view.physicalSize.width / tester.view.devicePixelRatio,
              'viewportHeight':
                  tester.view.physicalSize.height /
                  tester.view.devicePixelRatio,
              'includesSearchSubmissionAndFirstResultVisibility': true,
            };
            onMeasurement(measurement);
            // Diagnostic only: the provisional 200ms goal is not a pass threshold.
            // ignore: avoid_print
            print('round10-search-render $measurement');
            expect(tester.takeException(), isNull);
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          binding?.dispose();
          scope.dispose();
          await tester.runAsync(fixture.db.close);
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
