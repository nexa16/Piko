import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/ui/piko_theme.dart';
import 'collection_compact_header_test.dart'
    show HeaderHarness, headerProjection, key;
import 'collection_query_detail_test.dart' show projection;

void expectPose(String? pose) {
  for (final name in ['reading', 'sleeping', 'celebration']) {
    expect(key('piko-$name'), name == pose ? findsOneWidget : findsNothing);
  }
}

void main() {
  testWidgets(
    'context uses the resolved scope and independent learning modes',
    (tester) async {
      final h = HeaderHarness();
      await h.mount(tester);
      expectPose('reading');
      for (final scenario in [
        (headerProjection(speedForward: 0, speedReverse: 0), 'reading'),
        (headerProjection(forward: 0, reverse: 0), null),
        (headerProjection(forward: 0, reverse: 2), 'reading'),
        (
          headerProjection(
            forward: 0,
            reverse: 0,
            speedForward: 0,
            speedReverse: 0,
          ),
          'sleeping',
        ),
        (
          headerProjection(
            forward: 0,
            reverse: 0,
            speedForward: 0,
            speedReverse: 0,
            pending: true,
          ),
          null,
        ),
        (projection(all: const [], visible: const []), null),
        (projection(visible: const []), null),
      ]) {
        h.service.value = scenario.$1;
        await h.refresh(tester);
        expectPose(scenario.$2);
        expect(tester.takeException(), isNull);
      }
      expect(h.reviews, isEmpty);
      expect(h.speed, isEmpty);
      expect(h.vocabulary.writes, isEmpty);
    },
  );

  testWidgets('loading and failed refresh hide the previous no-work pose', (
    tester,
  ) async {
    final h = HeaderHarness();
    h.service.value = headerProjection(
      forward: 0,
      reverse: 0,
      speedForward: 0,
      speedReverse: 0,
    );
    await h.mount(tester);
    expectPose('sleeping');
    final gate = h.service.gate = Completer<CollectionQuerySnapshot>();
    h.binding.refresh();
    await tester.pump();
    expectPose(null);
    gate.completeError(StateError('Synthetic query failure'));
    await tester.pumpAndSettle();
    expectPose(null);
    h.service.gate = null;
    await h.refresh(tester);
    expectPose('sleeping');
  });

  for (final locale in ['en', 'de']) {
    testWidgets('$locale sleeping at 320dp/200% is decorative and unpinned', (
      tester,
    ) async {
      final h = HeaderHarness();
      h.service.value = headerProjection(
        forward: 0,
        reverse: 0,
        speedForward: 0,
        speedReverse: 0,
      );
      await h.mount(tester, language: locale, scale: 2);
      final semantics = tester.ensureSemantics();
      try {
        expectPose('sleeping');
        final image = tester.widget<Image>(key('piko-sleeping'));
        expect(image.excludeFromSemantics, isTrue);
        expect(image.filterQuality, FilterQuality.none);
        expect(
          image.width,
          pikoDesign.dimension('components.collectionReview.mascotSize'),
        );
        expect(tester.getSize(key('piko-sleeping')), const Size(64, 64));
        expect(
          tester.getRect(key('piko-sleeping')).right,
          lessThanOrEqualTo(320),
        );
        await h.collapse(tester);
        expectPose(null);
        h.position(tester).jumpTo(0);
        await tester.pumpAndSettle();
        expectPose('sleeping');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
