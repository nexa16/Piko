import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../shared/catalogs.dart';

const pikoDesign = PikoDesign();

abstract final class PikoTheme {
  static bool _fontLicensesRegistered = false;

  static void _registerFontLicenses() {
    if (_fontLicensesRegistered) return;
    _fontLicensesRegistered = true;
    LicenseRegistry.addLicense(() async* {
      for (final font in ['NunitoSans', 'NotoSansKR']) {
        yield LicenseEntryWithLineBreaks([
          font,
        ], await rootBundle.loadString('assets/fonts/$font-OFL.txt'));
      }
    });
  }

  static ThemeData build() {
    _registerFontLicenses();
    final d = pikoDesign;
    // Map every Material role explicitly: generated tonal palettes would add
    // unreviewed colors to native controls, menus and their state layers.
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: d.color('primary'),
      onPrimary: d.color('onPrimary'),
      primaryContainer: d.color('tint'),
      onPrimaryContainer: d.color('ink'),
      primaryFixed: d.color('tint'),
      primaryFixedDim: d.color('tint'),
      onPrimaryFixed: d.color('ink'),
      onPrimaryFixedVariant: d.color('primary'),
      secondary: d.color('primary'),
      onSecondary: d.color('onPrimary'),
      secondaryContainer: d.color('tint'),
      onSecondaryContainer: d.color('ink'),
      secondaryFixed: d.color('tint'),
      secondaryFixedDim: d.color('tint'),
      onSecondaryFixed: d.color('ink'),
      onSecondaryFixedVariant: d.color('primary'),
      tertiary: d.color('gold'),
      onTertiary: d.color('ink'),
      tertiaryContainer: d.color('gold'),
      onTertiaryContainer: d.color('ink'),
      tertiaryFixed: d.color('gold'),
      tertiaryFixedDim: d.color('gold'),
      onTertiaryFixed: d.color('ink'),
      onTertiaryFixedVariant: d.color('ink'),
      surface: d.color('surface'),
      onSurface: d.color('ink'),
      surfaceDim: d.color('bg'),
      surfaceBright: d.color('surface'),
      surfaceContainerLowest: d.color('surface'),
      surfaceContainerLow: d.color('surface'),
      surfaceContainer: d.color('surface'),
      surfaceContainerHigh: d.color('tint'),
      surfaceContainerHighest: d.color('tint'),
      onSurfaceVariant: d.color('muted'),
      outline: d.color('muted'),
      outlineVariant: border,
      shadow: d.color('ink'),
      scrim: d.color('ink'),
      inverseSurface: d.color('ink'),
      onInverseSurface: d.color('surface'),
      inversePrimary: d.color('tint'),
      surfaceTint: d.color('surface'),
      error: d.color('danger'),
      onError: d.color('onDanger'),
      errorContainer: d.color('surface'),
      onErrorContainer: d.color('danger'),
    );
    TextStyle role(String size, String weight, String height) => TextStyle(
      fontFamily: d.text('typography.family'),
      fontFamilyFallback: [d.text('typography.fallback')],
      fontSize: d.dimension('typography.$size'),
      fontWeight: d.weight('typography.$weight'),
      height: d.dimension('typography.$height'),
      letterSpacing: 0,
      color: d.color('ink'),
    );
    final body = role('body', 'bodyWeight', 'bodyLineHeight');
    final helper = role('helper', 'bodyWeight', 'helperLineHeight');
    final control = role('control', 'controlWeight', 'controlLineHeight');
    return ThemeData(
      colorScheme: scheme,
      fontFamily: d.text('typography.family'),
      fontFamilyFallback: [d.text('typography.fallback')],
      scaffoldBackgroundColor: d.color('bg'),
      canvasColor: d.color('surface'),
      cardColor: d.color('surface'),
      dividerColor: border,
      disabledColor: d
          .color('muted')
          .withValues(alpha: d.dimension('states.disabledOpacity')),
      shadowColor: d.color('ink'),
      splashColor: d
          .color('primary')
          .withValues(alpha: d.dimension('states.pressedOpacity')),
      highlightColor: d
          .color('primary')
          .withValues(alpha: d.dimension('states.pressedOpacity')),
      hoverColor: d
          .color('primary')
          .withValues(alpha: d.dimension('states.hoverOpacity')),
      focusColor: d
          .color('primary')
          .withValues(alpha: d.dimension('states.focusOpacity')),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: d.color('primary'),
        selectionColor: d
            .color('primary')
            .withValues(alpha: d.dimension('states.selectionOpacity')),
        selectionHandleColor: d.color('primary'),
      ),
      textTheme: TextTheme(
        displayLarge: role('answer', 'answerWeight', 'answerLineHeight'),
        displayMedium: role('answer', 'answerWeight', 'answerLineHeight'),
        displaySmall: role(
          'answerPrompt',
          'answerPromptWeight',
          'answerPromptLineHeight',
        ),
        headlineLarge: role('title', 'titleWeight', 'titleLineHeight'),
        headlineMedium: role(
          'dialogTitle',
          'dialogTitleWeight',
          'dialogLineHeight',
        ),
        headlineSmall: role('section', 'sectionWeight', 'sectionLineHeight'),
        titleLarge: role('title', 'titleWeight', 'titleLineHeight'),
        titleMedium: role(
          'dialogTitle',
          'dialogTitleWeight',
          'dialogLineHeight',
        ),
        titleSmall: role('section', 'sectionWeight', 'sectionLineHeight'),
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: helper.copyWith(color: d.color('muted')),
        labelLarge: control,
        labelMedium: control,
        labelSmall: helper,
      ),
    );
  }

  static Color get border => Color.alphaBlend(
    pikoDesign
        .color('ink')
        .withValues(alpha: pikoDesign.dimension('states.borderInkOpacity')),
    pikoDesign.color('surface'),
  );

  static Color get warningBackground => Color.alphaBlend(
    pikoDesign
        .color('danger')
        .withValues(alpha: pikoDesign.dimension('states.warningOpacity')),
    pikoDesign.color('surface'),
  );

  static Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(
          milliseconds: pikoDesign.dimension('controls.motionFastMs').round(),
        );
}
