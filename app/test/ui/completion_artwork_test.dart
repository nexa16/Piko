import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/speed/speed_completion_notice.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_reading.dart';
import 'collection_speed_launch_test.dart' show DetailSpeedHarness;

Finder key(String value) => find.byKey(ValueKey(value));
Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Speed celebrates only committed completion, overrides reading and restores it on X; next launch clears notice',
    (tester) async {
      final h = DetailSpeedHarness();
      await h.mount(tester);
      expect(find.byType(PikoReading), findsOneWidget);
      await h.setup(tester);
      await tester.enterText(key('speed-pool-size'), '1');
      await h.start(tester);
      expect(key('piko-celebration'), findsNothing);
      h.completionGate = Completer<void>();
      await tap(tester, key('review-reveal-target'));
      await tap(tester, key('speed-grade-correct'));
      expect(key('piko-celebration'), findsNothing);
      expect(find.byType(SpeedSessionRoute), findsOneWidget);
      h.completionGate!.complete();
      await tester.pumpAndSettle();
      expect(key('piko-celebration'), findsOneWidget);
      expect(find.byType(PikoReading), findsNothing);
      expect(find.text('Speed complete · 1 word'), findsOneWidget);
      await tester.pump(const Duration(minutes: 2));
      expect(key('piko-celebration'), findsOneWidget);
      final dismiss = find.byWidgetPredicate(
        (w) =>
            w is PikoIconButton &&
            w.semanticLabel == 'Dismiss completion message',
      );
      final expandedDismiss = tester.widget<PikoIconButton>(dismiss).focusNode!;
      expandedDismiss.requestFocus();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(key('collection-review-compact').hitTestable(), findsOneWidget);
      expect(key('speed-completion-notice'), findsOneWidget);
      expect(find.text('Speed complete · 1 word'), findsOneWidget);
      expect(key('piko-celebration'), findsNothing);
      expect(
        tester.widget<PikoIconButton>(dismiss).focusNode!.hasFocus,
        isTrue,
      );
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(expandedDismiss.hasFocus, isTrue);
      expect(key('piko-celebration'), findsOneWidget);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      expect(key('speed-completion-notice'), findsNothing);
      expect(key('piko-celebration'), findsNothing);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.byType(PikoReading), findsOneWidget);
      await h.setup(tester);
      await h.start(tester);
      await tap(tester, key('review-reveal-target'));
      await tap(tester, key('speed-grade-correct'));
      expect(key('piko-celebration'), findsOneWidget);
      await h.setup(tester);
      expect(key('speed-completion-notice'), findsNothing);
      expect(key('piko-celebration'), findsNothing);
    },
  );
  testWidgets('failed completion and exit never celebrate', (tester) async {
    final h = DetailSpeedHarness()..failCompletion = true;
    await h.mount(tester);
    await h.setup(tester);
    await h.start(tester);
    await tap(tester, key('review-reveal-target'));
    await tap(tester, key('speed-grade-correct'));
    expect(key('piko-celebration'), findsNothing);
    expect(find.byType(SpeedSessionRoute), findsOneWidget);
    await tap(tester, key('speed-exit'));
    expect(key('speed-completion-notice'), findsNothing);
    expect(key('piko-celebration'), findsNothing);
    expect(find.byType(PikoReading), findsOneWidget);
  });
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language completion notice 320/200 keeps top-right dismiss and decorative single pose; compact omits art',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        try {
          final copy = PikoCopy(language);
          Future<void> mount(bool art) => tester.pumpWidget(
            PikoApp(
              locale: Locale(language),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SpeedCompletionNotice(
                    count: 123,
                    onDismiss: () {},
                    showArtwork: art,
                  ),
                ),
              ),
            ),
          );
          await mount(true);
          await tester.pumpAndSettle();
          final button = find.byWidgetPredicate(
            (w) =>
                w is PikoIconButton &&
                w.semanticLabel == copy.text('speed.dismissCompletion'),
          );
          final notice = key('speed-completion-notice');
          expect(tester.getTopLeft(button).dy, tester.getTopLeft(notice).dy);
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(
            tester.widget<Image>(key('piko-celebration')).excludeFromSemantics,
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await mount(false);
          await tester.pumpAndSettle();
          expect(key('piko-celebration'), findsNothing);
          expect(
            find.text(copy.text('speed.completionNotice', {'count': 123})),
            findsOneWidget,
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
