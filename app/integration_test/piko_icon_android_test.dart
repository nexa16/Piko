import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_icon.dart';

/// Test-only content; the production application retains its empty scaffold.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android bundles original icons and renders every outline', (
    tester,
  ) async {
    registerPikoIconLicenses();
    await tester.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final name in PikoIconName.values)
                  RepaintBoundary(key: ValueKey(name), child: PikoIcon(name)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final name in PikoIconName.values) {
      expect(await rootBundle.loadString(name.assetPath), contains('<svg'));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(ValueKey(name)),
      );
      final image = await boundary.toImage();
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var visible = 0;
      for (var i = 3; i < data.lengthInBytes; i += 4) {
        if (data.getUint8(i) > 0) visible++;
      }
      expect(visible, greaterThan(10), reason: name.fileName);
      image.dispose();
    }
    final notice = await rootBundle.loadString(
      '$pikoIconAssetDirectory/LICENSE.txt',
    );
    expect(notice, contains('ISC License'));
    expect(notice, contains('The MIT License (MIT)'));
    expect(tester.takeException(), isNull);
  });
}
