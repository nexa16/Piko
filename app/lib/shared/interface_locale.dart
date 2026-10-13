import 'package:flutter/widgets.dart';
import 'generated_catalogs.dart';

/// Interface language only; never transforms vocabulary or collection data.
final class InterfaceLocaleController extends ValueNotifier<Locale> {
  InterfaceLocaleController([Locale? initial]) : super(resolve(initial));
  static const supportedLocales = [Locale('en'), Locale('de')];
  static Locale resolve(Locale? requested) => supportedLocales.firstWhere(
    (locale) => locale.languageCode == requested?.languageCode,
    orElse: () => Locale(copyCatalog['defaultLocale']! as String),
  );
  @override
  set value(Locale requested) => super.value = resolve(requested);
}
