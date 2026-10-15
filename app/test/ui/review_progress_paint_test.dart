import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/learning_session_progress.dart';
import 'package:piko/features/learning/review_progress.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  for (final language in ['en', 'de']) {
    for (var completed = 0; completed <= 2; completed++) {
      testWidgets('UX-CARD-012 $language paints $completed/2 at nonzero height', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        const members = {
          (itemId: 1, generation: 0),
          (itemId: 2, generation: 0),
        };
        const rasterKey = ValueKey('progress-raster');
        final progress = LearningSessionProgress(
          members: members,
          completed: members.take(completed).toSet(),
          firstTry: members.take(completed).toSet(),
        );
        await tester.pumpWidget(
          PikoCopyScope(
            copy: PikoCopy(language),
            child: MaterialApp(
              theme: PikoTheme.build(),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 900),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 280,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RepaintBoundary(
                            key: rasterKey,
                            child: ReviewProgress(
                              direction: 'KO → DE',
                              progress: progress,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final track = tester.getRect(find.byKey(const ValueKey('review-progress')));
        final fill = tester.getRect(find.byKey(const ValueKey('review-progress-fill')));
        expect(track.height, pikoDesign.dimension('components.progress.height'));
        expect(track.height, greaterThan(0));
        expect(fill.height, track.height);
        expect(fill.width, closeTo(track.width * completed / 2, .01));
        final origin = tester.getTopLeft(find.byKey(rasterKey));
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(rasterKey));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
            for (final fraction in [.25, .75]) {
              final expected = pikoDesign.color(
                fraction < completed / 2 ? 'ink' : 'tint',
              ).toARGB32();
              final x = (track.left - origin.dx + track.width * fraction).floor();
              for (final heightFraction in [.25, .5, .75]) {
                final y = (track.top - origin.dy + track.height * heightFraction).floor();
                final offset = (y * image.width + x) * 4;
                expect(pixels.getUint8(offset), closeTo((expected >> 16) & 255, 1));
                expect(pixels.getUint8(offset + 1), closeTo((expected >> 8) & 255, 1));
                expect(pixels.getUint8(offset + 2), closeTo(expected & 255, 1));
                expect(pixels.getUint8(offset + 3), 255);
              }
            }
          } finally {
            image.dispose();
          }
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
