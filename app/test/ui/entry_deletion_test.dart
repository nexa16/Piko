import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import '../support/entry_deletion_fixture.dart';

Future<ValueNotifier<EntrySessionController>> mount(
  WidgetTester tester,
  EntryDeletionFixture f, {
  String locale = 'en',
  double width = 760,
  double scale = 1,
  double keyboard = 0,
  bool reduced = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final current = ValueNotifier(f.session);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    current.dispose();
    await f.dispose();
  });
  await tester.pumpWidget(
    PikoApp(
      locale: Locale(locale),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      ValueListenableBuilder<EntrySessionController>(
                        valueListenable: current,
                        builder: (context, session, _) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(scale),
                            viewInsets: EdgeInsets.only(bottom: keyboard),
                            disableAnimations: reduced,
                          ),
                          child: EntrySessionScreen(
                            collection: f.owner,
                            session: session,
                          ),
                        ),
                      ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return current;
}

Finder card(String id) => find.byKey(ValueKey('entry-card-$id'));
Finder field(String id) => find.descendant(
  of: find.byKey(ValueKey('$id-target'), skipOffstage: false),
  matching: find.byType(TextField, skipOffstage: false),
);
double center(WidgetTester tester, String id) =>
    tester.getRect(card(id)).center.dy;
Future<void> flush(WidgetTester tester, EntryDeletionFixture f) async {
  await f.db.customSelect('SELECT 1').get();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'only expanded saved cards delete; pending Undo stays visible and failures retry without losing draft',
    (tester) async {
      final f = EntryDeletionFixture();
      await f.initialize();
      final a = await f.confirm('One', 'Eins'),
          b = await f.confirm('Two', 'Zwei'),
          c = await f.confirm('Three', 'Drei');
      f.session.setTargetText(' raw draft ');
      await mount(tester, f);
      final draft = tester.widget<TextField>(field('draft')).controller!;
      draft.selection = const TextSelection(baseOffset: 2, extentOffset: 4);
      expect(find.text('Delete vocabulary'), findsNothing);
      f.session.selectSavedEntry(b.id);
      await tester.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsOneWidget);
      await tester.ensureVisible(find.text('Delete vocabulary'));
      f.deletion.failDelete = true;
      await tester.tap(find.text('Delete vocabulary'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't delete this vocabulary. Please try again."),
        findsOneWidget,
      );
      expect(f.session.confirmedEntries, hasLength(3));
      f.deletion.failDelete = false;
      await tester.tap(find.text('Delete vocabulary'));
      await flush(tester, f);
      expect(f.session.activeEntryId, c.id);
      expect(find.byKey(ValueKey('undo-${b.id}')), findsOneWidget);
      expect(f.session.confirmedEntries.map((e) => e.id), [a.id, c.id]);
      f.deletion.restoreGate = Completer<void>();
      f.deletion.failRestore = true;
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('undo-${b.id}')), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Undo'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave this entry session?'), findsNothing);
      f.deletion.restoreGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't restore this vocabulary. Please try again."),
        findsOneWidget,
      );
      f.deletion.failRestore = false;
      await tester.tap(find.text('Undo'));
      await flush(tester, f);
      expect(f.session.confirmedEntries.map((e) => e.id), [a.id, b.id, c.id]);
      expect(f.session.activeEntryId, c.id);
      expect(draft.text, ' raw draft ');
      expect(
        draft.selection,
        const TextSelection(baseOffset: 2, extentOffset: 4),
      );
    },
  );

  for (final activeDraft in [true, false]) {
    testWidgets(
      'structural Undo above ${activeDraft ? 'draft' : 'saved card'} preserves anchor through concurrent autosave',
      (tester) async {
        final f = EntryDeletionFixture();
        await f.initialize();
        final a = await f.confirm('One', 'Eins'),
            b = await f.confirm('Two', 'Zwei'),
            c = await f.confirm('Three', 'Drei');
        f.session.setTargetText(' raw draft ');
        await mount(tester, f);
        if (!activeDraft) {
          f.session.selectSavedEntry(c.id);
          await tester.pumpAndSettle();
        }
        final active = activeDraft ? 'draft' : c.id;
        final editor = tester.widget<TextField>(field(active)).controller!;
        editor.selection = const TextSelection(baseOffset: 1, extentOffset: 2);
        final before = center(tester, active);
        await f.session.deleteSavedEntry(a.id);
        await tester.pumpAndSettle();
        expect(center(tester, active), closeTo(before, 2));
        final afterDelete = center(tester, active);
        final gate = Completer<void>();
        f.repository.updateGates[b.id] = gate;
        f.session.editSavedEntry(b.id, nativeText: 'Updated');
        await f.session.undoDeletion(a.id);
        await tester.pump(const Duration(milliseconds: 30));
        gate.complete();
        await f.session.awaitSavedEdits();
        final samples = <double>[];
        for (var frame = 0; frame < 15; frame++) {
          await tester.pump(const Duration(milliseconds: 20));
          samples.add(center(tester, active));
          expect(f.session.activeEntryId, activeDraft ? null : c.id);
        }
        expect(
          samples.every((value) => (value - afterDelete).abs() <= 2),
          isTrue,
          reason: 'before=$before; afterDelete=$afterDelete; frames=$samples',
        );
        expect(
          editor.selection,
          const TextSelection(baseOffset: 1, extentOffset: 2),
        );
        expect(f.session.draft.targetText, ' raw draft ');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'two deletions reveal older Undo without renewing its deadline, then expire',
    (tester) async {
      final f = EntryDeletionFixture();
      await f.initialize();
      final a = await f.confirm('One', 'Eins'),
          b = await f.confirm('Two', 'Zwei');
      await mount(tester, f);
      await f.session.deleteSavedEntry(a.id);
      await tester.pumpAndSettle();
      final deadline = f.session.undoEntries.first.expiresAt;
      f.clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await f.session.deleteSavedEntry(b.id);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('undo-${b.id}')), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await flush(tester, f);
      expect(find.byKey(ValueKey('undo-${a.id}')), findsOneWidget);
      expect(f.session.undoEntries.single.expiresAt, deadline);
      f.clock.advance(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 6));
      expect(f.session.undoEntries, isEmpty);
      expect(find.text('Undo'), findsNothing);
      expect(f.deletion.canUndo(f.deletion.receipts.first), isFalse);
    },
  );

  testWidgets(
    'backward clock reschedules cleanup instead of retaining a capability forever',
    (tester) async {
      final f = EntryDeletionFixture();
      await f.initialize();
      final a = await f.confirm(
        List.filled(100, 'Long vocabulary').join(' '),
        List.filled(100, 'Lange Vokabel').join(' '),
      );
      await mount(tester, f);
      await f.session.deleteSavedEntry(a.id);
      await tester.pumpAndSettle();
      f.clock.advance(const Duration(seconds: -4));
      await tester.pump(const Duration(seconds: 8));
      expect(f.session.undoEntries, hasLength(1));
      f.clock.advance(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 12));
      expect(f.session.undoEntries, isEmpty);
      expect(f.deletion.canUndo(f.deletion.receipts.single), isFalse);
    },
  );

  testWidgets(
    'session replacement releases late receipt; covered routes receive no late deletion errors',
    (tester) async {
      final f = EntryDeletionFixture();
      await f.initialize();
      final a = await f.confirm('One', 'Eins');
      f.session.selectSavedEntry(a.id);
      final current = await mount(tester, f);
      f.deletion.deleteGate = Completer<void>();
      await tester.ensureVisible(find.text('Delete vocabulary'));
      await tester.tap(find.text('Delete vocabulary'));
      await tester.pumpAndSettle();
      current.value = f.newSession();
      await tester.pumpAndSettle();
      f.deletion.deleteGate!.complete();
      await flush(tester, f);
      expect(f.session.undoEntries, isEmpty);
      expect(f.deletion.canUndo(f.deletion.receipts.single), isFalse);
      expect(find.text('Vocabulary deleted'), findsNothing);
      expect(f.deletion.disposals, 0);
      final second = current.value;
      second.setTargetText('Two');
      second.setNativeText('Zwei');
      final b = await second.confirmAndNext();
      second.selectSavedEntry(b.id);
      await tester.pumpAndSettle();
      f.deletion.deleteGate = Completer<void>();
      f.deletion.failDelete = true;
      await tester.ensureVisible(find.text('Delete vocabulary'));
      await tester.tap(find.text('Delete vocabulary'));
      await tester.pumpAndSettle();
      final navigator = Navigator.of(
        tester.element(find.byType(EntrySessionScreen)),
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      f.deletion.deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Covered'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't delete this vocabulary. Please try again."),
        findsNothing,
      );
      expect(second.confirmedEntries.single.id, b.id);
    },
  );

  testWidgets(
    'German 392px 200% keyboard-resized Undo stays reachable and pending restore remains visible',
    (tester) async {
      final f = EntryDeletionFixture();
      await f.initialize();
      final a = await f.confirm(
        List.filled(100, 'Long vocabulary').join(' '),
        List.filled(100, 'Lange Vokabel').join(' '),
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
      await f.session.deleteSavedEntry(a.id);
      await tester.pumpAndSettle();
      final undo = find.text(const PikoCopy('de').text('vocab.undo'));
      expect(tester.getRect(undo).bottom, lessThanOrEqualTo(700));
      f.deletion.restoreGate = Completer<void>();
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('undo-${a.id}')), findsOneWidget);
      f.deletion.restoreGate!.complete();
      await flush(tester, f);
      expect(find.byKey(ValueKey('undo-${a.id}')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
