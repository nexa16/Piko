import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../piko_theme.dart';

/// Names of the pinned originals shared with the binding HTML mockup.
enum PikoIconName {
  alertTriangle('triangle-alert'),
  arrowLeft('arrow-left'),
  bookOpen('book-open'),
  chartNoAxesColumn('chart-no-axes-column'),
  check('check'),
  chevronRight('chevron-right'),
  ellipsis('ellipsis'),
  grid2x2('grid-2x2'),
  info('info'),
  layers('layers'),
  listFilter('list-filter'),
  pencil('pencil'),
  plus('plus'),
  rotateCcw('rotate-ccw'),
  search('search'),
  settings('settings'),
  tags('tags'),
  trash('trash'),
  upload('upload'),
  x('x'),
  zap('zap');

  const PikoIconName(this.fileName);
  final String fileName;
  String get assetPath => '$pikoIconAssetDirectory/$fileName.svg';
}

const pikoIconAssetDirectory = 'assets/generated/lucide';
bool _licensesRegistered = false;

/// Register once at startup; preserve the full ISC and Feather MIT notices.
void registerPikoIconLicenses() {
  if (_licensesRegistered) return;
  _licensesRegistered = true;
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString(
      '$pikoIconAssetDirectory/LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Lucide / Feather icons'], notice);
  });
}

/// Decorative by default. Actions receive their names from PikoIconButton.
class PikoIcon extends StatelessWidget {
  const PikoIcon(this.name, {this.semanticLabel, this.size, super.key});

  final PikoIconName name;
  final String? semanticLabel;
  final double? size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    name.assetPath,
    width: size ?? pikoDesign.dimension('components.icons.size'),
    height: size ?? pikoDesign.dimension('components.icons.size'),
    colorFilter: ColorFilter.mode(
      context
              .dependOnInheritedWidgetOfExactType<IconTheme>()
              ?.data
              .resolve(context)
              .color ??
          pikoDesign.color('ink'),
      BlendMode.srcIn,
    ),
    excludeFromSemantics: semanticLabel == null,
    semanticsLabel: semanticLabel,
  );
}
