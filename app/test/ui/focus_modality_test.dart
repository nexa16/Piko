import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  testWidgets(
    'touch focus stays quiet; keyboard focus is visible and updates live',
    (tester) async {
      final manager = FocusManager.instance;
      final strategy = manager.highlightStrategy;
      addTearDown(() => manager.highlightStrategy = strategy);
      manager.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PikoButton(label: 'Action', onPressed: () {}),
                const PikoCard(focused: true, child: Text('Card')),
              ],
            ),
          ),
        ),
      );
      BorderSide side() => tester
          .widget<TextButton>(find.byType(TextButton))
          .style!
          .side!
          .resolve({WidgetState.focused})!;
      expect(side().color, Colors.transparent);
      final card = find
          .descendant(
            of: find.byType(PikoCard),
            matching: find.byType(Container),
          )
          .last;
      expect(
        (tester.widget<Container>(card).decoration! as BoxDecoration)
            .border!
            .top
            .width,
        1,
      );
      manager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(side().color, pikoDesign.color('primary'));
      expect(side().width, 3);
      expect(
        (tester.widget<Container>(card).decoration! as BoxDecoration)
            .border!
            .top
            .width,
        3,
      );
      manager.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      await tester.pump();
      expect(side().color, Colors.transparent);
    },
  );

  testWidgets('shared field forwards IME Next and has subtle active border', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PikoTextField(
            label: 'First field',
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      ),
    );
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textInputAction, TextInputAction.next);
    expect(
      (field.decoration!.focusedBorder! as OutlineInputBorder).borderSide.width,
      1,
    );
    await tester.enterText(find.byType(TextField), 'word');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    expect(submitted, 'word');
  });

  testWidgets('semantic filled actions use their own tested foreground pair', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PikoButton(
                label: 'Delete',
                variant: PikoButtonVariant.dangerFilled,
                onPressed: () {},
              ),
              PikoButton(
                label: 'Correct',
                variant: PikoButtonVariant.gradeCorrect,
                onPressed: () {},
              ),
              PikoButton(
                label: 'Cancel',
                variant: PikoButtonVariant.neutral,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final buttons = tester
        .widgetList<TextButton>(find.byType(TextButton))
        .toList();
    expect(
      buttons[0].style!.backgroundColor!.resolve({}),
      pikoDesign.color('danger'),
    );
    expect(
      buttons[0].style!.foregroundColor!.resolve({}),
      pikoDesign.color('onDanger'),
    );
    expect(
      buttons[1].style!.foregroundColor!.resolve({}),
      pikoDesign.color('onSuccess'),
    );
    expect(
      buttons[2].style!.foregroundColor!.resolve({}),
      pikoDesign.color('muted'),
    );
  });
}
