import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/main.dart';

import 'collection_inline_edit_test.dart'
    show LiveCollections, LiveVocabulary, owner, card, field;

Future<void> mountCollection(WidgetTester tester, {int count = 400}) async {
  final collections = LiveCollections();
  final vocabulary = LiveVocabulary()
    ..records = List.generate(
      count,
      (i) => VocabularyRecord(
        id: 'word-$i',
        collectionId: owner.id,
        targetText: 'Word $i',
        nativeText: 'Translation $i',
      ),
    );
  tester.view.physicalSize = const Size(392, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await collections.close();
    await vocabulary.close();
    tester.view.reset();
  });
  await tester.pumpWidget(
    PikoApp(
      home: CollectionDetail(
        repository: collections,
        collectionId: owner.id,
        vocabularyRepository: vocabulary,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollableState pageScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first);

void main() {
  testWidgets(
    'long collection builds only nearby rows and reaches the last word',
    (tester) async {
      await mountCollection(tester);
      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('vocabulary-row-'),
      );
      expect(rows.evaluate().length, lessThan(30));
      expect(card('word-399'), findsNothing);
      await tester.scrollUntilVisible(
        card('word-399'),
        600,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      expect(card('word-399').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'successive slow drags continue and a fast fling remains bounded',
    (tester) async {
      await mountCollection(tester);
      final scroll = pageScroll(tester);
      for (var i = 0; i < 5; i++) {
        final before = scroll.position.pixels;
        await tester.timedDragFrom(
          const Offset(196, 650),
          const Offset(0, -180),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.pixels - before, inExclusiveRange(130, 250));
      }
      final before = scroll.position.pixels;
      await tester.flingFrom(
        const Offset(196, 650),
        const Offset(0, -250),
        10000,
      );
      await tester.pumpAndSettle();
      expect(scroll.position.pixels - before, inExclusiveRange(250, 1800));
      final after = scroll.position.pixels;
      await tester.timedDragFrom(
        const Offset(196, 650),
        const Offset(0, 180),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, lessThan(after - 130));
      // A new gesture must take over an ongoing coast, then keep moving.
      await tester.flingFrom(
        const Offset(196, 650),
        const Offset(0, -200),
        4000,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(scroll.position.isScrollingNotifier.value, isTrue);
      final coasting = scroll.position.pixels;
      await tester.flingFrom(
        const Offset(196, 650),
        const Offset(0, -200),
        4000,
      );
      await tester.pumpAndSettle();
      expect(scroll.position.pixels - coasting, inExclusiveRange(200, 1800));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scrolling far from an inline draft retains raw text and selection',
    (tester) async {
      await mountCollection(tester);
      await tester.ensureVisible(card('word-0'));
      await tester.tap(card('word-0'));
      await tester.pumpAndSettle();
      await tester.enterText(field('word-0'), '   ');
      final controller = tester.widget<TextField>(field('word-0')).controller!;
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 2,
      );
      final position = pageScroll(tester).position;
      position.jumpTo(6000);
      await tester.pumpAndSettle();
      expect(controller.text, '   ');
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('word-0'));
      expect(
        tester.widget<TextField>(field('word-0')).controller,
        same(controller),
      );
      expect(controller.text, '   ');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 2),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
