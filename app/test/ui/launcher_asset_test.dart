import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

const approvedColors = {
  0xfff9f0,
  0xb7d1f4,
  0xf2b9c5,
  0x34365b,
  0xffe08a,
  0xd6a34a,
  0x7fa6df,
  0xd97f95,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'approved 64px icon masters keep eight colors and exact foreground/background composition',
    () async {
      final images = <ui.Image>[];
      try {
        for (final name in [
          'piko-app-icon',
          'piko-app-icon-foreground',
          'piko-app-icon-background',
        ]) {
          final codec = await ui.instantiateImageCodec(
            await File('assets/brand/$name.png').readAsBytes(),
          );
          images.add((await codec.getNextFrame()).image);
          codec.dispose();
        }
        final data = [
          for (final image in images)
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
        ];
        for (final image in images) {
          expect(image.width, 64);
          expect(image.height, 64);
        }
        final palette = <int>{};
        for (var i = 0; i < data[0].lengthInBytes; i += 4) {
          final expected = data[data[1].getUint8(i + 3) == 255 ? 1 : 2];
          for (var channel = 0; channel < 4; channel++) {
            expect(
              data[0].getUint8(i + channel),
              expected.getUint8(i + channel),
            );
          }
          expect(data[0].getUint8(i + 3), 255);
          palette.add(
            (data[0].getUint8(i) << 16) |
                (data[0].getUint8(i + 1) << 8) |
                data[0].getUint8(i + 2),
          );
        }
        expect(palette.difference(approvedColors), isEmpty);
        expect(
          palette.length,
          7,
        ); // This pose uses seven of the eight approved colors.
      } finally {
        for (final image in images) {
          image.dispose();
        }
      }
    },
  );

  test(
    'all Android densities preserve crisp colors and foreground inside the adaptive safe circle',
    () async {
      for (final density in {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      }.entries) {
        for (final name in [
          'ic_launcher',
          'ic_launcher_foreground',
          'ic_launcher_background',
        ]) {
          final codec = await ui.instantiateImageCodec(
            await File(
              'android/app/src/main/res/mipmap-${density.key}/$name.png',
            ).readAsBytes(),
          );
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          try {
            final size = ((name == 'ic_launcher' ? 48 : 108) * density.value)
                .toInt();
            expect(image.width, size);
            expect(image.height, size);
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            var painted = 0;
            for (var y = 0; y < size; y++) {
              for (var x = 0; x < size; x++) {
                final i = (y * size + x) * 4,
                    alpha = data.getUint8((y * size + x) * 4 + 3);
                expect(alpha, anyOf(0, 255));
                if (alpha == 0) continue;
                painted++;
                final color =
                    (data.getUint8(i) << 16) |
                    (data.getUint8(i + 1) << 8) |
                    data.getUint8(i + 2);
                expect(approvedColors, contains(color));
                if (name == 'ic_launcher_foreground') {
                  final radius = sqrt(
                    pow((x + .5 - size / 2).abs() + .5, 2) +
                        pow((y + .5 - size / 2).abs() + .5, 2),
                  );
                  expect(
                    radius,
                    lessThanOrEqualTo(33 * density.value),
                    reason: '${density.key} clips a source pixel',
                  );
                }
              }
            }
            expect(painted, greaterThan(0));
          } finally {
            image.dispose();
          }
        }
      }
    },
  );
}
