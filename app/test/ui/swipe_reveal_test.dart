import 'dart:ui' show ImageByteFormat, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/components/piko_swipe_reveal.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  testWidgets(
    'rounded closed and disabled cards have no danger halo; reveal and close retain a continuous danger underlay',
    (t) async {
      late StateSetter rebuild;
      var enabled = true;
      const actualKey = ValueKey('swipe-raster');
      const referenceKey = ValueKey('plain-raster');
      Widget foreground() => const SizedBox(
        width: 280,
        height: 140,
        child: PikoCard(padding: EdgeInsets.zero, child: SizedBox.expand()),
      );
      await t.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(
                        key: referenceKey,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            pikoDesign.dimension('radii.card'),
                          ),
                          child: foreground(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      RepaintBoundary(
                        key: actualKey,
                        child: SizedBox(
                          width: 280,
                          child: PikoSwipeReveal(
                            enabled: enabled,
                            label: 'Delete vocabulary',
                            onDelete: () =>
                                fail('raster verification must not delete'),
                            child: foreground(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final row = find.byType(PikoSwipeReveal);
      final underlay = find
          .descendant(of: row, matching: find.byType(ColoredBox))
          .first;
      final card = find.descendant(of: row, matching: find.byType(PikoCard));
      double displacement() => t.getTopLeft(row).dx - t.getTopLeft(card).dx;
      Future<Uint8List> raster(Key key) async {
        final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
        return (await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final data = await image.toByteData(
              format: ImageByteFormat.rawRgba,
            );
            return Uint8List.fromList(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        }))!;
      }

      final reference = await raster(referenceKey);
      Future<void> closedWithoutHalo(String state) async {
        expect(
          t.widget<ColoredBox>(underlay).color,
          Colors.transparent,
          reason: '$state must not paint a hidden danger surface',
        );
        expect(displacement(), 0);
        final actual = await raster(actualKey);
        // Compare each antialiased rounded-edge pixel against the identical
        // clipped production card with no swipe underlay, including alpha.
        final radius = pikoDesign.dimension('radii.card').ceil();
        final mismatches = <(int, int)>[];
        for (var y = 0; y < 140; y++) {
          for (var x = 0; x < 280; x++) {
            if (x >= radius &&
                x < 280 - radius &&
                y >= radius &&
                y < 140 - radius) {
              continue;
            }
            final offset = (y * 280 + x) * 4;
            if (actual[offset] != reference[offset] ||
                actual[offset + 1] != reference[offset + 1] ||
                actual[offset + 2] != reference[offset + 2] ||
                actual[offset + 3] != reference[offset + 3]) {
              mismatches.add((x, y));
            }
          }
        }
        expect(
          mismatches,
          isEmpty,
          reason:
              '$state rounded edges must match the card without red underpainting',
        );
      }

      Future<void> continuousDanger(String state) async {
        expect(
          t.widget<ColoredBox>(underlay).color,
          pikoDesign.color('danger'),
          reason: '$state retains danger behind rounded foreground corners',
        );
        expect(
          t.getSize(underlay),
          t.getSize(row),
          reason: 'The underlay covers the entire card throughout $state',
        );
        final pixels = await raster(actualKey);
        final offset = (70 * 280 + 278) * 4;
        final painted = Color.fromARGB(
          pixels[offset + 3],
          pixels[offset],
          pixels[offset + 1],
          pixels[offset + 2],
        );
        expect(
          painted,
          pikoDesign.color('danger'),
          reason: '$state exposed right edge remains solid danger',
        );
      }

      await closedWithoutHalo('initially closed');
      final halfMotion = Duration(
        milliseconds: (pikoDesign.dimension('controls.motionFastMs') / 2)
            .round(),
      );
      await t.drag(row, const Offset(-100, 0));
      await t.pump();
      await t.pump(halfMotion);
      final openingOffset = displacement();
      expect(openingOffset, greaterThan(0));
      await continuousDanger('partially opening');
      await t.pumpAndSettle();
      final fullOffset = displacement();
      expect(fullOffset, greaterThan(openingOffset));
      await continuousDanger('fully open');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await t.pump(halfMotion);
      expect(displacement(), greaterThan(0));
      expect(displacement(), lessThan(fullOffset));
      await continuousDanger('partially closing');
      await t.pumpAndSettle();
      await closedWithoutHalo('settled closed');
      await t.drag(row, const Offset(-100, 0));
      await t.pumpAndSettle();
      rebuild(() => enabled = false);
      await t.pumpAndSettle();
      await closedWithoutHalo('disabled after opening');
      expect(find.text('Delete vocabulary'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  Future<void> mount(
    WidgetTester t,
    VoidCallback delete, {
    bool enabled = true,
    String label = 'Delete vocabulary',
    double scale = 1,
  }) async {
    await t.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: Center(
              child: SizedBox(
                width: 280,
                child: PikoSwipeReveal(
                  enabled: enabled,
                  label: label,
                  onDelete: delete,
                  child: const SizedBox(
                    height: 140,
                    width: 280,
                    child: Text('Vocabulary'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'touch reveals only; explicit delete, right close, Escape and hidden semantics',
    (t) async {
      var calls = 0;
      await mount(t, () => calls++);
      final semantics = t.ensureSemantics();
      expect(find.text('Delete vocabulary'), findsNothing);
      await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
      await t.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Delete vocabulary'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(calls, 1);
      await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
      await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
      await t.pumpAndSettle();
      await t.drag(find.byType(PikoSwipeReveal), const Offset(100, 0));
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
      semantics.dispose();
    },
  );
  testWidgets('vertical, diagonal and disabled swipes cannot expose deletion', (
    t,
  ) async {
    await mount(t, () => fail('gesture must not delete'));
    for (final offset in [const Offset(0, -100), const Offset(-100, -100)]) {
      await t.drag(find.byType(PikoSwipeReveal), offset);
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
    }
    await mount(t, () => fail('disabled'), enabled: false);
    await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
    await t.pumpAndSettle();
    expect(find.text('Delete vocabulary'), findsNothing);
  });
  testWidgets(
    'German 200% measured action fits narrow card with reduced motion',
    (t) async {
      await mount(t, () {}, label: 'Vokabel löschen', scale: 2);
      await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final action = t.getRect(find.byType(TextButton));
      final card = t.getRect(find.byType(PikoSwipeReveal));
      expect(action.left, greaterThanOrEqualTo(card.left));
      expect(action.right, lessThanOrEqualTo(card.right));
      expect(action.height, greaterThanOrEqualTo(44));
      expect(
        t
            .widget<TweenAnimationBuilder<double>>(
              find.byType(TweenAnimationBuilder<double>),
            )
            .duration,
        Duration.zero,
      );
    },
  );
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale 320px/200% rapid row swaps retire action focus and stale callbacks',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(320, 900);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        final semantics = t.ensureSemantics();
        final label = PikoCopy(locale).text('vocab.delete');
        var calls = 0;
        await t.pumpWidget(
          PikoApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: Center(
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final id in ['A', 'B'])
                          PikoSwipeReveal(
                            key: ValueKey('row-$id'),
                            label: label,
                            onDelete: () => calls++,
                            child: SizedBox(
                              height: 140,
                              width: 280,
                              child: Text(id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> reveal(String id) async {
          await t.drag(find.byKey(ValueKey('row-$id')), const Offset(-100, 0));
          await t.pumpAndSettle();
          expect(find.bySemanticsLabel(label), findsOneWidget);
          expect(find.widgetWithText(PikoButton, label), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(ValueKey('row-$id')),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }

        await reveal('A');
        final oldAction = t
            .widget<PikoButton>(find.widgetWithText(PikoButton, label))
            .onPressed!;
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        final oldFocus = FocusManager.instance.primaryFocus!;
        expect(oldFocus.hasFocus, isTrue);
        await reveal('B');
        expect(oldFocus.hasFocus, isFalse);
        oldAction();
        expect(calls, 0);
        for (final id in ['A', 'B', 'A', 'B']) {
          await reveal(id);
          oldAction();
          expect(calls, 0);
        }
        final active = t
            .widget<PikoButton>(find.widgetWithText(PikoButton, label))
            .onPressed!;
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.bySemanticsLabel(label), findsNothing);
        expect(find.text(label), findsNothing);
        active();
        expect(calls, 0);
        await reveal('A');
        await t.tap(find.widgetWithText(PikoButton, label));
        await t.pumpAndSettle();
        expect(calls, 1);
        expect(find.bySemanticsLabel(label), findsNothing);
        expect(t.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'gesture threshold, cancellation and mouse drag never admit a destructive action',
    (t) async {
      await mount(t, () => fail('a gesture cannot delete'));
      final row = find.byType(PikoSwipeReveal);
      await t.drag(row, const Offset(-40, 0));
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
      final touch = await t.startGesture(t.getCenter(row));
      await touch.moveBy(const Offset(-100, 0));
      await touch.cancel();
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
      await t.drag(row, const Offset(-100, 0), kind: PointerDeviceKind.mouse);
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
    },
  );

  testWidgets(
    'in-flight group handoffs snap the prior row closed; disabled and disposed owners release',
    (t) async {
      late StateSetter rebuild;
      var enabledA = true;
      var visibleA = true;
      await t.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Column(
                  children: [
                    for (final id in [if (visibleA) 'A', 'B'])
                      PikoSwipeReveal(
                        key: ValueKey('swap-$id'),
                        enabled: id != 'A' || enabledA,
                        label: 'Delete $id',
                        onDelete: () =>
                            fail('revealing/retiring rows must not delete'),
                        child: SizedBox(
                          key: ValueKey('foreground-$id'),
                          height: 100,
                          width: 280,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      final halfMotion = Duration(
        milliseconds: (pikoDesign.dimension('controls.motionFastMs') / 2)
            .round(),
      );
      Future<void> start(String id) async {
        await t.drag(find.byKey(ValueKey('swap-$id')), const Offset(-100, 0));
        await t.pump();
        await t.pump(halfMotion);
      }

      await start('A');
      for (final id in ['B', 'A', 'B', 'A']) {
        await start(id);
        final other = id == 'A' ? 'B' : 'A';
        expect(
          t.getTopLeft(find.byKey(ValueKey('foreground-$other'))),
          t.getTopLeft(find.byKey(ValueKey('swap-$other'))),
        );
        expect(find.text('Delete $other'), findsNothing);
        expect(find.byType(TextButton).evaluate().length, lessThanOrEqualTo(1));
      }
      await t.pumpAndSettle();
      expect(find.text('Delete A'), findsOneWidget);
      rebuild(() => enabledA = false);
      await t.pumpAndSettle();
      expect(find.text('Delete A'), findsNothing);
      await start('B');
      await t.pumpAndSettle();
      expect(find.text('Delete B'), findsOneWidget);
      rebuild(() {
        enabledA = true;
        visibleA = true;
      });
      await t.pump();
      await start('A');
      await t.pumpAndSettle();
      rebuild(() => visibleA = false);
      await t.pumpAndSettle();
      await start('B');
      await t.pumpAndSettle();
      expect(find.text('Delete B'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'vertical scroll remains native and disabled editor selection is unchanged',
    (t) async {
      final scroll = ScrollController();
      final text = TextEditingController(text: '학교 Schule');
      final focus = FocusNode();
      await t.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    PikoSwipeReveal(
                      label: 'Delete vocabulary',
                      onDelete: () {},
                      child: const SizedBox(height: 200, child: Text('Saved')),
                    ),
                    PikoSwipeReveal(
                      enabled: false,
                      label: 'Delete vocabulary',
                      onDelete: () {},
                      child: TextField(controller: text, focusNode: focus),
                    ),
                    const SizedBox(height: 600),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.drag(find.text('Saved'), const Offset(-70, -120));
      await t.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(find.text('Delete vocabulary'), findsNothing);
      focus.requestFocus();
      text.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
      await t.pump();
      expect(
        text.selection,
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
      expect(focus.hasFocus, isTrue);
      expect(find.text('Delete vocabulary'), findsNothing);
      await t.pumpWidget(const SizedBox());
      scroll.dispose();
      text.dispose();
      focus.dispose();
    },
  );
}
