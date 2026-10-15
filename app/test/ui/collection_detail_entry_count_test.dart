import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../support/collection_deletion_fixture.dart';

Future<void> flush(
  WidgetTester tester,
  CollectionDeletionFixture fixture,
) async {
  await tester.runAsync(() => fixture.db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

Finder pikoButton(String label) => find.byWidgetPredicate(
  (widget) => widget is PikoButton && widget.label == label,
);

void main() {
  testWidgets(
    'UX-HEADER-001 Detail subtitle follows real delete and Undo mutations',
    (tester) async {
      final fixture = CollectionDeletionFixture();
      await tester.runAsync(fixture.initialize);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(fixture.mutations.isBusy, isFalse);
        expect(fixture.deletion.disposals, 1);
        await tester.runAsync(fixture.db.close);
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: fixture.collections,
            collectionId: fixture.owner.id,
            vocabularyRepository: fixture.repository,
            vocabularyMutationsFactory: (_) => fixture.mutations,
          ),
        ),
      );
      await flush(tester, fixture);
      expect(find.text('French · German · 3 entries'), findsOneWidget);

      final entryId = fixture.entries.first.id;
      final card = find.byKey(ValueKey('vocabulary-$entryId'));
      await tester.drag(card, const Offset(-150, 0));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('vocabulary-row-$entryId')),
          matching: pikoButton('Delete vocabulary'),
        ),
      );
      await flush(tester, fixture);
      expect(find.text('French · German · 2 entries'), findsOneWidget);

      await tester.tap(pikoButton('Undo'));
      await flush(tester, fixture);
      expect(find.text('French · German · 3 entries'), findsOneWidget);
    },
  );
}
