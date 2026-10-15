import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/vocabulary/collection_vocabulary_mutations.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';
import '../support/collection_deletion_fixture.dart';

Finder card(String id) => find.byKey(ValueKey('vocabulary-$id'));
Finder row(String id) => find.byKey(ValueKey('vocabulary-row-$id'));
Finder field(String id, [bool target = true]) => find.descendant(
  of: find.byKey(ValueKey('inline-$id-${target ? 'target' : 'native'}')),
  matching: find.byType(TextField),
);
Finder button(String label) =>
    find.byWidgetPredicate((w) => w is PikoButton && w.label == label);
Finder finish(String label) => find.byWidgetPredicate(
  (w) => w is PikoIconButton && w.semanticLabel == label,
);
Future<void> flush(WidgetTester tester, CollectionDeletionFixture f) async {
  await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  CollectionDeletionFixture f, {
  String locale = 'en',
  double width = 760,
  double scale = 1,
  double keyboard = 0,
  bool reduced = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(f.mutations.isBusy, isFalse);
    expect(f.deletion.disposals, 1);
    // Route disposal already ended the owner in fake time. All accepted work is
    // settled by each test; close only native storage outside the fake zone.
    await tester.runAsync(f.db.close);
  });
  CollectionVocabularyMutations factory(String _) => f.mutations;
  await tester.pumpWidget(
    PikoApp(
      locale: Locale(locale),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: reduced,
          ),
          child: CollectionDetail(
            repository: f.collections,
            collectionId: f.owner.id,
            vocabularyRepository: f.repository,
            vocabularyMutationsFactory: factory,
          ),
        ),
      ),
    ),
  );
  await flush(tester, f);
}

Future<void> swipeDelete(
  WidgetTester tester,
  String id, [
  String label = 'Delete vocabulary',
]) async {
  await tester.ensureVisible(card(id));
  await tester.drag(card(id), const Offset(-150, 0));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: row(id), matching: button(label)));
  await tester.pump();
}

