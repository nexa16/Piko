import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/category_tag_roles.dart';
import 'package:piko/ui/components/piko_category_tag.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  testWidgets(
    'CAT-COLOR-001 all twelve accepted backgrounds use navy with readable contrast and growing labels',
    (tester) async {
      const expected = [
        0xfff2e2b5,
        0xffd2dcf3,
        0xfff3dfe7,
        0xffcfdfcc,
        0xfff8e2cf,
        0xffe8e1f4,
        0xffe3ebc8,
        0xffe8effa,
        0xffe7ddca,
        0xffcbe8e5,
        0xffebd3eb,
        0xffddeee5,
      ];
      double luminance(Color c) {
        double linear(double x) => x <= .04045
            ? x / 12.92
            : math.pow((x + .055) / 1.055, 2.4).toDouble();
        return .2126 * linear(c.r) + .7152 * linear(c.g) + .0722 * linear(c.b);
      }

      for (var i = 0; i < 12; i++) {
        final role = categoryTagRoles[i];
        final bg = pikoDesign.color(role);
        expect(bg.toARGB32(), expected[i]);
        expect(
          (luminance(bg) + .05) / (luminance(const Color(0xff34365b)) + .05),
          greaterThan(4.5),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: PikoTheme.build(),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SizedBox(
                  width: 280,
                  child: PikoCategoryTag(
                    group: CategoryDimensionRecord(
                      id: 'group',
                      collectionId: 'owner',
                      name: 'Gruppe',
                      mode: CategoryMode.multiple,
                      position: i,
                      tagColorRole: role,
                    ),
                    label: 'Lange Kategoriebezeichnung mit Umlauten äöü',
                  ),
                ),
              ),
            ),
          ),
        );
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(PikoCategoryTag),
            matching: find.byType(Container),
          ),
        );
        expect((container.decoration! as BoxDecoration).color, bg);
        expect(
          tester
              .widget<Text>(
                find.text('Lange Kategoriebezeichnung mit Umlauten äöü'),
              )
              .style!
              .color,
          const Color(0xff34365b),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
