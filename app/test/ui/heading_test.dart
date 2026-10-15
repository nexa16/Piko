import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'package:piko/ui/piko_theme.dart';

Widget host(Widget child) => MaterialApp(
  theme: PikoTheme.build(),
  home: Scaffold(body: PikoPage(child: child)),
);

void main() {
  testWidgets('default page title is a single level-one semantic heading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const PikoHeading(title: 'Settings')));
    expect(find.text('Settings'), findsOneWidget);
    final node = tester.getSemantics(find.text('Settings'));
    expect(node.getSemanticsData().headingLevel, 1);
    expect(find.byType(Text), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'meaningful context is readable without becoming another heading',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          Column(
            children: [
              const PikoHeading(
                title: 'Korean',
                subtitle: 'KO → DE · 12 entries',
              ),
              const Text('KO → DE'),
              const Text('3 / 12'),
              Semantics(
                header: true,
                headingLevel: 2,
                child: const Text('Vocabulary'),
              ),
              const Text('Enter both language values.'),
            ],
          ),
        ),
      );
      expect(
        tester
            .getSemantics(find.text('Korean'))
            .getSemanticsData()
            .headingLevel,
        1,
      );
      expect(
        tester
            .getSemantics(find.text('KO → DE · 12 entries'))
            .getSemanticsData()
            .headingLevel,
        0,
      );
      expect(
        tester
            .getSemantics(find.text('KO → DE'))
            .getSemanticsData()
            .headingLevel,
        0,
      );
      expect(
        tester
            .getSemantics(find.text('3 / 12'))
            .getSemanticsData()
            .headingLevel,
        0,
      );
      expect(
        tester
            .getSemantics(find.text('Vocabulary'))
            .getSemanticsData()
            .headingLevel,
        2,
      );
      expect(find.text('Enter both language values.'), findsOneWidget);
      final subtitle = tester.widget<Text>(find.text('KO → DE · 12 entries'));
      expect(subtitle.style!.color, pikoDesign.color('muted'));
      expect(
        subtitle.style!.fontSize,
        pikoDesign.dimension('typography.small'),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'long German title, context and actions wrap at doubled text size',
    (tester) async {
      tester.view.physicalSize = const Size(392, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final copy = const PikoCopy('de');
      await tester.pumpWidget(
        MaterialApp(
          theme: PikoTheme.build(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: PikoPage(
                child: PikoHeading(
                  title: 'Koreanische Vokabelsammlung für Alltag und Reisen',
                  subtitle:
                      'Koreanisch → Deutsch · ${copy.text('common.entries', {'count': 12345})}',
                  leading: PikoButton(
                    label: copy.text('common.back'),
                    onPressed: () {},
                  ),
                  actions: [
                    PikoButton(
                      label: copy.text('collection.delete'),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
      }
      expect(
        tester
            .getSize(
              find.text('Koreanische Vokabelsammlung für Alltag und Reisen'),
            )
            .height,
        greaterThan(pikoDesign.dimension('typography.title') * 2),
      );
    },
  );
}
