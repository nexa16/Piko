import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'shared/catalogs.dart';
import 'shared/copy_scope.dart';
import 'shared/generated_catalogs.dart';
import 'ui/piko_theme.dart';

void main() {
  runApp(const PikoApp());
}

class PikoApp extends StatelessWidget {
  const PikoApp({this.locale, super.key});

  final Locale? locale;
  static const supportedLocales = [Locale('en'), Locale('de')];

  @override
  Widget build(BuildContext context) {
    final defaultLanguage = copyCatalog['defaultLocale']! as String;
    final selected = supportedLocales.firstWhere(
      (supported) => supported.languageCode == locale?.languageCode,
      orElse: () => Locale(defaultLanguage),
    );
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
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
  }
}
