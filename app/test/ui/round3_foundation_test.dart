import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'package:piko/ui/piko_theme.dart';

void main() {
  test('Material roles use the accepted palette without generated tones', () {
    final scheme = PikoTheme.build().colorScheme;
    final permitted = <Color>{
      for (final role in [
        'primary',
        'tint',
        'bg',
        'surface',
        'ink',
        'muted',
        'gold',
        'danger',
        'success',
      ])
        pikoDesign.color(role),
      PikoTheme.border,
    };
    final roles = <Color>[
      scheme.primary,
      scheme.onPrimary,
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      scheme.primaryFixed,
      scheme.primaryFixedDim,
      scheme.onPrimaryFixed,
      scheme.onPrimaryFixedVariant,
      scheme.secondary,
      scheme.onSecondary,
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
      scheme.secondaryFixed,
      scheme.secondaryFixedDim,
      scheme.onSecondaryFixed,
      scheme.onSecondaryFixedVariant,
      scheme.tertiary,
      scheme.onTertiary,
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      scheme.tertiaryFixed,
      scheme.tertiaryFixedDim,
      scheme.onTertiaryFixed,
      scheme.onTertiaryFixedVariant,
      scheme.surface,
      scheme.onSurface,
      scheme.surfaceDim,
      scheme.surfaceBright,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
      scheme.outline,
      scheme.outlineVariant,
      scheme.shadow,
      scheme.scrim,
      scheme.inverseSurface,
      scheme.onInverseSurface,
      scheme.inversePrimary,
      scheme.surfaceTint,
      scheme.error,
      scheme.onError,
      scheme.errorContainer,
      scheme.onErrorContainer,
    ];
    expect(roles.every(permitted.contains), isTrue);
    expect(scheme.onPrimary, const Color(0xfffffdf8));
    expect(scheme.onError, const Color(0xfffffdf8));
    expect(scheme.scrim, const Color(0xff34365b));
  });

  test(
    'typography has explicit family, fallback and accepted role metrics',
    () {
      final text = PikoTheme.build().textTheme;
      void check(
        TextStyle style,
        double size,
        FontWeight weight,
        double height,
      ) {
        expect(style.fontFamily, 'Piko Nunito Sans');
        expect(style.fontFamilyFallback, contains('Piko Noto Sans KR'));
        expect(style.fontSize, size);
        expect(style.fontWeight, weight);
        expect(style.height, height);
        expect(style.letterSpacing, 0);
      }

      check(text.titleLarge!, 26, FontWeight.w700, 1.2);
      check(text.titleMedium!, 20, FontWeight.w700, 1.3);
      check(text.titleSmall!, 18, FontWeight.w700, 1.35);
      check(text.bodyMedium!, 16, FontWeight.w400, 1.5);
      check(text.labelLarge!, 14, FontWeight.w700, 1.4);
      check(text.bodySmall!, 14, FontWeight.w400, 1.45);
      check(text.displayLarge!, 37, FontWeight.w600, 1.3);
      check(text.displaySmall!, 22, FontWeight.w400, 1.4);
    },
  );

  testWidgets(
    'Speed gold role and consequence warning use accepted paired colors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PikoTheme.build(),
          home: Scaffold(
            body: PikoButton(
              label: 'Speed',
              variant: PikoButtonVariant.speed,
              onPressed: () {},
            ),
          ),
        ),
      );
      final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
      expect(style.backgroundColor!.resolve({}), const Color(0xffffe08a));
      expect(style.foregroundColor!.resolve({}), const Color(0xff34365b));
      expect(
        PikoTheme.warningBackground,
        Color.alphaBlend(
          const Color(0xffb42318).withValues(alpha: .12),
          const Color(0xfffffdf8),
        ),
      );
    },
  );

  testWidgets('font binaries and licenses resolve from the offline bundle', (
    tester,
  ) async {
    for (final font in ['NunitoSans', 'NotoSansKR']) {
      expect(
        (await rootBundle.load('assets/fonts/$font.ttf')).lengthInBytes,
        greaterThan(100000),
      );
      expect(
        await rootBundle.loadString('assets/fonts/$font-OFL.txt'),
        contains('SIL OPEN FONT LICENSE'),
      );
    }
  });

  testWidgets(
    'essential fields, growing controls and interactive layers share roles',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: 'ÄÖÜ äöü ß 0123 한국어');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: PikoTheme.build(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Column(
                children: [
                  PikoTextField(label: 'Übersetzung', controller: controller),
                  PikoButton(
                    label: 'Änderungen übernehmen',
                    onPressed: () {},
                    minimumSize: const Size(40, 40),
                  ),
                  const PikoButton(label: 'Deaktiviert', onPressed: null),
                ],
              ),
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style!.fontWeight, FontWeight.w400);
      expect(field.style!.height, 1.5);
      expect(
        field.decoration!.enabledBorder!.borderSide.color,
        const Color(0xff62657d),
      );
      expect(
        field.decoration!.enabledBorder!.borderSide.color,
        isNot(PikoTheme.border),
      );
      expect(
        field.decoration!.focusedBorder!.borderSide.color,
        pikoDesign.color('primary'),
      );
      expect(
        field.decoration!.errorBorder!.borderSide.color,
        pikoDesign.color('danger'),
      );
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        final minimum = button.style!.minimumSize!.resolve({})!;
        expect(minimum.width, greaterThanOrEqualTo(48));
        expect(minimum.height, greaterThanOrEqualTo(48));
        expect(
          button.style!.overlayColor!.resolve({WidgetState.pressed})!.a,
          closeTo(pikoDesign.dimension('states.pressedOpacity'), .001),
        );
        expect(
          button.style!.overlayColor!.resolve({WidgetState.disabled}),
          Colors.transparent,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
