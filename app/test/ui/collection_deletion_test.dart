import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/vocabulary/collection_vocabulary_mutations.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/shared/catalogs.dart';
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
  (w) =>
      (w is PikoIconButton && w.semanticLabel == label) ||
      (w is PikoButton && w.label == label),
);
Future<void> flush(WidgetTester tester, CollectionDeletionFixture f) async {
  await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

// UX-ANCHOR-001 r1 permits only scroll-bound clamping, without permanent slack.
void expectAnchoredOrClamped(
  WidgetTester tester,
  Finder target,
  double before,
) {
  final delta = tester.getRect(target).top - before;
  if (delta.abs() <= 1) return;
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  final desired = position.pixels + delta;
  expect(
    desired < position.minScrollExtent || desired > position.maxScrollExtent,
    isTrue,
  );
  expect(
    position.pixels,
    delta > 0 ? position.maxScrollExtent : position.minScrollExtent,
  );
}

Future<void> mount(
  WidgetTester tester,
  CollectionDeletionFixture f, {
  String locale = 'en',
  double width = 760,
  double scale = 1,
  double keyboard = 0,
  bool reduced = false,
  bool nativeViewport = false,
}) async {
  if (!nativeViewport) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
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

void registerRound10EditorTests({
  bool nativeViewport = false,
  String locale = 'en',
  double scale = 1,
}) {
  testWidgets(
    '$locale editor Delete Cancel preserves invalid raw draft and title status',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await mount(
        tester,
        f,
        locale: locale,
        scale: scale,
        nativeViewport: nativeViewport,
      );
      final id = f.entries.first.id;
      await tester.tap(card(id));
      await tester.pumpAndSettle();
      await tester.enterText(field(id), '  ');
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(field(id)).controller!;
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 1,
      );
      final remove = find.byKey(ValueKey('inline-delete-' + id));
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(f.deletion.deletes, 0);
      await tester.tap(
        find.descendant(
          of: find.byType(PikoDialog).last,
          matching: button(PikoCopy(locale).text('action.cancel')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field(id)).controller, same(controller));
      expect(controller.text, '  ');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(f.deletion.deletes, 0);
      expect(find.text(PikoCopy(locale).text('entry.unsaved')), findsOneWidget);
    },
  );
}

void main() {
  registerRound10EditorTests();
  testWidgets(
    'Undo above a raw editor uses the documented short-list scroll-bound fallback',
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
      await tester.runAsync(() => f.mutations.undo(f.mutations.latest!));
      await flush(tester, f);
      expectAnchoredOrClamped(tester, card(active), before);
      expect(tester.widget<TextField>(field(active)).controller!.text, ' ');
    },
  );
  testWidgets(
    'covered route receives no late focus or navigation after a failed accepted deletion',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f);
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
      expect(card(f.entries[0].id), findsOneWidget);
    },
  );
  testWidgets(
    'autosave retains collapse chevron; invalid collapse stays open and compact field gaps stay canonical',
    (tester) async {
      final f = CollectionDeletionFixture();
      await tester.runAsync(f.initialize);
      await mount(tester, f, width: 392);
      final id = f.entries[0].id;
      await tester.tap(card(id));
      await tester.pumpAndSettle();
      expect(finish('Close'), findsOneWidget);
      await tester.enterText(field(id), 'Edited');
      await flush(tester, f);
      expect(finish('Close'), findsOneWidget);
      final icon = tester.widget<PikoIcon>(
        find.descendant(of: finish('Close'), matching: find.byType(PikoIcon)),
      );
      expect(icon.name, PikoIconName.x);
      expect(tester.getRect(finish('Close')).height, greaterThanOrEqualTo(44));
      final nativeLabel = find.text('German');
      expect(
        tester.getTopLeft(nativeLabel).dy - tester.getBottomLeft(field(id)).dy,
        33,
      );
      await tester.enterText(field(id), ' ');
      await tester.pumpAndSettle();
      await tester.ensureVisible(finish('Close'));
      await tester.tap(finish('Close'));
      await tester.pumpAndSettle();
      expect(field(id), findsOneWidget);
      await tester.enterText(field(id), 'Edited again');
      await flush(tester, f);
      await tester.ensureVisible(finish('Close'));
      await tester.tap(finish('Close'));
      await flush(tester, f);
      expect(field(id), findsNothing);
    },
  );
  testWidgets(
    'modal retains invalid selection and blocks background deletion; Close then swipe and Undo remain available',
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
      await tester.tap(finish('Close'));
      await flush(tester, f);
      expect(field(active), findsOneWidget);
      expect(text.controller!.text, '  ');
      expect(
        text.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(f.deletion.deletes, 0);
      await tester.enterText(field(active), 'Valid again');
      await flush(tester, f);
      await tester.tap(finish('Close'));
      await flush(tester, f);
      await swipeDelete(tester, deleted);
      await flush(tester, f);
      expect(card(deleted), findsNothing);
      await tester.tap(button('Undo'));
      await flush(tester, f);
      expect(card(deleted), findsOneWidget);
      expect(
        (await tester.runAsync(
          () => f.real.watchById(active).first,
        ))!.targetText,
        'Valid again',
      );
      expect(tester.takeException(), isNull);
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
      final delete = find.byKey(ValueKey('inline-delete-$id'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PikoDialog).last,
          matching: button('Delete vocabulary'),
        ),
      );
      await tester.pumpAndSettle();
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
