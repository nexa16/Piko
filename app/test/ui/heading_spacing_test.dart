import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  for (final width in [392.0, 1100.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('compact heading geometry at ${width}px / ${scale}x', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const title = 'Vokabelsammlung für Alltag und Reisen';
        const subtitle = 'Koreanisch → Deutsch · 12345 Vokabeln';
        await tester.pumpWidget(
          MaterialApp(
            theme: PikoTheme.build(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: PikoPage(
                  child: PikoHeading(
                    title: title,
                    subtitle: subtitle,
                    leading: PikoButton(label: 'Zurück', onPressed: () {}),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Zurück'), findsOneWidget);
        final backBox = tester.getRect(find.byType(PikoButton));
        final titleBox = tester.getRect(find.text(title));
        final subtitleBox = tester.getRect(find.text(subtitle));
        expect(
          titleBox.top - backBox.bottom,
          pikoDesign.dimension('spacing.1') +
              pikoDesign.dimension('components.headings.titleMargin'),
        );
        expect(
          subtitleBox.top - titleBox.bottom,
          pikoDesign.dimension('components.headings.titleMargin'),
        );
        expect(
          subtitleBox.left - titleBox.left,
          pikoDesign.dimension('spacing.2'),
        );
        expect(titleBox.right, lessThanOrEqualTo(width));
        expect(subtitleBox.right, lessThanOrEqualTo(width));
      });
    }
  }

  testWidgets('title margin remains consistent when navigation is absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PikoTheme.build(),
        home: const Scaffold(
          body: PikoPage(child: PikoHeading(title: 'Settings')),
        ),
      ),
    );
    final headingBox = tester.getRect(find.byType(PikoHeading));
    final titleBox = tester.getRect(find.text('Settings'));
    final margin = pikoDesign.dimension('components.headings.titleMargin');
    expect(titleBox.top - headingBox.top, margin);
    expect(headingBox.bottom - titleBox.bottom, margin);
    expect(find.byType(PikoButton), findsNothing);
  });
}
