import 'package:flutter/material.dart';
import 'dart:ui' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/piko_theme.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'package:piko/ui/components/piko_page.dart';

Widget host(Widget child, {bool reduced = false, double scale = 1}) =>
    MaterialApp(
      theme: PikoTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets(
    'soft buttons and semantic grading preserve accepted colors and radius',
    (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              PikoButton(label: 'Review', onPressed: () {}),
              PikoButton(
                label: 'Incorrect',
                variant: PikoButtonVariant.gradeIncorrect,
                onPressed: () {},
              ),
              PikoButton(
                label: 'Correct',
                variant: PikoButtonVariant.gradeCorrect,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      final buttons = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .toList();
      expect(
        buttons[0].style!.backgroundColor!.resolve({}),
        pikoDesign.color('tint'),
      );
      expect(
        buttons[1].style!.backgroundColor!.resolve({}),
        pikoDesign.color('danger'),
      );
      expect(
        buttons[2].style!.backgroundColor!.resolve({}),
        pikoDesign.color('success'),
      );
      final shape =
          buttons[0].style!.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(24));
    },
  );

  testWidgets(
    'disabled actions do not run; keyboard focus has visible treatment',
    (tester) async {
      final oldStrategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = oldStrategy);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              const PikoButton(label: 'Disabled', onPressed: null),
              PikoButton(label: 'Enabled', onPressed: () {}, focusNode: focus),
            ],
          ),
        ),
      );
      final disabled = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Disabled'),
      );
      expect(disabled.onPressed, isNull);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      final enabled = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Enabled'),
      );
      expect(
        enabled.style!.side!.resolve({WidgetState.focused})!.color,
        pikoDesign.color('primary'),
      );
      expect(enabled.style!.side!.resolve({WidgetState.focused})!.width, 3);
    },
  );

  testWidgets(
    'narrow layout and long German labels support doubled text size',
    (tester) async {
      tester.view.physicalSize = const Size(392, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          PikoPage(
            child: Column(
              children: [
                PikoHeading(
                  title: 'Vokabelsammlung bearbeiten',
                  actions: [
                    PikoButton(label: 'Änderungen verwerfen', onPressed: () {}),
                  ],
                ),
                PikoCard(
                  child: Column(
                    children: [
                      PikoTextField(
                        label: 'Übersetzung in die Muttersprache',
                        error: const PikoCopy(
                          'de',
                        ).text('vocab.inlineDuplicate'),
                        controller: controller,
                      ),
                      PikoDropdown<String>(
                        label: 'Bevorzugte Abfragerichtung',
                        value: 'de',
                        items: const [
                          DropdownMenuItem(
                            value: 'de',
                            child: Text('Deutsch nach Koreanisch'),
                          ),
                        ],
                        onChanged: (_) {},
                      ),
                      PikoButton(
                        label: 'Vorherige Bewertung korrigieren',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          scale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'icon controls are labeled and reduced motion removes animation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var activated = false;
      await tester.pumpWidget(
        host(
          PikoIconButton(
            icon: const Icon(Icons.close),
            semanticLabel: 'Close dialog',
            onPressed: () {
              activated = true;
            },
          ),
          reduced: true,
        ),
      );
      expect(find.bySemanticsLabel('Close dialog'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Close dialog'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      expect(activated, isTrue);
      expect(
        tester.getCenter(find.byType(Icon)).dx,
        tester.getCenter(find.byType(TextButton)).dx,
      );
      expect(
        tester
            .widget<TextButton>(find.byType(TextButton))
            .style!
            .animationDuration,
        Duration.zero,
      );
      semantics.dispose();
    },
  );
}
