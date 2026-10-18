import 'package:piko/ui/components/piko_interaction_anchor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/piko_theme.dart';

import 'entry_stack_test.dart' as fixture;

void main() {
  for (final height in [914.285714, 1400.0]) {
    testWidgets(
      'a fitting short stack activates in both drag directions at $height',
      (tester) async {
        tester.view.physicalSize = Size(411.428571, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = EntrySessionController(
          collectionId: fixture.owner.id,
          repository: fixture.ScreenRepository(),
        );
        fixture.clean(tester, session);
        await fixture.seed(session, 1);
        session.setTargetText('  retained raw draft  ');
        await tester.pumpWidget(
          PikoApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: EntrySessionScreen(
                collection: fixture.owner,
                session: session,
                onOpenInterchange: () async => null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final stack = find.byKey(const ValueKey('entry-stack'));
        final position = tester
            .widget<PikoAnchoredBoxScrollView>(stack)
            .controller!;
        final savedId = session.confirmedEntries.single.id;
        final saved = find.byKey(ValueKey('entry-card-$savedId'));
        final draft = find.byKey(const ValueKey('entry-card-draft'));
        expect(position.position.maxScrollExtent, 0);
        expect(position.offset, 0);
        expect(
          tester.getTopLeft(saved).dy - tester.getTopLeft(stack).dy,
          closeTo(pikoDesign.dimension('spacing.2'), 1),
        );

        // The catalogue calls ensureVisible before its gestures. A reveal must not
        // select a card, and the gesture must still work without scroll extent.
        await tester.ensureVisible(saved);
        await tester.ensureVisible(draft);
        await tester.pumpAndSettle();
        expect(session.activeEntryId, isNull);
        final rawController = tester
            .widget<TextField>(fixture.field('draft', 'target'))
            .controller!;
        rawController.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 7,
        );

        Future<void> dragStack(double direction) async {
          final bounds = tester.getRect(stack);
          await tester.dragFrom(
            Offset(bounds.left + 4, bounds.center.dy),
            Offset(0, direction * bounds.height * .6),
          );
          await tester.pumpAndSettle();
        }

        await dragStack(1);
        expect(session.activeEntryId, savedId);
        expect(tester.widget<PikoCard>(saved).selected, isTrue);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(session.draft.targetText, '  retained raw draft  ');
        if (height == 1400) {
          expect(position.position.maxScrollExtent, 0);
        }

        await dragStack(-1);
        expect(session.activeEntryId, isNull);
        expect(tester.widget<PikoCard>(draft).selected, isTrue);
        expect(
          tester.widget<TextField>(fixture.field('draft', 'target')).controller,
          same(rawController),
        );
        expect(rawController.text, '  retained raw draft  ');
        expect(
          rawController.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a reverse zero-extent gesture survives an in-flight expansion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411.428571, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = EntrySessionController(
      collectionId: fixture.owner.id,
      repository: fixture.ScreenRepository(),
    );
    fixture.clean(tester, session);
    await fixture.seed(session, 1);
    session.setTargetText('  animated raw draft  ');
    await tester.pumpWidget(
      PikoApp(
        home: EntrySessionScreen(
          collection: fixture.owner,
          session: session,
          onOpenInterchange: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final stack = find.byKey(const ValueKey('entry-stack'));
    final position = tester
        .widget<PikoAnchoredBoxScrollView>(stack)
        .controller!;
    expect(position.position.maxScrollExtent, 0);
    final savedId = session.confirmedEntries.single.id;
    final bounds = tester.getRect(stack);
    final start = Offset(bounds.left + 4, bounds.center.dy);
    await tester.dragFrom(start, const Offset(0, 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(session.activeEntryId, savedId);
    final animated = find.descendant(
      of: stack,
      matching: find.byType(AnimatedSize),
    );
    expect(
      animated.evaluate().any(
        (element) =>
            (element.findRenderObject() as RenderAnimatedSize).isAnimating,
      ),
      isTrue,
      reason: 'The reverse gesture must end before expansion settles',
    );
    expect(position.position.maxScrollExtent, 0);
    await tester.dragFrom(start, const Offset(0, -80));
    await tester.pump();
    expect(
      session.activeEntryId,
      savedId,
      reason: 'Selection waits for the active expansion to settle',
    );
    await tester.pumpAndSettle();
    expect(session.activeEntryId, isNull);
    expect(session.draft.targetText, '  animated raw draft  ');
    expect(position.offset, 0);
    expect(tester.takeException(), isNull);
  });
}
