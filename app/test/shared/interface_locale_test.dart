import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/shared/interface_locale.dart';

void main() {
  testWidgets('live interface language preserves input, selection and focus', (
    tester,
  ) async {
    final language = InterfaceLocaleController();
    final input = TextEditingController(text: '학교');
    final focus = FocusNode();
    addTearDown(language.dispose);
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    final home = Scaffold(
      body: Builder(
        builder: (context) => TextField(
          controller: input,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: PikoCopyScope.of(context).text('collection.name'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(PikoApp(localeController: language, home: home));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    input.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
    await tester.pump();
    expect(
      find.text(const PikoCopy('en').text('collection.name')),
      findsOneWidget,
    );
    language.value = const Locale('de');
    await tester.pumpAndSettle();
    expect(
      find.text(const PikoCopy('de').text('collection.name')),
      findsOneWidget,
    );
    expect(input.text, '학교');
    expect(
      input.selection,
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    expect(focus.hasFocus, isTrue);
    expect(
      Localizations.localeOf(tester.element(find.byType(TextField))),
      const Locale('de'),
    );
  });
  test('controller consistently resolves unsupported and regional locales', () {
    final language = InterfaceLocaleController(const Locale('de', 'AT'));
    addTearDown(language.dispose);
    expect(language.value, const Locale('de'));
    language.value = const Locale('ko');
    expect(language.value, const Locale('en'));
  });
}
