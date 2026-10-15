import 'package:flutter/material.dart';
import '../shared/catalogs.dart';

const pikoDesign = PikoDesign();

abstract final class PikoTheme {
  static ThemeData build() {
    final d = pikoDesign;
    final scheme = ColorScheme.fromSeed(seedColor: d.color('primary')).copyWith(
      primary: d.color('primary'),
      onPrimary: d.color('onPrimary'),
      surface: d.color('surface'),
      onSurface: d.color('ink'),
      error: d.color('danger'),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: d.color('bg'),
      textTheme: TextTheme(
        bodyMedium: TextStyle(
          fontSize: d.dimension('typography.body'),
          color: d.color('ink'),
        ),
        titleLarge: TextStyle(
          fontSize: d.dimension('typography.title'),
          fontWeight: d.weight('typography.titleWeight'),
          color: d.color('ink'),
        ),
      ),
    );
  }

  static Color get border => Color.alphaBlend(
    pikoDesign
        .color('ink')
        .withValues(alpha: pikoDesign.dimension('states.borderInkOpacity')),
    pikoDesign.color('surface'),
  );

  static Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(
          milliseconds: pikoDesign.dimension('controls.motionFastMs').round(),
        );
}
