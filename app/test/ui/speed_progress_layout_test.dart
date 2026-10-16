import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/shared/catalogs.dart';

import 'speed_session_route_test.dart' show SpeedHarness;

void main() {
  for (final language in ['en', 'de']) {
    testWidgets('$language Speed progress stacks at 320dp and 200% text', (
      tester,
    ) async {
      final harness = SpeedHarness(language: language);
      await harness.mount(tester, scale: 2);

      final direction = find.byKey(const ValueKey('speed-fixed-direction'));
      final progress = find.byKey(const ValueKey('speed-progress-count'));
      final bar = find.byKey(const ValueKey('speed-progress'));
      final expected = PikoCopy(
        language,
      ).text('learn.speedProgress', {'completed': 0, 'total': 2});
      expect(tester.widget<Text>(progress).data, expected);
      expect(
        tester.getRect(progress).top,
        greaterThanOrEqualTo(tester.getRect(direction).bottom),
      );
      expect(
        tester.getRect(bar).top,
        greaterThan(tester.getRect(progress).bottom),
      );
      expect(tester.getRect(progress).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$language Speed progress stays inline when width permits', (
      tester,
    ) async {
      final harness = SpeedHarness(language: language);
      await harness.mount(tester);
      tester.view.physicalSize = const Size(800, 900);
      await tester.pumpAndSettle();

      final direction = tester.getRect(
        find.byKey(const ValueKey('speed-fixed-direction')),
      );
      final progress = tester.getRect(
        find.byKey(const ValueKey('speed-progress-count')),
      );
      expect(progress.top, closeTo(direction.top, 0.1));
      expect(progress.left, greaterThan(direction.right));
      expect(tester.takeException(), isNull);
    });
  }
}
