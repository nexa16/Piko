import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all pinned SVGs load, parse, and rasterize visible strokes', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final svgAssets = manifest.listAssets().where(
      (p) => p.startsWith('$pikoIconAssetDirectory/') && p.endsWith('.svg'),
    );
    expect(
      svgAssets.toSet(),
      PikoIconName.values.map((n) => n.assetPath).toSet(),
    );
    for (final name in PikoIconName.values) {
      final source = await rootBundle.loadString(name.assetPath);
      expect(source, contains('stroke-width="2"'));
      final picture = await vg.loadPicture(
        SvgAssetLoader(name.assetPath),
        null,
      );
      expect(picture.size, const Size(24, 24));
      final image = await picture.picture.toImage(24, 24);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      var visible = 0;
      for (var i = 3; i < bytes.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) > 0) visible++;
      }
      expect(visible, greaterThan(10), reason: name.fileName);
      image.dispose();
      picture.picture.dispose();
    }
  });

  test('full upstream notice is bundled and registered once', () async {
    registerPikoIconLicenses();
    registerPikoIconLicenses();
    final entries = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Lucide / Feather icons'))
        .toList();
    expect(entries, hasLength(1));
    final notice = entries.single.paragraphs.map((p) => p.text).join('\n');
    expect(notice, contains('ISC License'));
    expect(notice, contains('The MIT License (MIT)'));
    expect(notice, contains('Cole Bemis'));
  });

  testWidgets(
    'canonical size and inherited color reach actual rendered pixels',
    (tester) async {
      const key = ValueKey('raster');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: Color(0xff1234ab), size: 99),
              child: RepaintBoundary(
                key: key,
                child: PikoIcon(PikoIconName.plus),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(PikoIcon)),
        Size.square(pikoDesign.dimension('components.icons.size')),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!;
        var colored = 0;
        for (var i = 0; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i + 3) > 20 &&
              (bytes.getUint8(i) - 0x12).abs() <= 2 &&
              (bytes.getUint8(i + 1) - 0x34).abs() <= 2 &&
              (bytes.getUint8(i + 2) - 0xab).abs() <= 2) {
            colored++;
          }
        }
        expect(colored, greaterThan(10));
        image.dispose();
      });
    },
  );

  testWidgets('fallback ink, decorative default and optional labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IconTheme(
          data: IconThemeData(),
          child: Column(
            children: [
              PikoIcon(PikoIconName.x),
              PikoIcon(PikoIconName.bookOpen, semanticLabel: 'Reveal cue'),
            ],
          ),
        ),
      ),
    );
    final icons = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(
      icons.first.colorFilter,
      ColorFilter.mode(pikoDesign.color('ink'), BlendMode.srcIn),
    );
    expect(icons.first.excludeFromSemantics, isTrue);
    expect(find.bySemanticsLabel('Reveal cue'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('action name and activation belong to the enclosing control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var activated = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PikoTheme.build(),
        home: Scaffold(
          body: PikoIconButton(
            icon: const PikoIcon(PikoIconName.x),
            semanticLabel: 'Close dialog',
            onPressed: () => activated = true,
          ),
        ),
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('Close dialog'));
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, ui.SemanticsAction.tap);
    expect(activated, isTrue);
    semantics.dispose();
  });
}
