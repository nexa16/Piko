import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_swipe_reveal.dart';
import 'package:piko/ui/piko_theme.dart';

const _raster = ValueKey('swipe-raster');
const _foreground = ValueKey('paint-card');

Future<void> _expectContinuousRed(WidgetTester tester) async {
  final row = tester.getRect(find.byKey(_raster));
  final foreground = tester.getRect(find.byKey(_foreground));
  final edge = foreground.right - row.left;
  expect(edge, lessThan(row.width));
  final radius = pikoDesign.dimension('radii.card');
  final samples = <Offset>[
    // The old surface interrupted this corner cutout with white/a square join.
    if (edge > radius && edge < row.width - radius)
      for (final y in [2.0, row.height - 3]) Offset(edge - 2, y),
    for (final y in [2.0, row.height - 3])
      Offset(
        (edge + 3).clamp(radius + 2, row.width - radius - 2).toDouble(),
        y,
      ),
    if (edge > radius) Offset(edge + 3, row.height / 2),
  ];
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_raster),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      final danger = pikoDesign.color('danger').toARGB32();
      for (final sample in samples) {
        final offset =
            (sample.dy.floor() * image.width + sample.dx.floor()) * 4;
        expect(
          pixels.getUint8(offset),
          closeTo((danger >> 16) & 255, 1),
          reason: 'red at $sample',
        );
        expect(
          pixels.getUint8(offset + 1),
          closeTo((danger >> 8) & 255, 1),
          reason: 'green at $sample',
        );
        expect(
          pixels.getUint8(offset + 2),
          closeTo(danger & 255, 1),
          reason: 'blue at $sample',
        );
        expect(pixels.getUint8(offset + 3), 255);
      }
    } finally {
      image.dispose();
    }
  });
}

void main() {
  for (final locale in ['en', 'de']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'UX-VOCAB-DELETE-001 $locale 320px/$scale paints continuous partial/open/closing red',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final semantics = tester.ensureSemantics();
          final label = PikoCopy(locale).text('vocab.delete');
          var calls = 0;
          await tester.pumpWidget(
            PikoApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Center(
                    child: SizedBox(
                      width: 280,
                      child: RepaintBoundary(
                        key: _raster,
                        child: PikoSwipeReveal(
                          label: label,
                          onDelete: () => calls++,
                          child: Container(
                            key: _foreground,
                            width: 280,
                            height: 140,
                            decoration: BoxDecoration(
                              color: pikoDesign.color('surface'),
                              borderRadius: BorderRadius.circular(
                                pikoDesign.dimension('radii.card'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final row = find.byType(PikoSwipeReveal);
          final halfMotion = Duration(
            milliseconds: (pikoDesign.dimension('controls.motionFastMs') / 2)
                .round(),
          );
          await tester.drag(row, const Offset(-100, 0));
          await tester.pump();
          await tester.pump(halfMotion);
          expect(find.text(label), findsNothing);
          expect(find.bySemanticsLabel(label), findsNothing);
          await _expectContinuousRed(tester);
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel(label), findsOneWidget);
          final button = find.widgetWithText(PikoButton, label);
          final action = tester.getRect(button);
          final card = tester.getRect(find.byKey(_foreground));
          final outer = tester.getRect(row);
          expect(action.left, greaterThanOrEqualTo(card.right - .01));
          expect(action.right, lessThanOrEqualTo(outer.right + .01));
          expect(action.width, greaterThanOrEqualTo(44));
          expect(action.height, greaterThanOrEqualTo(44));
          final text = tester.getRect(find.text(label));
          expect(text.left, greaterThanOrEqualTo(action.left));
          expect(text.right, lessThanOrEqualTo(action.right));
          final renderedButton = tester.widget<TextButton>(
            find.descendant(of: button, matching: find.byType(TextButton)),
          );
          expect(
            renderedButton.style!.foregroundColor!.resolve({}),
            pikoDesign.color('onDanger'),
          );
          expect(
            renderedButton.style!.backgroundColor!.resolve({}),
            pikoDesign.color('danger'),
          );
          await _expectContinuousRed(tester);
          await tester.drag(row, const Offset(100, 0));
          await tester.pump();
          expect(find.text(label), findsNothing);
          expect(find.bySemanticsLabel(label), findsNothing);
          await tester.pump(halfMotion);
          await _expectContinuousRed(tester);
          await tester.pumpAndSettle();
          expect(tester.getRect(find.byKey(_foreground)), outer);
          expect(calls, 0);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }
}
