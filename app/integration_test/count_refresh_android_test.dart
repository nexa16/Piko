import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/features/collections/collection_compact_action.dart';
import 'package:piko/features/learning/learning_direction_choice.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/speed/speed_launch.dart';
import '../test/ui/collection_compact_header_test.dart' as header;

/// Run the production header/launch compositions on Android with deterministic
/// read barriers and isolated in-memory fixtures. No normal app data is opened.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Finder key(String id) => find.byKey(ValueKey(id));
  String? compactCount(WidgetTester tester, String kind) => tester
      .widget<CollectionCompactAction>(
        find.byKey(ValueKey('collection-$kind-compact'), skipOffstage: false),
      )
      .count;

  testWidgets(
    'native delayed refresh and read failure retain controls and geometry',
    (tester) async {
      final h = header.HeaderHarness();
      await h.mount(tester, nativeView: true);
      final action = key('collection-review-targetToNative');
      expect(action.hitTestable(), findsOneWidget);
      final rect = tester.getRect(action);
      final reviewOwner = tester.state(find.byType(ReviewLaunch));
      final speedOwner = tester.state(find.byType(SpeedLaunch));
      final gate = Completer<CollectionQuerySnapshot>();
      h.service.gate = gate;
      h.binding.refresh();
      await tester.pump();
      expect(tester.getRect(action), rect);
      expect(tester.state(find.byType(ReviewLaunch)), same(reviewOwner));
      expect(tester.state(find.byType(SpeedLaunch)), same(speedOwner));
      expect(compactCount(tester, 'review'), '19');
      expect(compactCount(tester, 'speed'), '7');
      expect(find.text('Updating counts · last known values'), findsWidgets);
      gate.completeError(StateError('synthetic local read failure'));
      await tester.pumpAndSettle();
      expect(tester.getRect(action), rect);
      expect(compactCount(tester, 'review'), '19');
      expect(
        find.text('Counts could not update · last known values'),
        findsWidgets,
      );
      expect(h.reviews, isEmpty);
      expect(h.speed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('native scope change rejects an obsolete delayed completion', (
    tester,
  ) async {
    final h = header.HeaderHarness();
    await h.mount(tester, nativeView: true);
    final obsolete = Completer<CollectionQuerySnapshot>();
    h.service.gate = obsolete;
    h.binding.refresh();
    await tester.pump();
    final current = Completer<CollectionQuerySnapshot>();
    h.service.gate = current;
    h.scope.setSearch('different');
    await tester.pump();
    expect(compactCount(tester, 'review'), '…');
    obsolete.complete(header.headerProjection(forward: 99));
    await tester.pump();
    expect(compactCount(tester, 'review'), '…');
    current.complete(
      header.headerProjection(
        forward: 2,
        reverse: 1,
        speedForward: 1,
        speedReverse: 0,
      ),
    );
    await tester.pumpAndSettle();
    expect(compactCount(tester, 'review'), '3');
    expect(compactCount(tester, 'speed'), '1');
    expect(h.reviews, isEmpty);
    expect(h.speed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native rapid refresh taps recheck once and never launch authoritative zero',
    (tester) async {
      final h = header.HeaderHarness();
      await h.mount(tester, nativeView: true);
      final gate = Completer<CollectionQuerySnapshot>();
      h.service.gate = gate;
      h.binding.refresh();
      await tester.pump();
      final action = key('collection-review-targetToNative');
      expect(action.hitTestable(), findsOneWidget);
      final before = h.service.reads;
      await tester.tap(action);
      await tester.pump();
      await tester.tap(action);
      await tester.pump();
      expect(h.service.reads, before + 1);
      expect(h.reviews, isEmpty);
      gate.complete(
        header.headerProjection(
          forward: 0,
          reverse: 0,
          speedForward: 0,
          speedReverse: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(compactCount(tester, 'review'), '0');
      expect(h.reviews, isEmpty);
      expect(h.speed, isEmpty);
      expect(find.byType(LearningDirectionChoice), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
