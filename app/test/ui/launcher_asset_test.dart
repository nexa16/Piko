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
    'prepared plain-book foreground retains exact padding, hard pixels and safe-circle bounds',
    () async {
      final codec = await ui.instantiateImageCodec(
        await File(
          'android/app/src/main/res/drawable-nodpi/piko_book_foreground.png',
        ).readAsBytes(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      try {
        expect(image.width, 1080);
        expect(image.height, 1080);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var left = 1080, top = 1080, right = 0, bottom = 0, count = 0;
        for (var y = 0; y < 1080; y++) {
          for (var x = 0; x < 1080; x++) {
            final alpha = bytes.getUint8((y * 1080 + x) * 4 + 3);
            expect(alpha, anyOf(0, 255));
            if (alpha == 0) continue;
            count++;
            left = min(left, x);
            top = min(top, y);
            right = max(right, x + 1);
            bottom = max(bottom, y + 1);
            final radius = sqrt(
              pow((x + .5 - 540).abs() + .5, 2) +
                  pow((y + .5 - 540).abs() + .5, 2),
            );
            expect(radius, lessThanOrEqualTo(330));
          }
        }
        expect([left, top, right, bottom], [264, 324, 816, 756]);
        expect(count, 364 * 24 * 24);
        final drawable = await File(
          'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
        ).readAsString();
        expect(drawable, contains('android:gravity="fill"'));
        expect(drawable, isNot(contains('inset')));
        expect(
          await File(
            'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
          ).readAsString(),
          contains('monochrome'),
        );
        for (final density in {
          'mdpi': 48,
          'hdpi': 72,
          'xhdpi': 96,
          'xxhdpi': 144,
          'xxxhdpi': 192,
        }.entries) {
          for (final name in ['ic_launcher', 'ic_launcher_round']) {
            final legacy = await ui.instantiateImageCodec(
              await File(
                'android/app/src/main/res/mipmap-${density.key}/$name.png',
              ).readAsBytes(),
            );
            final icon = (await legacy.getNextFrame()).image;
            expect(icon.width, density.value);
            expect(icon.height, density.value);
            icon.dispose();
            legacy.dispose();
          }
        }
      } finally {
        image.dispose();
      }
    },
  );
}
