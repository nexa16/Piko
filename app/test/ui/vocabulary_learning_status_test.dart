import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/data/vocabulary_learning_status.dart';
import 'package:piko/features/vocabulary/vocabulary_learning_status.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'collection_query_detail_test.dart' show projection;

CollectionQuerySnapshot statusProjection(VocabularyLearningStatus status) {
  final base = projection();
  return CollectionQuerySnapshot(
    collection: base.collection,
    allEntries: base.allEntries,
    entries: base.entries,
    categoryDimensions: base.categoryDimensions,
    categoryValues: base.categoryValues,
    assignments: base.assignments,
    directions: {
      for (final entry in base.directions.entries)
        entry.key: CollectionDirectionSnapshot(
          review: entry.value.review,
          newSpeedItems: entry.value.newSpeedItems,
          statuses: {'one': status},
        ),
    },
  );
}

void main() {
  for (final language in ['en', 'de']) {
    for (final preference in PreferredDirection.values) {
      for (final kind in VocabularyLearningStatusKind.values) {
        testWidgets(
          '$language ${preference.name} ${kind.name} has directional status without invented levels',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(320, 1000);
            addTearDown(tester.view.reset);
            final at = DateTime.utc(2026, 10, 20, 14, 30);
            final snapshot = statusProjection(
              VocabularyLearningStatus(
                kind: kind,
                nextReviewAt: kind == VocabularyLearningStatusKind.nextReview
                    ? at
                    : null,
                speedCompleted: kind == VocabularyLearningStatusKind.newWord,
              ),
            );
            await tester.pumpWidget(
              PikoApp(
                locale: Locale(language),
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: Scaffold(
                      body: VocabularyLearningStatusView(
                        collection: snapshot.collection,
                        entryId: 'one',
                        snapshot: snapshot,
                        directions: preference.directions,
                      ),
                    ),
                  ),
                ),
              ),
            );
            final copy = PikoCopy(language);
            final labels = find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.key.toString().contains('vocabulary-status-one-'),
            );
            expect(labels, findsNWidgets(preference.directions.length));
            final label = tester.widget<Text>(labels.first).data!;
            final expected = switch (kind) {
              VocabularyLearningStatusKind.pendingRetry => copy.text(
                'vocab.statusRetryPending',
              ),
              VocabularyLearningStatusKind.newWord => copy.text(
                'vocab.statusNew',
              ),
              VocabularyLearningStatusKind.due => copy.text('vocab.statusDue'),
              VocabularyLearningStatusKind.nextReview =>
                copy.text('vocab.statusNext', {
                  'date': MaterialLocalizations.of(
                    tester.element(labels.first),
                  ).formatMediumDate(at.toLocal()),
                  'time': MaterialLocalizations.of(
                    tester.element(labels.first),
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(at.toLocal())),
                }),
            };
            expect(label, contains(expected));
            expect(label.contains('→'), preference == PreferredDirection.both);
            expect(
              label.contains(copy.text('vocab.statusSpeedCompleted')),
              kind == VocabularyLearningStatusKind.newWord,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets('missing projected status never guesses New', (tester) async {
    final base = projection();
    await tester.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: VocabularyLearningStatusView(
            collection: base.collection,
            entryId: 'one',
            snapshot: base,
            directions: PreferredDirection.both.directions,
          ),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);
  });
}
