import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  testWidgets(
    'semantic learning action pairs use canonical palette roles and disabled opacity',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PikoTheme.build(),
          home: Scaffold(
            body: Column(
              children: [
                for (final variant in [
                  PikoButtonVariant.tint,
                  PikoButtonVariant.reviewPrimary,
                  PikoButtonVariant.reviewSecondary,
                ])
                  PikoButton(
                    label: variant.name,
                    variant: variant,
                    onPressed: () {},
                  ),
              ],
            ),
          ),
        ),
      );
      final pairs = {
        PikoButtonVariant.tint: ['tint', 'primary'],
        PikoButtonVariant.reviewPrimary: ['primary', 'onPrimary'],
        PikoButtonVariant.reviewSecondary: [
          'reviewSecondary',
          'onReviewSecondary',
        ],
      };
      for (final entry in pairs.entries) {
        final button = tester.widget<TextButton>(
          find.descendant(
            of: find.widgetWithText(PikoButton, entry.key.name),
            matching: find.byType(TextButton),
          ),
        );
        final style = button.style!;
        expect(
          style.backgroundColor!.resolve({}),
          pikoDesign.color(entry.value[0]),
        );
        expect(
          style.foregroundColor!.resolve({}),
          pikoDesign.color(entry.value[1]),
        );
        expect(
          style.backgroundColor!.resolve({WidgetState.disabled})!.a,
          closeTo(pikoDesign.dimension('states.disabledOpacity'), 0.01),
        );
        expect(
          tester
              .getSize(find.widgetWithText(TextButton, entry.key.name))
              .height,
          greaterThanOrEqualTo(44),
        );
      }
    },
  );
}
