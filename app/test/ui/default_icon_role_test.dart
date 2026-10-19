import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/statistics/statistics_widgets.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  testWidgets(
    'F05 ordinary and warning icons inherit ink; controls keep contextual foreground',
    (tester) async {
      await tester.pumpWidget(
        PikoCopyScope(
          copy: PikoCopy('en'),
          child: MaterialApp(
            theme: PikoTheme.build(),
            home: Scaffold(
              body: Column(
                children: [
                  const PikoIcon(PikoIconName.chevronRight),
                  const StatisticsReminder(),
                  PikoButton(
                    label: 'Primary',
                    variant: PikoButtonVariant.reviewPrimary,
                    icon: const PikoIcon(PikoIconName.plus),
                    onPressed: () {},
                  ),
                  PikoButton(
                    label: 'Danger',
                    variant: PikoButtonVariant.dangerFilled,
                    icon: const PikoIcon(PikoIconName.trash),
                    onPressed: () {},
                  ),
                  PikoButton(
                    label: 'Disabled',
                    variant: PikoButtonVariant.reviewPrimary,
                    icon: const PikoIcon(PikoIconName.plus),
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ColorFilter filter(Finder parent) => tester
          .widget<SvgPicture>(
            find.descendant(of: parent, matching: find.byType(SvgPicture)),
          )
          .colorFilter!;
      expect(
        filter(find.byType(PikoIcon).first),
        const ColorFilter.mode(Color(0xff34365b), BlendMode.srcIn),
      );
      expect(
        filter(find.byType(StatisticsReminder)),
        const ColorFilter.mode(Color(0xff34365b), BlendMode.srcIn),
      );
      for (final label in ['Primary', 'Danger', 'Disabled']) {
        final b = find.widgetWithText(PikoButton, label);
        expect(
          filter(b),
          ColorFilter.mode(
            label == 'Disabled'
                ? pikoDesign
                      .color('onPrimary')
                      .withValues(
                        alpha: pikoDesign.dimension('states.disabledOpacity'),
                      )
                : pikoDesign.color(
                    label == 'Danger' ? 'onDanger' : 'onPrimary',
                  ),
            BlendMode.srcIn,
          ),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
