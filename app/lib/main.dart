import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'shared/catalogs.dart';
import 'shared/copy_scope.dart';
import 'shared/interface_locale.dart';
import 'ui/piko_theme.dart';

void main() {
  runApp(const PikoApp());
}

class PikoApp extends StatelessWidget {
  const PikoApp({this.locale, this.localeController, this.home, super.key});

  final Locale? locale;
  final InterfaceLocaleController? localeController;
  final Widget? home;
  static const supportedLocales = InterfaceLocaleController.supportedLocales;

  @override
  Widget build(BuildContext context) {
    final controller = localeController;
    if (controller != null) {
      return ValueListenableBuilder<Locale>(
        valueListenable: controller,
        builder: (context, selected, child) => _localizedApp(selected),
      );
    }
    return _localizedApp(InterfaceLocaleController.resolve(locale));
  }

  Widget _localizedApp(Locale selected) {
    return PikoCopyScope(
      copy: PikoCopy(selected.languageCode),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: selected,
          supportedLocales: supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          title: PikoCopyScope.of(context).text('app.name'),
          theme: PikoTheme.build(),
          debugShowCheckedModeBanner: false,
          home: home ?? const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
  }
}
