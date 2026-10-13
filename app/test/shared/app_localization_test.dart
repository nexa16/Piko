import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/copy_scope.dart';

void main() {
  testWidgets('German device still starts with explicit English default', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(const PikoApp());
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context), const Locale('en'));
    expect(PikoCopyScope.of(context).locale, 'en');
    expect(MaterialLocalizations.of(context).closeButtonTooltip, 'Close');
  });

  testWidgets('explicit German aligns native controls and canonical copy', (
    tester,
  ) async {
    await tester.pumpWidget(const PikoApp(locale: Locale('de', 'AT')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context), const Locale('de'));
    expect(PikoCopyScope.of(context).locale, 'de');
    expect(MaterialLocalizations.of(context).closeButtonTooltip, 'Schließen');
    expect(
      MaterialLocalizations.of(context).selectAllButtonLabel,
      'Alle auswählen',
    );
  });

  testWidgets(
    'unsupported locale falls back for both copy and native controls',
    (tester) async {
      await tester.pumpWidget(const PikoApp(locale: Locale('fr')));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold));
      expect(Localizations.localeOf(context), const Locale('en'));
      expect(PikoCopyScope.of(context).locale, 'en');
    },
  );
}