void main() {
  testWidgets(
    'Undo above a newly opened editor preserves position even when the short list cannot yet scroll',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      await swipeDelete(tester, f.entries[0].id);
      await flush(tester, f);
      final active = f.entries[1].id;
      await tester.tap(card(active));
      await tester.pumpAndSettle();
      await tester.enterText(field(active), ' ');
      final before = tester.getRect(card(active)).top;
      await tester.tap(button('Undo'));
      await flush(tester, f);
      expect(tester.getRect(card(active)).top, closeTo(before, 1));
      expect(tester.widget<TextField>(field(active)).controller!.text, ' ');
    },
  );
  testWidgets(
    'covered route receives no late focus or navigation after a failed accepted deletion',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      final active = f.entries[1].id;
      await tester.tap(card(active));
      await tester.pumpAndSettle();
      await tester.enterText(field(active), ' ');
      final gate = Completer<void>();
      f.deletion.deleteGate = gate;
      f.deletion.failDelete = true;
      await swipeDelete(tester, f.entries[0].id);
      final navigator = Navigator.of(
        tester.element(find.byType(CollectionDetail)),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Other route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      gate.complete();
      await flush(tester, f);
      expect(find.text('Other route'), findsOneWidget);
      expect(f.mutations.isBusy, isFalse);
      expect(navigator.canPop(), isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field(active)).controller!.text, ' ');
    },
  );
  testWidgets(
    'opening raw changes retain check after autosave; invalid finish stays open and compact field gaps stay canonical',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f, width: 392);
      final id = f.entries[0].id;
      await tester.tap(card(id));
      await tester.pumpAndSettle();
      expect(finish('Collapse vocabulary editor'), findsOneWidget);
      await tester.enterText(field(id), 'Edited');
      await flush(tester, f);
      expect(finish('Finish editing'), findsOneWidget);
      final icon = tester.widget<PikoIcon>(
        find.descendant(
          of: finish('Finish editing'),
          matching: find.byType(PikoIcon),
        ),
      );
      expect(icon.name, PikoIconName.check);
      expect(
        tester.getRect(finish('Finish editing')).height,
        greaterThanOrEqualTo(44),
      );
      final nativeLabel = find.text('German');
      expect(
        tester.getTopLeft(nativeLabel).dy - tester.getBottomLeft(field(id)).dy,
        pikoDesign.dimension('spacing.3'),
      );
      await tester.enterText(field(id), ' ');
      await tester.pumpAndSettle();
      await tester.tap(finish('Finish editing'));
      await tester.pumpAndSettle();
      expect(field(id), findsOneWidget);
      await tester.enterText(field(id), 'Edited again');
      await flush(tester, f);
      await tester.tap(finish('Finish editing'));
      await flush(tester, f);
      expect(field(id), findsNothing);
    },
  );
  testWidgets(
    'inactive swipe only reveals; explicit delete and Undo retain unrelated invalid raw selection focus and anchor',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      final active = f.entries[1].id, deleted = f.entries[0].id;
      await tester.tap(card(active));
      await tester.pumpAndSettle();
      await tester.enterText(field(active), '  ');
      final text = tester.widget<TextField>(field(active));
      text.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 1,
      );
      final before = tester.getRect(card(active)).top;
      await tester.drag(card(deleted), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(f.deletion.deletes, 0);
      await tester.tap(
        find.descendant(
          of: row(deleted),
          matching: button('Delete vocabulary'),
        ),
      );
      await flush(tester, f);
      expect(card(deleted), findsNothing);
      expect(
        tester.widget<TextField>(field(active)).controller,
        same(text.controller),
      );
      expect(text.controller!.text, '  ');
      expect(
        text.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(text.focusNode!.hasFocus, isTrue);
      expect(tester.getRect(card(active)).top, closeTo(before, 1));
      await tester.tap(button('Undo'));
      await flush(tester, f);
      expect(card(deleted), findsOneWidget);
      expect(text.focusNode!.hasFocus, isTrue);
      expect(tester.getRect(card(active)).top, closeTo(before, 1));
      await tester.enterText(field(active), 'Valid again');
      await flush(tester, f);
      await tester.tap(finish('Finish editing'));
      await flush(tester, f);
      final scrollable = find
          .descendant(
            of: find.byType(CollectionDetail),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(card(deleted)).top,
        closeTo(
          tester.getRect(find.text('Vocabulary')).bottom +
              pikoDesign.dimension('components.sectionHeading.bottomMargin'),
          1,
        ),
      );
    },
  );
  testWidgets(
    'expanded Delete drains queued target saves; restore remains visible disabled pending and route owns service without registry',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
      final id = f.entries[0].id;
      await tester.tap(card(id));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      f.repository.updateGates[id] = gate;
      await tester.enterText(field(id), 'Accepted A');
      await tester.enterText(field(id), 'Accepted B');
      await tester.tap(button('Delete vocabulary'));
      await tester.pump();
      expect(f.deletion.deletes, 0);
      expect(tester.widget<TextField>(field(id)).enabled, isFalse);
      gate.complete();
      await flush(tester, f);
      expect(card(id), findsNothing);
      expect(f.mutations.latest!.entry.targetText, 'Accepted B');
      final restoreGate = Completer<void>();
      f.deletion.restoreGate = restoreGate;
      await tester.tap(button('Undo'));
      await tester.pump();
      expect(button('Undo'), findsOneWidget);
      expect(tester.widget<PikoButton>(button('Undo')).onPressed, isNull);
      restoreGate.complete();
      await flush(tester, f);
      expect(card(id), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(f.deletion.disposals, 1);
    },
  );
  testWidgets(
    'German long-text Undo at 392px 200 percent stays above on-screen keyboard with reduced motion and localized retry',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      final id = f.entries[0].id;
      await tester.runAsync(
        () => f.real.update(
          id: id,
          targetText: List.filled(60, 'Langes Wort').join(' '),
          nativeText: List.filled(60, 'Lange Übersetzung').join(' '),
        ),
      );
      await mount(
        tester,
        f,
        locale: 'de',
        width: 392,
        scale: 2,
        keyboard: 300,
        reduced: true,
      );
      f.deletion.failDelete = true;
      await swipeDelete(tester, id, 'Vokabel löschen');
      await flush(tester, f);
      expect(
        find.text(
          'Diese Vokabel konnte nicht gelöscht werden. Bitte versuche es erneut.',
        ),
        findsOneWidget,
      );
      f.deletion.failDelete = false;
      await swipeDelete(tester, id, 'Vokabel löschen');
      await flush(tester, f);
      await tester.ensureVisible(button('Rückgängig'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(button('Rückgängig'));
      expect(rect.bottom, lessThanOrEqualTo(700));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
      await tester.tap(button('Rückgängig'));
      await flush(tester, f);
      expect(card(id), findsOneWidget);
    },
  );
}
