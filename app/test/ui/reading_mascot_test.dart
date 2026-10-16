import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/components/piko_reading.dart';
import 'package:piko/ui/piko_theme.dart';

import 'collection_review_icon_test.dart' show Vocabulary, collection;

void main() {
  Future<void> mount(
    WidgetTester tester,
    Map<LearningDirection, int> counts, {
    bool enabled = true,
    String language = 'en',
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      PikoApp(
        locale: Locale(language),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: ReviewLaunch(
                collection: collection,
                factory: (_, _) async => throw StateError('Not launched'),
                vocabularyRepository: const Vocabulary(),
                beforeLaunch: () async {},
                onPendingWrites: null,
                onBusyChanged: (_) {},
                enabled: enabled,
                presentation: ReviewLaunchPresentation.collectionCard,
                dueCount: counts.values.fold<int>(0, (a, b) => a + b),
                directionCounts: counts,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('one reading pose belongs to the first available review action', (
    tester,
  ) async {
    await mount(tester, {
      LearningDirection.targetToNative: 2,
      LearningDirection.nativeToTarget: 3,
    });

    final first = find.byKey(
      const ValueKey('collection-review-targetToNative'),
    );
    final second = find.byKey(
      const ValueKey('collection-review-nativeToTarget'),
    );
    expect(find.byType(PikoReading), findsOneWidget);
    expect(
      find.descendant(of: first, matching: find.byType(PikoReading)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: second, matching: find.byType(PikoReading)),
      findsNothing,
    );
    expect(
      find.descendant(of: first, matching: find.byType(PikoIcon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: second, matching: find.byType(PikoIcon)),
      findsOneWidget,
    );

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('piko-reading')),
    );
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/brand/piko-reading.png',
    );
    expect(
      image.width,
      pikoDesign.dimension('components.collectionReview.mascotSize'),
    );
    expect(image.height, image.width);
    expect(image.fit, BoxFit.contain);
    expect(image.filterQuality, FilterQuality.none);
    expect(image.excludeFromSemantics, isTrue);
    expect(tester.widget<PikoButton>(first).onPressed, isNotNull);
  });

  testWidgets('reverse-only review uses the first visible action', (
    tester,
  ) async {
    await mount(tester, {
      LearningDirection.targetToNative: 0,
      LearningDirection.nativeToTarget: 1,
    });

    expect(
      find.byKey(const ValueKey('collection-review-targetToNative')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('collection-review-nativeToTarget')),
        matching: find.byType(PikoReading),
      ),
      findsOneWidget,
    );
  });

  testWidgets('zero available normal directions have no pose or reserved gap', (
    tester,
  ) async {
    await mount(tester, {
      LearningDirection.targetToNative: 0,
      LearningDirection.nativeToTarget: 0,
    });

    expect(find.byType(PikoReading), findsNothing);
    expect(find.byType(PikoButton), findsNothing);
    expect(find.byType(ReviewLaunch), findsOneWidget);
  });

  testWidgets('pose keeps disabled review action disabled', (tester) async {
    await mount(tester, {LearningDirection.targetToNative: 1}, enabled: false);
    expect(find.byType(PikoReading), findsOneWidget);
    expect(
      tester.widget<PikoButton>(find.byType(PikoButton)).onPressed,
      isNull,
    );
  });

  for (final language in ['en', 'de']) {
    testWidgets(
      '$language 320dp 200% keeps art, text and review icon separate',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        try {
          await mount(
            tester,
            {LearningDirection.targetToNative: 2},
            language: language,
            textScale: 2,
          );
          await tester.pumpAndSettle();

          final first = find.byKey(
            const ValueKey('collection-review-targetToNative'),
          );
          final label = language == 'en'
              ? 'FR → DE · 2 to review'
              : 'FR → DE · 2 zum Wiederholen';
          final labelFinder = find.descendant(
            of: first,
            matching: find.text(label),
          );
          final imageFinder = find.byKey(const ValueKey('piko-reading'));
          final iconFinder = find.descendant(
            of: first,
            matching: find.byType(PikoIcon),
          );
          final buttonRect = tester.getRect(first);
          final labelRect = tester.getRect(labelFinder);
          final imageRect = tester.getRect(imageFinder);
          final iconRect = tester.getRect(iconFinder);

          expect(imageRect.width, 64);
          expect(imageRect.height, 64);
          expect(buttonRect.contains(imageRect.topLeft), isTrue);
          expect(buttonRect.contains(imageRect.bottomRight), isTrue);
          expect(labelRect.right, lessThanOrEqualTo(imageRect.left));
          expect(imageRect.right, lessThanOrEqualTo(iconRect.left));
          expect(tester.getSemantics(first).label, label);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'bundled reading master retains 64px transparent source palette',
    (tester) async {
      await tester.runAsync(() async {
        final bytes = await rootBundle.load('assets/brand/piko-reading.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          expect(image.width, 64);
          expect(image.height, 64);
          final raw = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(raw, isNotNull);
          final pixels = raw!.buffer.asUint8List();
          final palette = <int>{};
          for (var i = 0; i < pixels.length; i += 4) {
            final alpha = pixels[i + 3];
            expect(alpha, anyOf(0, 255));
            if (alpha == 0) {
              palette.add(0);
            } else {
              palette.add(
                (255 << 24) |
                    (pixels[i] << 16) |
                    (pixels[i + 1] << 8) |
                    pixels[i + 2],
              );
            }
          }
          expect(palette, {
            0x00000000,
            0xff34365b,
            0xff7fa6df,
            0xffb7d1f4,
            0xffd97f95,
            0xfff2b9c5,
            0xfffff9f0,
          });
        } finally {
          image.dispose();
          codec.dispose();
        }
      });
    },
  );
}
