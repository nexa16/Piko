import 'package:piko/ui/components/piko_interaction_anchor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/piko_theme.dart';
import 'entry_stack_test.dart' show ScreenRepository, owner, seed, field, clean;

Future<ValueNotifier<double>> keyboardHost(
  WidgetTester tester,
  EntrySessionController session,
  String language,
  double scale,
) async {
  final inset = ValueNotifier(0.0);
  final locale = InterfaceLocaleController(Locale(language));
  addTearDown(inset.dispose);
  addTearDown(locale.dispose);
  clean(tester, session);
  await tester.pumpWidget(
    PikoApp(
      localeController: locale,
      home: Builder(
        builder: (context) => ValueListenableBuilder<double>(
          valueListenable: inset,
          builder: (_, value, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
              viewInsets: EdgeInsets.only(bottom: value),
            ),
            child: EntrySessionScreen(collection: owner, session: session),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return inset;
}

Rect bounds(WidgetTester tester, String side) =>
    tester.getRect(find.byKey(ValueKey('draft-$side')));

void visible(WidgetTester tester, Rect field) {
  final viewport = tester.getRect(find.byKey(const ValueKey('entry-stack')));
  expect(field.top, greaterThanOrEqualTo(viewport.top - 1));
  expect(field.bottom, lessThanOrEqualTo(viewport.bottom + 1));
}

Future<void> scrollActionIntoView(WidgetTester tester, Finder action) async {
  // Let explicit input focus finish before the user starts browsing actions.
  await tester.pumpAndSettle();
  final viewport = find.byKey(const ValueKey('entry-stack'));
  for (var attempt = 0; attempt < 4; attempt++) {
    final area = tester.getRect(viewport);
    final button = tester.getRect(action);
    if (button.top >= area.top && button.bottom <= area.bottom) return;
    final delta = button.bottom > area.bottom
        ? area.bottom - button.bottom - 24
        : area.top - button.top + 24;
    await tester.dragFrom(
      Offset(area.left + 4, area.center.dy),
      Offset(0, delta),
    );
    await tester.pumpAndSettle();
  }
  visible(tester, tester.getRect(action));
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language first card has no leading spacer; delayed IME retains both labels and Next/Done traversal',
      (tester) async {
        tester.view.physicalSize = const Size(392, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = EntrySessionController(
          collectionId: owner.id,
          repository: ScreenRepository(),
        );
        final inset = await keyboardHost(tester, session, language, 2);
        final viewport = find.byKey(const ValueKey('entry-stack'));
        final scroll = tester
            .widget<PikoAnchoredBoxScrollView>(viewport)
            .controller!;
        expect(scroll.offset, 0);
        expect(
          tester.getRect(find.byKey(const ValueKey('entry-card-draft'))).top -
              tester.getRect(viewport).top,
          closeTo(pikoDesign.dimension('spacing.2'), 1),
        );
        for (final height in [100.0, 200.0, 300.0]) {
          inset.value = height;
          await tester.pumpAndSettle();
          visible(tester, bounds(tester, 'target'));
          visible(tester, bounds(tester, 'native'));
          expect(
            tester
                .widget<TextField>(field('draft', 'target'))
                .focusNode!
                .hasFocus,
            isTrue,
          );
        }
        expect(
          tester.widget<TextField>(field('draft', 'target')).textInputAction,
          TextInputAction.next,
        );
        expect(
          tester.widget<TextField>(field('draft', 'native')).textInputAction,
          TextInputAction.done,
        );
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(field('draft', 'native'))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(session.confirmedEntries, isEmpty);
        expect(session.activeEntryId, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language short viewport prioritizes complete first label/input after Save & Next and keeps actions scrollable',
      (tester) async {
        tester.view.physicalSize = const Size(392, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = EntrySessionController(
          collectionId: owner.id,
          repository: ScreenRepository(),
        );
        final inset = await keyboardHost(tester, session, language, 2);
        inset.value = 400;
        await tester.pumpAndSettle();
        visible(tester, bounds(tester, 'target'));
        await tester.enterText(field('draft', 'target'), 'Word');
        await tester.ensureVisible(field('draft', 'native'));
        await tester.enterText(field('draft', 'native'), 'Wort');
        final save = find.byTooltip(PikoCopy(language).text('action.saveNext'));
        await scrollActionIntoView(tester, save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(session.confirmedEntries, hasLength(1));
        expect(
          tester
              .widget<TextField>(field('draft', 'target'))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        visible(tester, bounds(tester, 'target'));
        await scrollActionIntoView(tester, save);
        // A subsequent IME reflow must not undo the deliberate action scroll.
        final scroll = tester
            .widget<PikoAnchoredBoxScrollView>(
              find.byKey(const ValueKey('entry-stack')),
            )
            .controller!;
        final actionOffset = scroll.offset;
        inset.value = 390;
        await tester.pumpAndSettle();
        expect(
          scroll.offset,
          closeTo(
            actionOffset.clamp(
              scroll.position.minScrollExtent,
              scroll.position.maxScrollExtent,
            ),
            1,
          ),
        );
        final viewport = tester.getRect(
          find.byKey(const ValueKey('entry-stack')),
        );
        expect(
          tester.getRect(save).bottom,
          lessThanOrEqualTo(viewport.bottom + 1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'returning to top activates first card without a centering spacer after keyboard resize',
    (tester) async {
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      await seed(session, 4);
      final inset = await keyboardHost(tester, session, 'en', 1);
      final viewport = find.byKey(const ValueKey('entry-stack'));
      final scroll = tester
          .widget<PikoAnchoredBoxScrollView>(viewport)
          .controller!;
      final area = tester.getRect(viewport);
      await tester.dragFrom(
        Offset(area.left + 4, area.center.dy),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      expect(session.activeEntryId, 'entry-0');
      expect(scroll.offset, 0);
      inset.value = 200;
      await tester.pumpAndSettle();
      inset.value = 0;
      await tester.pumpAndSettle();
      expect(session.activeEntryId, 'entry-0');
      expect(scroll.offset, 0);
      expect(
        tester.getRect(find.byKey(const ValueKey('entry-card-entry-0'))).top -
            tester.getRect(viewport).top,
        closeTo(pikoDesign.dimension('spacing.2'), 1),
      );
      expect(
        tester
            .widget<PikoAnchoredBoxScrollView>(viewport)
            .padding
            .resolve(TextDirection.ltr)
            .top,
        0,
      );
    },
  );
}
