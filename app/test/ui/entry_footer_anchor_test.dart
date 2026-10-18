import 'package:piko/ui/components/piko_interaction_anchor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/piko_theme.dart';
import '../support/entry_deletion_fixture.dart';
import 'entry_stack_test.dart' show field;

Finder get draft => find.byKey(const ValueKey('entry-card-draft'));
Finder get viewport => find.byKey(const ValueKey('entry-stack'));

Future<void> flush(WidgetTester tester, EntryDeletionFixture f) async {
  await tester.pump();
  await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

Future<EntryDeletionFixture> mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(760, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = EntryDeletionFixture();
  await tester.runAsync(() async {
    await f.initialize();
    await f.confirm('One', 'Eins');
    await f.confirm('Two', 'Zwei');
    await f.confirm('Three', 'Drei');
  });
  f.session.setTargetText(' raw draft ');
  f.session.setNativeText(' Entwurf ');
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(f.dispose);
  });
  await tester.pumpWidget(
    PikoApp(
      home: EntrySessionScreen(collection: f.owner, session: f.session),
    ),
  );
  await tester.pumpAndSettle();
  return f;
}

void inputVisible(WidgetTester tester, String side) {
  final bounds = tester.getRect(find.byKey(ValueKey('draft-$side')));
  final area = tester.getRect(viewport);
  expect(bounds.top, greaterThanOrEqualTo(area.top - 1));
  expect(bounds.bottom, lessThanOrEqualTo(area.bottom + 1));
}

void main() {
  testWidgets(
    'deliberate scrolling releases deletion compensation and leaves no leading centering gap',
    (tester) async {
      final f = await mount(tester);
      final deleting = f.session.deleteSavedEntry(
        f.session.confirmedEntries.first.id,
      );
      await flush(tester, f);
      await deleting;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('entry-structural-gap-draft')),
        findsOneWidget,
      );
      final area = tester.getRect(viewport);
      await tester.dragFrom(
        Offset(area.left + 4, area.center.dy),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('entry-structural-gap-draft')),
        findsNothing,
      );
      final first = f.session.confirmedEntries.first.id;
      expect(f.session.activeEntryId, first);
      expect(
        tester.widget<PikoAnchoredBoxScrollView>(viewport).controller!.offset,
        0,
      );
      expect(
        tester.getRect(find.byKey(ValueKey('entry-card-$first'))).top -
            tester.getRect(viewport).top,
        closeTo(pikoDesign.dimension('spacing.2'), 1),
      );
    },
  );

  testWidgets(
    'Undo footer appearance and removal retain active draft anchor, focus, raw input and selection',
    (tester) async {
      final f = await mount(tester);
      final deleted = f.session.confirmedEntries.first.id;
      final text = tester.widget<TextField>(field('draft', 'target'));
      text.controller!.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      final before = tester.getRect(draft).center.dy;
      final height = tester.getRect(viewport).height;
      final deleting = f.session.deleteSavedEntry(deleted);
      await flush(tester, f);
      await deleting;
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport).height, lessThan(height));
      expect(tester.getRect(draft).center.dy, closeTo(before, 2));
      expect(
        find.byKey(const ValueKey('entry-structural-gap-draft')),
        findsOneWidget,
      );
      expect(text.focusNode!.hasFocus, isTrue);
      final restoring = f.session.undoDeletion(deleted);
      await flush(tester, f);
      await restoring;
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport).height, closeTo(height, 1));
      expect(
        find.byKey(const ValueKey('entry-structural-gap-draft')),
        findsNothing,
      );
      expect(tester.getRect(draft).center.dy, closeTo(before, 2));
      expect(
        tester.widget<TextField>(field('draft', 'target')).controller,
        same(text.controller),
      );
      expect(text.controller!.text, ' raw draft ');
      expect(
        text.controller!.selection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      expect(text.focusNode!.hasFocus, isTrue);
      expect(f.session.activeEntryId, isNull);
    },
  );

  testWidgets(
    'platform keyboard insets still reveal labeled input during Undo footer reflow',
    (tester) async {
      final f = await mount(tester);
      final deleted = f.session.confirmedEntries.first.id;
      final native = field('draft', 'native');
      await tester.tap(native);
      await tester.pumpAndSettle();
      final text = tester.widget<TextField>(native);
      text.controller!.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      final deleting = f.session.deleteSavedEntry(deleted);
      await flush(tester, f);
      await deleting;
      await tester.pumpAndSettle();
      final beforeKeyboard = tester.getRect(draft).center.dy;
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();
      inputVisible(tester, 'native');
      expect(tester.getRect(draft).center.dy, lessThan(beforeKeyboard));
      expect(text.focusNode!.hasFocus, isTrue);
      // A simultaneous real inset increase and structural footer removal still
      // prioritizes reachable input, even when their viewport deltas nearly cancel.
      final restoring = f.session.undoDeletion(deleted);
      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      await flush(tester, f);
      await restoring;
      await tester.pumpAndSettle();
      inputVisible(tester, 'native');
      expect(text.focusNode!.hasFocus, isTrue);
      expect(text.controller!.text, ' Entwurf ');
      expect(
        text.controller!.selection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      expect(f.session.activeEntryId, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
